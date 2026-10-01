function SC = g1_scenarios_test()
%G1_SCENARIOS_TEST Held-out scenario set for the G1 acceptance test
%   (bulgular.md, section 11). Written and committed before any v5 result
%   was seen and never used for design: profiles, fault channels, sizes and
%   times differ from the development set (g1_scenarios_v3.m). Each
%   scenario runs with white and colored noise, seeds 100-119.
%
%   class: "fault" motion fault judged by K2 (detection, delay, coverage)
%          "slow"  slow drift at constant temperature, judged by K2b
%          "none"  no motion fault (false alarms and traps only)

h = 3600;
none = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
flt  = @(ch, t0, type, mag) struct('ch', ch, 't0', t0*h, 'type', type, 'mag', mag);
prof = @(t, c) struct('profileT', t*h, 'profileC', c);

SC = struct('name', {}, 'class', {}, 'tests', {}, 'S', {});

% T1 faster, smaller ramp; gz drift in the middle of the down-ramp
S = prof([0 0.75 2.25 3.5 5 8], [20 20 35 35 20 20]);
S.faults = flt(3, 4.25, "drift", 0.02);                   % dps/h
S.heaterOn = [5.5 5.7]*h;
SC(end+1) = struct('name', "t1-fast-ramp", 'class', "fault", ...
    'tests', "gz drift during a faster down-ramp (10 degC/h)", 'S', S);

% T2 step on a plateau
S = prof([0 1.5 3 5 6.5 8], [22 22 38 38 22 22]);
S.faults = flt(4, 4.0, "step", 0.2);                      % mg
S.heaterOn = [2.0 2.2]*h;
SC(end+1) = struct('name', "t2-plateau-step", 'class', "fault", ...
    'tests', "ax step at constant temperature (plateau)", 'S', S);

% T3 slow sinusoid, gy drift
tp = 0:600:8*h;
S = struct('profileT', tp, 'profileC', 25 + 5*sin(2*pi*tp/(6*h)));
S.faults = flt(2, 3.0, "drift", 0.02);
S.heaterOn = [1.5 1.7]*h;
SC(end+1) = struct('name', "t3-slow-sine", 'class', "fault", ...
    'tests', "gy drift under a 25 +- 5 degC, 6 h sinusoid", 'S', S);

% T4 magnetometer fault (never tested in development)
S = prof([0 1 2.5 4 5.5 8], [24 24 36 36 24 24]);
S.faults = flt(9, 4.5, "drift", 0.3);                     % uT/h
S.heaterOn = [6.5 6.7]*h;
SC(end+1) = struct('name', "t4-mag-drift", 'class', "fault", ...
    'tests', "mz drift during the down-ramp", 'S', S);

% T5 two heater bursts, no fault
S = prof([0 1 3 4 6 8], [25 25 40 40 25 25]);
S.faults = none;
S.heaterOn = [1.5 1.7; 6.0 6.25]*h;
SC(end+1) = struct('name', "t5-two-heaters", 'class', "none", ...
    'tests', "two BME688 heater bursts (ramp and rest), no fault", 'S', S);

% T6 EMI on a plateau, other amplitude
S = prof([0 1 3 4.5 6 8], [25 25 38 38 25 25]);
S.faults = none;
S.emi = struct('t0', 3.6*h, 't1', 3.85*h, 'amp', [-1 2 -0.5]);   % uT
S.heaterOn = [5.0 5.2]*h;
SC(end+1) = struct('name', "t6-emi-plateau", 'class', "none", ...
    'tests', "magnetic interference at constant temperature", 'S', S);

% T7 BME688 step fault
S = prof([0 1 3 4 6 8], [25 25 40 40 25 25]);
S.faults = none;
S.bmeFault = struct('t0', 4.5*h, 'type', "step", 'mag', 1.0);   % degC
S.heaterOn = [2.0 2.2]*h;
SC(end+1) = struct('name', "t7-bme-step", 'class', "none", ...
    'tests', "BME688 temperature step +1 degC (confounder fault)", 'S', S);

% T8 fault-free day cycle (pure false-alarm run)
tp = 0:600:8*h;
S = struct('profileT', tp, 'profileC', 25 + 8*sin(2*pi*tp/(3*h)));
S.faults = none;
S.heaterOn = [4.0 4.2]*h;
SC(end+1) = struct('name', "t8-cycle-clean", 'class', "none", ...
    'tests', "25 +- 8 degC, 3 h period, no fault", 'S', S);

% T9 relaxation hysteresis with another time constant, az drift
S = prof([0 0.75 2.75 4 6 8], [23 23 37 37 23 23]);
S.faults = flt(6, 4.5, "drift", 0.3);                     % mg/h
S.hystType = "relax";  S.hystTau = 300;
S.heaterOn = [6.5 6.7]*h;
SC(end+1) = struct('name', "t9-relax-az", 'class', "fault", ...
    'tests', "az drift, relaxation hysteresis tau 300 s (model mismatch)", 'S', S);

% T10 slow drift at constant temperature, 1 h drift >= 5*K*sqrt(1 h):
% largest gyro K of the Allan fit 0.0027 dps/sqrt(h) -> 0.0135; use 0.015
S = prof([0 8], [28 28]);
S.faults = flt(1, 2.0, "drift", 0.015);
S.heaterOn = [6.0 6.2]*h;
SC(end+1) = struct('name', "t10-slow-drift", 'class', "slow", ...
    'tests', "gx slow drift at constant 28 degC (detectability floor, 9D)", 'S', S);
end
