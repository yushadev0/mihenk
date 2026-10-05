%% g1_dev_tsrc_v6.m
% Development run of the G1 v6 temperature-source model (g1_tsrc_v6.m)
% against the v5 model, with ablations. Bulgular section 14 diagnosed the
% v5 locks (13D); this script measures whether the v6 changes remove them
% without losing the heater trap or the BME fault.
%
% Variants (g1_tsrc_v6 options):
%   v5   structure "lag",     gridErr off, frozenFloor off  (= v5, checked)
%   L    structure "leadlag", gridErr off, frozenFloor off
%   G    structure "lag",     gridErr on,  frozenFloor off
%   LG   structure "leadlag", gridErr on,  frozenFloor off  <- candidate
%   LGF  LG + frozenFloor on (channel fix B carried over; expected to absorb
%        the T7 BME step, see g1_tsrc_v6.m note 3)
%
% Data (all development data; nothing here is a held-out test):
%   dev   g1_scenarios_v3 (8 scenarios), seeds 0-9
%   spent g1_scenarios_test (10 scenarios), seeds 100-119. The v5 acceptance
%         test has used this set (section 13), so it is development data now.
% The model reads temperatures only and they do not depend on the noise
% type, so only white noise is simulated.
%
% Checks (must hold before any result is read):
%   C1 v5 variant == acceptance CSV tSrcFlagsOutside on all 200 spent runs.
%   C2 (information only) v5 variant vs g1_v5_results.csv (detector v5,
%      white) on the dev set; that CSV scores on a window intersected with
%      v0's valid blocks, so small differences are possible.
%
% Metrics per run (heater window = D.truth.heater: burst + 3 tau_BME tail):
%   outside   flags outside heater and BME fault, after warm-up (= K3b)
%   heatDet   share of heater-window blocks flagged (trap seen by T-src)
%   faultCov  share of BME-fault blocks flagged (bme-fault, t7-bme-step)
%   delay     first flag after the BME fault starts [min], Inf = never
%
% Selection rule (declared before any result of this script is seen):
%   per scenario take mean outside, mean heatDet, mean faultCov and median
%   delay over seeds. The candidate is LG unless another variant is nowhere
%   worse on these and better somewhere. Target from K3b: mean outside <= 1
%   block per run in every scenario. A variant that misses it is reported,
%   not tuned on this data.
%
% Output: g1_dev_tsrc_v6_output.txt, g1_dev_tsrc_v6_results.csv,
% ../../figures/g1_dev_tsrc_v6.png. Runtime ~20-25 min (280 simulations).

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
figDir = g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_dev_tsrc_v6_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);
V = struct('name', {"v5", "L", "G", "LG", "LGF"}, ...
    'opt', {struct('structure', "lag",     'gridErr', false, 'frozenFloor', false), ...
            struct('structure', "leadlag", 'gridErr', false, 'frozenFloor', false), ...
            struct('structure', "lag",     'gridErr', true,  'frozenFloor', false), ...
            struct('structure', "leadlag", 'gridErr', true,  'frozenFloor', false), ...
            struct('structure', "leadlag", 'gridErr', true,  'frozenFloor', true)});
nV = numel(V);
warm = 30;

sets = struct('name', {"dev", "spent"}, 'SC', {g1_scenarios_v3(), g1_scenarios_test()}, ...
    'seeds', {0:9, 100:119});
Tacc = readtable(fullfile(g1, 'test', 'g1_acceptance_results.csv'), 'TextType', 'string');
Tv5  = readtable(fullfile(g1, 'v5', 'g1_v5_results.csv'), 'TextType', 'string');

rows = {};
show = struct();
showKeys = ["t2_plateau_step_100", "t8_cycle_clean_100", "t7_bme_step_100", "bme_fault_0"];
nC1 = 0;  nC2 = 0;  nC2n = 0;
tic;
for is = 1:numel(sets)
    for i = 1:numel(sets(is).SC)
        sc = sets(is).SC(i);
        for s = sets(is).seeds
            S = sc.S;  S.noise = "white";
            D = simulate_node(seedS(S, s));
            valid = (1:numel(D.tB))' > warm;
            heat  = D.truth.heater & valid;
            flt   = D.truth.tempFault & valid;
            key = sprintf('%s_%d', strrep(sc.name, '-', '_'), s);
            keepA = struct();
            for iv = 1:nV
                A = g1_tsrc_v6(D, V(iv).opt);
                out = nnz(A.tf & ~D.truth.heater & ~D.truth.tempFault & valid);
                [hd, fc, dl] = deal(NaN);
                if any(heat), hd = nnz(A.tf & heat) / nnz(heat); end
                if any(flt)
                    fc = nnz(A.tf & flt) / nnz(flt);
                    k1 = find(A.tf & flt, 1);
                    if isempty(k1), dl = Inf; else, dl = (D.tB(k1) - D.S.bmeFault.t0) / 60; end
                end
                rows(end+1, :) = {sets(is).name, sc.name, s, V(iv).name, out, hd, fc, dl, ...
                    A.tau(end), A.b(end), A.c(end)}; %#ok<SAGROW>
                if V(iv).name == "v5"
                    if sets(is).name == "spent"
                        csv = Tacc.tSrcFlagsOutside(Tacc.scenario == sc.name & ...
                            Tacc.noise == "white" & Tacc.seed == s);
                        nC1 = nC1 + (csv ~= out);
                    else
                        csv = Tv5.tSrcFlagsOutside(Tv5.scenario == sc.name & ...
                            Tv5.noise == "white" & Tv5.seed == s & Tv5.detector == "v5");
                        if ~isempty(csv) && ~isnan(csv)
                            nC2n = nC2n + 1;  nC2 = nC2 + (csv ~= out);
                        end
                    end
                end
                if any(showKeys == key), keepA.(V(iv).name) = A; end
            end
            if any(showKeys == key), show.(key) = struct('D', D, 'A', keepA); end
        end
        fprintf('%-6s %-16s done (%.0f s)\n', sets(is).name, sc.name, toc);
    end
end
T = cell2table(rows, 'VariableNames', {'set', 'scenario', 'seed', 'variant', 'outside', ...
    'heatDet', 'faultCov', 'delayMin', 'tauEnd', 'bEnd', 'cEnd'});
writetable(T, fullfile(here, 'g1_dev_tsrc_v6_results.csv'));

%% Checks
fprintf('\nC1 v5 variant vs acceptance CSV (spent set): %d mismatches of 200 runs (must be 0)\n', nC1);
fprintf('C2 v5 variant vs g1_v5_results.csv (dev set, info only): %d mismatches of %d runs\n', nC2, nC2n);

%% Summary per scenario
fprintf('\nPer scenario: outside = mean [max] flags/run; heat = mean heater-window share flagged;\n');
fprintf('fault = mean BME-fault share flagged; delay = median first flag after fault [min]\n');
for is = 1:numel(sets)
    fprintf('\n[%s]\n%-16s', sets(is).name, 'scenario');
    for iv = 1:nV, fprintf(' | %-21s', V(iv).name); end
    fprintf('\n');
    for sc = [sets(is).SC.name]
        fprintf('%-16s', sc);
        for iv = 1:nV
            r = T(T.set == sets(is).name & T.scenario == sc & T.variant == V(iv).name, :);
            fprintf(' | %5.1f [%3d]', mean(r.outside), max(r.outside));
            fprintf(' %s', cellCol(mean(r.heatDet), '%4.2f'));
        end
        fprintf('\n');
        r5 = T(T.set == sets(is).name & T.scenario == sc, :);
        if any(~isnan(r5.faultCov))
            fprintf('%-16s', '  BME fault');
            for iv = 1:nV
                r = r5(r5.variant == V(iv).name, :);
                fprintf(' | cov %4.2f dly %5s ', mean(r.faultCov), cellCol(median(r.delayMin), '%5.1f'));
            end
            fprintf('\n');
        end
    end
end

%% Learned structure (LG): tau_B, b, c at the end of the run, median over seeds
fprintf('\nLG learned structure at end of run (median over seeds): tau_B [s], b, c [s]\n');
fprintf('(simulator truth: tau_B = 200, tau_I = 120, b = 1, so c ~ 120)\n');
for is = 1:numel(sets)
    for sc = [sets(is).SC.name]
        r = T(T.set == sets(is).name & T.scenario == sc & T.variant == "LG", :);
        fprintf('  %-6s %-16s %5.0f  %6.3f  %6.1f\n', sets(is).name, sc, median(r.tauEnd), ...
            median(r.bEnd), median(r.cEnd));
    end
end

%% Selection rule
fprintf('\nSelection: scenario-level metrics, LG vs each other variant\n');
keys = unique(T(:, {'set', 'scenario'}), 'rows');
M = zeros(height(keys), 4, nV);         % outside (low), heat (high), fault (high), delay (low)
for kk = 1:height(keys)
    for iv = 1:nV
        r = T(T.set == keys.set(kk) & T.scenario == keys.scenario(kk) & T.variant == V(iv).name, :);
        M(kk, :, iv) = [mean(r.outside), mean(r.heatDet), mean(r.faultCov), median(r.delayMin)];
    end
end
sgn = [-1 1 1 -1];                      % +: higher is better after the sign flip
iLG = find([V.name] == "LG");
pick = "LG";
for iv = setdiff(1:nV, iLG)
    d = (M(:, :, iv) - M(:, :, iLG)) .* sgn;   % > 0: variant better than LG
    d(isnan(d)) = 0;
    worse  = any(d(:) < 0);
    better = any(d(:) > 0);
    fprintf('  %-4s vs LG: worse somewhere %d, better somewhere %d\n', V(iv).name, worse, better);
    if ~worse && better, pick = V(iv).name; end
end
fprintf('  -> candidate: %s\n', pick);
miss = keys(M(:, 1, [V.name] == pick) > 1, :);
fprintf('  K3b target (mean outside <= 1 per scenario) missed by %s in %d scenario(s)', pick, height(miss));
if height(miss) > 0, fprintf(': %s', strjoin(miss.set + "/" + miss.scenario, ', ')); end
fprintf('\n');

%% Figure: zT of v5 and LG (and LGF), temperatures
f = figure('Position', [40 40 1400 260*numel(showKeys)]);
tiledlayout(numel(showKeys), 2);
for j = 1:numel(showKeys)
    if ~isfield(show, showKeys(j)), continue; end
    D = show.(showKeys(j)).D;  A = show.(showKeys(j)).A;
    th = D.tB / h;
    nexttile;
    plot(th, D.TicmB, th, D.TbmeB);  hold on;  shade(th, D.truth.heater, [1 0.6 0.2]);
    shade(th, D.truth.tempFault, [0.6 0.6 1]);
    grid on;  xlabel('t [h]');  ylabel('T [degC]');  legend('ICM', 'BME', 'Location', 'best');
    title(strrep(showKeys(j), '_', ' '));
    nexttile;
    plot(th, A.v5.zT, th, A.LG.zT, th, A.LGF.zT);  hold on;
    shade(th, D.truth.heater, [1 0.6 0.2]);  shade(th, D.truth.tempFault, [0.6 0.6 1]);
    yline([-5 -3 3 5], ':');  ylim([-30 30]);
    grid on;  xlabel('t [h]');  ylabel('zT');  legend('v5', 'LG', 'LGF', 'Location', 'best');
    title('temperature-source z (orange: heater window, blue: BME fault)');
end
exportgraphics(f, fullfile(figDir, 'g1_dev_tsrc_v6.png'), 'Resolution', 120);
diary('off');

%% Helpers
function s = cellCol(v, f)
    if isnan(v), s = "  - "; else, s = string(sprintf(f, v)); end
end

function shade(th, mask, col)
    yl = ylim;
    on  = find(diff([false; mask; false]) == 1);
    off = find(diff([false; mask; false]) == -1) - 1;
    for i = 1:numel(on)
        patch(th([on(i) off(i) off(i) on(i)]), yl([1 1 2 2]), col, ...
            'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    ylim(yl);
end
