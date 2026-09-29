%% allan_noise_terms_check.m
% Isolates each remaining stochastic term of imuSensor's gyro model and
% checks its Allan deviation against the IEEE Std 952 definitions.
% (White noise N was already verified in first_allan_check.m.)
%
%   A) Rate random walk K        : sigma(tau) = K*sqrt(tau/3)  (slope +1/2)
%   B) Bias instability B,
%      default filter            : flat floor = 0.664*B        (slope 0)
%   C) Bias instability B,
%      long 1/f filter (Kasdin)  : flat floor = 0.664*B        (slope 0)
%
% Source reading (R2026a, IMUSensorSimulator.m / fractalcoef.m):
%   - RandomWalk step std = K/sqrt(bandwidth) -> NoiseType matters here too
%   - BiasInstability drives filter 1/(1 - 0.5 z^-1) by default: a 2-sample
%     Gauss-Markov process, i.e. NOT 1/f. Test B checks whether that
%     still yields an IEEE bias-instability floor.

clear; clc; close all;

BI_FLOOR = sqrt(2*log(2)/pi);    % 0.664 - IEEE flicker floor factor
TOL      = 10;                   % [%] M1 exit criterion

% Magnitudes are placeholders (provenance: assumed) - each term is
% simulated alone, so only the ratio measured/expected matters.
K = 20 * (pi/180) / 3600 / 60;   % 20 deg/h/sqrt(h) -> rad/s/sqrt(s)
B = 5  * (pi/180) / 3600;        % 5 deg/h          -> rad/s

results = {};

%% A) Rate random walk - single-sided vs double-sided
Fs = 100;  T = 2*3600;
tauMax = T/10;                   % longer tau has too few clusters

for type = ["single-sided", "double-sided"]
    gp = gyroparams('RandomWalk', K, 'NoiseType', type);
    [tau, adev] = gyroAllan(gp, Fs, T, 1);
    idx   = tau <= tauMax;
    K_est = median(adev(idx) .* sqrt(3 ./ tau(idx)));
    results(end+1,:) = {"A RRW " + type, K, K_est, slopeOf(tau, adev, idx)}; %#ok<SAGROW>
    plotCase(tau, adev, K*sqrt(tau/3), "A) RRW, " + type);
end

%% B) Bias instability - default filter (fractalcoef(1,1))
gp = gyroparams('BiasInstability', B);
[tau, adev] = gyroAllan(gp, Fs, T, 2);
idx = tau >= 1 & tau <= tauMax;
results(end+1,:) = {"B BI default filter", BI_FLOOR*B, median(adev(idx)), slopeOf(tau, adev, idx)};
plotCase(tau, adev, BI_FLOOR*B*ones(size(tau)), "B) Bias instability, default filter");

%% C) Bias instability - long 1/f filter
% A K-pole Kasdin filter approximates 1/f up to tau ~ K/Fs, so use a
% lower sample rate to keep it cheap: Fs = 10 Hz, 2000 poles -> ~200 s.
Fs = 10;  T = 4*3600;
gp = gyroparams('BiasInstability', B, ...
    'BiasInstabilityCoefficients', fractalcoef(2000, 1));
[tau, adev] = gyroAllan(gp, Fs, T, 3);
idx = tau >= 1 & tau <= 100;
results(end+1,:) = {"C BI 1/f filter (2000p)", BI_FLOOR*B, median(adev(idx)), slopeOf(tau, adev, idx)};
plotCase(tau, adev, BI_FLOOR*B*ones(size(tau)), "C) Bias instability, 1/f filter");

%% Report
fprintf('%-26s %11s %11s %8s %7s  %s\n', 'Case', 'Expected', 'Measured', 'Err[%]', 'Slope', 'Result');
for i = 1:size(results, 1)
    [name, expd, meas, slope] = results{i,:};
    err = 100 * (meas - expd) / expd;
    verdict = "FAIL";
    if abs(err) <= TOL, verdict = "PASS"; end
    fprintf('%-26s %11.4e %11.4e %+8.2f %+7.2f  %s\n', name, expd, meas, err, slope, verdict);
end
fprintf('\nExpected slopes: RRW +0.50, bias instability 0.00, white noise -0.50\n');

%% Local helpers
function [tau, adev] = gyroAllan(gp, Fs, T, seed)
    % Stationary gyro, one term at a time; seeded for reproducibility (I2)
    n = round(T * Fs);
    imu = imuSensor('accel-gyro', 'SampleRate', Fs, ...
        'RandomStream', 'mt19937ar with seed', 'Seed', seed);
    imu.Gyroscope = gp;
    [~, gyro] = imu(zeros(n,3), zeros(n,3));
    [avar, tau] = allanvar(gyro(:,1), 'octave', Fs);
    adev = sqrt(avar);
end

function s = slopeOf(tau, adev, idx)
    p = polyfit(log10(tau(idx)), log10(adev(idx)), 1);
    s = p(1);
end

function plotCase(tau, adev, expected, titleStr)
    figure;
    loglog(tau, adev, 'o-', tau, expected, '--');
    grid on;
    xlabel('\tau [s]');
    ylabel('Allan deviation [rad/s]');
    legend('imuSensor output', 'IEEE expected', 'Location', 'best');
    title(titleStr);
end
