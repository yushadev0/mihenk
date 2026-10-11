%% g1_smoke_test2.m
% Checks before the one-shot g1_acceptance_test2 run (bulgular.md, section
% 21). Prints no detector metric on the held-out set.
% 1. Simulator: the default path and the play / relax paths are unchanged
%    after the "pi" and bmeTau2 extensions, and v10 = v9noE: metrics of
%    v10 and v6 on four dev/spent runs reproduce g1_v9_results.csv.
%    A "pi" form with two equal widths equals the play form (bit level).
% 2. The 100 held-out scenarios as drawn (parameters only).
% 3. One scenario per family runs through simulate_node, v10 and v6
%    without error; temperature-level sanity of the new forms.
% ~3-4 min.

clear; clc;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(here, g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;

none = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
for nz = ["white", "colored"]
    Sc = struct('noise', nz, 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
        'heaterOn', [], 'faults', none, ...
        'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
    Dc = simulate_node(Sc);
    NM.(char(nz)) = g1_allan_fit(Dc.Y, Dc.S.B);
end
seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);

%% 1. Regression against the v9 dev run
CSV = readtable(fullfile(g1, 'v9', 'g1_v9_results.csv'), 'TextType', 'string');
SCd = g1_scenarios_v3();  SCt = g1_scenarios_test();
runs = {"dev", SCd, "base", "white"; "dev", SCd, "two-faults", "colored"; ...
        "dev", SCd, "hyst-relax", "white"; "spent", SCt, "t9-relax-az", "colored"};
worst = 0;
for j = 1:size(runs, 1)
    [sn, SC, name, nz] = runs{j, :};
    s = 0;  if sn == "spent", s = 100; end
    S = SC([SC.name] == name).S;  S.noise = nz;
    D = simulate_node(seedS(S, s));
    R = {g1_detect_v10(D, NM.(char(nz))), g1_detect_v6(D, NM.(char(nz)))};
    for d = 1:2
        Rc = R{d};  Rc.valid = Rc.valid & g1_detect_v0(D).valid;
        m = lite(D, Rc);
        ref = CSV(CSV.set == sn & CSV.scenario == name & CSV.noise == nz & CSV.seed == s & ...
            CSV.detector == ifelse(d == 1, "v9noE", "v6"), :);
        e = max(abs([m.falsePerH - ref.falsePerH, m.episodesPerH - ref.episodesPerH, ...
            fillNan(m.coverage - ref.coverage)]));
        worst = max(worst, e);
    end
end
fprintf('Regression v10 / v6 vs v9noE / v6 rows of g1_v9_results.csv (4 runs): max difference %.2g %s\n', ...
    worst, string(ifelse(worst < 1e-12, '(OK)', '(MISMATCH)')));
D1 = simulate_node();
D2 = simulate_node(struct('hystType', "pi", 'hystWidths', [1 1]));
fprintf('"pi" with widths [1 1] vs default play 1.0: max difference %g %s\n', ...
    max(abs(D1.Y - D2.Y), [], 'all'), string(ifelse(isequal(D1.Y, D2.Y), '(OK)', '(MISMATCH)')));

%% 2. The held-out scenarios
SC2 = g1_scenarios_test2();
fprintf('\nHeld-out scenarios (%d):\n', numel(SC2));
for i = 1:numel(SC2)
    S = SC2(i).S;
    ev = "";
    for f = S.faults(:)'
        ev = ev + sprintf("%s %s %+.3g @%.2f h; ", string(compose("ch%d", f.ch)), f.type, f.mag, f.t0/h);
    end
    if ~isempty(S.emi), ev = ev + sprintf("EMI %.2f-%.2f h [%+.1f %+.1f %+.1f]; ", S.emi.t0/h, S.emi.t1/h, S.emi.amp); end
    if ~isempty(S.bmeFault), ev = ev + sprintf("BME %s %+.2f @%.2f h; ", S.bmeFault.type, S.bmeFault.mag, S.bmeFault.t0/h); end
    fprintf('  %-16s %-5s T %4.1f-%4.1f degC  heaters %d  %-14s BME tau2 %3.0f  %s\n', SC2(i).name, ...
        SC2(i).class, min(S.profileC), max(S.profileC), size(S.heaterOn, 1), SC2(i).hyst, ...
        SC2(i).bmeTau2, ev);
end
form = extractBefore([SC2.hyst], " ");
fprintf('Forms: play %d, relax %d, pi %d; BME second order %d\n', nnz(form == "play"), ...
    nnz(form == "relax"), nnz(form == "pi"), nnz([SC2.bmeTau2] > 0));

%% 3. One scenario per family runs (no metrics)
for i = 1:10
    S = SC2(i).S;  S.noise = "white";
    D = simulate_node(S);
    g1_detect_v10(D, NM.white);  g1_detect_v6(D, NM.white);
    fprintf('  %-16s runs; ICM hysteresis offset max %.2f degC, BME - ICM die max %.2f degC\n', ...
        SC2(i).name, max(abs(D.truth.Teff(:, 1) - D.truth.Tdie(:, 1))), ...
        max(abs(D.truth.Tdie(:, 3) - D.truth.Tdie(:, 1))));
end

function m = lite(D, R)
    st = R.state;  fault = D.truth.fault;  valid = R.valid;
    flag = st == 1;  ofs = st == 2;
    healthy = ~fault & valid;
    if any(D.truth.emi), healthy(D.truth.emi, 7:9) = false; end
    hours = nnz(valid) * D.S.B / 3600;
    m.falsePerH = nnz(flag & healthy) / hours;
    onsets = diff([false(1, 9); flag & healthy]) == 1;
    m.episodesPerH = (nnz(onsets) + nnz(ofs & healthy)) / hours;
    cv = nan(1, numel(D.S.faults));
    for i = 1:numel(D.S.faults)
        f = D.S.faults(i);  c = f.ch;  after = D.tB >= f.t0;
        rep = flag(:, c);
        if f.type == "step"
            ko = find(ofs(:, c) & after, 1);
            if ~isempty(ko), rep(ko:end) = true; end
        end
        cv(i) = nnz(rep & fault(:, c) & valid) / nnz(fault(:, c) & valid);
    end
    m.coverage = mean(cv);
    if isempty(cv), m.coverage = NaN; end
end

function x = fillNan(x)
    x(isnan(x)) = 0;
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
