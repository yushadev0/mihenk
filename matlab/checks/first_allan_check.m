%% first_allan_check.m
% Sanity check for the reference model: does imuSensor give back the
% noise density we put in? (principle I7 / CI gate #3, in miniature)
%
% Stationary sensor, white noise only -> Allan deviation must follow
% sigma(tau) = N / sqrt(tau). M1 exit criterion: within +-10 %.

clear; clc; close all;

%% Parameters (provenance: datasheet - ICM-42688-P DS-000347 rev 1.6,
% Tables 1-2, @10 Hz)
Fs = 100;                        % sample rate [Hz]
T  = 2 * 3600;                   % duration [s] - 2 h stationary
n  = T * Fs;

gyroN  = 2.8e-3 * pi/180;            % 0.0028 dps/sqrt(Hz) -> rad/s/sqrt(Hz)
accelN = [65 65 70] * 1e-6 * 9.80665; % X,Y 65 / Z 70 ug/sqrt(Hz) -> m/s^2/sqrt(Hz)

%% Sensor model
% NoiseType must be "single-sided": datasheets and the Allan N use the
% one-sided PSD (white std = N*sqrt(Fs)). MATLAB's default "double-sided"
% uses sqrt(Fs/2) and silently yields N/sqrt(2) (-29.3 %).
imu = imuSensor('accel-gyro', 'SampleRate', Fs);
imu.Gyroscope     = gyroparams('NoiseDensity', gyroN, 'NoiseType', 'single-sided');
imu.Accelerometer = accelparams('NoiseDensity', accelN, 'NoiseType', 'single-sided');

%% Simulate: sensor sits still on a table
trueAcc    = zeros(n, 3);        % no motion (gravity is added by imuSensor)
trueAngVel = zeros(n, 3);
[accelReadings, gyroReadings] = imu(trueAcc, trueAngVel);

%% Allan deviation of gyro X
[avar, tau] = allanvar(gyroReadings(:,1), 'octave', Fs);
adev = sqrt(avar);

% White noise: adev * sqrt(tau) = N on every tau; use tau <= T/10
% (longer tau has too few clusters to be reliable)
idx   = tau <= T/10;
N_est = median(adev(idx) .* sqrt(tau(idx)));
err   = 100 * (N_est - gyroN) / gyroN;

fprintf('Given N     : %.4e rad/s/sqrt(Hz)\n', gyroN);
fprintf('Recovered N : %.4e rad/s/sqrt(Hz)\n', N_est);
fprintf('Error       : %+.2f %%  -> %s\n', err, ...
    string(ifelse(abs(err) <= 10, "PASS", "FAIL")));

%% Plot
figure;
loglog(tau, adev, 'o-', tau, gyroN ./ sqrt(tau), '--');
grid on;
xlabel('\tau [s]');
ylabel('Allan deviation [rad/s]');
legend('imuSensor output', 'Expected N/\surd\tau', 'Location', 'southwest');
title('Gyro X - Allan deviation (stationary, white noise only)');

%% Local helper
function out = ifelse(cond, a, b)
    if cond, out = a; else, out = b; end
end
