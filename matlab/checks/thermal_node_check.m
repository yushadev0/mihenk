%% thermal_node_check.m
% Checks thermal_node.m - per-sensor temperatures for a heterogeneous node
% (bulgular.md, Finding 3D) - and feeds its output to imuSensor.
%
%   C1) Identical sensors -> identical temperatures (perfect common mode
%       appears only when we explicitly ask for it)
%   C2) Thermal lag: after an ambient step, each sensor reaches 63.2 % of
%       the step at t = tau
%   C3) Self-heating: steady-state rise = Rth * P
%   C4) Hysteresis through imuSensor: at the same die temperature, the
%       gyro thermal bias on the cooling leg exceeds the heating leg by
%       kb * hystWidth
%
% Figures are saved to figures/ automatically.

clear; clc; close all;

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'models'));
figDir = fullfile(here, '..', 'figures');
if ~isfolder(figDir), mkdir(figDir); end

%% Node definition
% ICM power: datasheet (DS-000347 rev 1.6, Table 3: 6-axis low-noise mode
% 0.88 mA at VDD 1.8 V). Everything else: assumed placeholders until the
% thermal-swing log (mihenk.md 14.2/2, Ek C.3) gives real values.
ICM_P = 0.88e-3 * 1.8;           % [W]
sensors = struct( ...
    'name',      {"ICM-42688-P", "Magnetometer", "BME688"}, ...
    'tau',       {120,  90,   200}, ...    % [s]      thermal time constant
    'gradient',  {0,    0.5,  -0.3}, ...   % [degC]   position on the board
    'Rth',       {150,  150,  150}, ...    % [degC/W] die-to-ambient resistance
    'hystWidth', {1.0,  0,    0});         % [degC]   thermal hysteresis
m = numel(sensors);

%% C1) Identical sensors give identical temperatures
t    = (0:3*3600)';
n    = numel(t);
Tamb = 25 + 10*sin(2*pi*t/3600);
Tsame = thermal_node(t, Tamb, repmat(ICM_P, n, 3), repmat(sensors(1), 1, 3));
c1 = max(abs(Tsame - Tsame(:,1)), [], 'all');

%% C2) Thermal lag: 63.2 % of an ambient step at t = tau
t    = (0:3000)';
n    = numel(t);
k0   = 1001;                     % ambient steps 25 -> 35 degC at t = 1000 s
Tamb = 25 * ones(n, 1);
Tamb(k0:end) = 35;
Tdie = thermal_node(t, Tamb, zeros(n, m), sensors);
c2 = 0;
for j = 1:m
    expected = 25 + sensors(j).gradient + 10*(1 - exp(-1));
    c2 = max(c2, abs(Tdie(k0 + sensors(j).tau, j) - expected));
end

%% C3) Self-heating: steady-state rise = Rth * P
t  = (0:10000)';
n  = numel(t);
P  = zeros(n, m);
P(k0:end, :) = 10e-3;            % 10 mW step at t = 1000 s
Tdie = thermal_node(t, 25*ones(n, 1), P, sensors);
rise = Tdie(end, :) - Tdie(k0, :);
c3 = max(abs(rise - [sensors.Rth]*10e-3) ./ ([sensors.Rth]*10e-3));

%% C4) Hysteresis through imuSensor
% 5 h profile: 25 degC hold, ramp to 45 (1 h), hold, ramp to 25 (1 h), hold
t    = (0:5*3600-1)';
n    = numel(t);
Tamb = interp1([0 0.5 1.5 2.5 3.5 5]*3600, [25 25 45 45 25 25], t);

P = repmat([ICM_P, 1e-3, 1e-3], n, 1);           % mag / BME688 baseline: assumed
heater = t >= 2.0*3600 & t < 2.25*3600;           % BME688 gas-heater burst: assumed
P(heater, 3) = P(heater, 3) + 10e-3;              % channel-specific self-heating
[Tdie, Teff] = thermal_node(t, Tamb, P, sensors);

% Unit-specific coefficients, drawn inside the datasheet bounds (Finding 4A)
rs = RandStream('mt19937ar', 'Seed', 7);
kbUnit     = (2*rand(rs, 1, 3) - 1) * 0.005*pi/180;  % +-0.005 dps/degC per axis
offsetUnit = (2*rand(rs) - 1) * 5;                   % +-5 degC temp-sensor offset (Finding 4E)

imu = imuSensor('accel-gyro', 'SampleRate', 1);
imu.Gyroscope = gyroparams('TemperatureBias', kbUnit);
g = zeros(n, 1);
for k = 1:n
    imu.Temperature = Teff(k, 1);                 % bias follows Teff, not Tdie
    [~, gyro] = imu([0 0 0], [0 0 0]);
    g(k) = gyro(1);
end

% Compare both legs at the same die temperature (35 degC)
up = t >= 0.75*3600 & t <= 1.5*3600;              % die temperature strictly rising
dn = t >= 2.75*3600 & t <= 3.5*3600;              % die temperature strictly falling
gUp = interp1(Tdie(up, 1), g(up), 35);
gDn = interp1(flipud(Tdie(dn, 1)), flipud(g(dn)), 35);
gapExpected = kbUnit(1) * sensors(1).hystWidth;
c4 = abs((gDn - gUp) - gapExpected) / abs(gapExpected);

% ICM on-chip temperature readout: unit offset + 16-bit quantization
Tread = round((Tdie(:, 1) - 25 + offsetUnit) * 132.48) / 132.48 + 25;

%% Report
fprintf('C1 identical sensors  max |dT|        : %.2e degC  -> %s\n', c1, verdict(c1 < 1e-12));
fprintf('C2 thermal lag        max error       : %.2e degC  -> %s\n', c2, verdict(c2 < 1e-9));
fprintf('C3 self-heating       max rel. error  : %.2e       -> %s\n', c3, verdict(c3 < 1e-9));
fprintf('C4 hysteresis gap     rel. error      : %.2e       -> %s\n', c4, verdict(c4 < 1e-6));
fprintf('   gap expected %.4e, measured %.4e rad/s (kb_x = %+.4f dps/degC)\n', ...
    gapExpected, gDn - gUp, rad2deg(kbUnit(1)));

fprintf('\nCommon-mode imperfection over the 5 h profile:\n');
for j = 1:m
    fprintf('  %-13s max |Tdie - Tamb| = %.2f degC\n', sensors(j).name, max(abs(Tdie(:, j) - Tamb)));
end
d = Tread - Tdie(:, 3);
fprintf('  ICM readout - BME688 die temp: mean %+.2f, range %.2f degC (unit offset %+.2f)\n', ...
    mean(d), max(d) - min(d), offsetUnit);

%% Plots
th = t / 3600;
f1 = figure;
plot(th, Tamb, 'k', th, Tdie, th, Tread, ':'); grid on;
xlabel('Time [h]'); ylabel('Temperature [\circC]');
legend(["Ambient", [sensors.name] + " die", "ICM readout (offset)"], 'Location', 'best');
title('Per-sensor temperatures (lag, gradient, self-heating)');

f2 = figure;
tiledlayout(1, 2);
nexttile;
plot(Tdie(:, 1), rad2deg(g)); grid on;
xlabel('ICM die temperature [\circC]'); ylabel('Gyro x thermal bias [dps]');
title('vs die temperature: hysteresis only');
nexttile;
plot(Tamb, rad2deg(g)); grid on;
xlabel('Ambient temperature [\circC]'); ylabel('Gyro x thermal bias [dps]');
title('vs ambient: hysteresis + lag');

exportgraphics(f1, fullfile(figDir, 'thermal_node_1.png'), 'Resolution', 150);
exportgraphics(f2, fullfile(figDir, 'thermal_node_2.png'), 'Resolution', 150);

%% Local helpers
function s = verdict(ok)
    s = "FAIL";
    if ok, s = "PASS"; end
end
