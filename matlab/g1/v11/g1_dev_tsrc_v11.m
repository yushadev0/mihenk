%% g1_dev_tsrc_v11.m
% Development run of two fixes to the G1 temperature-source model
% (g1_tsrc_v6.m) for the K3b failures diagnosed in bulgular section 22.
% Variants and the selection rule are declared before any result.
%
%   v6  model as the v6-v10 detectors call it: lead-lag, no grid term,
%       no frozen floor, tauGrid 0:20:300, reentryHold 0
%   H   v6 + re-entry hold (22B, H1): after a rejected block the model
%       updates again only after m consecutive in-gate blocks,
%       m = ceil(3 * max(tauGrid) / B): three time constants of the slowest
%       lag the model can represent, so a disturbance seen through it has
%       decayed to ~5 %. With the v6 grid m = 15.
%   W   v6 with a wider lag grid, tauGrid 0:20:600 (22C, H2): the BME path
%       of the second held-out set had a net lag of up to ~600 s, beyond
%       the 300 s grid end. NOTE: this range is chosen after seeing that
%       set, so W is circular on it; the third held-out set must contain
%       slower and structurally different BME paths.
%   HW  both, m = ceil(3 * 600 / 60) = 30                   <- candidate
%
% Data (development data only, white noise: the model reads temperatures
% only and they do not depend on the noise):
%   dev     g1_scenarios_v3, seeds 0-9 (80 runs)
%   spent1  g1_scenarios_test, seeds 100-119 (200 runs)
%   spent2  g1_scenarios_test2, seeds 200-299 (100 runs). The fixes were
%           designed on this set (section 22), so it shows whether they do
%           what they were built for, not whether they generalize.
%
% Checks (must hold before any result is read):
%   C1 v6 variant, old truth labels, scored like the acceptance test (block
%      > warm and v0 valid) == tSrcFlagsOutside of v10 / white in
%      g1_acceptance2_runs.csv on all 100 spent2 runs.
%   C2 v6 variant, old truth labels, block > warm == variant L of
%      g1_dev_tsrc_v6_results.csv on all 280 dev + spent1 runs.
%
% Metrics per run, block > warm, truth labels with the onset block counted
% as faulty (g1_truth_onset.m, 22D):
%   outside   flags outside heater window and BME fault (K3b)
%   heatDet   share of heater-window blocks flagged (the trap seen by T-src)
%   faultCov  share of BME-fault blocks flagged
%   delay     first flag at or after the fault onset block [min], Inf = never
%   (descriptive: longest outside run, held-back blocks)
%
% Selection rule (declared before any result):
%   Groups: scenario (dev, spent1) or family (spent2). Per group: mean
%   outside, mean heatDet, mean faultCov, median delay.
%   Step 1: the candidate is HW unless H or W is nowhere worse and
%           somewhere better than HW over groups x metrics.
%   Step 2: the candidate replaces v6 only if on every set (dev, spent1,
%           spent2) over all runs: mean outside lower than v6 (or both 0),
%           mean heatDet >= v6 - 0.01, mean faultCov >= v6 - 0.01, median
%           delay <= v6 + 1 min. Otherwise v6 stays and the failing items
%           are reported, not tuned away.
%   K3b target (mean outside <= 1 per run) is reported per set.
%
% Output: g1_dev_tsrc_v11_output.txt, g1_dev_tsrc_v11_results.csv,
% ../../figures/g1_dev_tsrc_v11.png. Runtime roughly 30-40 min.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'), fullfile(g1, 'test2'));
figDir = g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_dev_tsrc_v11_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);
B = 60;
holdFor = @(grid) ceil(3 * max(grid) / B);
base = struct('structure', "leadlag", 'gridErr', false, 'frozenFloor', false, ...
    'tauGrid', 0:20:300, 'reentryHold', 0);
gW = 0:20:600;
V = struct('name', {"v6", "H", "W", "HW"}, ...
    'opt', {base, ...
            setfield(base, 'reentryHold', holdFor(base.tauGrid)), ...
            setfield(base, 'tauGrid', gW), ...
            setfield(setfield(base, 'tauGrid', gW), 'reentryHold', holdFor(gW))});
nV = numel(V);
warm = 30;
fprintf('Re-entry hold: H m = %d blocks, HW m = %d blocks\n\n', V(2).opt.reentryHold, V(4).opt.reentryHold);

% Every run as {set, group, scenario name, seed, S}
SC1 = g1_scenarios_v3();  SC2 = g1_scenarios_test();  SC3 = g1_scenarios_test2();
runs = {};
for i = 1:numel(SC1), for s = 0:9,     runs(end+1, :) = {"dev",    SC1(i).name, SC1(i).name, s, seedS(SC1(i).S, s)}; end, end %#ok<SAGROW>
for i = 1:numel(SC2), for s = 100:119, runs(end+1, :) = {"spent1", SC2(i).name, SC2(i).name, s, seedS(SC2(i).S, s)}; end, end %#ok<SAGROW>
for i = 1:numel(SC3), runs(end+1, :) = {"spent2", SC3(i).family, SC3(i).name, SC3(i).seed, SC3(i).S}; end %#ok<SAGROW>

Tacc = readtable(fullfile(g1, 'test2', 'g1_acceptance2_runs.csv'), 'TextType', 'string');
Tacc = Tacc(Tacc.detector == "v10" & Tacc.noise == "white", :);
Tv6  = readtable(fullfile(g1, 'v6', 'g1_dev_tsrc_v6_results.csv'), 'TextType', 'string');
Tv6  = Tv6(Tv6.variant == "L", :);

showKeys = ["step-242", "two-faults-264", "emi-227", "bme-step-269", "t7-bme-step"];
show = struct();
rows = {};  nC1 = 0;  nC1n = 0;  nC2 = 0;  nC2n = 0;
tic;
for r = 1:size(runs, 1)
    [sn, grp, name, s, S] = runs{r, :};
    S.noise = "white";
    D  = simulate_node(S);
    Dn = g1_truth_onset(D);
    valid = (1:numel(D.tB))' > warm;
    heat  = Dn.truth.heater & valid;
    flt   = Dn.truth.tempFault & valid;
    keepA = struct();
    for iv = 1:nV
        A = g1_tsrc_v6(D, V(iv).opt);
        outM = A.tf & ~Dn.truth.heater & ~Dn.truth.tempFault & valid;
        [hd, fc, dl] = deal(NaN);
        if any(heat), hd = nnz(A.tf & heat) / nnz(heat); end
        if any(flt)
            fc = nnz(A.tf & flt) / nnz(flt);
            k1 = find(A.tf & flt, 1);
            if isempty(k1), dl = Inf; else, dl = max(D.tB(k1) - D.S.bmeFault.t0, 0) / 60; end
        end
        rows(end+1, :) = {sn, grp, name, s, V(iv).name, nnz(outM), hd, fc, dl, ...
            longestRun(outM), nnz(A.hold & valid), A.tau(end), A.b(end), A.c(end)}; %#ok<SAGROW>
        if iv == 1                          % checks on the v6 variant, old labels
            oldOut = A.tf & ~D.truth.heater & ~D.truth.tempFault & valid;
            if sn == "spent2"
                R0 = g1_detect_v0(D);
                csv = Tacc.tSrcFlagsOutside(Tacc.scenario == name);
                nC1n = nC1n + 1;  nC1 = nC1 + ~isequal(csv, nnz(oldOut & R0.valid));
            else
                csv = Tv6.outside(Tv6.set == ifelse(sn == "dev", "dev", "spent") & ...
                    Tv6.scenario == name & Tv6.seed == s);
                nC2n = nC2n + 1;  nC2 = nC2 + ~isequal(csv, nnz(oldOut));
            end
        end
        keepA.(V(iv).name) = A;
    end
    if any(showKeys == name) && ~isfield(show, matlab.lang.makeValidName(name))
        show.(matlab.lang.makeValidName(name)) = struct('D', Dn, 'A', keepA, 's', s);
    end
    if mod(r, 20) == 0, fprintf('  %3d / %d runs (%.0f s)\n', r, size(runs, 1), toc); end
end
T = cell2table(rows, 'VariableNames', {'set', 'group', 'scenario', 'seed', 'variant', 'outside', ...
    'heatDet', 'faultCov', 'delayMin', 'longest', 'held', 'tauEnd', 'bEnd', 'cEnd'});
writetable(T, fullfile(here, 'g1_dev_tsrc_v11_results.csv'));

%% Checks
fprintf('\nC1 v6 variant vs acceptance CSV (spent2): %d mismatches of %d runs (must be 0)\n', nC1, nC1n);
fprintf('C2 v6 variant vs g1_dev_tsrc_v6 L (dev + spent1): %d mismatches of %d runs (must be 0)\n', nC2, nC2n);

%% Per group
md = @(x) median(x, 'omitnan');  mn = @(x) mean(x, 'omitnan');
sets = ["dev", "spent1", "spent2"];
fprintf('\nPer group: outside mean [max] | heatDet | BME fault cov / median delay [min]\n');
for st = sets
    fprintf('\n[%s]\n%-16s', st, 'group');
    for iv = 1:nV, fprintf(' | %-26s', V(iv).name); end
    fprintf('\n');
    for g = unique(T.group(T.set == st), 'stable')'
        fprintf('%-16s', g);
        for iv = 1:nV
            q = T(T.set == st & T.group == g & T.variant == V(iv).name, :);
            fprintf(' | %5.1f [%3d] %s %s/%s', mn(q.outside), max(q.outside), num(mn(q.heatDet), '%4.2f'), ...
                num(mn(q.faultCov), '%4.2f'), num(md(q.delayMin), '%4.0f'));
        end
        fprintf('\n');
    end
end

%% Selection, step 1: family rule
keys = unique(T(:, {'set', 'group'}), 'rows', 'stable');
M = nan(height(keys), 4, nV);
for kk = 1:height(keys)
    for iv = 1:nV
        q = T(T.set == keys.set(kk) & T.group == keys.group(kk) & T.variant == V(iv).name, :);
        M(kk, :, iv) = [mn(q.outside), mn(q.heatDet), mn(q.faultCov), md(q.delayMin)];
    end
end
sgn = [-1 1 1 -1];
iC = find([V.name] == "HW");
pick = "HW";
fprintf('\nStep 1 (family rule), vs HW:\n');
for iv = find(ismember([V.name], ["H", "W"]))
    d = (M(:, :, iv) - M(:, :, iC)) .* sgn;
    d(isnan(d)) = 0;
    worse = nnz(d < -1e-9);  better = nnz(d > 1e-9);
    fprintf('  %-2s worse in %d, better in %d cells\n', V(iv).name, worse, better);
    if worse == 0 && better > 0, pick = V(iv).name; end
end
fprintf('  -> candidate: %s\n', pick);

%% Selection, step 2: candidate vs v6, per set
fprintf('\nStep 2: %s vs v6 per set (all runs)\n', pick);
adopt = true;
for st = sets
    a = T(T.set == st & T.variant == pick, :);  b = T(T.set == st & T.variant == "v6", :);
    o1 = mn(a.outside) < mn(b.outside) || (mn(a.outside) == 0 && mn(b.outside) == 0);
    o2 = isnan(mn(b.heatDet))  || mn(a.heatDet)  >= mn(b.heatDet) - 0.01;
    o3 = isnan(mn(b.faultCov)) || mn(a.faultCov) >= mn(b.faultCov) - 0.01;
    o4 = isnan(md(b.delayMin)) || md(a.delayMin) <= md(b.delayMin) + 1;
    fprintf(['  [%s] outside %.2f vs %.2f %s | heatDet %s vs %s %s | faultCov %s vs %s %s | ' ...
        'delay %s vs %s %s\n'], st, mn(a.outside), mn(b.outside), pf(o1), ...
        num(mn(a.heatDet), '%.3f'), num(mn(b.heatDet), '%.3f'), pf(o2), ...
        num(mn(a.faultCov), '%.3f'), num(mn(b.faultCov), '%.3f'), pf(o3), ...
        num(md(a.delayMin), '%.1f'), num(md(b.delayMin), '%.1f'), pf(o4));
    adopt = adopt && o1 && o2 && o3 && o4;
    fprintf('         K3b target (mean outside <= 1): %s %s\n', pick, pf(mn(a.outside) <= 1));
end
fprintf('  -> temperature-source model for v11: %s\n', string(ifelse(adopt, pick, "v6")));

%% Learned lag at end of run (descriptive; truth BME lag 200 s + tau2)
fprintf('\nMedian tau_B at end of run [s], spent2 by BME path (truth 200 + tau2)\n');
SCt = struct2table(rmfield(SC3, 'S'));
for iv = 1:nV
    q = T(T.set == "spent2" & T.variant == V(iv).name, :);
    t2 = SCt.bmeTau2(match(q.scenario, string(SCt.name)));
    fprintf('  %-3s first order %4.0f | second order %4.0f (true net lag median %4.0f)\n', V(iv).name, ...
        md(q.tauEnd(t2 == 0)), md(q.tauEnd(t2 > 0)), 200 + md(t2(t2 > 0)));
end

%% Figure: temperatures and zT of v6 and HW
ks = fieldnames(show);
f = figure('Position', [40 40 1400 240*numel(ks)]);
tiledlayout(numel(ks), 2, 'TileSpacing', 'compact');
for j = 1:numel(ks)
    D = show.(ks{j}).D;  A = show.(ks{j}).A;  th = D.tB / h;
    nexttile;
    plot(th, D.TicmB, th, D.TbmeB);  hold on;
    shade(th, D.truth.heater, [1 0.6 0.2]);  shade(th, D.truth.tempFault, [0.6 0.6 1]);
    grid on;  ylabel('T [degC]');  title(sprintf('%s seed %d', ks{j}, show.(ks{j}).s), 'Interpreter', 'none');
    nexttile;
    plot(th, A.v6.zT, th, A.HW.zT);  hold on;
    shade(th, D.truth.heater, [1 0.6 0.2]);  shade(th, D.truth.tempFault, [0.6 0.6 1]);
    yline([-5 -3 3 5], ':');  ylim([-30 30]);  grid on;  ylabel('zT');
    legend('v6', 'HW', 'Location', 'best');  title('zT (orange: heater window, blue: BME fault)');
end
exportgraphics(f, fullfile(figDir, 'g1_dev_tsrc_v11.png'), 'Resolution', 110);
diary('off');

%% Helpers
function n = longestRun(m)
    r = 0;  n = 0;
    for k = 1:numel(m), r = (r + 1) * m(k);  n = max(n, r); end
end

function i = match(a, b)
    [~, i] = ismember(a, b);
end

function s = num(v, f)
    if isnan(v), s = "-"; else, s = string(sprintf(f, v)); end
end

function s = pf(ok)
    s = string(ifelse(ok, 'pass', 'FAIL'));
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
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
