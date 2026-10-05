%% g1_prototype_v6.m
% Development run of G1 v6 (g1_detect_v6.m): v5 plus A (lead-lag
% temperature-source model), B (event-end release) and C (multi-state
% output: C1 offset event, C2 model unreliable), with one ablation per
% change.
%
% 0. Equivalence: v6 with A, B, C1, C2 off must reproduce g1_detect_v5
%    exactly (flags, score, temperature-source flags).
% 1. Characterization: the same 12 h static logs and Allan fit as v3-v5.
% 2. Evaluation, detectors v5, v6noA, v6noB, v6noC1, v6noC2, v6 on
%    dev    g1_scenarios_v3, 8 scenarios x white/colored x seeds 0-9
%    spent  g1_scenarios_test, 10 scenarios x white/colored x seeds 100-109
%           (used by the v5 acceptance test, section 13: development data now)
%    Scoring window as in v5 development: blocks valid for every detector
%    and for v0.
% 3. Selection rule (declared before any v6 result): the candidate is v6
%    unless an ablation is nowhere worse and somewhere better on the
%    scenario-level metrics listed in the summary.
%
% Metrics with the new states (user decisions, bulgular section 15):
%   fault      = state 1; offset event = state 2; unreliable = state 3.
%   detected   a fault channel reaches state 1 after the fault starts.
%   coverage   share of faulty blocks reported: state 1, or, for a STEP
%              fault, any block after an offset event on that channel
%              (detected, reported and recalibrated). A drift is covered
%              only by state 1. coverageFlag = state 1 only (v5 meaning).
%   falsePerH  state-1 blocks on healthy channels per hour (magnetometer
%              excluded inside the EMI window, as in K1).
%   episodesPerH  onsets of state 1 on healthy channels plus offset events
%              on healthy channels, per hour (K1c, decision 1).
%   unrelShare share of scored blocks with any channel unreliable (capped by
%              a criterion to be declared, decision 2); unrelOnFault share
%              of faulty blocks where the faulty channel is unreliable
%              (masking).
%   trap metrics from g1_evaluate on state 1 (heater, T-src outside, EMI
%              after, BME fault).
%
% Output: g1_v6_output.txt, g1_v6_results.csv. Runtime ~2 h (360 runs x 6
% detectors); the replay export will show single runs.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_v6_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

%% 1. Characterization (identical to v3-v5)
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

%% 0. Equivalence: v6 with every change off == v5
asV5 = struct('tsrc', "lag", 'eventEnd', false, 'offsetEvent', false, 'unreliable', false);
SCd = g1_scenarios_v3();
eqWorst = 0;
for i = [1, find([SCd.name] == "emi"), find([SCd.name] == "hyst-relax")]
    for nz = noises
        S = SCd(i).S;  S.noise = nz;
        D = simulate_node(seedS(S, 0));
        R5 = g1_detect_v5(D, NM.(char(nz)));
        R6 = g1_detect_v6(D, NM.(char(nz)), asV5);
        eqWorst = max([eqWorst, nnz(R5.sensorFlag ~= R6.sensorFlag), nnz(R5.tempFlag ~= R6.tempFlag), ...
            nnz(R5.tempAmbig ~= R6.tempAmbig), max(abs(R5.score - R6.score), [], 'all'), ...
            max(abs(R5.zT - R6.zT))]);
    end
end
fprintf('Equivalence v6(all changes off) vs v5: max difference %.2g %s\n\n', eqWorst, ...
    string(ifelse(eqWorst == 0, '(OK)', '(MISMATCH)')));

%% 2. Evaluation
dets = ["v5", "v6noA", "v6noB", "v6noC1", "v6noC2", "v6"];
opts = {[], struct('tsrc', "lag"), struct('eventEnd', false), struct('offsetEvent', false), ...
        struct('unreliable', false), struct()};
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
                    if d == 1, R{d} = g1_detect_v5(D, nmz); else, R{d} = g1_detect_v6(D, nmz, opts{d}); end
                end
                both = g1_detect_v0(D).valid;
                for d = 1:numel(R), both = both & R{d}.valid; end
                for d = 1:numel(dets)
                    Rc = R{d};  Rc.valid = both;
                    if ~isfield(Rc, 'state'), Rc.state = uint8(Rc.sensorFlag); Rc.unrel = false(size(both)); end
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
writetable(T, fullfile(here, 'g1_v6_results.csv'));

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

%% Overall per noise (all scenarios of both sets)
fprintf('\nOverall (all runs of both sets)\n%-32s%s\n', '', cols(dets, 9));
for nz = noises
    fprintf('[%s]\n', nz);
    for m = 1:size(show, 1)
        v = arrayfun(@(d) show{m, 3}(T.(show{m, 2})(T.noise == nz & T.detector == d)), dets);
        if all(isnan(v)), continue; end
        fprintf('%-32s%s\n', show{m, 1}, cols(arrayfun(show{m, 4}, v, 'UniformOutput', false), 9));
    end
end

%% 3. Selection rule
% Scenario-level metrics and their direction (+1 higher is better)
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
i6 = numel(dets);
pick = "v6";
fprintf('\nSelection: each ablation vs v6 over %d scenario/noise cells x %d metrics\n', height(keys), size(sm, 1));
for d = 2:numel(dets) - 1
    df = (Mv(:, :, d) - Mv(:, :, i6)) .* dirn;   % > 0: ablation better
    df(isnan(df)) = 0;
    worse = nnz(df < -1e-9);  better = nnz(df > 1e-9);
    fprintf('  %-7s worse in %3d, better in %3d\n', dets(d), worse, better);
    if worse == 0 && better > 0, pick = dets(d); end
end
fprintf('  -> candidate: %s\n', pick);
diary('off');

%% Helpers
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
