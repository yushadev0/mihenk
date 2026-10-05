%% g1_prototype_v7.m
% Development run of G1 v7 (g1_detect_v7.m): v6 plus D1 (model error of a
% frozen channel anchored at the freeze) and D2 (a large non-growing
% deviation is an offset event), bulgular section 17, with one ablation per
% change.
%
% 0. Equivalence: v7 with D1 and D2 off must reproduce g1_detect_v6
%    exactly (states, score, temperature-source flags).
% 1. Characterization: the same 12 h static logs and Allan fit as v3-v6.
% 2. Evaluation, detectors v6, v7noD1, v7noD2, v7 on the same data as v6:
%    dev    g1_scenarios_v3, 8 scenarios x white/colored x seeds 0-9
%    spent  g1_scenarios_test, 10 scenarios x white/colored x seeds 100-109
%    Scoring window as in v5/v6 development.
% 3. Regression: the v6 rows must equal g1_v6_results.csv (the v6 detector
%    got two diagnostic switches for section 17; their defaults must not
%    change it).
% 4. Selection rule (declared before any v7 result): the candidate is v7
%    unless an ablation is nowhere worse and somewhere better on the
%    scenario-level metrics listed in the summary.
%
% Metrics are those of g1_prototype_v6.m (states: 1 fault, 2 offset event,
% 3 unreliable; coverage counts a step as reported after an offset event).
%
% Output: g1_v7_output.txt, g1_v7_results.csv. Runtime ~1.5 h (360 runs x 4
% detectors).

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_v7_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

%% 1. Characterization (identical to v3-v6)
noises = ["white", "colored"];
none   = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
NM     = struct();
for nz = noises
    Sc = struct('noise', nz, 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
        'heaterOn', [], 'faults', none, ...
        'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
    Dc = simulate_node(Sc);
    NM.(char(nz)) = g1_allan_fit(Dc.Y, Dc.S.B);
end
seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);

%% 0. Equivalence: v7 with D1 and D2 off == v6
asV6 = struct('floorMode', "frozen", 'offsetLarge', false);
SCd = g1_scenarios_v3();
eqWorst = 0;
for i = [1, find([SCd.name] == "accel-step"), find([SCd.name] == "emi"), find([SCd.name] == "hyst-relax")]
    for nz = noises
        S = SCd(i).S;  S.noise = nz;
        D = simulate_node(seedS(S, 0));
        R6 = g1_detect_v6(D, NM.(char(nz)));
        R7 = g1_detect_v7(D, NM.(char(nz)), asV6);
        eqWorst = max([eqWorst, nnz(R6.state ~= R7.state), nnz(R6.tempFlag ~= R7.tempFlag), ...
            nnz(R6.tempAmbig ~= R7.tempAmbig), max(abs(R6.score - R7.score), [], 'all'), ...
            max(abs(R6.zT - R7.zT))]);
    end
end
fprintf('Equivalence v7(D1, D2 off) vs v6: max difference %.2g %s\n\n', eqWorst, ...
    string(ifelse(eqWorst == 0, '(OK)', '(MISMATCH)')));

%% 2. Evaluation
dets = ["v6", "v7noD1", "v7noD2", "v7"];
opts = {[], struct('floorMode', "frozen"), struct('offsetLarge', false), struct()};
sets = struct('name', {"dev", "spent"}, 'SC', {SCd, g1_scenarios_test()}, 'seeds', {0:9, 100:109});

rows = {};
tic;
for is = 1:numel(sets)
    for i = 1:numel(sets(is).SC)
        sc = sets(is).SC(i);
        for nz = noises
            for s = sets(is).seeds
                S = sc.S;  S.noise = nz;
                D = simulate_node(seedS(S, s));
                nmz = NM.(char(nz));
                R = cell(1, numel(dets));
                for d = 1:numel(dets)
                    if d == 1, R{d} = g1_detect_v6(D, nmz); else, R{d} = g1_detect_v7(D, nmz, opts{d}); end
                end
                both = g1_detect_v0(D).valid;
                for d = 1:numel(R), both = both & R{d}.valid; end
                for d = 1:numel(dets)
                    Rc = R{d};  Rc.valid = both;
                    M = g1_evaluate(D, Rc);
                    N = newMetrics(D, Rc, both);
                    rows(end+1, :) = {sets(is).name, sc.name, nz, s, dets(d), N.detected, N.delay, ...
                        N.coverage, N.coverageFlag, N.falsePerH, N.episodesPerH, N.offsetHealthy, ...
                        N.offsetFault, N.unrelShare, N.unrelOnFault, M.heaterSensorFlags, ...
                        M.tempFlagsOutside, M.emiAfterMagFlags, M.tempFaultSensorFlags, ...
                        M.tempFaultBlameIcm, M.tempFaultBlameBme + M.tempFaultAmbig}; %#ok<SAGROW>
                end
            end
        end
        fprintf('%-6s %-16s done (%.0f s)\n', sets(is).name, sc.name, toc);
    end
end
T = cell2table(rows, 'VariableNames', {'set', 'scenario', 'noise', 'seed', 'detector', ...
    'detected', 'delayMin', 'coverage', 'coverageFlag', 'falsePerH', 'episodesPerH', ...
    'offsetHealthy', 'offsetFault', 'unrelShare', 'unrelOnFault', 'heaterSensorFlags', ...
    'tSrcFlagsOutside', 'emiAfterMagShare', 'bmeSensorShare', 'bmeIcmShare', 'bmeOrAmbigShare'});
T.set = string(T.set);  T.scenario = string(T.scenario);
T.noise = string(T.noise);  T.detector = string(T.detector);
writetable(T, fullfile(here, 'g1_v7_results.csv'));

%% 3. Regression: v6 rows vs g1_v6_results.csv
V6 = readtable(fullfile(here, '..', 'v6', 'g1_v6_results.csv'), 'TextType', 'string');
V6 = V6(V6.detector == "v6", :);
metricsR = string(T.Properties.VariableNames(6:end));
worst = 0;  nCmp = 0;
for j = 1:height(V6)
    kk = find(T.set == V6.set(j) & T.scenario == V6.scenario(j) & T.noise == V6.noise(j) & ...
        T.seed == V6.seed(j) & T.detector == "v6");
    for m = metricsR
        a = T.(m)(kk);  b = V6.(m)(j);
        if isnan(a) && isnan(b), continue; end
        worst = max(worst, abs(a - b) / max(1, abs(b)));  nCmp = nCmp + 1;
    end
end
fprintf('\nRegression v6 vs g1_v6_results.csv: %d rows, %d values, max relative difference %.2g %s\n', ...
    height(V6), nCmp, worst, string(ifelse(worst < 1e-9, '(OK)', '(MISMATCH)')));

%% Summary
cols = @(c, w) strjoin(compose("%" + w + "s", string(c)), "");
md = @(x) median(x, 'omitnan');  mn = @(x) mean(x, 'omitnan');  mx = @(x) max(x, [], 'omitnan');
keys = unique(T(:, {'set', 'scenario', 'noise'}), 'stable');
fprintf('\nPer scenario: rows = detectors %s\n', strjoin(dets, ', '));
show = { ...
    'detected (mean)',              "detected",          mn, @pct; ...
    'delay [min] (median)',         "delayMin",          md, @num; ...
    'coverage (mean)',              "coverage",          mn, @pct; ...
    'coverage, flags only (mean)',  "coverageFlag",      mn, @pct; ...
    'false flags/h (median)',       "falsePerH",         md, @num; ...
    'false flags/h (worst)',        "falsePerH",         mx, @num; ...
    'false episodes/h (mean)',      "episodesPerH",      mn, @num2; ...
    'offset events, healthy (mean)', "offsetHealthy",    mn, @num; ...
    'offset events, faulty (mean)', "offsetFault",       mn, @num; ...
    'unreliable share (mean)',      "unrelShare",        mn, @pct; ...
    'unreliable on fault (mean)',   "unrelOnFault",      mn, @pct; ...
    'heater sensor flags (mean)',   "heaterSensorFlags", mn, @num; ...
    'T-src outside (mean)',         "tSrcFlagsOutside",  mn, @num; ...
    'EMI after, mag (mean)',        "emiAfterMagShare",  mn, @pct; ...
    'BME fault, sensor (mean)',     "bmeSensorShare",    mn, @pct; ...
    'BME fault, BME or ambig (mean)', "bmeOrAmbigShare", mn, @pct};
for j = 1:height(keys)
    sel = T.set == keys.set(j) & T.scenario == keys.scenario(j) & T.noise == keys.noise(j);
    fprintf('\n[%s] %s / %s\n%-32s%s\n', keys.set(j), keys.scenario(j), keys.noise(j), '', cols(dets, 9));
    for m = 1:size(show, 1)
        v = arrayfun(@(d) show{m, 3}(T.(show{m, 2})(sel & T.detector == d)), dets);
        if all(isnan(v)), continue; end
        fprintf('%-32s%s\n', show{m, 1}, cols(arrayfun(show{m, 4}, v, 'UniformOutput', false), 9));
    end
end

fprintf('\nOverall (all runs of both sets)\n%-32s%s\n', '', cols(dets, 9));
for nz = noises
    fprintf('[%s]\n', nz);
    for m = 1:size(show, 1)
        v = arrayfun(@(d) show{m, 3}(T.(show{m, 2})(T.noise == nz & T.detector == d)), dets);
        if all(isnan(v)), continue; end
        fprintf('%-32s%s\n', show{m, 1}, cols(arrayfun(show{m, 4}, v, 'UniformOutput', false), 9));
    end
end

%% 4. Selection rule
sm = { "detected", mn, 1; "delayMin", md, -1; "coverage", mn, 1; "falsePerH", md, -1; ...
       "falsePerH", mx, -1; "episodesPerH", mn, -1; "unrelShare", mn, -1; "unrelOnFault", mn, -1; ...
       "heaterSensorFlags", mn, -1; "tSrcFlagsOutside", mn, -1; "emiAfterMagShare", mn, -1; ...
       "bmeSensorShare", mn, -1; "bmeOrAmbigShare", mn, 1};
Mv = nan(height(keys), size(sm, 1), numel(dets));
for j = 1:height(keys)
    sel = T.set == keys.set(j) & T.scenario == keys.scenario(j) & T.noise == keys.noise(j);
    for d = 1:numel(dets)
        for m = 1:size(sm, 1)
            Mv(j, m, d) = sm{m, 2}(T.(sm{m, 1})(sel & T.detector == dets(d)));
        end
    end
end
dirn = reshape([sm{:, 3}], 1, []);
i7 = numel(dets);
pick = "v7";
fprintf('\nSelection: each ablation vs v7 over %d scenario/noise cells x %d metrics\n', height(keys), size(sm, 1));
for d = 2:numel(dets) - 1
    df = (Mv(:, :, d) - Mv(:, :, i7)) .* dirn;   % > 0: ablation better
    df(isnan(df)) = 0;
    worse = nnz(df < -1e-9);  better = nnz(df > 1e-9);
    fprintf('  %-7s worse in %3d, better in %3d\n', dets(d), worse, better);
    if worse == 0 && better > 0, pick = dets(d); end
end
fprintf('  -> candidate: %s\n', pick);
diary('off');

%% Helpers (newMetrics as in g1_prototype_v6.m)
function N = newMetrics(D, R, valid)
    st = R.state;  fault = D.truth.fault;  tB = D.tB;
    flag = st == 1;  ofs = st == 2;
    healthy = ~fault & valid;
    if any(D.truth.emi), healthy(D.truth.emi, 7:9) = false; end
    hours = nnz(valid) * D.S.B / 3600;
    N.falsePerH = nnz(flag & healthy) / hours;
    onsets = diff([false(1, size(flag, 2)); flag & healthy]) == 1;
    N.episodesPerH = (nnz(onsets) + nnz(ofs & healthy)) / hours;
    N.offsetHealthy = nnz(ofs & healthy);
    N.offsetFault = nnz(ofs & fault);
    N.unrelShare = nnz(R.unrel & valid) / nnz(valid);
    inF = fault & valid;
    N.unrelOnFault = NaN;
    if any(inF(:)), N.unrelOnFault = nnz(st == 3 & inF) / nnz(inF); end
    [N.detected, N.delay, N.coverage, N.coverageFlag] = deal(NaN);
    F = D.S.faults;
    if isempty(F), return; end
    det = zeros(1, numel(F));  dl = nan(1, numel(F));  cv = dl;  cf = dl;
    for i = 1:numel(F)
        c = F(i).ch;  after = tB >= F(i).t0;
        k = find(flag(:, c) & after, 1);
        if ~isempty(k), det(i) = 1; dl(i) = (tB(k) - F(i).t0) / 60; end
        rep = flag(:, c);
        if F(i).type == "step"
            ko = find(ofs(:, c) & after, 1);
            if ~isempty(ko), rep(ko:end) = true; end
        end
        inFc = fault(:, c) & valid;
        cv(i) = nnz(rep & inFc) / nnz(inFc);
        cf(i) = nnz(flag(:, c) & inFc) / nnz(inFc);
    end
    N.detected = mean(det);  N.delay = max(dl);  N.coverage = mean(cv);  N.coverageFlag = mean(cf);
end

function s = num(v)
    if isnan(v), s = "-"; else, s = sprintf('%.1f', v); end
end

function s = num2(v)
    if isnan(v), s = "-"; else, s = sprintf('%.2f', v); end
end

function s = pct(v)
    if isnan(v), s = "-"; else, s = sprintf('%.0f%%', 100*v); end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
