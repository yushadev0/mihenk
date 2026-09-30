function R = g1_detect_v3(D, NM, opt)
%G1_DETECT_V3 G1 v3 detector: v1 with an Allan-derived stochastic null model.
%
%   v1 (g1_detect_v1.m) failed under colored noise (bulgular.md, 8B): its
%   noise level came from warm-up block differences, which see only white
%   noise, and any slow change the temperature did not explain counted as a
%   fault - but rate random walk is exactly such a change in a healthy sensor.
%
%   v3 replaces the per channel x reference RLS model by a Kalman filter
%       y_k = a_k + g_k + b*(T_r - T_r0) + c*d_r(w) + v_k
%       a_k = a_{k-1} + w_a             rate random walk        var K^2*B
%       g_k = phi*g_{k-1} + w_g         bias instability (Gauss-Markov)
%       v_k                             white noise             var N^2/B
%   N, K and the Gauss-Markov term come from the Allan variance of a
%   separate static log (NM, g1_allan_fit.m). The expected wander of a
%   healthy sensor is inside the prediction variance; a fault is a deviation
%   beyond that stochastic budget.
%
%   Release from a false lock (7C): a flagged channel is not updated, but
%   its prediction keeps running, so its prediction variance grows by the
%   process noise. A benign excursion (random walk, EMI that ends) becomes
%   explainable again and the CUSUM drains; a drift grows like t, faster
%   than the budget (~sqrt(t)), and stays flagged.
%
%   Signed CUSUM (Page, two one-sided, k = 0.5): the random-walk state partly
%   follows a slow drift, which then shows as innovations of constant sign
%   but modest size (~2 sigma). v1's |z| - 1.5 CUSUM cannot see the sign and
%   barely accumulates such a shift (smoke test: 123 min delay). k and h are
%   set from the in-control run length, not tuned on a scenario.
%   opt.cusum = "abs" restores v1's CUSUM (ablation "v3a").
%
%   Everything else - update gating, common-mode events, hysteresis width
%   and lag grids, temperature-source consistency - is v1 unchanged, with
%   v1's thresholds.
%
%   Uses only firmware-visible fields of D (Y, TicmB, TbmeB, Ticm, S) and NM.

o = struct( ...
    'warm',        30, ...          % blocks of unconditional learning at start
    'zU',          3, ...           % update gate |z| < zU
    'thrT',        5, ...           % temperature-source disagreement threshold
    'nCommon',     3, ...           % >= this many channels break together ...
    'moveLag',     5, ...           % ... while temperature moved over this many blocks ...
    'thermalMove', 0.1, ...         % ... by more than this [degC] or direction flipped
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
F = zeros(4, 4, nC);  Q = F;
for c = 1:nC
    F(:, :, c) = diag([1, NM.phi(c), 1, 1]);
    Q(:, :, c) = diag([NM.q(c), NM.qg(c), 0, 0]);
end
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
R.tempFlag = false(nB, 1);  R.blameBme = R.tempFlag;  R.blameIcm = R.tempFlag;

Sp = zeros(1, nC);  Sn = Sp;
for k = 1:nB
    decide = k > o.warm;

    % --- time update of every model (also the frozen ones)
    if k > 1
        for r = 1:2
            for iw = 1:nW
                for c = 1:nC
                    theta(:, c, r, iw) = F(:, :, c) * theta(:, c, r, iw);
                    Pm(:, :, c, r, iw) = F(:, :, c) * Pm(:, :, c, r, iw) * F(:, :, c)' + Q(:, :, c);
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
    bI   = tf && ~bB;
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
    com = decide && moved && nnz(a > o.zU) >= o.nCommon;
    if o.cusum == "signed"
        if com, zs(:) = 0; end                     % drain both sides
        Sp = max(0, Sp + zs - o.kSigned);
        Sn = max(0, Sn - zs - o.kSigned);
    else
        inc = a - o.kappa;
        if com, inc(:) = -o.kappa; end
        Sp = max(0, Sp + inc);
    end
    if ~decide, Sp(:) = 0; Sn(:) = 0; end
    S = max(Sp, Sn);
    flag = decide & (S > o.h);

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
    R.tempFlag(k) = tf;  R.blameBme(k) = bB;  R.blameIcm(k) = bI;
end

R.name    = "G1 v3";
if o.cusum == "abs", R.name = "G1 v3a"; end
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
