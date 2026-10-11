%% g1_prototype_v9.m
% Development run of G1 v9 (g1_detect_v9.m): v8 without C2 and with an
% equivalence test for offset events (E), bulgular section 19 (19E, 19F),
% with one ablation per change, and the decision against v6.
%
% 0. Equivalence: v9 with C2 on and releaseTest "growth" must reproduce
%    g1_detect_v8 exactly. Also prints dMin per channel and noise type.
% 1. Characterization: the same 12 h static logs and Allan fit as v3-v8.
% 2. Evaluation, detectors v6 (current G1), v8 (reference), v9noE
%    (= v8 - C2), v9noC2 (= v8 + E), v9, on the same data as v6-v8:
%    dev    g1_scenarios_v3, 8 scenarios x white/colored x seeds 0-9
%    spent  g1_scenarios_test, 10 scenarios x white/colored x seeds 100-109
%    Scoring window as in v5-v8 development.
% 3. Regression: the v6 and v8 rows must equal g1_v8_results.csv.
% 4. Selection rule (declared before any v9 result, commit before the run;
%    same two steps and thresholds as v8, section 19):
%    step 1, within the v9 family: the candidate is v9 unless an ablation
%      (v9noE, v9noC2) is nowhere worse and somewhere better on the
%      scenario-level metrics;
%    step 2, against v6 (the current G1 detector): the candidate replaces
%      v6 only if
%        (a) over the same scenario/noise cells x metrics it is better in
%            more cells than it is worse, and
%        (b) for both noise types, over all runs: worst false flags/h <=
%            v6, mean coverage >= v6 - 1 point, mean detection >= v6.
%      Otherwise v6 stays the G1 detector. v8 is printed for reference and
%      takes no part in the decision.
%
% Metrics are those of g1_prototype_v8.m (relaxShare included).
%
% Output: g1_v9_output.txt, g1_v9_results.csv. Runtime ~1.5-2 h (360 runs x
% 5 detectors).

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_v9_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

%% 1. Characterization (identical to v3-v8)
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

%% 0. Equivalence: v9(C2 on, growth test) == v8
asV8 = struct('unreliable', true, 'releaseTest', "growth");
SCd = g1_scenarios_v3();
eqWorst = 0;
dif = @(A, B) max([nnz(A.state ~= B.state), nnz(A.tempFlag ~= B.tempFlag), ...
    nnz(A.tempAmbig ~= B.tempAmbig), max(abs(A.score - B.score), [], 'all'), max(abs(A.zT - B.zT))]);
for i = [1, find([SCd.name] == "two-faults"), find([SCd.name] == "accel-step"), find([SCd.name] == "hyst-relax")]
    for nz = noises
        S = SCd(i).S;  S.noise = nz;
        D = simulate_node(seedS(S, 0));
        nmz = NM.(char(nz));
        eqWorst = max(eqWorst, dif(g1_detect_v8(D, nmz), g1_detect_v9(D, nmz, asV8)));
    end
end
fprintf('Equivalence v9(C2 on, growth test) vs v8: max difference %.2g %s\n', eqWorst, ...
    string(ifelse(eqWorst == 0, '(OK)', '(MISMATCH)')));
for nz = noises
    Rq = g1_detect_v9(D, NM.(char(nz)));
    fprintf('dMin [%s], channel units per hour: %s\n', nz, strjoin(compose('%s %.3g', D.names', Rq.dMin')', ', '));
end
fprintf('\n');

%% 2. Evaluation
dets = ["v6", "v8", "v9noE", "v9noC2", "v9"];
opts = {[], [], struct('releaseTest', "growth"), struct('unreliable', true), struct()};
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
                    if d == 1, R{d} = g1_detect_v6(D, nmz);
                    elseif d == 2, R{d} = g1_detect_v8(D, nmz);
                    else, R{d} = g1_detect_v9(D, nmz, opts{d}); end
                end
                both = g1_detect_v0(D).valid;
                for d = 1:numel(R), both = both & R{d}.valid; end
                for d = 1:numel(dets)
                    Rc = R{d};  Rc.valid = both;
                    M = g1_evaluate(D, Rc);
                    N = newMetrics(D, Rc, both);
                    relaxShare = NaN;                       % (R) diagnostic
                    if isfield(Rc, 'tauHBest'), relaxShare = mean(~isnan(Rc.tauHBest(both, 1))); end
                    rows(end+1, :) = {sets(is).name, sc.name, nz, s, dets(d), N.detected, N.delay, ...
                        N.coverage, N.coverageFlag, N.falsePerH, N.episodesPerH, N.offsetHealthy, ...
                        N.offsetFault, N.unrelShare, N.unrelOnFault, M.heaterSensorFlags, ...
                        M.tempFlagsOutside, M.emiAfterMagFlags, M.tempFaultSensorFlags, ...
                        M.tempFaultBlameIcm, M.tempFaultBlameBme + M.tempFaultAmbig, relaxShare}; %#ok<SAGROW>
                end
            end
        end
        fprintf('%-6s %-16s done (%.0f s)\n', sets(is).name, sc.name, toc);
    end
end
T = cell2table(rows, 'VariableNames', {'set', 'scenario', 'noise', 'seed', 'detector', ...
    'detected', 'delayMin', 'coverage', 'coverageFlag', 'falsePerH', 'episodesPerH', ...
    'offsetHealthy', 'offsetFault', 'unrelShare', 'unrelOnFault', 'heaterSensorFlags', ...
    'tSrcFlagsOutside', 'emiAfterMagShare', 'bmeSensorShare', 'bmeIcmShare', 'bmeOrAmbigShare', ...
    'relaxShare'});
T.set = string(T.set);  T.scenario = string(T.scenario);
T.noise = string(T.noise);  T.detector = string(T.detector);
writetable(T, fullfile(here, 'g1_v9_results.csv'));

%% 3. Regression: v6 and v8 rows vs g1_v8_results.csv
regs = {"v6", fullfile(here, '..', 'v8', 'g1_v8_results.csv'), "v6"; ...
        "v8", fullfile(here, '..', 'v8', 'g1_v8_results.csv'), "v8"};
for g = 1:size(regs, 1)
    Ref = readtable(regs{g, 2}, 'TextType', 'string');
    Ref = Ref(Ref.detector == regs{g, 3}, :);
    metricsR = intersect(string(T.Properties.VariableNames(6:end)), string(Ref.Properties.VariableNames), 'stable');
    worst = 0;  nCmp = 0;
    for j = 1:height(Ref)
        kk = find(T.set == Ref.set(j) & T.scenario == Ref.scenario(j) & T.noise == Ref.noise(j) & ...
            T.seed == Ref.seed(j) & T.detector == regs{g, 1});
        for m = metricsR
            a = T.(m)(kk);  b = Ref.(m)(j);
            if isnan(a) && isnan(b), continue; end
            worst = max(worst, abs(a - b) / max(1, abs(b)));  nCmp = nCmp + 1;
        end
    end
    [~, refName] = fileparts(regs{g, 2});
    fprintf('\nRegression %s vs %s rows of %s.csv: %d rows, %d values, max relative difference %.2g %s', ...
        regs{g, 1}, regs{g, 3}, refName, height(Ref), nCmp, worst, string(ifelse(worst < 1e-9, '(OK)', '(MISMATCH)')));
end
fprintf('\n');

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
    'BME fault, BME or ambig (mean)', "bmeOrAmbigShare", mn, @pct; ...
    'relaxation form, ICM ref (mean)', "relaxShare",     mn, @pct};
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
cmpCells = @(d, ref) deal(nnz(fillNan((Mv(:, :, d) - Mv(:, :, ref)) .* dirn) < -1e-9), ...
                          nnz(fillNan((Mv(:, :, d) - Mv(:, :, ref)) .* dirn) > 1e-9));

% step 1: within the v9 family (v8 is a reference, not part of it)
i9 = numel(dets);
ic = i9;
fprintf('\nSelection step 1: each ablation vs v9 over %d scenario/noise cells x %d metrics\n', height(keys), size(sm, 1));
for d = 3:numel(dets) - 1
    [worse, better] = cmpCells(d, i9);
    fprintf('  %-7s worse in %3d, better in %3d\n', dets(d), worse, better);
    if worse == 0 && better > 0, ic = d; end
end
fprintf('  -> candidate: %s\n', dets(ic));

% step 2: candidate vs the previous version v6
[worse, better] = cmpCells(ic, 1);
fprintf('\nSelection step 2: %s vs v6\n  (a) cells: %s worse in %d, better in %d -> %s\n', ...
    dets(ic), dets(ic), worse, better, string(ifelse(better > worse, 'pass', 'fail')));
okA = better > worse;
okB = true;
for nz = noises
    g6 = T.noise == nz & T.detector == "v6";  gc = T.noise == nz & T.detector == dets(ic);
    f6 = mx(T.falsePerH(g6));  fc = mx(T.falsePerH(gc));
    c6 = mn(T.coverage(g6));   cc = mn(T.coverage(gc));
    d6 = mn(T.detected(g6));   dc = mn(T.detected(gc));
    ok = fc <= f6 + 1e-9 && cc >= c6 - 0.01 && dc >= d6 - 1e-9;
    fprintf('  (b) [%s] worst false/h %.1f vs %.1f, coverage %.1f%% vs %.1f%%, detected %.1f%% vs %.1f%% -> %s\n', ...
        nz, fc, f6, 100*cc, 100*c6, 100*dc, 100*d6, string(ifelse(ok, 'pass', 'fail')));
    okB = okB && ok;
end
if ic ~= 1 && okA && okB, g1det = dets(ic); else, g1det = "v6"; end
fprintf('  -> G1 detector: %s\n', g1det);
[worse, better] = cmpCells(ic, 2);
fprintf('\nFor reference, %s vs v8: worse in %d, better in %d cells\n', dets(ic), worse, better);
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

function x = fillNan(x)
    x(isnan(x)) = 0;
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
