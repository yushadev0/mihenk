function A = g1_tsrc_v6(D, opt)
%G1_TSRC_V6 Temperature-source consistency model of G1 v6: does the BME688
%   temperature agree with the ICM temperature? Reads temperatures only
%   (D.Ticm, D.TicmB, D.TbmeB, D.S.dtT, D.S.B).
%
%   v5 (g1_detect_v5.m) models T_bme = a + b*(lag(T_icm, tau) - L0) on a lag
%   grid, RLS updated only while |zT| < zU. Bulgular section 14 found three
%   causes of its locks (13D): a structure that cannot follow two lags in
%   series (14C), an error budget sT with no model-error term (14B), and a
%   frozen RLS whose covariance never grows (14B). Changes, each a switch so
%   that every one can be ablated:
%
%   1. opt.structure = "leadlag". Both dies follow the ambient through a
%      first-order lag (tau_I, tau_B). Eliminating the ambient gives
%          T_bme = (1 + tau_I s)/(1 + tau_B s) * T_icm + const
%                = L + tau_I * dL/dt + const,   L = lag(T_icm, tau_B),
%      i.e. a lead-lag. With the lead as a third regressor the model stays
%      linear in its parameters: x = [1; L - L0; dL/dt], theta = [a; b; c],
%      c ~ b*tau_I [s]. Only tau_B needs the grid, tau_I is estimated. The
%      block value of dL/dt is the block mean of the backward difference,
%      (L(end of block) - L(end of previous block)) / B: causal, exact.
%      "lag" = v5 (x = [1; L - L0]).
%      NOTE (ADR-012): the simulator uses exactly this physics (two
%      first-order lags), so on simulated data the structure is exact. The
%      new held-out set must contain a thermal structure that differs.
%
%   2. opt.gridErr. The lag is chosen from a grid with step dTau; a lag
%      error d produces an error d*dL/dt. With d uniform over one grid step
%      its variance is dTau^2/12 * (dL/dt)^2. This term is added to the
%      measurement variance of each candidate (update weight and sT). It
%      grows with the rate of temperature change (14C: fast sine) and is
%      fixed by the grid, not tuned.
%
%   3. opt.frozenFloor (ablation, default off). The v5 channel fix B: while
%      the model is not updated, slope and lead behave as random walks,
%      P += diag(0, sbT^2, scT^2)/modelHorizon, so a locked model's sT grows
%      and it can release. Off by default because a constant BME offset
%      fault (T7: 1 degC step) would then be absorbed as a "changed slope"
%      after ~1 h: the 12B dilemma (a persistent offset is not separable
%      from a benign model error by its size alone). Kept as an ablation
%      so the trade-off is measured, not argued.
%
%   With structure "lag", gridErr false and frozenFloor false this is the
%   v5 model operation for operation (checked against the acceptance CSV).
%
%   Output A (nB x 1 unless noted): zT, eT, sT, tf (|zT| > thrT after
%   warm-up), upd (model updated), tau (selected tau_B), b, c, bsd.

o = struct( ...
    'warm',        30, ...           % blocks of unconditional learning at start
    'zU',          3, ...            % update gate |zT| < zU
    'thrT',        5, ...            % disagreement threshold
    'lambda',      1 - 1/(24*60), ... % RLS forgetting and score memory: ~24 h
    'tauGrid',     0:20:300, ...     % tau_B candidates [s]
    'sigmaTFloor', 0.02, ...         % [degC]
    'structure',   "leadlag", ...    % "leadlag" (1) | "lag" (v5)
    'gridErr',     true, ...         % lag-grid error term (2)
    'frozenFloor', false, ...        % covariance growth while not updated (3, ablation)
    'modelHorizon', 24*60, ...       % (3) blocks over which b, c may move by sbT, scT
    'sbT',         0.1, ...          % slope prior std (v5's initial value)
    'scT',         300);             % lead prior std [s] (>= the largest tau_I in reason)
if nargin > 1
    for f = fieldnames(opt)', o.(f{1}) = opt.(f{1}); end
end

nB = numel(D.TbmeB);
nJ = numel(o.tauGrid);
n  = D.S.B / D.S.dtT;                       % thermal samples per block
lead = double(o.structure == "leadlag");     % 1 = lead regressor present
nP = 2 + lead;

LB = zeros(nB, nJ);  dLB = LB;
for j = 1:nJ
    L = lagFilter(D.Ticm, o.tauGrid(j), D.S.dtT);
    LB(:, j) = mean(reshape(L, n, nB), 1)';
    Le = L(n:n:end);                         % end of each block
    dLB(:, j) = diff([L(1); Le]) / D.S.B;
end
L0 = LB(1, :);
if o.gridErr
    dTau = o.tauGrid(2) - o.tauGrid(1);
    g2 = dTau^2 / 12 * dLB.^2;               % [nB x nJ]
else
    g2 = zeros(nB, nJ);
end

thT = repmat([D.TbmeB(1); 1; zeros(lead, 1)], 1, nJ);
PT  = repmat(diag([25, o.sbT^2, o.scT^2 * ones(1, lead)]), 1, 1, nJ);
Qf  = diag([0, o.sbT^2, o.scT^2 * ones(1, lead)]) / o.modelHorizon;
sigT0 = max(std(diff(D.TbmeB(1:o.warm) - D.TicmB(1:o.warm))) / sqrt(2), o.sigmaTFloor);
sig2T = sigT0^2;
sseT  = zeros(1, nJ);

[A.zT, A.eT, A.sT, A.b, A.c, A.bsd, A.tau] = deal(nan(nB, 1));
[A.tf, A.upd] = deal(false(nB, 1));
for k = 1:nB
    decide = k > o.warm;
    eT = zeros(1, nJ);  sT = eT;
    for j = 1:nJ
        x = regressor(LB(k, j) - L0(j), dLB(k, j), lead);
        eT(j) = D.TbmeB(k) - x' * thT(:, j);
        sT(j) = sqrt(sig2T + g2(k, j) + x' * PT(:, :, j) * x);
    end
    [~, jb] = min(sseT);
    zT = eT(jb) / sT(jb);
    A.zT(k) = zT;  A.eT(k) = eT(jb);  A.sT(k) = sT(jb);
    A.b(k) = thT(2, jb);  A.bsd(k) = sqrt(PT(2, 2, jb));  A.tau(k) = o.tauGrid(jb);
    if lead, A.c(k) = thT(3, jb); end
    A.tf(k) = decide && abs(zT) > o.thrT;
    if ~decide || abs(zT) < o.zU
        for j = 1:nJ
            x = regressor(LB(k, j) - L0(j), dLB(k, j), lead);
            [thT(:, j), PT(:, :, j)] = rlsUpdate(thT(:, j), PT(:, :, j), x, ...
                D.TbmeB(k), sig2T + g2(k, j), o.lambda);
        end
        sseT = o.lambda * sseT + min((eT ./ sT).^2, o.zU^2);
        A.upd(k) = true;
    elseif o.frozenFloor
        for j = 1:nJ
            PT(:, :, j) = PT(:, :, j) + Qf(1:nP, 1:nP);
        end
    end
end
end

%% Helpers
function x = regressor(dL0, dL, lead)
    if lead, x = [1; dL0; dL]; else, x = [1; dL0]; end
end

function [th, P] = rlsUpdate(th, P, x, y, s2, lambda)
    Px = P * x;
    K  = Px / (x' * Px + s2);
    th = th + K * (y - x' * th);
    P  = (P - K * Px') / lambda;
    P  = (P + P') / 2;
end

function L = lagFilter(x, tau, dt)
    L = x;
    if tau == 0, return; end
    a = 1 - exp(-dt / tau);
    for k = 2:numel(x)
        L(k) = L(k-1) + a * (x(k-1) - L(k-1));
    end
end
