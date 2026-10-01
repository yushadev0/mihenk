%% g1_prototype_v5.m
% G1 v5: v4 with changes A-D of g1_detect_v5.m (CUSUM cap, model-error
% floor only on frozen channels, growth-based release, CUSUM reset on a
% model switch; bulgular.md section 10), on the v3 factorial scenario set
% with 10 seeds.
%
% 0. Equivalence: v5 with v4 options (A-D off, floor "always") must
%    reproduce g1_detect_v4 exactly.
% 1. Characterization: the same 12 h static logs and Allan fit as v3.
% 2. Evaluation: 8 scenarios x 2 noise types x 10 seeds, detectors v4nf
%    (v4 without its floor, the reference), v5 and three ablations of it:
%    v5a (no floor, B off), v5noC (no release test), v5noD (no switch
%    reset); on the blocks scored in v3. Written to g1_v5_results.csv,
%    with the lag-1 autocorrelation of the v5 innovations as a diagnostic
%    of the correlated-innovation trigger (10F).
% 3. Regression: v4nf rows must equal g1_v4_results.csv.
% Runtime: roughly 30-45 min.

clear; clc; close all;
addpath(fileparts(fileparts(mfilename('fullpath'))));   % g1/
figDir = g1_setup();
here   = fileparts(mfilename('fullpath'));
h      = 3600;
logFile = fullfile(here, 'g1_v5_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

%% 1. Characterization (identical to v3)
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

SC    = g1_scenarios_v3();
seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);

%% 0. Equivalence: v5 with v4 options == v4
asV4 = struct('floorMode', "always", 'Smax', Inf, 'release', false, 'resetOnSwitch', false);
eqWorst = 0;
for i = [1, find([SC.name] == "emi"), find([SC.name] == "hyst-relax")]
    for nz = noises
        S = SC(i).S;  S.noise = nz;
        D = simulate_node(seedS(S, 0));
        R4 = g1_detect_v4(D, NM.(char(nz)));
        R5 = g1_detect_v5(D, NM.(char(nz)), asV4);
        eqWorst = max([eqWorst, nnz(R4.sensorFlag ~= R5.sensorFlag), nnz(R4.tempAmbig ~= R5.tempAmbig), ...
            max(abs(R4.score - R5.score), [], 'all')]);
    end
end
fprintf('Equivalence v5(v4 options) vs v4: max difference %.2g %s\n\n', eqWorst, ...
    string(ifelse(eqWorst == 0, '(OK)', '(MISMATCH)')));

%% 2. Evaluation
seeds = 0:9;
dets  = ["v4nf", "v5a", "v5noC", "v5noD", "v5"];   % v5 and its ablations
nS    = numel(SC);
names = Dc.names;

rows = {};
show = struct('c', {cell(nS, 1)}, 'w', {cell(nS, 1)});   % v5, seed 0: R and D
heaterCh = zeros(numel(noises), numel(names));           % v5 heater flags per channel
tic;
for i = 1:nS
    for in = 1:numel(noises)
        nz = noises(in);
        for s = seeds
            S = SC(i).S;  S.noise = nz;
            D = simulate_node(seedS(S, s));
            nmz = NM.(char(nz));
            R = {g1_detect_v4(D, nmz, struct('modelHorizon', Inf)), ...
                 g1_detect_v5(D, nmz, struct('floorMode', "off")), ...
                 g1_detect_v5(D, nmz, struct('release', false)), ...
                 g1_detect_v5(D, nmz, struct('resetOnSwitch', false)), g1_detect_v5(D, nmz)};
            % same scoring window as v3 (v0 decides from block 101 on)
            both = g1_detect_v0(D).valid;
            for d = 1:numel(R), both = both & R{d}.valid; end
            ac = innovAC(R{end}, both, D.truth.fault);
            for d = 1:numel(dets)
                Rc = R{d};  Rc.valid = both;
                M  = g1_evaluate(D, Rc);
                detected = NaN;  delayMax = NaN;  cov = NaN;
                if ~isempty(M.delayAll)
                    detected = double(all(~isnan(M.delayAll)));
                    delayMax = max(M.delayAll);
                    cov      = mean(M.coverageAll);
                end
                rows(end+1, :) = {SC(i).name, nz, s, dets(d), detected, delayMax, cov, ...
                    M.falsePerH, M.heaterSensorFlags, M.tempFlagsOutside, ...
                    M.emiMagFlags, M.tempFaultBlameBme, M.tempFaultSensorFlags, ...
                    M.emiAfterMagFlags, M.emiCommon, M.tempFaultBlameIcm, M.tempFaultAmbig, ...
                    M.heaterBlameBme / M.heaterBlocks, M.heaterAmbig / M.heaterBlocks, ac}; %#ok<SAGROW>
            end
            heaterCh(in, :) = heaterCh(in, :) + sum(R{end}.sensorFlag & D.truth.heater & both, 1);
            if s == 0, show.(char(extractBefore(nz, 2))){i} = {R{end}, D}; end
        end
    end
    fprintf('%-12s done (%.0f s)\n', SC(i).name, toc);
end

T = cell2table(rows, 'VariableNames', {'scenario', 'noise', 'seed', 'detector', 'detected', ...
    'delayMaxMin', 'coverage', 'falsePerH', 'heaterSensorFlags', 'tSrcFlagsOutside', ...
    'emiMagFlagShare', 'bmeFaultBlameShare', 'bmeFaultSensorFlagShare', ...
    'emiAfterMagFlagShare', 'emiCommonShare', 'bmeFaultBlameIcmShare', 'bmeFaultAmbigShare', 'heaterBlameBmeShare', 'heaterAmbigShare', 'innovAC1max'});
T.scenario = string(T.scenario);
T.noise    = string(T.noise);
T.detector = string(T.detector);
writetable(T, fullfile(here, 'g1_v5_results.csv'));

%% 3. Regression against v4 (v4nf, all seeds)
V3 = readtable(fullfile(here, '..', 'v4', 'g1_v4_results.csv'), 'TextType', 'string');
V3 = V3(V3.detector == "v4nf", :);
metrics = ["detected", "delayMaxMin", "coverage", "falsePerH", "heaterSensorFlags", ...
    "tSrcFlagsOutside", "emiMagFlagShare", "bmeFaultBlameShare", "bmeFaultSensorFlagShare", ...
    "emiAfterMagFlagShare", "emiCommonShare", "bmeFaultBlameIcmShare", "bmeFaultAmbigShare"];
worst = 0;
for j = 1:height(V3)
    k = find(T.scenario == V3.scenario(j) & T.noise == V3.noise(j) & ...
        T.seed == V3.seed(j) & T.detector == V3.detector(j));
    for m = metrics
        a = T.(m)(k);  b = V3.(m)(j);
        if isnan(a) && isnan(b), continue; end
        worst = max(worst, abs(a - b) / max(1, abs(b)));
    end
end
fprintf('\nRegression vs v4: %d rows compared, max relative difference %.2g %s\n', ...
    height(V3), worst, string(ifelse(worst < 1e-9, '(OK)', '(MISMATCH)')));

%% Summary
agg = @(sc, nz, d, v, f) f(T.(v)(T.scenario == sc & T.noise == nz & T.detector == d));
mn  = @(x) mean(x, 'omitnan');
md  = @(x) median(x, 'omitnan');
mx  = @(x) max(x, [], 'omitnan');

cols = @(c, w) strjoin(compose("%" + w + "s", string(c)), "");
hdr  = cols(dets, 6);
fprintf('\nFaults (%d seeds; detected and coverage: mean, delay: median)\n', numel(seeds));
fprintf('%-22s | %-24s | %-24s | %s\n', 'scenario / noise', 'detected', 'delay [min]', 'coverage');
fprintf('%-22s | %s | %s | %s\n', '', hdr, hdr, hdr);
for i = 1:nS
    for nz = noises
        n = SC(i).name;
        rowOf = @(v, f, fmt) cols(arrayfun(@(d) fmt(agg(n, nz, d, v, f)), dets, 'UniformOutput', false), 6);
        fprintf('%-22s | %s | %s | %s\n', n + " / " + nz, rowOf("detected", mn, @pct), ...
            rowOf("delayMaxMin", md, @num), rowOf("coverage", mn, @pct));
    end
end

fprintf('\nFalse sensor flags per hour: median [worst seed]\n');
fprintf('%-22s | %s\n', 'scenario / noise', cols(dets, 14));
for i = 1:nS
    for nz = noises
        n = SC(i).name;
        c = arrayfun(@(d) sprintf('%s [%s]', num(agg(n, nz, d, "falsePerH", md)), ...
            num(agg(n, nz, d, "falsePerH", mx))), dets, 'UniformOutput', false);
        fprintf('%-22s | %s\n', n + " / " + nz, cols(c, 14));
    end
end

fprintf('\n  %-44s%s\n', 'Traps (mean over seeds)', hdr);
for nz = noises
    fprintf('[%s]\n', nz);
    E = T(T.scenario == "emi", :);  B = T(T.scenario == "bme-fault", :);
    trap(T, nz, dets, 'heater: sensor flags / run', "heaterSensorFlags", @num);
    trap(T, nz, dets, 'T-src flags outside events / run', "tSrcFlagsOutside", @num);
    trap(T, nz, dets, 'heater: share blaming BME688', "heaterBlameBmeShare", @pct);
    trap(T, nz, dets, 'heater: share ambiguous', "heaterAmbigShare", @pct);
    trap(E, nz, dets, 'emi: share with a mag blamed (event)', "emiMagFlagShare", @pct);
    trap(E, nz, dets, 'emi: share with a mag blamed (after)', "emiAfterMagFlagShare", @pct);
    trap(E, nz, dets, 'emi: share taken as common mode', "emiCommonShare", @pct);
    trap(B, nz, dets, 'bme-fault: share blaming BME688', "bmeFaultBlameShare", @pct);
    trap(B, nz, dets, 'bme-fault: share blaming ICM', "bmeFaultBlameIcmShare", @pct);
    trap(B, nz, dets, 'bme-fault: share ambiguous', "bmeFaultAmbigShare", @pct);
    trap(B, nz, dets, 'bme-fault: share with a sensor blamed', "bmeFaultSensorFlagShare", @pct);
end

T5 = T(T.detector == "v5", :);
for nz = noises
    v = T5.innovAC1max(T5.noise == nz);
    fprintf('\nv5 innovations, max lag-1 autocorrelation over channels [%s]: median %.2f, max %.2f, runs > 0.3: %d of %d\n', ...
        nz, median(v), max(v), nnz(v > 0.3), numel(v));
end

fprintf('\nv5 heater flags per channel (sum over scenarios and seeds)\n');
fprintf('%-8s%s\n', '', cols(names, 6));
for in = 1:numel(noises)
    fprintf('%-8s%s\n', noises(in), cols(heaterCh(in, :), 6));
end

%% Figures
cond = strings(0);  covA = [];  falMd = [];  falMx = [];
for i = 1:nS
    for nz = noises
        cond(end+1) = SC(i).name + "/" + extractBefore(nz, 2); %#ok<SAGROW>
        covA(end+1, :)  = arrayfun(@(d) agg(SC(i).name, nz, d, "coverage", mn), dets); %#ok<SAGROW>
        falMd(end+1, :) = arrayfun(@(d) agg(SC(i).name, nz, d, "falsePerH", md), dets); %#ok<SAGROW>
        falMx(end+1, :) = arrayfun(@(d) agg(SC(i).name, nz, d, "falsePerH", mx), dets); %#ok<SAGROW>
    end
end
cats = categorical(cond, cond);
f1 = figure('Position', [100 100 1200 700]);
tiledlayout(2, 1);
nexttile;
bar(cats, covA * 100);
grid on; ylabel('Coverage [%]'); legend(dets, 'Location', 'bestoutside');
title('Fault coverage, mean over seeds (w = white, c = colored; empty = no motion fault)');
nexttile;
b = bar(cats, max(falMd, 0.01));
set(gca, 'YScale', 'log');  [b.BaseValue] = deal(0.01);
hold on;
for d = 1:numel(dets)
    plot(b(d).XEndPoints, max(falMx(:, d), 0.01), 'v', 'Color', b(d).FaceColor, ...
        'MarkerFaceColor', b(d).FaceColor, 'HandleVisibility', 'off');
end
grid on; ylabel('False sensor flags per hour'); legend(dets, 'Location', 'bestoutside');
title('False alarms: bar = median, triangle = worst seed (log scale; 0 drawn at 0.01)');

figs = gobjects(2, 1);
for in = 1:numel(noises)
    key = char(extractBefore(noises(in), 2));
    figs(in) = figure('Position', [50 50 1400 900]);
    tiledlayout(3, 3);
    for i = 1:nS
        Rs = show.(key){i}{1};  Ds = show.(key){i}{2};
        nexttile;
        g1_flag_raster(Ds.tB/3600, [Rs.sensorFlag, Rs.tempFlag, Rs.tempAmbig], ...
            [Ds.names, "T src", "T amb"], Ds);
        title(sprintf('v5 - %s, %s (seed 0)', SC(i).name, noises(in)));
    end
end

exportgraphics(f1,      fullfile(figDir, 'g1_v5_1.png'), 'Resolution', 150);
exportgraphics(figs(2), fullfile(figDir, 'g1_v5_2.png'), 'Resolution', 150);   % colored
exportgraphics(figs(1), fullfile(figDir, 'g1_v5_3.png'), 'Resolution', 150);   % white
diary('off');

%% Local helpers
function s = num(v)
    if isnan(v), s = "-"; else, s = sprintf('%.1f', v); end
end

function s = pct(v)
    if isnan(v), s = "-"; else, s = sprintf('%.0f%%', 100*v); end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end

function trap(T, nz, dets, label, var, fmt)
    v = arrayfun(@(d) mean(T.(var)(T.noise == nz & T.detector == d), 'omitnan'), dets);
    c = arrayfun(fmt, v, 'UniformOutput', false);
    fprintf('  %-44s%s\n', label, strjoin(compose("%6s", string(c)), ""));
end

function ac = innovAC(R, scored, fault)
    % Largest lag-1 autocorrelation over channels of the v5 innovations
    % (vs ICM) on scored, fault-free blocks - diagnostic of 10F's trigger
    ok = scored & ~any(fault, 2);
    ac = -Inf;
    for c = 1:size(R.zI, 2)
        z = R.zI(ok, c);
        z = z(~isnan(z));
        if numel(z) > 10, cc = corrcoef(z(1:end-1), z(2:end)); ac = max(ac, cc(1, 2)); end
    end
end
