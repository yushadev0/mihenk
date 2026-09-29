function R = g1_detect_v0(D)
%G1_DETECT_V0 G1 prototype v0 detector (bulgular.md, section 6).
%   Per 60 s block, channel c and temperature reference r: fit
%   y = a + b*T_r on a trailing window (ridge on b); z = prediction
%   residual / window residual std. A channel is blamed if unexplained by
%   BOTH references; a temperature source is blamed if the sources disagree
%   and more channels break against it. Baseline: same test with b = 0.
%
%   Uses only firmware-visible fields of D (Y, TicmB, TbmeB).

W   = 90;                        % fit window [blocks]
G   = 10;                        % guard between window and tested block [blocks]
lam = 0.2^2;                     % ridge on b [degC^2]
thr = 5;                         % |z| threshold

[nB, nC] = size(D.Y);
zI = nan(nB, nC);  zB = zI;  z0 = zI;
for c = 1:nC
    zI(:, c) = thermalZ(D.Y(:, c), D.TicmB, W, G, lam);
    zB(:, c) = thermalZ(D.Y(:, c), D.TbmeB, W, G, lam);
    z0(:, c) = thermalZ(D.Y(:, c), D.TicmB, W, G, Inf);
end
zT = thermalZ(D.TbmeB, D.TicmB, W, G, lam);

R.name       = "G1 v0";
R.valid      = ~isnan(zI(:, 1));
R.score      = min(abs(zI), abs(zB));
R.sensorFlag = R.score > thr;
R.baseFlag   = abs(z0) > thr;
R.tempFlag   = abs(zT) > thr;
R.blameBme   = R.tempFlag & (sum(abs(zB) > thr, 2) > sum(abs(zI) > thr, 2));
R.blameIcm   = R.tempFlag & ~R.blameBme;
R.zI = zI;  R.zB = zB;  R.z0 = z0;  R.zT = zT;
R.thr = thr;
end

function z = thermalZ(y, T, W, G, lam)
    n = numel(y);
    z = nan(n, 1);
    for k = W+G+1:n
        w  = (k-G-W):(k-G-1);
        Tm = mean(T(w));
        ym = mean(y(w));
        dT = T(w) - Tm;
        b  = sum(dT .* (y(w) - ym)) / (sum(dT.^2) + W*lam);
        s  = std(y(w) - ym - b*dT);
        z(k) = (y(k) - ym - b*(T(k) - Tm)) / max(s, eps);
    end
end
