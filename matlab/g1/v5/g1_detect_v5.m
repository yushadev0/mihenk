function R = g1_detect_v5(D, NM, opt)
%G1_DETECT_V5 G1 v5 detector: v4 (g1_detect_v4.m) with four changes from
%   bulgular.md section 10 (A-D). Fixes 1 and 2 of v4 stay as they are.
%
%   A. CUSUM cap (opt.Smax, finding 10B). During a large excursion (EMI:
%      |z| in the hundreds for ~20 blocks) the CUSUM collected thousands of
%      units and then drained by only k = 0.5 per block, so the channel
%      stayed flagged for the rest of the run although its residuals were
%      back to normal. A value above the alarm level h adds nothing to the
%      decision, so S is capped at Smax = 2h: after the excursion ends the
%      flag clears within (Smax - h)/k = 20 blocks. Inf restores v4.
%
%   B. Model-error floor only while frozen (opt.floorMode, 10C). In v4 the
%      tempco b and hysteresis c were random walks all the time, so on a
%      temperature ramp a drift was partly explained as a changing tempco
%      (finding 6F): +45 min delay. The floor is there to let a frozen
%      channel be released, so now it only acts while the channel is
%      flagged (its models are not updated): learning stays rigid, a frozen
%      channel's prediction variance grows by the model error. A real
%      drift grows like t, the floor's prediction std like sqrt(t), so a
%      fault should stay flagged. "always" restores v4, "off" v4nf.
%
%   C. Growth-based release (opt.release, finding 10F). A frozen channel's
%      innovation does not return to zero after a benign deviation: the
%      deviation and the prediction std grow alike, z stays at ~0.8 with a
%      fixed sign, and a CUSUM with k = 0.5 never drains. Under a drift z
%      grows like sqrt(t). So a flagged channel is released (CUSUM reset)
%      when, over the last Wrel = 30 blocks, z has no significant growth
%      (one-sided t-test of the slope of z vs sqrt(time since freeze),
%      alpha 0.01) and |z| < zU. Wrel and alpha were declared before any
%      v5 result was seen.
%
%   D. CUSUM reset on a model switch (opt.resetOnSwitch, 10F). Before the
%      first thermal excitation the hysteresis width is not identified; at
%      the first ramp the wrong width gives a 3-4 sigma transient that can
%      reach the alarm level before the width choice catches up. When the
%      width choice of either reference changes, the CUSUM of unflagged
%      channels is reset.
%
%   Everything else is v4 unchanged. Uses only firmware-visible fields of
%   D (Y, TicmB, TbmeB, Ticm, S), NM and the channel grouping.

o = struct( ...
    'warm',        30, ...          % blocks of unconditional learning at start
    'zU',          3, ...           % update gate |z| < zU
    'thrT',        5, ...           % temperature-source disagreement threshold
    'nCommon',     3, ...           % >= this many channels break together ...
    'moveLag',     5, ...           % ... while temperature moved over this many blocks ...
    'thermalMove', 0.1, ...         % ... by more than this [degC] or direction flipped ...
    'group',       [1 1 1 2 2 2 3 3 3], ...  % ... in >= 2 of these sensing elements (fix 1)
    'ambiguous',   true, ...        % tie in temperature-source blame -> no blame (fix 2)
    'modelHorizon', 24*60, ...      % blocks over which b, c may move by sb (v4 fix 3)
    'floorMode',   "frozen", ...    % model-error floor: "frozen" (B) | "always" (v4) | "off" (v4nf)
    'Smax',        20, ...          % CUSUM cap (A), 2h; Inf = v4
    'release',     true, ...        % growth-based release test for flagged channels (C)
    'Wrel',        30, ...          % ... window [blocks] (declared before any v5 result)
    'tCrit',       2.467, ...       % ... one-sided t, alpha 0.01, df = Wrel - 2 = 28
    'resetOnSwitch', true, ...      % reset CUSUM of unflagged channels when the width choice changes (D)
    'lambda',      1 - 1/(24*60), ...  % forgetting of grid scores and T-source model: ~24 h
    'cusum',       "signed", ...    % "signed" (Page, two one-sided) | "abs" (v1: |z| - kappa)
    'kSigned',     0.5, ...         % signed CUSUM reference: detects a 1-sigma mean shift
    'kappa',       1.5, ...         % abs CUSUM slack (v1)
    'h',           10, ...          % CUSUM alarm level; signed, k 0.5: ARL0 ~1e5 blocks per side
    'wGrid',       [0.2 0.5 1 1.5 2], ...  % hysteresis width candidates [degC]
    'tauGrid',     0:20:300, ...    % lag candidates between temperature sources [s]
    'inflMax',     1.5, ...         % prediction std / steady-state std above this = low confidence
    'sigmaTFloor', 0.02);           % [degC]
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

% Tempco prior per channel: gyro dps/degC, accel mg/degC (datasheet bounds),
% mag uT/degC (assumed) - the only sensor knowledge besides NM
sb = [0.005 0.005 0.005 0.15 0.15 0.15 0.05 0.05 0.05];

% Noise model: state [a g b c], F = diag(1, phi, 1, 1), Q = diag(q, qg, 0, 0)
% Model-error floor Qm = diag(0, 0, qm, qm) on tempco and hysteresis, added
% always (v4), only while the channel is flagged (B), or never
F = zeros(4, 4, nC);  Q = F;  Qm = F;
for c = 1:nC
    qm = sb(c)^2 / o.modelHorizon;
    F(:, :, c)  = diag([1, NM.phi(c), 1, 1]);
    Q(:, :, c)  = diag([NM.q(c), NM.qg(c), 0, 0]);
    Qm(:, :, c) = diag([0, 0, qm, qm]);
end
flag = false(1, nC);               % flags of the previous block
rv  = NM.r;
sSS = steadyStd(NM);               % innovation std of a fully learned model

theta = zeros(4, nC, 2, nW);
Pm    = zeros(4, 4, nC, 2, nW);
for r = 1:2
    for c = 1:nC
        for iw = 1:nW
            theta(:, c, r, iw) = [Y(1, c); 0; 0; 0];
            Pm(:, :, c, r, iw) = diag([(100*sSS(c))^2, NM.sg2(c), sb(c)^2, sb(c)^2]);
        end
    end
end
sseW = zeros(2, nW);

% Temperature-source model candidates: T_bme = a + b*(lag(T_icm, tau) - L0)  (v1)
nJ = numel(o.tauGrid);
LB = zeros(nB, nJ);
for j = 1:nJ
    L = lagFilter(D.Ticm, o.tauGrid(j), D.S.dtT);
    LB(:, j) = mean(reshape(L, D.S.B/D.S.dtT, nB), 1)';
end
L0    = LB(1, :);
thT   = repmat([D.TbmeB(1); 1], 1, nJ);
PT    = repmat(diag([25, 0.1^2]), 1, 1, nJ);
sigT0 = max(std(diff(D.TbmeB(1:o.warm) - D.TicmB(1:o.warm))) / sqrt(2), o.sigmaTFloor);
sig2T = repmat(sigT0^2, 1, nJ);
sseT  = zeros(1, nJ);

% Outputs
R.zI = nan(nB, nC);  R.zB = R.zI;  R.score = zeros(nB, nC);  R.infl = R.zI;
R.zT = nan(nB, 1);   R.tauBest = nan(nB, 1);  R.wBest = nan(nB, 2);
R.common = false(nB, 1);
R.sensorFlag = false(nB, nC);
R.tempFlag = false(nB, 1);  R.blameBme = R.tempFlag;  R.blameIcm = R.tempFlag;  R.tempAmbig = R.tempFlag;
R.released = false(nB, nC);  R.switchReset = false(nB, 1);

Sp = zeros(1, nC);  Sn = Sp;
iwPrev = [];                       % width choice of the previous block (D)
zHist  = zeros(o.Wrel, nC);        % signed z of flagged channels, ring buffer (C)
nFroz  = zeros(1, nC);             % blocks flagged in a row (C)
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

    % --- temperature-source consistency (best lag so far)
    eT = zeros(1, nJ);  sT = eT;
    for j = 1:nJ
        x = [1; LB(k, j) - L0(j)];
        eT(j) = D.TbmeB(k) - x' * thT(:, j);
        sT(j) = sqrt(sig2T(j) + x' * PT(:, :, j) * x);
    end
    [~, jb] = min(sseT);
    zT = eT(jb) / sT(jb);

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
    [~, iwb] = min(sseW, [], 2);                   % best width per reference
    zc = [zAll(:, 1, iwb(1)), zAll(:, 2, iwb(2))];
    sc = [sAll(:, 1, iwb(1)), sAll(:, 2, iwb(2))];

    % --- blame a temperature source?
    tf   = decide && abs(zT) > o.thrT;
    nbad = sum(abs(zc) > o.zU, 1);                 % [vs ICM, vs BME]
    bB   = tf && nbad(2) > nbad(1);
    if o.ambiguous
        bI = tf && nbad(1) > nbad(2);              % tie: no source blamed (fix 2)
    else
        bI = tf && ~bB;                            % v3: tie blames the ICM
    end
    amb  = tf && ~bB && ~bI;
    usable = [~bI, ~bB];

    % --- channel anomaly, common-mode event, CUSUM
    Zu = zc(:, usable);
    [a, iu] = min(abs(Zu), [], 2);                 % best-explaining usable reference
    zs = Zu(sub2ind(size(Zu), (1:nC)', iu))';      % ... with its sign
    a  = a';
    dNow = dr(k, 1, iwb(1));
    moved = k > o.moveLag && ...
        (abs(Tr(k, 1) - Tr(k - o.moveLag, 1)) > o.thermalMove || ...
         abs(dNow - dr(k - o.moveLag, 1, iwb(1))) > 0.5);
    brk = a > o.zU;
    com = decide && moved && nnz(brk) >= o.nCommon && ...
        numel(unique(o.group(brk))) >= 2;          % >= 2 sensing elements (fix 1)
    zRaw = zs;                                     % before common-mode zeroing (C)

    % (D) innovations collected under a rejected width hypothesis are no
    % evidence against a channel: reset the CUSUM of unflagged channels
    % when the width choice of either reference changes
    sw = o.resetOnSwitch && ~isempty(iwPrev) && any(iwb(:) ~= iwPrev(:));
    if sw
        Sp(~flag) = 0;  Sn(~flag) = 0;
    end
    iwPrev = iwb;
    if o.cusum == "signed"
        if com, zs(:) = 0; end                     % drain both sides
        Sp = max(0, Sp + zs - o.kSigned);
        Sn = max(0, Sn - zs - o.kSigned);
    else
        inc = a - o.kappa;
        if com, inc(:) = -o.kappa; end
        Sp = max(0, Sp + inc);
    end
    Sp = min(Sp, o.Smax);  Sn = min(Sn, o.Smax);   % cap (A)
    if ~decide, Sp(:) = 0; Sn(:) = 0; end
    S = max(Sp, Sn);
    flag = decide & (S > o.h);

    % (C) release test. A frozen channel's innovation stays at a constant
    % level when the deviation is benign (prediction std and deviation grow
    % alike, finding 10F), but grows like sqrt(t) under a drift. Over the
    % last Wrel flagged blocks, regress the signed z (oriented to the alarm
    % side) on sqrt(blocks since freeze); release unless the slope is
    % significantly positive (one-sided t-test) or any |z| >= zU.
    rel = false(1, nC);
    nFroz(~flag) = 0;
    for c = find(flag)
        nFroz(c) = nFroz(c) + 1;
        zHist(mod(nFroz(c) - 1, o.Wrel) + 1, c) = zRaw(c);
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
            rel(c) = true;
        end
    end
    if any(rel)
        Sp(rel) = 0;  Sn(rel) = 0;  S(rel) = 0;
        flag(rel) = false;  nFroz(rel) = 0;
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
    if ~decide || abs(zT) < o.zU
        for j = 1:nJ
            x = [1; LB(k, j) - L0(j)];
            [thT(:, j), PT(:, :, j)] = rlsUpdate(thT(:, j), PT(:, :, j), x, ...
                D.TbmeB(k), sig2T(j), o.lambda);
        end
        sseT = o.lambda * sseT + min((eT ./ sT).^2, o.zU^2);
    end

    % --- record
    R.zI(k, :) = zc(:, 1)';   R.zB(k, :) = zc(:, 2)';
    R.infl(k, :) = (sc(:, 1) ./ sSS(:))';
    R.zT(k) = zT;  R.tauBest(k) = o.tauGrid(jb);  R.wBest(k, :) = o.wGrid(iwb);
    R.common(k) = com;
    R.score(k, :) = S;  R.sensorFlag(k, :) = flag;
    R.tempFlag(k) = tf;  R.blameBme(k) = bB;  R.blameIcm(k) = bI;  R.tempAmbig(k) = amb;
    R.released(k, :) = rel;  R.switchReset(k) = sw;
end

R.name    = "G1 v5";
R.valid   = (1:nB)' > o.warm;
R.lowConf = R.infl > o.inflMax;
R.opt     = o;
end

%% Helpers
function [th, P] = kfUpdate(th, P, x, y, r)
    Px = P * x;
    K  = Px / (x' * Px + r);
    th = th + K * (y - x' * th);
    P  = P - K * Px';
    P  = (P + P') / 2;
end

function [th, P] = rlsUpdate(th, P, x, y, s2, lambda)
    Px = P * x;
    K  = Px / (x' * Px + s2);
    th = th + K * (y - x' * th);
    P  = (P - K * Px') / lambda;
    P  = (P + P') / 2;
end

function s = steadyStd(NM)
    % Innovation std of the noise-only filter [a g] after convergence
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
    % +1 heating, -1 cooling, in between while turning (play operator)
    d = zeros(size(T));
    p = T(1);
    for k = 1:numel(T)
        p = min(max(p, T(k) - w/2), T(k) + w/2);
        d(k) = (T(k) - p) / (w/2);
    end
end

function L = lagFilter(x, tau, dt)
    L = x;
    if tau == 0, return; end
    a = 1 - exp(-dt / tau);
    for k = 2:numel(x)
        L(k) = L(k-1) + a * (x(k-1) - L(k-1));
    end
end
