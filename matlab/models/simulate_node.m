function D = simulate_node(S)
%SIMULATE_NODE Synthetic heterogeneous node for G1 experiments.
%   D = simulate_node() runs the default scenario (as in g1_prototype_v0):
%   stationary node, 8 h, ambient 25 -> 40 -> 25 degC, BME688 heater burst
%   (channel-specific heat, no fault) and a gyro z bias drift (fault).
%   D = simulate_node(S) overrides any field of the default scenario S.
%   The default path is bit-identical to the one used for v0/v1; every
%   extension below is off by default and draws from its own random stream.
%
%   Extensions (G1 v2):
%     noise     "white" | "colored": adds bias instability (1/f, Kasdin
%               filter) and rate random walk per channel      (assumed values)
%     faults    struct array: ch (1-9), t0 [s], type "drift" | "step",
%               mag [channel unit per hour | channel unit]; may be empty
%     emi       [] | struct t0, t1 [s], amp [1x3 uT] - magnetometer only
%     bmeFault  [] | struct t0 [s], type "drift" | "step", mag [degC/h | degC]
%     hystType  "play" | "relax" (ICM thermal hysteresis form), hystTau [s]
%
%   Firmware-visible outputs (60 s block means unless noted):
%     D.Y       [nB x 9]  gx gy gz [dps] | ax ay az [mg] | mx my mz [uT]
%     D.TicmB   [nB x 1]  ICM temperature readout      [degC]
%     D.TbmeB   [nB x 1]  BME688 temperature readout   [degC]
%     D.Ticm, D.Tbme      same readouts on the thermal grid (D.tT, 10 s)
%   Ground truth (evaluation only - never give it to a detector):
%     D.truth.fault [nB x 9], D.truth.heater, D.truth.emi, D.truth.tempFault
%     [nB x 1] logical; D.truth.Tamb, Tdie, unit (sampled coefficients)

h = 3600;
def = struct( ...
    'Fs',        10, ...                    % motion sample rate [Hz]
    'dtT',       10, ...                    % thermal step [s]
    'Tend',      8*h, ...
    'profileT',  [0 1 3 4 6 8]*h, ...       % ambient breakpoints [s]
    'profileC',  [25 25 40 40 25 25], ...   % ambient values [degC]
    'heaterOn',  [3.25 3.50]*h, ...         % BME688 heater burst [s]; [] = none
    'heaterP',   10e-3, ...                 % [W]
    'B',         60, ...                    % block length [s]
    'unitSeed',  7, 'icmSeed', 11, 'magSeed', 12, 'noiseSeed', 13, ...
    'noise',     "white", ...
    'bi',        [5/3600, 0.04, 0.01], ...  % bias instability: gyro dps, accel mg, mag uT (assumed)
    'rrw',       [5/3600, 0.02, 0], ...     % random walk per sqrt(h), same units (assumed)
    'biPoles',   2000, ...                  % 1/f valid up to ~biPoles seconds
    'emi',       [], ...
    'bmeFault',  [], ...
    'hystType',  "play", ...
    'hystTau',   180);
def.faults = struct('ch', 3, 't0', 4.5*h, 'type', "drift", 'mag', 0.03);
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
    'hystWidth', {1.0,  0,    0}, ...       % assumed
    'hystTau',   {0,    0,    0});
if S.hystType == "relax"
    sensors(1).hystWidth = 0;
    sensors(1).hystTau   = S.hystTau;
end
P = repmat([ICM_P, 1e-3, 1e-3], nT, 1);
if ~isempty(S.heaterOn)
    heater = tT >= S.heaterOn(1) & tT < S.heaterOn(2);
    P(heater, 3) = P(heater, 3) + S.heaterP;
end
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

%% Faults (additive, in SI units at sample level)
ts = (0:N-1)' / S.Fs;
for f = S.faults(:)'
    if f.type == "drift"
        base = max(ts - f.t0, 0)/h;
    else
        base = double(ts >= f.t0);
    end
    if f.ch <= 3
        gyro(:, f.ch) = gyro(:, f.ch) + base * f.mag*pi/180;
    elseif f.ch <= 6
        accel(:, f.ch-3) = accel(:, f.ch-3) + base * f.mag*9.80665e-3;
    else
        magn(:, f.ch-6) = magn(:, f.ch-6) + base * f.mag;
    end
end
if ~isempty(S.emi)                           % environment, not a sensor fault
    on = ts >= S.emi.t0 & ts < S.emi.t1;
    magn(on, :) = magn(on, :) + S.emi.amp;
end

%% Temperature readouts
Ticm = round((Tdie(:, 1) - 25 + unit.offIcm) * 132.48) / 132.48 + 25;   % 16-bit register
Tbme = round((Tdie(:, 3) + unit.offBme) * 100) / 100;                    % 0.01 degC, assumed
if ~isempty(S.bmeFault)                      % the confounder sensor itself fails
    if S.bmeFault.type == "drift"
        Tbme = Tbme + max(tT - S.bmeFault.t0, 0)/h * S.bmeFault.mag;
    else
        Tbme = Tbme + (tT >= S.bmeFault.t0) * S.bmeFault.mag;
    end
end

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

%% Colored noise: bias instability + rate random walk, generated at 1 Hz
if S.noise == "colored"
    rsN = RandStream('mt19937ar', 'Seed', S.noiseSeed);
    n1  = S.Tend;
    Bv  = repelem(S.bi, 3);
    Kv  = repelem(S.rrw, 3) / 60;           % per sqrt(h) -> per sqrt(s)
    fc  = fractalcoef(S.biPoles, 1);
    X   = filter(fc.Numerator, fc.Denominator, randn(rsN, n1, 9) .* Bv) ...
        + cumsum(randn(rsN, n1, 9) .* Kv, 1);
    D.Y = D.Y + reshape(mean(reshape(X, S.B, nB, 9), 1), nB, 9);
end

%% Ground truth
fault = false(nB, 9);
for f = S.faults(:)'
    fault(:, f.ch) = fault(:, f.ch) | D.tB >= f.t0;
end
D.truth.fault  = fault;
D.truth.heater = false(nB, 1);
if ~isempty(S.heaterOn)
    D.truth.heater = D.tB >= S.heaterOn(1) & D.tB < S.heaterOn(2) + 3*sensors(3).tau;
end
D.truth.emi = false(nB, 1);
if ~isempty(S.emi)
    D.truth.emi = D.tB >= S.emi.t0 & D.tB < S.emi.t1 + 5*60;
end
D.truth.tempFault = false(nB, 1);
if ~isempty(S.bmeFault)
    D.truth.tempFault = D.tB >= S.bmeFault.t0;
end
D.truth.Tamb    = Tamb;
D.truth.Tdie    = Tdie;
D.truth.unit    = unit;
D.truth.sensors = sensors;
end
