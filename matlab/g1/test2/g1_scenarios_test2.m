function SC = g1_scenarios_test2()
%G1_SCENARIOS_TEST2 Second held-out set for the G1 acceptance test
%   (bulgular.md, section 21). Declared and committed before any detector
%   was run on it. Instead of hand-written scenarios, every seed 200-299
%   draws one scenario from declared ranges with its own random stream
%   (seed 50000 + s), so nobody chose the individual cases. Seeds 200-299
%   were never used before (dev 0-9, spent 100-119, diagnosis 300-309).
%
%   Ten families, ten seeds each (family = mod(s - 200, 10) + 1):
%     fault  drift-ramp   one drift during a trapezoid profile
%     fault  drift-sine   one drift during a sinusoidal profile
%     fault  step         one step (offset) fault
%     slow   slow         slow drift at constant temperature (K2d)
%     fault  two-faults   two drifts on two different sensing elements
%     none   clean        no fault
%     none   heaters      no fault, three heater bursts
%     none   emi          magnetometer EMI, no motion fault
%     none   bme-drift    BME688 temperature drift, no motion fault
%     none   bme-step     BME688 temperature step, no motion fault
%
%   Drawn for every scenario (ranges in section 21):
%     profile    trapezoid or sinusoid (fixed by the family where named)
%     heaters    1-2 bursts of 10-20 min (3 in "heaters")
%     hysteresis play (width 0.5-1.5 degC), relax (tau 90-600 s) or
%                Prandtl-Ishlinskii (widths 0.2-0.6 and 1.0-2.0 degC,
%                a form G1 does not model), one third each
%     BME path   first order, or second order with tau2 100-400 s (half each)
%   All scenarios run 8 h. Noise seeds follow the dev convention
%   (unitSeed = 7 + 100 s, ...).

h = 3600;
fam = ["drift-ramp", "drift-sine", "step", "slow", "two-faults", ...
       "clean", "heaters", "emi", "bme-drift", "bme-step"];
cls = ["fault", "fault", "fault", "slow", "fault", "none", "none", "none", "none", "none"];
drift = [0.02 0.04; 0.3 0.6; 0.3 0.6];      % dps/h, mg/h, uT/h per sensing element
step  = [0.02 0.05; 0.2 0.5; 0.5 1.5];      % dps, mg, uT
slow  = [0.015 0.025; 0.22 0.35];           % >= 1.1 x 5 K sqrt(1 h) of the colored fit (K2d)
none  = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});

SC = struct('name', {}, 'family', {}, 'class', {}, 'seed', {}, 'hyst', {}, ...
    'bmeTau2', {}, 'S', {});
for s = 200:299
    i  = mod(s - 200, 10) + 1;
    rs = RandStream('mt19937ar', 'Seed', 50000 + s);
    U  = @(a, b) a + (b - a) * rand(rs);
    sg = @() 2 * (rand(rs) < 0.5) - 1;
    flt = @(ch, t0, type, mag) struct('ch', ch, 't0', t0*h, 'type', type, 'mag', mag);
    S = struct('Tend', 8*h, 'faults', none, 'emi', [], 'bmeFault', [], ...
        'unitSeed', 7 + 100*s, 'icmSeed', 11 + 100*s, 'magSeed', 12 + 100*s, 'noiseSeed', 13 + 100*s);

    % ambient profile
    if fam(i) == "slow"
        Tc = U(18, 35);
        S.profileT = [0 8]*h;  S.profileC = [Tc Tc];
    else
        sine = fam(i) == "drift-sine" || (fam(i) ~= "drift-ramp" && rand(rs) < 0.5);
        if sine
            tp = 0:600:8*h;
            m = U(20, 32);  A = U(4, 10);  P = U(2, 6)*h;  ph = U(0, 2*pi);
            S.profileT = tp;  S.profileC = m + A*sin(2*pi*tp/P + ph);
        else
            L0 = U(15, 30);  dT = U(8, 18) * sg();  rate = U(5, 15);
            t1 = U(0.75, 1.5);  pl = U(1, 2.5);
            r = min(abs(dT) / rate, (7.5 - t1 - pl) / 2);
            S.profileT = [0, t1, t1 + r, t1 + r + pl, t1 + 2*r + pl, 8]*h;
            S.profileC = [L0, L0, L0 + dT, L0 + dT, L0, L0];
        end
    end

    % heater bursts, one per equal slot of [1, 7.6] h
    nH = 1 + (rand(rs) < 0.5);
    if fam(i) == "heaters", nH = 3; end
    edges = linspace(1, 7.6, nH + 1);
    S.heaterOn = zeros(nH, 2);
    for j = 1:nH
        len = U(10, 20) / 60;
        t0 = U(edges(j), edges(j + 1) - len);
        S.heaterOn(j, :) = [t0, t0 + len]*h;
    end

    % ICM hysteresis form
    r = rand(rs);
    if r < 1/3
        S.hystType = "play";  S.hystWidth = U(0.5, 1.5);
        hy = sprintf("play %.2f", S.hystWidth);
    elseif r < 2/3
        S.hystType = "relax";  S.hystTau = U(90, 600);
        hy = sprintf("relax %.0f", S.hystTau);
    else
        S.hystType = "pi";  S.hystWidths = [U(0.2, 0.6), U(1.0, 2.0)];
        hy = sprintf("pi %.2f/%.2f", S.hystWidths);
    end

    % BME688 thermal path
    S.bmeTau2 = 0;
    if rand(rs) >= 0.5, S.bmeTau2 = U(100, 400); end

    % events
    switch fam(i)
        case {"drift-ramp", "drift-sine"}
            ch = randi(rs, 9);  g = ceil(ch / 3);
            S.faults = flt(ch, U(2.5, 5.5), "drift", U(drift(g, 1), drift(g, 2)) * sg());
        case "step"
            ch = randi(rs, 9);  g = ceil(ch / 3);
            S.faults = flt(ch, U(2.5, 5.5), "step", U(step(g, 1), step(g, 2)) * sg());
        case "slow"
            ch = randi(rs, 6);  g = ceil(ch / 3);
            S.faults = flt(ch, U(1.5, 3), "drift", U(slow(g, 1), slow(g, 2)) * sg());
        case "two-faults"
            g = randperm(rs, 3, 2);
            ch = 3*(g - 1) + [randi(rs, 3), randi(rs, 3)];
            t0 = U(2.5, 5);
            S.faults = [flt(ch(1), t0, "drift", U(drift(g(1), 1), drift(g(1), 2)) * sg()), ...
                        flt(ch(2), t0 + U(0, 0.5), "drift", U(drift(g(2), 1), drift(g(2), 2)) * sg())];
        case "emi"
            t0 = U(2, 5);
            S.emi = struct('t0', t0*h, 't1', (t0 + U(10, 40)/60)*h, ...
                'amp', [U(0.5, 2)*sg(), U(0.5, 2)*sg(), U(0.5, 2)*sg()]);
        case "bme-drift"
            S.bmeFault = struct('t0', U(2.5, 5.5)*h, 'type', "drift", 'mag', U(0.5, 2) * sg());
        case "bme-step"
            S.bmeFault = struct('t0', U(2.5, 5.5)*h, 'type', "step", 'mag', U(0.5, 2) * sg());
    end

    SC(end+1) = struct('name', sprintf("%s-%d", fam(i), s), 'family', fam(i), 'class', cls(i), ...
        'seed', s, 'hyst', hy, 'bmeTau2', S.bmeTau2, 'S', S); %#ok<AGROW>
end
end
