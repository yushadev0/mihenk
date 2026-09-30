%% g1_prototype_v3.m
% G1 v3: Allan-derived null model (g1_detect_v3.m) against v0 and v1 on a
% factorial scenario set - every v2 scenario with white and with colored
% noise (bulgular.md, section 9; findings 8B, 8F).
%
% 1. Characterization: one 12 h static log per noise type (constant 25 degC,
%    no heater, no fault, own seeds) -> Allan fit -> noise model NM.
%    The detector never sees the simulator's noise parameters.
% 2. Evaluation: 8 scenarios x 2 noise types x 5 seeds, detectors v0, v1,
%    v3a (v3 with v1's |z| CUSUM, ablation) and v3,
%    on blocks where all of them decide. Written to g1_v3_results.csv.
% 3. Regression: v0/v1 rows must equal g1_v2_results.csv wherever the
%    condition already existed in v2.
% Runtime: roughly 10-20 min.

clear; clc; close all;
addpath(fileparts(fileparts(mfilename('fullpath'))));   % g1/
figDir = g1_setup();
here   = fileparts(mfilename('fullpath'));
h      = 3600;
logFile = fullfile(here, 'g1_v3_output.txt');            % console output, kept with the CSV
if isfile(logFile), delete(logFile); end
diary(logFile);

%% 1. Characterization (static log -> Allan fit)
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
names = Dc.names;

% Simulator values, for comparison only (the detector does not get these)
Ntrue = [repmat(2.8e-3, 1, 3), [65 65 70]*1e-3, repmat(0.1, 1, 3)];    % per sqrt(s)
Ktrue = repelem([5/3600, 0.02, 0], 3);                                  % per sqrt(h)
Btrue = repelem([5/3600, 0.04, 0.01], 3);
fprintf('Allan fit on the 12 h static log (colored noise)\n');
fprintf('%-4s %10s %10s %11s %11s %10s %10s %7s\n', 'ch', 'N sim', 'N fit', ...
    'K sim /rh', 'K fit /rh', 'B sim', 'sg fit', 'Tg [s]');
nm = NM.colored;
for c = 1:numel(names)
    fprintf('%-4s %10.3g %10.3g %11.3g %11.3g %10.3g %10.3g %7d\n', names(c), ...
        Ntrue(c), nm.N(c), Ktrue(c), nm.K(c)*60, Btrue(c), nm.sg(c), nm.Tg(c));
end
fprintf('White-noise log: K fit /rh max %.3g, sg fit max %.3g (relative to N: %.2g)\n\n', ...
    max(NM.white.K*60 ./ Ntrue), max(NM.white.sg ./ Ntrue), max(NM.white.N ./ Ntrue));

%% 2. Evaluation
SC    = g1_scenarios_v3();
seeds = 0:4;
dets  = ["v0", "v1", "v3a", "v3"];                  % v3a: v3 with v1's |z| CUSUM (ablation)
nS    = numel(SC);

rows = {};
Rshow = cell(nS, 1);  Dshow = cell(nS, 1);            % colored, seed 0
tic;
for i = 1:nS
    for nz = noises
        for s = seeds
            S = SC(i).S;
            S.noise     = nz;
            S.unitSeed  = 7  + 100*s;
            S.icmSeed   = 11 + 100*s;
            S.magSeed   = 12 + 100*s;
            S.noiseSeed = 13 + 100*s;
            D = simulate_node(S);
            nmz = NM.(char(nz));
            R = {g1_detect_v0(D), g1_detect_v1(D), ...
                 g1_detect_v3(D, nmz, struct('cusum', "abs")), g1_detect_v3(D, nmz)};
            both = R{1}.valid & R{2}.valid & R{3}.valid & R{4}.valid;
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
                    M.emiMagFlags, M.tempFaultBlameBme, M.tempFaultSensorFlags}; %#ok<SAGROW>
            end
            if nz == "colored" && s == 0, Rshow{i} = R{4}; Dshow{i} = D; end
        end
    end
    fprintf('%-12s done (%.0f s)\n', SC(i).name, toc);
end

T = cell2table(rows, 'VariableNames', {'scenario', 'noise', 'seed', 'detector', 'detected', ...
    'delayMaxMin', 'coverage', 'falsePerH', 'heaterSensorFlags', 'tSrcFlagsOutside', ...
    'emiMagFlagShare', 'bmeFaultBlameShare', 'bmeFaultSensorFlagShare'});
T.scenario = string(T.scenario);
T.noise    = string(T.noise);
T.detector = string(T.detector);
writetable(T, fullfile(here, 'g1_v3_results.csv'));

%% 3. Regression against v2
V2 = readtable(fullfile(here, '..', 'v2', 'g1_v2_results.csv'), 'TextType', 'string');
metrics = ["detected", "delayMaxMin", "coverage", "falsePerH", "heaterSensorFlags", ...
    "tSrcFlagsOutside", "emiMagFlagShare", "bmeFaultBlameShare", "bmeFaultSensorFlagShare"];
worst = 0;  nCmp = 0;
for j = 1:height(V2)
    sc = V2.scenario(j);  nz = "colored";
    if sc == "white",   sc = "base";  nz = "white";   end
    if sc == "colored", sc = "base";  end
    k = find(T.scenario == sc & T.noise == nz & T.seed == V2.seed(j) & T.detector == V2.detector(j));
    for m = metrics
        a = T.(m)(k);  b = V2.(m)(j);
        if isnan(a) && isnan(b), continue; end
        worst = max(worst, abs(a - b) / max(1, abs(b)));
    end
    nCmp = nCmp + 1;
end
fprintf('\nRegression vs v2: %d rows compared, max relative difference %.2g %s\n', ...
    nCmp, worst, string(ifelse(worst < 1e-9, '(OK)', '(MISMATCH)')));

%% Summary (mean over seeds; delay: median)
agg = @(sc, nz, d, v, f) f(T.(v)(T.scenario == sc & T.noise == nz & T.detector == d));
mn  = @(x) mean(x, 'omitnan');
md  = @(x) median(x, 'omitnan');

cols = @(c) strjoin(compose("%6s", string(c)), "");   % one fixed-width cell per detector
hdr  = cols(dets);
fprintf('\n%-22s | %-24s | %-24s | %-24s | %s\n', 'scenario / noise', 'detected', ...
    'delay [min]', 'coverage', 'false / h');
fprintf('%-22s | %s | %s | %s | %s\n', '', hdr, hdr, hdr, hdr);
for i = 1:nS
    for nz = noises
        n = SC(i).name;
        rowOf = @(v, f, fmt) cols(arrayfun(@(d) fmt(agg(n, nz, d, v, f)), dets, 'UniformOutput', false));
        fprintf('%-22s | %s | %s | %s | %s\n', n + " / " + nz, ...
            rowOf("detected", mn, @pct), rowOf("delayMaxMin", md, @num), ...
            rowOf("coverage", mn, @pct), rowOf("falsePerH", mn, @num));
    end
end

fprintf('\n  %-40s%s\n', 'Traps (mean over seeds)', hdr);
for nz = noises
    fprintf('[%s]\n', nz);
    trap(T, nz, dets, 'heater: sensor flags / run', "heaterSensorFlags", @num);
    trap(T, nz, dets, 'T-src flags outside events / run', "tSrcFlagsOutside", @num);
    trap(T(T.scenario == "emi", :), nz, dets, 'emi: share with a mag blamed', "emiMagFlagShare", @pct);
    trap(T(T.scenario == "bme-fault", :), nz, dets, 'bme-fault: share blaming BME688', "bmeFaultBlameShare", @pct);
    trap(T(T.scenario == "bme-fault", :), nz, dets, 'bme-fault: share with a sensor blamed', "bmeFaultSensorFlagShare", @pct);
end

%% Figures
cond = strings(0);  cov3 = [];  fal3 = [];
for i = 1:nS
    for nz = noises
        cond(end+1) = SC(i).name + "/" + extractBefore(nz, 2); %#ok<SAGROW>
        cov3(end+1, :) = arrayfun(@(d) agg(SC(i).name, nz, d, "coverage", mn), dets); %#ok<SAGROW>
        fal3(end+1, :) = arrayfun(@(d) agg(SC(i).name, nz, d, "falsePerH", mn), dets); %#ok<SAGROW>
    end
end
cats = categorical(cond, cond);
f1 = figure('Position', [100 100 1200 700]);
tiledlayout(2, 1);
nexttile;
bar(cats, cov3 * 100);
grid on; ylabel('Coverage [%]'); legend(dets, 'Location', 'bestoutside');
title('Fault coverage (w = white, c = colored; empty = no motion fault)');
nexttile;
b = bar(cats, max(fal3, 0.01));
set(gca, 'YScale', 'log');  [b.BaseValue] = deal(0.01);
grid on; ylabel('False sensor flags per hour'); legend(dets, 'Location', 'bestoutside');
title('False alarms (log scale; 0 drawn at 0.01)');

f2 = figure('Position', [50 50 1400 900]);
tiledlayout(3, 3);
for i = 1:nS
    nexttile;
    g1_flag_raster(Dshow{i}.tB/3600, [Rshow{i}.sensorFlag, Rshow{i}.tempFlag], ...
        [Dshow{i}.names, "T src"], Dshow{i});
    title(sprintf('v3 - %s, colored (seed 0)', SC(i).name));
end

f3 = figure('Position', [80 80 1200 850]);
tiledlayout(3, 3);
for c = 1:numel(names)
    nexttile;
    loglog(nm.tau, sqrt(nm.avar(:, c)), 'k.', 'MarkerSize', 12); hold on;
    loglog(nm.tau, sqrt(sum(nm.parts(:, :, c), 2)), 'r-', 'LineWidth', 1.5);
    loglog(nm.tau, sqrt(nm.parts(:, :, c)), '--');
    grid on; xlabel('\tau [s]'); ylabel('Allan dev');
    title(names(c));
    if c == 1, legend('static log', 'fit', 'N', 'K', 'Gauss-Markov', 'Location', 'southwest'); end
end
sgtitle('Allan fit of the 12 h static log (colored noise)');

exportgraphics(f1, fullfile(figDir, 'g1_v3_1.png'), 'Resolution', 150);
exportgraphics(f2, fullfile(figDir, 'g1_v3_2.png'), 'Resolution', 150);
exportgraphics(f3, fullfile(figDir, 'g1_v3_3.png'), 'Resolution', 150);
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
    fprintf('  %-40s%s\n', label, strjoin(compose("%6s", string(c)), ""));
end
