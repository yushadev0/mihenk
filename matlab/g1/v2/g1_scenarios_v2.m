function SC = g1_scenarios_v2()
%G1_SCENARIOS_V2 Scenario set for the G1 v2 evaluation (bulgular.md, section 8).
%   Each entry: name, what it tests, expected correct behaviour, and the
%   simulate_node overrides S. All but the first use colored noise
%   (bias instability + random walk). The BME688 heater burst of the default
%   scenario stays in every scenario.

h = 3600;
none   = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
gzBase = struct('ch', 3, 't0', 4.5*h, 'type', "drift", 'mag', 0.03);   % dps/h

SC = struct('name', {}, 'tests', {}, 'expect', {}, 'S', {});

SC(end+1).name = "white";
SC(end).tests  = "v1 conditions, only the seed changes";
SC(end).expect = "gz blamed; nothing else";
SC(end).S      = struct();

SC(end+1).name = "colored";
SC(end).tests  = "bias instability + random walk";
SC(end).expect = "gz blamed; nothing else";
SC(end).S      = struct('noise', "colored");

SC(end+1).name = "hold-fault";
SC(end).tests  = "slow drift at constant temperature (no thermal masking)";
SC(end).expect = "gz blamed";
SC(end).S      = struct('noise', "colored", ...
    'faults', struct('ch', 3, 't0', 6.25*h, 'type', "drift", 'mag', 0.01));

SC(end+1).name = "accel-step";
SC(end).tests  = "step fault on an accelerometer axis during a ramp";
SC(end).expect = "ay blamed";
SC(end).S      = struct('noise', "colored", ...
    'faults', struct('ch', 5, 't0', 5.0*h, 'type', "step", 'mag', 0.3));       % mg

SC(end+1).name = "two-faults";
SC(end).tests  = "two independent faults starting together (class 8)";
SC(end).expect = "gz and ax blamed; not taken as common mode";
SC(end).S      = struct('noise', "colored", 'faults', [gzBase, ...
    struct('ch', 4, 't0', 4.5*h, 'type', "drift", 'mag', 0.5)]);              % mg/h

SC(end+1).name = "emi";
SC(end).tests  = "magnetic interference: environmental but not common mode (class 8)";
SC(end).expect = "no sensor fault - G1 is expected to fail here";
SC(end).S      = struct('noise', "colored", 'faults', none, ...
    'emi', struct('t0', 5.0*h, 't1', 5.33*h, 'amp', [2 -1.5 1]));              % uT

SC(end+1).name = "bme-fault";
SC(end).tests  = "the confounder sensor itself drifts (class 7)";
SC(end).expect = "BME688 temperature blamed; no motion channel blamed";
SC(end).S      = struct('noise', "colored", 'faults', none, ...
    'bmeFault', struct('t0', 5.0*h, 'type', "drift", 'mag', 0.5));             % degC/h

SC(end+1).name = "hyst-relax";
SC(end).tests  = "model mismatch: relaxation hysteresis, detector assumes play (ADR-012)";
SC(end).expect = "gz blamed; nothing else";
SC(end).S      = struct('noise', "colored", 'hystType', "relax", 'hystTau', 180);

tp = (0:600:8*h);
SC(end+1).name = "day-cycle";
SC(end).tests  = "sinusoidal ambient 25 +- 8 degC, 4 h period (faster, never flat)";
SC(end).expect = "gz blamed; nothing else";
SC(end).S      = struct('noise', "colored", 'profileT', tp, ...
    'profileC', 25 + 8*sin(2*pi*tp/(4*h)), ...
    'faults', struct('ch', 3, 't0', 5.0*h, 'type', "drift", 'mag', 0.03));
end
