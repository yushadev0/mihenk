%% g1_acceptance_test2.m
% One-shot acceptance test of the G1 simulation stage on the second
% held-out set (bulgular.md, section 21). Scenarios (g1_scenarios_test2.m),
% criteria and both decision rules were declared and committed before any
% detector was run on this set. Run once. A failed criterion is reported,
% not tuned away; the set is spent afterwards. Only bug fixes that do not
% change a detector's logic are allowed.
%
% Detectors: v10 (candidate, g1_detect_v10.m = v9noE) and v6 (current G1
% detector), on the same runs and the same scoring window.
%
% Decision 1, G1 detector (same rule as step 2 of the v8/v9 dev runs, now
%   on held-out data): v10 replaces v6 only if
%     (a) over the family/noise cells x metrics it is better in more cells
%         than it is worse, and
%     (b) for both noise types, over all runs: worst false flags/h <= v6,
%         mean coverage >= v6 - 1 point, mean detection >= v6.
% Decision 2, acceptance: the simulation stage of G1 closes if the G1
%   detector of decision 1 passes every criterion K1a-K4 for both noise
%   types. The criteria table is printed for both detectors.
%
% Output: g1_acceptance2_output.txt, g1_acceptance2_runs.csv (one row per
% run and detector), g1_acceptance2_faults.csv (one row per injected
% motion fault and detector). Runtime ~20-30 min (200 runs x 2 detectors).

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(here, g1);
g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_acceptance2_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

%% Characterization (identical to development)
noises = ["white", "colored"];
none   = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
for nz = noises
    Sc = struct('noise', nz, 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
        'heaterOn', [], 'faults', none, ...
        'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
    Dc = simulate_node(Sc);
    NM.(char(nz)) = g1_allan_fit(Dc.Y, Dc.S.B);
end

%% Runs
SC   = g1_scenarios_test2();
dets = ["v10", "v6"];
rows = {};  rowsF = {};
tic;
for i = 1:numel(SC)
    for nz = noises
        S = SC(i).S;  S.noise = nz;
        D = simulate_node(S);
        R = {g1_detect_v10(D, NM.(char(nz))), g1_detect_v6(D, NM.(char(nz)))};
        valid = R{1}.valid & R{2}.valid & g1_detect_v0(D).valid;   % same window for both
        for d = 1:numel(dets)
            Rc = R{d};  Rc.valid = valid;
            M = g1_evaluate(D, Rc);
            N = runMetrics(D, Rc, valid);
            rows(end+1, :) = {SC(i).name, SC(i).family, SC(i).class, SC(i).hyst, SC(i).bmeTau2, ...
                nz, SC(i).seed, dets(d), N.detected, N.delayMin, N.coverage, N.falsePerH, ...
                N.episodesPerH, N.unrelShare, N.unrelOnFault, M.heaterSensorFlags, ...
                M.tempFlagsOutside, M.emiAfterMagFlags, M.tempFaultSensorFlags, ...
                M.tempFaultBlameIcm, M.tempFaultBlameBme + M.tempFaultAmbig}; %#ok<SAGROW>
            for f = 1:numel(N.fDelay)
                rowsF(end+1, :) = {SC(i).name, SC(i).family, SC(i).class, nz, SC(i).seed, dets(d), ...
                    D.names(D.S.faults(f).ch), D.S.faults(f).type, N.fDelay(f), N.fCoverage(f)}; %#ok<SAGROW>
            end
        end
    end
    if mod(i, 10) == 0, fprintf('%3d / %d scenarios done (%.0f s)\n', i, numel(SC), toc); end
end
T = cell2table(rows, 'VariableNames', {'scenario', 'family', 'class', 'hyst', 'bmeTau2', ...
    'noise', 'seed', 'detector', 'detected', 'delayMin', 'coverage', 'falsePerH', 'episodesPerH', ...
    'unrelShare', 'unrelOnFault', 'heaterSensorFlags', 'tSrcFlagsOutside', 'emiAfterMagShare', ...
    'bmeSensorShare', 'bmeIcmShare', 'bmeOrAmbigShare'});
for c = ["scenario", "family", "class", "hyst", "noise", "detector"], T.(c) = string(T.(c)); end
TF = cell2table(rowsF, 'VariableNames', {'scenario', 'family', 'class', 'noise', 'seed', ...
    'detector', 'channel', 'type', 'delayMin', 'coverage'});
for c = ["scenario", "family", "class", "noise", "detector", "channel", "type"], TF.(c) = string(TF.(c)); end
writetable(T, fullfile(here, 'g1_acceptance2_runs.csv'));
writetable(TF, fullfile(here, 'g1_acceptance2_faults.csv'));

md = @(x) median(x, 'omitnan');  mn = @(x) mean(x, 'omitnan');  mx = @(x) max(x, [], 'omitnan');

%% Decision 1: G1 detector
sm = { "detected", mn, 1; "delayMin", md, -1; "coverage", mn, 1; "falsePerH", md, -1; ...
       "falsePerH", mx, -1; "episodesPerH", mn, -1; "unrelShare", mn, -1; "unrelOnFault", mn, -1; ...
       "heaterSensorFlags", mn, -1; "tSrcFlagsOutside", mn, -1; "emiAfterMagShare", mn, -1; ...
       "bmeSensorShare", mn, -1; "bmeOrAmbigShare", mn, 1};
keys = unique(T(:, {'family', 'noise'}), 'stable');
Mv = nan(height(keys), size(sm, 1), numel(dets));
for j = 1:height(keys)
    sel = T.family == keys.family(j) & T.noise == keys.noise(j);
    for d = 1:numel(dets)
        for m = 1:size(sm, 1)
            Mv(j, m, d) = sm{m, 2}(T.(sm{m, 1})(sel & T.detector == dets(d)));
        end
    end
end
dif = (Mv(:, :, 1) - Mv(:, :, 2)) .* reshape([sm{:, 3}], 1, []);
dif(isnan(dif)) = 0;
worse = nnz(dif < -1e-9);  better = nnz(dif > 1e-9);
okA = better > worse;
fprintf('\nDecision 1: v10 vs v6 over %d family/noise cells x %d metrics\n', height(keys), size(sm, 1));
fprintf('  (a) v10 worse in %d, better in %d -> %s\n', worse, better, string(ifelse(okA, 'pass', 'fail')));
okB = true;
for nz = noises
    g6 = T.noise == nz & T.detector == "v6";  gc = T.noise == nz & T.detector == "v10";
    f6 = mx(T.falsePerH(g6));  fc = mx(T.falsePerH(gc));
    c6 = mn(T.coverage(g6));   cc = mn(T.coverage(gc));
    d6 = mn(T.detected(g6));   dc = mn(T.detected(gc));
    ok = fc <= f6 + 1e-9 && cc >= c6 - 0.01 && dc >= d6 - 1e-9;
    fprintf('  (b) [%s] worst false/h %.1f vs %.1f, coverage %.1f%% vs %.1f%%, detected %.1f%% vs %.1f%% -> %s\n', ...
        nz, fc, f6, 100*cc, 100*c6, 100*dc, 100*d6, string(ifelse(ok, 'pass', 'fail')));
    okB = okB && ok;
end
g1det = "v6";
if okA && okB, g1det = "v10"; end
fprintf('  -> G1 detector: %s\n', g1det);

%% Decision 2: acceptance criteria (section 11 thresholds, section 21 definitions)
pass = struct();
for d = dets
    fprintf('\nCriteria, %s%s\n', d, string(ifelse(d == g1det, ' (G1 detector)', '')));
    allPass = true;
    for nz = noises
        fprintf('[%s]\n', nz);
        A  = T(T.noise == nz & T.detector == d, :);
        Ff = TF(TF.noise == nz & TF.detector == d & TF.class == "fault", :);
        Fs = TF(TF.noise == nz & TF.detector == d & TF.class == "slow", :);
        det120 = Ff.delayMin <= 120;
        C = {
            'K1a false flags/h, median run <= 0.5',      md(A.falsePerH),                  @(v) v <= 0.5
            'K1b false flags/h, every run <= 6',         mx(A.falsePerH),                  @(v) v <= 6
            'K1c false episodes/h, mean <= 0.12',        mn(A.episodesPerH),               @(v) v <= 0.12
            'K2a faults detected within 120 min >= 0.95', mean(det120),                    @(v) v >= 0.95
            'K2b median delay [min] (w <= 15, c <= 40)', md(Ff.delayMin(det120)),          @(v) v <= ifelse(nz == "white", 15, 40)
            'K2c mean coverage >= 0.80',                 mn(Ff.coverage),                  @(v) v >= 0.80
            'K2d slow drifts within 180 min >= 0.80',    mean(Fs.delayMin <= 180),         @(v) v >= 0.80
            'K3a heater sensor flags/run, mean <= 1',    mn(A.heaterSensorFlags),          @(v) v <= 1
            'K3b T-src flags outside/run, mean <= 1',    mn(A.tSrcFlagsOutside),           @(v) v <= 1
            'K3c EMI: mag flagged after event <= 0.10',  mn(A.emiAfterMagShare),           @(v) v <= 0.10
            'K3d BME fault: motion channel blamed <= 0.05', mn(A.bmeSensorShare),          @(v) v <= 0.05
            'K3e BME fault: ICM blamed <= 0.05',         mn(A.bmeIcmShare),                @(v) v <= 0.05
            'K3f BME fault: BME or ambiguous >= 0.90',   mn(A.bmeOrAmbigShare),            @(v) v >= 0.90
            'K4 unreliable share of fault blocks <= 0.10', mn(A.unrelOnFault),             @(v) v <= 0.10
            };
        for j = 1:size(C, 1)
            ok = C{j, 3}(C{j, 2});
            allPass = allPass && ok;
            fprintf('  %-50s %8.3f  %s\n', C{j, 1}, C{j, 2}, string(ifelse(ok, 'PASS', 'FAIL')));
        end
    end
    pass.(d) = allPass;
    fprintf('  %s overall: %s\n', d, string(ifelse(allPass, 'PASS', 'FAIL')));
end
fprintf('\nOVERALL (G1 detector %s): %s\n', g1det, string(ifelse(pass.(g1det), 'PASS', 'FAIL')));

%% Breakdown (descriptive only, no decision)
fprintf('\nPer family: false flags/h median [worst], coverage, delay median [min]  (v10 | v6)\n');
fams = unique(T.family, 'stable');
for nz = noises
    for f = fams'
        s = cell(1, 2);
        for d = 1:2
            A = T(T.family == f & T.noise == nz & T.detector == dets(d), :);
            s{d} = sprintf('%5.2f [%5.1f] %5s %6s', md(A.falsePerH), mx(A.falsePerH), ...
                pct(mn(A.coverage)), num(md(A.delayMin)));
        end
        fprintf('  %-11s %-8s %s | %s\n', f, nz, s{1}, s{2});
    end
end
fprintf('\nBy hysteresis form and BME path: worst false flags/h, mean coverage  (v10 | v6)\n');
form = extractBefore(T.hyst, " ");
grp = {"play", form == "play"; "relax", form == "relax"; "pi (unmodelled)", form == "pi"; ...
       "BME 1st order", T.bmeTau2 == 0; "BME 2nd order", T.bmeTau2 > 0};
for nz = noises
    for g = 1:size(grp, 1)
        s = cell(1, 2);
        for d = 1:2
            A = T(grp{g, 2} & T.noise == nz & T.detector == dets(d), :);
            s{d} = sprintf('%5.1f %5s', mx(A.falsePerH), pct(mn(A.coverage)));
        end
        fprintf('  %-16s %-8s %s | %s   (%d runs)\n', grp{g, 1}, nz, s{1}, s{2}, ...
            nnz(grp{g, 2} & T.noise == nz & T.detector == "v10"));
    end
end
fprintf('\nRuns above 6 false flags/h:\n');
bad = T(T.falsePerH > 6, :);
for j = 1:height(bad)
    fprintf('  %-6s %-16s %-8s %-14s BME tau2 %3.0f s: %.1f\n', bad.detector(j), bad.scenario(j), ...
        bad.noise(j), bad.hyst(j), bad.bmeTau2(j), bad.falsePerH(j));
end
diary('off');

%% Helpers
function N = runMetrics(D, R, valid)
% Multi-state scoring as in the v6-v9 dev runs (section 21 definitions):
% false flags = state 1 on fault-free channels (without the magnetometer
% during an EMI event); an offset event on a fault-free channel counts as a
% false episode; a step fault counts as reported from its first offset
% event on (section 15 decision); delay = first state-1 flag after onset.
    st = R.state;  fault = D.truth.fault;  tB = D.tB;
    flag = st == 1;  ofs = st == 2;
    healthy = ~fault & valid;
    if any(D.truth.emi), healthy(D.truth.emi, 7:9) = false; end
    hours = nnz(valid) * D.S.B / 3600;
    N.falsePerH = nnz(flag & healthy) / hours;
    onsets = diff([false(1, size(flag, 2)); flag & healthy]) == 1;
    N.episodesPerH = (nnz(onsets) + nnz(ofs & healthy)) / hours;
    N.unrelShare = nnz(R.unrel & valid) / nnz(valid);
    inF = fault & valid;
    N.unrelOnFault = NaN;
    if any(inF(:)), N.unrelOnFault = nnz(st == 3 & inF) / nnz(inF); end
    F = D.S.faults;
    N.fDelay = nan(1, numel(F));  N.fCoverage = N.fDelay;
    for i = 1:numel(F)
        c = F(i).ch;  after = tB >= F(i).t0;
        k = find(flag(:, c) & after, 1);
        if ~isempty(k), N.fDelay(i) = (tB(k) - F(i).t0) / 60; end
        rep = flag(:, c);
        if F(i).type == "step"
            ko = find(ofs(:, c) & after, 1);
            if ~isempty(ko), rep(ko:end) = true; end
        end
        inFc = fault(:, c) & valid;
        N.fCoverage(i) = nnz(rep & inFc) / nnz(inFc);
    end
    [N.detected, N.delayMin, N.coverage] = deal(NaN);
    if ~isempty(F)
        N.detected = mean(~isnan(N.fDelay));
        N.delayMin = max(N.fDelay);
        N.coverage = mean(N.fCoverage);
    end
end

function s = num(v)
    if isnan(v), s = "-"; else, s = sprintf('%.1f', v); end
end

function s = pct(v)
    if isnan(v), s = "-"; else, s = sprintf('%.0f%%', 100*v); end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
