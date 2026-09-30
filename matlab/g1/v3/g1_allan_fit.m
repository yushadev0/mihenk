function NM = g1_allan_fit(Y, Bl)
%G1_ALLAN_FIT Stochastic null model per channel from a static log.
%   NM = g1_allan_fit(Y, Bl) fits the Allan variance of every column of Y
%   (block means over Bl seconds, recorded at rest and constant temperature)
%   with
%       N^2/tau + K^2*tau/3 + sg^2 * gm(tau, Tg)
%   white noise, rate random walk, and a first-order Gauss-Markov process
%   standing in for bias instability. Weighted nonnegative least squares
%   (weights = inverse relative error of each Allan point); Tg from a grid.
%
%   Returns the block-level state-space noise used by g1_detect_v3.m:
%     NM.r    white noise variance of a block mean      N^2/Bl
%     NM.q    random-walk increment per block           K^2*Bl
%     NM.phi  Gauss-Markov factor per block             exp(-Bl/Tg)
%     NM.qg   Gauss-Markov driving variance per block   sg^2*(1-phi^2)
%     NM.sg2  Gauss-Markov stationary variance          sg^2
%   and the fit itself (N, K, sg, Tg, tau, avar, parts) for reporting.

[n, nC] = size(Y);
m   = unique(round(logspace(0, log10(floor(n/4)), 30)))';   % cluster sizes [blocks]
tau = m * Bl;
TgGrid = [120 300 600 1200 2400 4800];                        % [s]
gm  = @(t, T) 2*T./t .* (1 - T./(2*t) .* (3 - 4*exp(-t/T) + exp(-2*t/T)));  % unit variance

NM.tau  = tau;
NM.avar = zeros(numel(tau), nC);
NM.parts = zeros(numel(tau), 3, nC);
[NM.N, NM.K, NM.sg, NM.Tg] = deal(zeros(1, nC));
for c = 1:nC
    av = allanvar(Y(:, c), m, 1/Bl);
    w  = sqrt(n ./ m - 1) ./ av;
    best = inf;
    for T = TgGrid
        A  = [1./tau, tau/3, gm(tau, T)];
        cn = vecnorm(A .* w);                                 % column scaling for lsqnonneg
        p  = lsqnonneg((A .* w) ./ cn, av .* w) ./ cn';
        res = norm((A*p - av) .* w);
        if res < best
            best = res;  pBest = p;  TBest = T;  ABest = A;
        end
    end
    NM.avar(:, c)     = av;
    NM.parts(:, :, c) = ABest .* pBest';
    NM.N(c)  = sqrt(pBest(1));
    NM.K(c)  = sqrt(pBest(2));
    NM.sg(c) = sqrt(pBest(3));
    NM.Tg(c) = TBest;
end

NM.r   = NM.N.^2 / Bl;
NM.q   = NM.K.^2 * Bl;
NM.phi = exp(-Bl ./ NM.Tg);
NM.sg2 = NM.sg.^2;
NM.qg  = NM.sg2 .* (1 - NM.phi.^2);
NM.Bl  = Bl;
end
