function D = simulate_node(S)
%SIMULATE_NODE Synthetic heterogeneous node for G1 experiments.
%   D = simulate_node() runs the default scenario (as in g1_prototype_v0):
%   stationary node, 8 h, ambient 25 -> 40 -> 25 degC, BME688 heater burst
%   (channel-specific heat, no fault) and a gyro z bias drift (fault).
%   D = simulate_node(S) overrides any field of the default scenario S.
%
%   Firmware-visible outputs (60 s block means unless noted):
%     D.Y       [nB x 9]  gx gy gz [dps] | ax ay az [mg] | mx my mz [uT]
%     D.TicmB   [nB x 1]  ICM temperature readout      [degC]
%     D.TbmeB   [nB x 1]  BME688 temperature readout   [degC]
%     D.Ticm, D.Tbme      same readouts on the thermal grid (D.tT, 10 s)
%   Ground truth (evaluation only - never give it to a detector):
%     D.truth.fault [nB x 9] logical, D.truth.heater [nB x 1] logical,
%     D.truth.Tamb, D.truth.Tdie, D.truth.unit (sampled coefficients)

h = 3600;
def = struct( ...
    'Fs',        10, ...                    % motion sample rate [Hz]
    'dtT',       10, ...                    % thermal step [s]
    'Tend',      8*h, ...
    'profileT',  [0 1 3 4 6 8]*h, ...       % ambient breakpoints [s]
    'profileC',  [25 25 40 40 25 25], ...   % ambient values [degC]
    'heaterOn',  [3.25 3.50]*h, ...         % BME688 heater burst [s]
    'heaterP',   10e-3, ...                 % [W]
    'faultCh',   3, ...                     % gyro z
    'faultT0',   4.5*h, ...                 % [s]
    'faultRate', 0.03, ...                  % [dps/h]
    'B',         60, ...                    % block length [s]
    'unitSeed',  7, 'icmSeed', 11, 'magSeed', 12);
if nargin < 1, S = struct(); end
for f = fieldnames(S)', def.(f{1}) = S.(f{1}); end
S = def;

%% Ambient and per-sensor temperatures
tT   = (0:S.dtT:S.Tend-S.dtT)';
nT   = numel(tT);
Tamb = interp1(S.profileT, S.profileC, tT);

ICM_P = 0.88e-3 * 1.8;                      % datasheet (Table 3)
sensors = struct( ...
    'name',      {"ICM-42688-P", "Magnetometer", "BME688"}, ...
    'tau',       {120,  90,   200}, ...     % assumed
    'gradient',  {0,    0.5,  -0.3}, ...    % assumed
    'Rth',       {150,  150,  150}, ...     % assumed
    'hystWidth', {1.0,  0,    0});          % assumed
P = repmat([ICM_P, 1e-3, 1e-3], nT, 1);
heater = tT >= S.heaterOn(1) & tT < S.heaterOn(2);
P(heater, 3) = P(heater, 3) + S.heaterP;
[Tdie, Teff] = thermal_node(tT, Tamb, P, sensors);

%% Unit-specific coefficients (draw order is part of the reproducibility contract)
rs = RandStream('mt19937ar', 'Seed', S.unitSeed);
u  = @(k) 2*rand(rs, 1, k) - 1;
unit.kbGyro  = u(3) * 0.005*pi/180;         % rad/s/degC    datasheet bound
unit.kbAccel = u(3) * 0.15e-3*9.80665;      % m/s^2/degC    datasheet bound
unit.kbMag   = u(3) * 0.05;                 % uT/degC       assumed
unit.offIcm  = u(1) * 5;                    % degC          datasheet bound
unit.offBme  = u(1) * 0.5;                  % degC          assumed

%% Sensors
icm = imuSensor('accel-gyro', 'SampleRate', S.Fs, ...
    'RandomStream', 'mt19937ar with seed', 'Seed', S.icmSeed);
icm.Gyroscope = gyroparams('NoiseDensity', 2.8e-3*pi/180, ...
    'NoiseType', 'single-sided', 'TemperatureBias', unit.kbGyro);
icm.Accelerometer = accelparams('NoiseDensity', [65 65 70]*1e-6*9.80665, ...
    'NoiseType', 'single-sided', 'TemperatureBias', unit.kbAccel);
mag = imuSensor('accel-mag', 'SampleRate', S.Fs, ...
    'RandomStream', 'mt19937ar with seed', 'Seed', S.magSeed);
mag.Magnetometer = magparams('NoiseDensity', 0.1, ...     % uT/sqrt(Hz), assumed
    'NoiseType', 'single-sided', 'TemperatureBias', unit.kbMag);

nS = S.dtT * S.Fs;
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

% Fault: additive gyro bias drift
ts = (0:N-1)' / S.Fs;
drift = max(ts - S.faultT0, 0)/h * S.faultRate*pi/180;
if S.faultCh >= 1 && S.faultCh <= 3
    gyro(:, S.faultCh) = gyro(:, S.faultCh) + drift;
end

% Temperature readouts
Ticm = round((Tdie(:, 1) - 25 + unit.offIcm) * 132.48) / 132.48 + 25;   % 16-bit register
Tbme = round((Tdie(:, 3) + unit.offBme) * 100) / 100;                    % 0.01 degC, assumed

%% 60 s block means
nB   = S.Tend / S.B;
blk  = @(x) reshape(mean(reshape(x, S.B*S.Fs, nB, []), 1), nB, []);
blkT = @(x) mean(reshape(x, S.B/S.dtT, nB), 1)';

D.S     = S;
D.names = ["gx" "gy" "gz" "ax" "ay" "az" "mx" "my" "mz"];
D.icmCh = 1:6;                              % channels on the ICM die
D.Y     = [rad2deg(blk(gyro)), blk(accel)/9.80665*1e3, blk(magn)];
D.tB    = ((1:nB)' - 0.5) * S.B;
D.TicmB = blkT(Ticm);
D.TbmeB = blkT(Tbme);
D.tT    = tT;
D.Ticm  = Ticm;
D.Tbme  = Tbme;

fault = false(nB, 9);
fault(:, S.faultCh) = D.tB >= S.faultT0;
D.truth.fault  = fault;
D.truth.heater = D.tB >= S.heaterOn(1) & D.tB < S.heaterOn(2) + 3*sensors(3).tau;
D.truth.Tamb   = Tamb;
D.truth.Tdie   = Tdie;
D.truth.unit   = unit;
D.truth.sensors = sensors;
end
