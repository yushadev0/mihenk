function R = g1_detect_v1(D, opt)
%G1_DETECT_V1 G1 prototype v1 detector - fixes for findings 6C-6F.
%
%   Per channel c and temperature reference r (ICM readout, BME688 readout)
%   a recursive Bayesian linear model is kept:
%       y_c = a + b*(T_r - T_r0) + c*d_r(w)
%   d_r(w) = (T_r - play(T_r, w)) / (w/2) in [-1, 1] is a heating/cooling
%   state. With the right width w the model is exact for play-type thermal
%   hysteresis, since play(T, w) = T - (w/2)*d. w is unknown, so it is
%   picked online per reference from a grid, like the lag below   (6C)
%   b starts from the datasheet tempco bound as a prior; the prediction
%   variance includes parameter uncertainty, so an unlearned model gives a
%   wide, honest prediction instead of a false alarm                (6F)
%
%   Memory instead of a sliding window                              (6E):
%   a model is updated only when its residual is small (|z| < zU), or when
%   several channels move together while the temperature moves (common-mode
%   event = environment). A channel that breaks alone stops updating, so a
%   slow fault cannot become the "new normal". Evidence is accumulated
%   with a CUSUM on the residual score.
%
%   Temperature-source consistency                                  (6D):
%   T_bme is predicted from a lagged T_icm; the lag is picked online from a
%   grid by running prediction error. When the sources disagree, the source
%   against which more channels break is blamed and its models are frozen.
%
%   Grid selections (lag, hysteresis width) learn only from consistent
%   blocks, with each block's contribution capped: an event must not
%   re-rank the candidates.
%
%   Uses only firmware-visible fields of D (Y, TicmB, TbmeB, Ticm, S).

o = struct( ...
    'warm',        30, ...          % blocks of unconditional learning at start
    'zU',          3, ...           % update gate |z| < zU
    'thrT',        5, ...           % temperature-source disagreement threshold
    'nCommon',     3, ...           % >= this many channels break together ...
    'moveLag',     5, ...           % ... while temperature moved over this many blocks ...
    'thermalMove', 0.1, ...         % ... by more than this [degC] or direction flipped
    'lambda',      1 - 1/(24*60), ...  % forgetting per update: ~24 h memory
    'kappa',       1.5, ...         % CUSUM slack
    'h',           10, ...          % CUSUM alarm level
    'wGrid',       [0.2 0.5 1 1.5 2], ...  % hysteresis width candidates [degC]
    'tauGrid',     0:20:300, ...    % lag candidates between temperature sources [s]
    'inflMax',     1.5, ...         % prediction std / noise std above this = low confidence
    'sigmaTFloor', 0.02, ...        % [degC]
    'alphaSigma',  1/240);          % noise-level tracking rate
if nargin > 1
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
% mag uT/degC (assumed) - the only sensor knowledge the detector uses
sb = [0.005 0.005 0.005 0.15 0.15 0.15 0.05 0.05 0.05];

% Noise level of the block means, from the warm-up (node at rest)
sig0 = std(diff(Y(1:o.warm, :)), 0, 1) / sqrt(2);

theta = zeros(3, nC, 2, nW);
Pm    = zeros(3, 3, nC, 2, nW);
sig2  = zeros(nC, 2);
for r = 1:2
    for c = 1:nC
        sig2(c, r) = sig0(c)^2;
        for iw = 1:nW
            theta(:, c, r, iw)  = [Y(1, c); 0; 0];
            Pm(:, :, c, r, iw)  = diag([(100*sig0(c))^2, sb(c)^2, sb(c)^2]);
        end
    end
end
sseW = zeros(2, nW);

% Temperature-source model candidates: T_bme = a + b*(lag(T_icm, tau) - L0)
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

S = zeros(1, nC);
for k = 1:nB
    decide = k > o.warm;

    % --- temperature-source consistency (best lag so far)
    eT = zeros(1, nJ);  sT = eT;
    for j = 1:nJ
        x = [1; LB(k, j) - L0(j)];
        eT(j) = D.TbmeB(k) - x' * thT(:, j);
        sT(j) = sqrt(sig2T(j) + x' * PT(:, :, j) * x);
    end
    [~, jb] = min(sseT);
    zT = eT(jb) / sT(jb);

    % --- channel residuals against both references, all width candidates
    zAll = zeros(nC, 2, nW);  eAll = zAll;  sAll = zAll;
    for r = 1:2
        for iw = 1:nW
            x = [1; Tr(k, r) - T0(r); dr(k, r, iw)];
            for c = 1:nC
                eAll(c, r, iw) = Y(k, c) - x' * theta(:, c, r, iw);
                sAll(c, r, iw) = sqrt(sig2(c, r) + x' * Pm(:, :, c, r, iw) * x);
                zAll(c, r, iw) = eAll(c, r, iw) / sAll(c, r, iw);
            end
        end
    end
    [~, iwb] = min(sseW, [], 2);                   % best width per reference
    zc = [zAll(:, 1, iwb(1)), zAll(:, 2, iwb(2))];
    ec = [eAll(:, 1, iwb(1)), eAll(:, 2, iwb(2))];
    sc = [sAll(:, 1, iwb(1)), sAll(:, 2, iwb(2))];

    % --- blame a temperature source?
    tf   = decide && abs(zT) > o.thrT;
    nbad = sum(abs(zc) > o.zU, 1);                 % [vs ICM, vs BME]
    bB   = tf && nbad(2) > nbad(1);
    bI   = tf && ~bB;
    usable = [~bI, ~bB];

    % --- channel anomaly, common-mode event, CUSUM
    a = min(abs(zc(:, usable)), [], 2)';
    dNow = dr(k, 1, iwb(1));
    moved = k > o.moveLag && ...
        (abs(Tr(k, 1) - Tr(k - o.moveLag, 1)) > o.thermalMove || ...
         abs(dNow - dr(k - o.moveLag, 1, iwb(1))) > 0.5);
    com = decide && moved && nnz(a > o.zU) >= o.nCommon;
    inc = a - o.kappa;
    if com, inc(:) = -o.kappa; end
    S = max(0, S + inc);
    if ~decide, S(:) = 0; end
    flag = decide & (S > o.h);

    % --- updates (gated), for every width candidate
    for r = 1:2
        accepted = false(1, nC);
        for c = 1:nC
            accepted(c) = ~decide || (usable(r) && ~flag(c) && (abs(zc(c, r)) < o.zU || com));
            if ~accepted(c), continue; end
            for iw = 1:nW
                x = [1; Tr(k, r) - T0(r); dr(k, r, iw)];
                [theta(:, c, r, iw), Pm(:, :, c, r, iw)] = rlsUpdate(theta(:, c, r, iw), ...
                    Pm(:, :, c, r, iw), x, Y(k, c), sig2(c, r), o.lambda);
            end
            if abs(zc(c, r)) < o.zU
                sig2(c, r) = (1 - o.alphaSigma)*sig2(c, r) + ...
                    o.alphaSigma * ec(c, r)^2 * sig2(c, r) / sc(c, r)^2;
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
    R.infl(k, :) = (sc(:, 1) ./ sqrt(sig2(:, 1)))';
    R.zT(k) = zT;  R.tauBest(k) = o.tauGrid(jb);  R.wBest(k, :) = o.wGrid(iwb);
    R.common(k) = com;
    R.score(k, :) = S;  R.sensorFlag(k, :) = flag;
    R.tempFlag(k) = tf;  R.blameBme(k) = bB;  R.blameIcm(k) = bI;
end

R.name    = "G1 v1";
R.valid   = (1:nB)' > o.warm;
R.lowConf = R.infl > o.inflMax;
R.opt     = o;
end

%% Helpers
function [th, P] = rlsUpdate(th, P, x, y, s2, lambda)
    Px = P * x;
    K  = Px / (x' * Px + s2);
    th = th + K * (y - x' * th);
    P  = (P - K * Px') / lambda;
    P  = (P + P') / 2;
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
