%% thermal_model_check.m
% Checks how imuSensor models temperature - the physical basis of G1.
%
% Source reading (R2026a, IMUSensorSimulator.m):
%   out = (1 + dT*TemperatureScaleFactor/100) .* (ideal + ... + dT*TemperatureBias)
%   with dT = Temperature - 25 (reference fixed at 25 degC).
%   Temperature is ONE scalar for the whole imuSensor, tunable between calls.
%
%   T1) Deterministic: rate table (100 dps) + temperature profile, no noise.
%       Output must match the formula above exactly.
%   T2) Noise continuity: N + RRW + thermal bias, temperature updated every
%       second. After removing the thermal term, Allan must still return
%       N and K -> changing Temperature does not reset the noise states.

clear; clc; close all;

TOL = 10;                        % [%] M1 exit criterion
Fs  = 100;                       % [Hz]; temperature updated once per second

% Temperature profile, one value per second [degC]:
% 1 h ramp 25->45, 1 h hold, 1 h ramp 45->25, 1 h hold
t     = (0:4*3600-1)';
Tprof = interp1([0 3600 7200 10800 14400], [25 45 45 25 25], t);
dT    = repelem(Tprof - 25, Fs); % per sample

% Thermal coefficients (provenance: datasheet - ICM-42688-P DS-000347
% rev 1.6, Table 1, 0-70 degC, "derived from characterization, not tested
% in production"). The datasheet gives +- bounds across parts, not the
% coefficient of a given unit; the upper bound is used here.
kb = 0.005 * pi/180;             % ZRO variation vs temp  +-0.005 dps/degC -> rad/s/degC
ks = 0.005;                      % sensitivity vs temp    +-0.005 %/degC

%% T1) Deterministic thermal bias + scale factor
w0 = 100 * pi/180;               % rate table, 100 dps about x
gp = gyroparams('TemperatureBias', kb, 'TemperatureScaleFactor', ks);
g1 = runChunked(gp, Fs, Tprof, [w0 0 0], 1);

expected1 = (1 + dT*ks/100) .* (w0 + kb*dT);
relErr1   = max(abs(g1 - expected1)) / w0;

%% T2) Noise states survive temperature updates
N = 2.8e-3 * pi/180;             % datasheet (see first_allan_check.m)
K = 1e-5;                        % rad/s/sqrt(s), assumed - RRW visible after ~10 s
gp = gyroparams('NoiseDensity', N, 'RandomWalk', K, ...
    'NoiseType', 'single-sided', 'TemperatureBias', kb);
g2 = runChunked(gp, Fs, Tprof, [0 0 0], 2);

resid = g2 - kb*dT;              % remove the known thermal term
[avar, tau]       = allanvar(resid, 'octave', Fs);
[avarRaw, tauRaw] = allanvar(g2,    'octave', Fs);
idx = tau <= numel(resid)/Fs/10;

% Fit avar = N^2/tau + K^2*tau/3 (relative-error weighted least squares)
A = [1./tau(idx), tau(idx)/3] ./ avar(idx);
x = A \ ones(nnz(idx), 1);
N_est = sqrt(x(1));
K_est = sqrt(x(2));

%% Report
fprintf('T1 deterministic thermal model : max rel. error %.2e  -> %s\n', ...
    relErr1, verdict(relErr1 < 1e-9));
fprintf('%-26s %11s %11s %8s  %s\n', 'T2 case', 'Expected', 'Measured', 'Err[%]', 'Result');
report('T2 N (white noise)', N, N_est, TOL);
report('T2 K (rate random walk)', K, K_est, TOL);

%% Plots
figure;
tiledlayout(2, 1);
nexttile;
plot(t/3600, Tprof); grid on;
ylabel('Temperature [\circC]');
title('Temperature profile');
nexttile;
th = (0:numel(g1)-1)'/Fs/3600;
plot(th, rad2deg(g1), th, rad2deg(expected1), '--'); grid on;
xlabel('Time [h]'); ylabel('Gyro x [dps]');
legend('imuSensor', 'Formula', 'Location', 'best');
title('T1) Rate table 100 dps under temperature profile');

figure;
loglog(tauRaw, sqrt(avarRaw), 'x-', tau, sqrt(avar), 'o-', ...
    tau, sqrt(N^2./tau + K^2*tau/3), '--');
grid on;
xlabel('\tau [s]'); ylabel('Allan deviation [rad/s]');
legend('Raw (thermal drift included)', 'Thermal term removed', ...
    'Expected N and K', 'Location', 'best');
title('T2) Allan deviation under temperature profile');

%% Local helpers
function g = runChunked(gp, Fs, Tprof, angvel, seed)
    % Steps imuSensor one second at a time, setting Temperature before each step
    imu = imuSensor('accel-gyro', 'SampleRate', Fs, ...
        'RandomStream', 'mt19937ar with seed', 'Seed', seed);
    imu.Gyroscope = gp;
    acc = zeros(Fs, 3);
    w   = repmat(angvel, Fs, 1);
    g   = zeros(Fs*numel(Tprof), 1);
    for k = 1:numel(Tprof)
        imu.Temperature = Tprof(k);
        [~, gyro] = imu(acc, w);
        g((k-1)*Fs + (1:Fs)) = gyro(:,1);
    end
end

function report(name, expd, meas, tol)
    err = 100 * (meas - expd) / expd;
    fprintf('%-26s %11.4e %11.4e %+8.2f  %s\n', name, expd, meas, err, verdict(abs(err) <= tol));
end

function s = verdict(ok)
    s = "FAIL";
    if ok, s = "PASS"; end
end
