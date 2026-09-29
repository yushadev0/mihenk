%% g1_prototype_v2.m
% G1 v2: honest evaluation of detectors v0 and v1 over many scenarios and
% seeds (bulgular.md, section 8). No detector was tuned on these scenarios.
%
% Scenarios: g1_scenarios_v2.m (9 scenarios x 5 seeds = 45 simulated nodes).
% Metrics per run are computed on blocks where both detectors decide, and
% written to g1_v2_results.csv next to this script.
% Runtime: several minutes.

clear; clc; close all;
addpath(fileparts(fileparts(mfilename('fullpath'))));   % g1/
figDir = g1_setup();
here   = fileparts(mfilename('fullpath'));

SC    = g1_scenarios_v2();
seeds = 0:4;
dets  = ["v0", "v1"];
nS    = numel(SC);

rows = {};
Rshow = cell(nS, 1);  Dshow = cell(nS, 1);          % seed 0, for the raster figure
tic;
for i = 1:nS
    for s = seeds
        S = SC(i).S;
        S.unitSeed  = 7  + 100*s;
        S.icmSeed   = 11 + 100*s;
        S.magSeed   = 12 + 100*s;
        S.noiseSeed = 13 + 100*s;
        D  = simulate_node(S);
        R  = {g1_detect_v0(D), g1_detect_v1(D)};
        both = R{1}.valid & R{2}.valid;
        for d = 1:2
            Rc = R{d};  Rc.valid = both;
            M  = g1_evaluate(D, Rc);
            detected = NaN;  delayMax = NaN;  cov = NaN;
            if ~isempty(M.delayAll)
                detected = double(all(~isnan(M.delayAll)));
                delayMax = max(M.delayAll);
                cov      = mean(M.coverageAll);
            end
            rows(end+1, :) = {SC(i).name, s, dets(d), detected, delayMax, cov, ...
                M.falsePerH, M.heaterSensorFlags, M.tempFlagsOutside, ...
                M.emiMagFlags, M.tempFaultBlameBme, M.tempFaultSensorFlags}; %#ok<SAGROW>
        end
        if s == 0, Rshow{i} = R{2}; Dshow{i} = D; end
    end
    fprintf('%-12s done (%.0f s)\n', SC(i).name, toc);
end

T = cell2table(rows, 'VariableNames', {'scenario', 'seed', 'detector', 'detected', ...
    'delayMaxMin', 'coverage', 'falsePerH', 'heaterSensorFlags', 'tSrcFlagsOutside', ...
    'emiMagFlagShare', 'bmeFaultBlameShare', 'bmeFaultSensorFlagShare'});
T.scenario = string(T.scenario);
T.detector = string(T.detector);
writetable(T, fullfile(here, 'g1_v2_results.csv'));

%% Summary (mean over seeds; delay: median)
agg = @(sc, d, v, f) f(T.(v)(T.scenario == sc & T.detector == d));
mn  = @(x) mean(x, 'omitnan');
md  = @(x) median(x, 'omitnan');

fprintf('\nFaults (%d seeds)          detected       delay [min]      coverage       false / h\n', numel(seeds));
fprintf('%-12s %8s %6s %8s %6s %8s %6s %8s %6s\n', 'scenario', 'v0', 'v1', 'v0', 'v1', 'v0', 'v1', 'v0', 'v1');
for i = 1:nS
    n = SC(i).name;
    fprintf('%-12s %8s %6s %8s %6s %8s %6s %8s %6s\n', n, ...
        pct(agg(n, "v0", "detected", mn)), pct(agg(n, "v1", "detected", mn)), ...
        num(agg(n, "v0", "delayMaxMin", md)), num(agg(n, "v1", "delayMaxMin", md)), ...
        pct(agg(n, "v0", "coverage", mn)), pct(agg(n, "v1", "coverage", mn)), ...
        num(agg(n, "v0", "falsePerH", mn)), num(agg(n, "v1", "falsePerH", mn)));
end

fprintf('\nTraps                       v0      v1\n');
trap(T, 'heater: sensor flags / run', "heaterSensorFlags", @num);
trap(T, 'T-src flags outside events / run', "tSrcFlagsOutside", @num);
fprintf('  emi: share of EMI blocks with a magnetometer blamed:  v0 %s  v1 %s\n', ...
    pct(agg("emi", "v0", "emiMagFlagShare", mn)), pct(agg("emi", "v1", "emiMagFlagShare", mn)));
fprintf('  bme-fault: share of fault blocks blaming BME688:     v0 %s  v1 %s\n', ...
    pct(agg("bme-fault", "v0", "bmeFaultBlameShare", mn)), pct(agg("bme-fault", "v1", "bmeFaultBlameShare", mn)));
fprintf('  bme-fault: share of fault blocks with a sensor blamed: v0 %s  v1 %s\n', ...
    pct(agg("bme-fault", "v0", "bmeFaultSensorFlagShare", mn)), pct(agg("bme-fault", "v1", "bmeFaultSensorFlagShare", mn)));

%% Figures
names = categorical([SC.name], [SC.name]);
f1 = figure('Position', [100 100 1000 650]);
tiledlayout(2, 1);
nexttile;
bar(names, [arrayfun(@(i) agg(SC(i).name, "v0", "coverage", mn), 1:nS); ...
            arrayfun(@(i) agg(SC(i).name, "v1", "coverage", mn), 1:nS)]' * 100);
grid on; ylabel('Coverage [%]'); legend('v0', 'v1', 'Location', 'best');
title('Fault coverage (mean over seeds; empty = no motion fault in scenario)');
nexttile;
bar(names, [arrayfun(@(i) agg(SC(i).name, "v0", "falsePerH", mn), 1:nS); ...
            arrayfun(@(i) agg(SC(i).name, "v1", "falsePerH", mn), 1:nS)]');
grid on; ylabel('False sensor flags per hour'); legend('v0', 'v1', 'Location', 'best');
title('False alarms (60 s blocks flagged per hour)');

f2 = figure('Position', [50 50 1400 900]);
tiledlayout(3, 3);
for i = 1:nS
    nexttile;
    g1_flag_raster(Dshow{i}.tB/3600, [Rshow{i}.sensorFlag, Rshow{i}.tempFlag], ...
        [Dshow{i}.names, "T src"], Dshow{i});
    title(sprintf('v1 - %s (seed 0)', SC(i).name));
end

exportgraphics(f1, fullfile(figDir, 'g1_v2_1.png'), 'Resolution', 150);
exportgraphics(f2, fullfile(figDir, 'g1_v2_2.png'), 'Resolution', 150);

%% Local helpers
function s = num(v)
    if isnan(v), s = "-"; else, s = sprintf('%.1f', v); end
end

function s = pct(v)
    if isnan(v), s = "-"; else, s = sprintf('%.0f%%', 100*v); end
end

function trap(T, label, var, fmt)
    a = mean(T.(var)(T.detector == "v0"), 'omitnan');
    b = mean(T.(var)(T.detector == "v1"), 'omitnan');
    fprintf('  %-34s %6s  %6s\n', label, fmt(a), fmt(b));
end
