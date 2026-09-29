%% g1_prototype_v0.m
% First prototype of G1: thermal common-mode vs channel-specific
% decomposition on a synthetic heterogeneous node (bulgular.md, "G1 nedir?").
%
% Node (stationary, 8 h): ICM-42688-P gyro + accel (one die), magnetometer,
% BME688 temperature. Per-sensor temperatures from thermal_node.m.
% Firmware-visible signals only: 9 motion channels + 2 temperature readouts.
%
% Ground truth events:
%   - ambient thermal cycle 25 -> 40 -> 25 degC   (environment: common mode)
%   - BME688 gas-heater burst                     (trap: channel-specific heat, no fault)
%   - gyro z bias drift during the down-ramp      (real sensor fault, thermally masked)
%
% Method v0 (per 60 s block, per channel c, per temperature reference r):
%   fit  y_c = a + b*T_r  on a trailing 90 min window (ridge on b),
%   z_c,r = prediction residual / window residual std.
%   - channel c is blamed        if it is unexplained by BOTH references
%   - a temperature source is blamed if the two sources disagree and more
%     channels break against it than against the other
% Baseline: same residual test without any temperature model (b = 0).
%
% v0 limitations (deliberate): white noise only (no bias instability /
% random walk), linear thermal fit (no hysteresis term), binary flags
% instead of a calibrated score (ADR-010 target comes later).

clear; clc; close all;

figDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'figures');
if ~isfolder(figDir), mkdir(figDir); end
h = 3600;

%% Scenario
Fs   = 10;                       % motion sample rate [Hz]
dtT  = 10;                       % thermal step and temperature update [s]
Tend = 8*h;
tT   = (0:dtT:Tend-dtT)';
nT   = numel(tT);
Tamb = interp1([0 1 3 4 6 8]*h, [25 25 40 40 25 25], tT);

heaterOn  = [3.25 3.50]*h;       % BME688 heater burst (trap)
faultT0   = 4.5*h;               % gyro z drift onset (fault)
faultRate = 0.03;                % [dps/h]

%% Thermal node (thermal_node.m; values as in thermal_node_check.m)
ICM_P = 0.88e-3 * 1.8;           % datasheet
sensors = struct( ...
    'name',      {"ICM-42688-P", "Magnetometer", "BME688"}, ...
    'tau',       {120,  90,   200}, ...    % assumed
    'gradient',  {0,    0.5,  -0.3}, ...   % assumed
    'Rth',       {150,  150,  150}, ...    % assumed
    'hystWidth', {1.0,  0,    0});         % assumed
P = repmat([ICM_P, 1e-3, 1e-3], nT, 1);
heater = tT >= heaterOn(1) & tT < heaterOn(2);
P(heater, 3) = P(heater, 3) + 10e-3;
[Tdie, Teff] = thermal_node(tT, Tamb, P, sensors);

%% Unit-specific coefficients (drawn once per virtual unit)
rs = RandStream('mt19937ar', 'Seed', 7);
u  = @(k) 2*rand(rs, 1, k) - 1;
kbGyro  = u(3) * 0.005*pi/180;           % rad/s/degC    datasheet bound
kbAccel = u(3) * 0.15e-3*9.80665;        % m/s^2/degC    datasheet bound
kbMag   = u(3) * 0.05;                   % uT/degC       assumed
offIcm  = u(1) * 5;                      % degC          datasheet bound
offBme  = u(1) * 0.5;                    % degC          assumed

%% Sensors
icm = imuSensor('accel-gyro', 'SampleRate', Fs, ...
    'RandomStream', 'mt19937ar with seed', 'Seed', 11);
icm.Gyroscope = gyroparams('NoiseDensity', 2.8e-3*pi/180, ...
    'NoiseType', 'single-sided', 'TemperatureBias', kbGyro);
icm.Accelerometer = accelparams('NoiseDensity', [65 65 70]*1e-6*9.80665, ...
    'NoiseType', 'single-sided', 'TemperatureBias', kbAccel);

mag = imuSensor('accel-mag', 'SampleRate', Fs, ...
    'RandomStream', 'mt19937ar with seed', 'Seed', 12);
mag.Magnetometer = magparams('NoiseDensity', 0.1, ...     % uT/sqrt(Hz), assumed
    'NoiseType', 'single-sided', 'TemperatureBias', kbMag);

nS = dtT * Fs;
N  = nT * nS;
gyro = zeros(N, 3);  accel = zeros(N, 3);  magn = zeros(N, 3);
still = zeros(nS, 3);
for k = 1:nT
    icm.Temperature = Teff(k, 1);
    mag.Temperature = Teff(k, 2);
    idx = (k-1)*nS + (1:nS);
    [accel(idx, :), gyro(idx, :)] = icm(still, still);
    [~, magn(idx, :)] = mag(still, still);
end

% Fault: additive gyro z bias drift
ts = (0:N-1)' / Fs;
gyro(:, 3) = gyro(:, 3) + max(ts - faultT0, 0)/h * faultRate*pi/180;

% Temperature readouts (what firmware sees)
Ticm = round((Tdie(:, 1) - 25 + offIcm) * 132.48) / 132.48 + 25;   % 16-bit register
Tbme = round((Tdie(:, 3) + offBme) * 100) / 100;                    % 0.01 degC, assumed

%% 60 s block means
B  = 60;
nB = Tend / B;
blk  = @(x) reshape(mean(reshape(x, B*Fs, nB, []), 1), nB, []);
blkT = @(x) mean(reshape(x, B/dtT, nB), 1)';

Y = [rad2deg(blk(gyro)), blk(accel)/9.80665*1e3, blk(magn)];   % dps | mg | uT
names = ["gx" "gy" "gz" "ax" "ay" "az" "mx" "my" "mz"];
nC = numel(names);
TicmB = blkT(Ticm);
TbmeB = blkT(Tbme);
tB = ((1:nB)' - 0.5) * B;

%% Decomposition
W   = 90;                        % fit window [blocks]
G   = 10;                        % guard between window and tested block [blocks]
lam = 0.2^2;                     % ridge on b [degC^2]: no excitation -> b ~ 0
thr = 5;                         % |z| threshold

zI = nan(nB, nC);  zB = zI;  z0 = zI;
for c = 1:nC
    zI(:, c) = thermalZ(Y(:, c), TicmB, W, G, lam);   % vs ICM temperature
    zB(:, c) = thermalZ(Y(:, c), TbmeB, W, G, lam);   % vs BME688 temperature
    z0(:, c) = thermalZ(Y(:, c), TicmB, W, G, Inf);   % baseline: no thermal model
end
zT = thermalZ(TbmeB, TicmB, W, G, lam);               % do the two sources agree?

sensorFlag = min(abs(zI), abs(zB)) > thr;
baseFlag   = abs(z0) > thr;
tempFlag   = abs(zT) > thr;
blameBme   = tempFlag & (sum(abs(zB) > thr, 2) > sum(abs(zI) > thr, 2));
blameIcm   = tempFlag & ~blameBme;

%% Evaluation against ground truth
valid       = ~isnan(zI(:, 1));
faultTruth  = tB >= faultT0;
heaterTruth = tB >= heaterOn(1) & tB < heaterOn(2) + 3*sensors(3).tau;
isFault     = false(nB, nC);
isFault(:, 3) = faultTruth;

delayG1   = detectDelay(sensorFlag(:, 3), tB, faultT0);
delayBase = detectDelay(baseFlag(:, 3),   tB, faultT0);

fprintf('G1 prototype v0 - decisions from %.2f h (window warm-up)\n\n', tB(find(valid, 1))/h);
fprintf('Gyro z drift (%.2f dps/h from %.1f h), detection delay:\n', faultRate, faultT0/h);
fprintf('  G1       : %s\n', delayG1);
fprintf('  Baseline : %s\n\n', delayBase);

fprintf('False "sensor fault" flags [blocks of 60 s] out of %d valid blocks:\n', nnz(valid));
fprintf('  %-8s %6s %9s\n', 'Channel', 'G1', 'Baseline');
for c = 1:nC
    fG = nnz(sensorFlag(:, c) & ~isFault(:, c) & valid);
    fB = nnz(baseFlag(:, c)   & ~isFault(:, c) & valid);
    fprintf('  %-8s %6d %9d\n', names(c), fG, fB);
end

fprintf('\nBME688 heater burst (trap):\n');
fprintf('  sensor flags during burst (any channel) : %d blocks\n', nnz(any(sensorFlag, 2) & heaterTruth & ~faultTruth));
fprintf('  temperature sources disagree            : %d of %d blocks\n', nnz(tempFlag & heaterTruth), nnz(heaterTruth & valid));
fprintf('  ... blamed on BME688 / ICM              : %d / %d blocks\n', nnz(blameBme & heaterTruth), nnz(blameIcm & heaterTruth));
fprintf('  temperature-source flags outside burst  : %d blocks\n', nnz(tempFlag & ~heaterTruth & valid));

%% Plots
th = tB / h;
f1 = figure('Position', [100 100 900 700]);
tiledlayout(3, 1);
nexttile;
plot(tT/h, Tamb, 'k', tT/h, Ticm, tT/h, Tbme); grid on;
ylabel('[\circC]'); legend('Ambient', 'ICM readout', 'BME688 readout', 'Location', 'best');
title('Temperatures (readouts include unit offsets)');
nexttile;
plot(th, Y(:, 3)); grid on; xline(faultT0/h, 'r--', 'fault onset');
ylabel('gz [dps]'); title('Gyro z, 60 s means');
nexttile;
plot(th, abs(zI(:, 3)), th, abs(zB(:, 3)), th, abs(z0(:, 3))); grid on;
yline(thr, 'k--'); xline(faultT0/h, 'r--');
set(gca, 'YScale', 'log');
xlabel('Time [h]'); ylabel('|z|');
legend('vs ICM temp', 'vs BME688 temp', 'Baseline (no thermal model)', 'Location', 'best');
title('Gyro z residual scores');

f2 = figure('Position', [100 100 900 600]);
tiledlayout(2, 1);
nexttile;
imagesc(th, 1:nC+1, double([sensorFlag, tempFlag])');
yticks(1:nC+1); yticklabels([names, "T src"]); colormap(flipud(gray));
xline(faultT0/h, 'r--'); xline(heaterOn/h, 'b--');
title('G1 v0: blamed channel (black) - red: fault onset, blue: heater burst');
nexttile;
imagesc(th, 1:nC, double(baseFlag)');
yticks(1:nC); yticklabels(names);
xline(faultT0/h, 'r--'); xline(heaterOn/h, 'b--');
xlabel('Time [h]'); title('Baseline without thermal model');

exportgraphics(f1, fullfile(figDir, 'g1_v0_1.png'), 'Resolution', 150);
exportgraphics(f2, fullfile(figDir, 'g1_v0_2.png'), 'Resolution', 150);

%% Local helpers
function z = thermalZ(y, T, W, G, lam)
    % Trailing-window fit y = a + b*T (ridge on b), normalized prediction residual
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

function s = detectDelay(flag, tB, t0)
    k = find(flag & tB >= t0, 1);
    if isempty(k)
        s = "not detected";
    else
        s = sprintf('%.0f min', (tB(k) - t0)/60);
    end
end
