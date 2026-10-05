function R = g1_detect_v6(D, NM, opt)
%G1_DETECT_V6 G1 v6 detector: v5 (g1_detect_v5.m) with three changes from
%   bulgular.md sections 13-15. Each is a switch so it can be ablated; with
%   all four switches off (tsrc "lag", eventEnd, offsetEvent, unreliable
%   false) the detector is v5 operation for operation.
%
%   A. Temperature-source model L (opt.tsrc, section 15). The lead-lag
%      model of g1_tsrc_v6.m (structure "leadlag", no grid term, no frozen
%      floor) replaces v5's single-lag model. That model reads only the
%      temperatures and is gated only by its own zT, so it is computed once
%      up front with the detector's own warm/zU/thrT/lambda/grid settings.
%      "lag" gives v5's model (equal to v5, bulgular 15 C1).
%
%   B. Event-end release (opt.eventEnd, 12D/13E). A flagged channel whose
%      episode reached |z| >= zBig and whose |z| has then stayed below zU
%      for nEnd blocks in a row is released at once (CUSUM reset), without
%      waiting for the Wrel-block growth test. A drift does not end like
%      this; an external event (EMI) does. The model was frozen during the
%      event, so it is still valid and is not recalibrated.
%
%   C. Multi-state output (12B, 12E, 13B, 13C; user decisions in section 15).
%      Per channel and block: 0 healthy, 1 fault, 2 offset event, 3 model
%      unreliable (R.state).
%      C1 offset event (opt.offsetEvent). When v5's growth test (C) releases
%         a flagged channel, the deviation has stopped growing: a persistent
%         offset. It is reported as an offset event on that block and the
%         channel is recalibrated: the offset state's variance is reset to
%         its start value (cross terms zeroed), so the next accepted
%         update takes the new offset. A persistent offset is not a fault
%         (user decision); an offset event on a healthy channel counts as a
%         false-alarm event in the evaluation.
%      C2 model unreliable (opt.unreliable). Lag-1 autocorrelation r1 of
%         each channel's signed innovation over the last Wac blocks. Under
%         a correct model the innovations are white and r1 ~ N(0, 1/Wac),
%         so the threshold is rThr = 3/sqrt(Wac) (not tuned). The model is
%         unreliable when channels with r1 > rThr span >= 2 sensing
%         elements (gyro/accel/mag) while the temperature has moved within
%         the last Wac blocks. Those channels get no CUSUM evidence and
%         their CUSUM is reset; they are reported as "unreliable", not
%         blamed. A drift on one channel also gives a high r1, which is why
%         two elements are required; it can still be masked while another
%         element is mismatched, and then re-accumulates afterwards
%         (measured as delay; the share of unreliable time is capped by a
%         criterion, section 15).
%
%   Parameters declared before any v6 channel result: zBig 10, nEnd 5,
%   Wac 30 (= Wrel), rThr 3/sqrt(Wac), 2 sensing elements (= fix 1).
%   Uses only firmware-visible fields of D, NM and the channel grouping.

o = struct( ...
    'warm',        30, ...          % blocks of unconditional learning at start
    'zU',          3, ...           % update gate |z| < zU
    'thrT',        5, ...           % temperature-source disagreement threshold
    'nCommon',     3, ...           % >= this many channels break together ...
    'moveLag',     5, ...           % ... while temperature moved over this many blocks ...
    'thermalMove', 0.1, ...         % ... by more than this [degC] or direction flipped ...
    'group',       [1 1 1 2 2 2 3 3 3], ...  % ... in >= 2 of these sensing elements (v4 fix 1)
    'ambiguous',   true, ...        % tie in temperature-source blame -> no blame (v4 fix 2)
    'modelHorizon', 24*60, ...      % blocks over which b, c may move by sb (v4 fix 3)
    'floorMode',   "frozen", ...    % model-error floor only while flagged (v5 B)
    'Smax',        20, ...          % CUSUM cap (v5 A)
    'release',     true, ...        % growth-based release test (v5 C)
    'Wrel',        30, ...
    'tCrit',       2.467, ...
    'resetOnSwitch', true, ...      % v5 D
    'lambda',      1 - 1/(24*60), ...
    'cusum',       "signed", ...
    'kSigned',     0.5, ...
    'kappa',       1.5, ...
    'h',           10, ...
    'wGrid',       [0.2 0.5 1 1.5 2], ...
    'tauGrid',     0:20:300, ...
    'inflMax',     1.5, ...
    'sigmaTFloor', 0.02, ...
    'tsrc',        "leadlag", ...   % (A) "leadlag" | "lag" (v5)
    'eventEnd',    true, ...        % (B)
    'zBig',        10, ...          % ... episode peak |z| that marks an event
    'nEnd',        5, ...           % ... quiet blocks after it
    'offsetEvent', true, ...        % (C1)
    'unreliable',  true, ...        % (C2)
    'Wac',         30, ...          % ... autocorrelation window [blocks]
    'rThr',        3/sqrt(30), ...  % ... 3 sigma of r1 under white innovations
    'nGroupsUnrel', 2, ...          % ... sensing elements needed
    'refMask',     [true true], ... % diagnostic only: references allowed for channel decisions [ICM BME]
    'trace',       false);          % diagnostic only: record offset and tempco of each channel model
if nargin > 2
    for f = fieldnames(opt)', o.(f{1}) = opt.(f{1}); end
end

Y = D.Y;
[nB, nC] = size(Y);
Tr = [D.TicmB, D.TbmeB];
T0 = Tr(1, :);
nW = numel(o.wGrid);
dr = zeros(nB, 2, nW);
for r = 1:2
    for iw = 1:nW
        dr(:, r, iw) = playDir(Tr(:, r), o.wGrid(iw));
    end
end

sb = [0.005 0.005 0.005 0.15 0.15 0.15 0.05 0.05 0.05];

F = zeros(4, 4, nC);  Q = F;  Qm = F;
for c = 1:nC
    qm = sb(c)^2 / o.modelHorizon;
    F(:, :, c)  = diag([1, NM.phi(c), 1, 1]);
    Q(:, :, c)  = diag([NM.q(c), NM.qg(c), 0, 0]);
    Qm(:, :, c) = diag([0, 0, qm, qm]);
end
flag = false(1, nC);
rv  = NM.r;
sSS = steadyStd(NM);
var0 = (100*sSS).^2;                % start variance of the offset state (also C1)

theta = zeros(4, nC, 2, nW);
Pm    = zeros(4, 4, nC, 2, nW);
for r = 1:2
    for c = 1:nC
        for iw = 1:nW
            theta(:, c, r, iw) = [Y(1, c); 0; 0; 0];
            Pm(:, :, c, r, iw) = diag([var0(c), NM.sg2(c), sb(c)^2, sb(c)^2]);
        end
    end
end
sseW = zeros(2, nW);

% (A) temperature-source model, computed up front (reads temperatures only)
tsOpt = struct('warm', o.warm, 'zU', o.zU, 'thrT', o.thrT, 'lambda', o.lambda, ...
    'tauGrid', o.tauGrid, 'sigmaTFloor', o.sigmaTFloor, 'gridErr', false, 'frozenFloor', false);
if o.tsrc == "leadlag", tsOpt.structure = "leadlag"; else, tsOpt.structure = "lag"; end
TS = g1_tsrc_v6(D, tsOpt);

% Outputs
R.zI = nan(nB, nC);  R.zB = R.zI;  R.score = zeros(nB, nC);  R.infl = R.zI;  R.r1 = R.zI;
R.zT = TS.zT;  R.tauBest = TS.tau;  R.wBest = nan(nB, 2);
R.common = false(nB, 1);  R.unrel = false(nB, 1);
R.sensorFlag = false(nB, nC);  R.unreliable = R.sensorFlag;  R.offsetEvent = R.sensorFlag;
R.state = zeros(nB, nC, 'uint8');
R.tempFlag = false(nB, 1);  R.blameBme = R.tempFlag;  R.blameIcm = R.tempFlag;  R.tempAmbig = R.tempFlag;
R.released = false(nB, nC);  R.releaseType = zeros(nB, nC, 'uint8');  R.switchReset = false(nB, 1);
if o.trace, R.thA = nan(nB, nC, 2);  R.thB = R.thA;  R.usable = false(nB, 2); end

Sp = zeros(1, nC);  Sn = Sp;
iwPrev = [];
zHist  = zeros(o.Wrel, nC);         % signed z of flagged channels, ring buffer (v5 C)
nFroz  = zeros(1, nC);
acBuf  = zeros(o.Wac, nC);          % signed z of every channel, ring buffer (C2)
nAc    = 0;
lastMove = -Inf;                    % last block with thermal movement (C2)
peakZ  = zeros(1, nC);              % largest |z| of the current flagged episode (B)
quiet  = zeros(1, nC);              % quiet blocks in a row while flagged (B)
for k = 1:nB
    decide = k > o.warm;

    % --- time update of every model (also the frozen ones)
    if k > 1
        useFloor = (o.floorMode == "always") | (o.floorMode == "frozen" & flag);
        for r = 1:2
            for iw = 1:nW
                for c = 1:nC
                    theta(:, c, r, iw) = F(:, :, c) * theta(:, c, r, iw);
                    Pm(:, :, c, r, iw) = F(:, :, c) * Pm(:, :, c, r, iw) * F(:, :, c)' ...
                        + Q(:, :, c) + useFloor(c) * Qm(:, :, c);
                end
            end
        end
    end

    zT = TS.zT(k);

    % --- channel innovations against both references, all width candidates
    zAll = zeros(nC, 2, nW);  sAll = zAll;
    for r = 1:2
        for iw = 1:nW
            x = [1; 1; Tr(k, r) - T0(r); dr(k, r, iw)];
            for c = 1:nC
                e = Y(k, c) - x' * theta(:, c, r, iw);
                sAll(c, r, iw) = sqrt(rv(c) + x' * Pm(:, :, c, r, iw) * x);
                zAll(c, r, iw) = e / sAll(c, r, iw);
            end
        end
    end
    [~, iwb] = min(sseW, [], 2);
    zc = [zAll(:, 1, iwb(1)), zAll(:, 2, iwb(2))];
    sc = [sAll(:, 1, iwb(1)), sAll(:, 2, iwb(2))];

    % --- blame a temperature source?
    tf   = decide && abs(zT) > o.thrT;
    nbad = sum(abs(zc) > o.zU, 1);
    bB   = tf && nbad(2) > nbad(1);
    if o.ambiguous
        bI = tf && nbad(1) > nbad(2);
    else
        bI = tf && ~bB;
    end
    amb  = tf && ~bB && ~bI;
    usable = [~bI, ~bB] & o.refMask;
    if ~any(usable), usable = o.refMask; end   % only reachable with a refMask

    % --- channel anomaly, common-mode event
    Zu = zc(:, usable);
    [a, iu] = min(abs(Zu), [], 2);
    zs = Zu(sub2ind(size(Zu), (1:nC)', iu))';
    a  = a';
    dNow = dr(k, 1, iwb(1));
    moved = k > o.moveLag && ...
        (abs(Tr(k, 1) - Tr(k - o.moveLag, 1)) > o.thermalMove || ...
         abs(dNow - dr(k - o.moveLag, 1, iwb(1))) > 0.5);
    brk = a > o.zU;
    com = decide && moved && nnz(brk) >= o.nCommon && ...
        numel(unique(o.group(brk))) >= 2;
    zRaw = zs;

    % (C2) model unreliable: correlated innovations on >= 2 sensing elements
    % while the temperature has recently moved
    if moved, lastMove = k; end
    uset = false(1, nC);
    if o.unreliable && decide
        nAc = nAc + 1;
        acBuf(mod(nAc - 1, o.Wac) + 1, :) = zRaw;
        if nAc >= o.Wac
            idx = mod((nAc - o.Wac : nAc - 1), o.Wac) + 1;   % oldest -> newest
            W = acBuf(idx, :) - mean(acBuf, 1);
            den = sum(W.^2, 1);
            r1 = sum(W(2:end, :) .* W(1:end-1, :), 1) ./ max(den, eps);
            R.r1(k, :) = r1;
            hi = r1 > o.rThr;
            if (k - lastMove) < o.Wac && numel(unique(o.group(hi))) >= o.nGroupsUnrel
                uset = hi;
            end
        end
    end
    if any(uset), zs(uset) = 0; end

    % (v5 D) reset on a width switch
    sw = o.resetOnSwitch && ~isempty(iwPrev) && any(iwb(:) ~= iwPrev(:));
    if sw
        Sp(~flag) = 0;  Sn(~flag) = 0;
    end
    iwPrev = iwb;
    if o.cusum == "signed"
        if com, zs(:) = 0; end
        Sp = max(0, Sp + zs - o.kSigned);
        Sn = max(0, Sn - zs - o.kSigned);
    else
        inc = a - o.kappa;
        if com, inc(:) = -o.kappa; end
        Sp = max(0, Sp + inc);
    end
    Sp = min(Sp, o.Smax);  Sn = min(Sn, o.Smax);
    if ~decide, Sp(:) = 0; Sn(:) = 0; end
    if any(uset), Sp(uset) = 0; Sn(uset) = 0; end      % (C2) not blamed
    S = max(Sp, Sn);
    flag = decide & (S > o.h);

    % (B) event-end release, then (v5 C) growth-based release
    rel = false(1, nC);  rtype = zeros(1, nC, 'uint8');
    nFroz(~flag) = 0;  peakZ(~flag) = 0;  quiet(~flag) = 0;
    for c = find(flag)
        nFroz(c) = nFroz(c) + 1;
        zHist(mod(nFroz(c) - 1, o.Wrel) + 1, c) = zRaw(c);
        peakZ(c) = max(peakZ(c), abs(zRaw(c)));
        if abs(zRaw(c)) < o.zU, quiet(c) = quiet(c) + 1; else, quiet(c) = 0; end
        if o.eventEnd && peakZ(c) >= o.zBig && quiet(c) >= o.nEnd
            rel(c) = true;  rtype(c) = 1;
            continue
        end
        if ~o.release || nFroz(c) < o.Wrel, continue; end
        n  = (nFroz(c) - o.Wrel + 1 : nFroz(c))';
        zw = zHist(mod(n - 1, o.Wrel) + 1, c);
        y  = sign(sum(zw)) * zw;
        u  = sqrt(n) - mean(sqrt(n));
        beta = (u' * (y - mean(y))) / (u' * u);
        res  = y - mean(y) - beta * u;
        se   = sqrt((res' * res) / (o.Wrel - 2) / (u' * u));
        tst  = beta / max(se, eps);
        if tst < o.tCrit && max(abs(zw)) < o.zU
            rel(c) = true;  rtype(c) = 2;
        end
    end
    if any(rel)
        Sp(rel) = 0;  Sn(rel) = 0;  S(rel) = 0;
        flag(rel) = false;  nFroz(rel) = 0;  peakZ(rel) = 0;  quiet(rel) = 0;
    end
    % (C1) a growth-test release is an offset event: recalibrate the offset
    ofs = o.offsetEvent & rtype == 2;
    for c = find(ofs)
        for r = 1:2
            for iw = 1:nW
                Pm(1, :, c, r, iw) = 0;  Pm(:, 1, c, r, iw) = 0;
                Pm(1, 1, c, r, iw) = var0(c);
            end
        end
    end

    if o.trace                      % prior state of the selected width, per reference
        for r = 1:2
            R.thA(k, :, r) = theta(1, :, r, iwb(r));
            R.thB(k, :, r) = theta(3, :, r, iwb(r));
        end
        R.usable(k, :) = usable;
    end

    % --- measurement updates (gated), for every width candidate
    for r = 1:2
        accepted = false(1, nC);
        for c = 1:nC
            accepted(c) = ~decide || (usable(r) && ~flag(c) && (abs(zc(c, r)) < o.zU || com));
            if ~accepted(c), continue; end
            for iw = 1:nW
                x = [1; 1; Tr(k, r) - T0(r); dr(k, r, iw)];
                [theta(:, c, r, iw), Pm(:, :, c, r, iw)] = kfUpdate(theta(:, c, r, iw), ...
                    Pm(:, :, c, r, iw), x, Y(k, c), rv(c));
            end
        end
        if any(accepted)
            capped = min(reshape(zAll(accepted, r, :), [], nW).^2, o.zU^2);
            sseW(r, :) = o.lambda * sseW(r, :) + sum(capped, 1);
        end
    end

    % --- record
    st = zeros(1, nC, 'uint8');
    st(flag) = 1;  st(ofs) = 2;  st(uset) = 3;
    R.zI(k, :) = zc(:, 1)';   R.zB(k, :) = zc(:, 2)';
    R.infl(k, :) = (sc(:, 1) ./ sSS(:))';
    R.wBest(k, :) = o.wGrid(iwb);
    R.common(k) = com;  R.unrel(k) = any(uset);
    R.score(k, :) = S;  R.sensorFlag(k, :) = flag;
    R.unreliable(k, :) = uset;  R.offsetEvent(k, :) = ofs;  R.state(k, :) = st;
    R.tempFlag(k) = tf;  R.blameBme(k) = bB;  R.blameIcm(k) = bI;  R.tempAmbig(k) = amb;
    R.released(k, :) = rel;  R.releaseType(k, :) = rtype;  R.switchReset(k) = sw;
end

R.name    = "G1 v6";
R.valid   = (1:nB)' > o.warm;
R.lowConf = R.infl > o.inflMax;
R.tsrc    = TS;
R.opt     = o;
end

%% Helpers (as in g1_detect_v5.m)
function [th, P] = kfUpdate(th, P, x, y, r)
    Px = P * x;
    K  = Px / (x' * Px + r);
    th = th + K * (y - x' * th);
    P  = P - K * Px';
    P  = (P + P') / 2;
end

function s = steadyStd(NM)
    nC = numel(NM.r);
    s  = zeros(1, nC);
    H  = [1 1];
    for c = 1:nC
        F2 = diag([1, NM.phi(c)]);  Q2 = diag([NM.q(c), NM.qg(c)]);
        P  = diag([0, NM.sg2(c)]);
        for it = 1:5000
            P  = F2*P*F2' + Q2;
            s2 = H*P*H' + NM.r(c);
            K  = P*H' / s2;
            P  = P - K*H*P;
        end
        s(c) = sqrt(s2);
    end
end

function d = playDir(T, w)
    d = zeros(size(T));
    p = T(1);
    for k = 1:numel(T)
        p = min(max(p, T(k) - w/2), T(k) + w/2);
        d(k) = (T(k) - p) / (w/2);
    end
end
