%% g1_diag_v6_side.m
% Diagnosis of finding 16E (bulgular.md), the two v6 side effects seen in
% the replay viewer on t2-plateau-step / white / seed 100:
%
%   E1 mz is flagged 3.8-4.8 h in v6 but not in v6noA (v5's temperature-
%      source model). The two runs differ only in the temperature-source
%      decision: in noA the BME688 is blamed 3.1-6.1 h (lock, 13D), so the
%      BME reference is unusable for the channels; in v6 it is usable.
%      Hypotheses:
%      H1 the BME-reference model of mz is biased (stale), and a channel
%         decision takes the reference with the smaller |z|; switching
%         between references can give a sign-consistent series that the
%         signed CUSUM accumulates although neither |z| alone is large.
%      H2 the histories differ earlier (width choice, CUSUM resets on a
%         width switch, common-mode events), not the reference choice.
%   E2 the ax step (4.0 h) is released by the event-end rule (B) at
%      4.09 h although the step persists. Hypothesis H3: while ax is
%      frozen, the reference with the smaller |z| changes and |z| drops
%      below zU for 5 blocks although the other reference still sees the
%      step.
%
% 1. Seed 100: first block where mz differs between v6 and noA, then a
%    block table around the mz alarm onset (both references: z, prior
%    offset and tempco of the selected width; reference used; CUSUM).
% 2. Counterfactual: v6 with channel decisions on the ICM reference only
%    (refMask [1 0], diagnostic switch). If the mz alarm disappears, the
%    BME reference causes it.
% 3. Block table for ax 3.95-4.25 h under v6: zI, zB, reference used,
%    episode peak |z|, quiet blocks, release type. Same with refMask [1 0].
% 4. Seeds 100-109 (white): per seed, healthy-channel flag blocks for v6,
%    noA and v6 ICM-only, and the time of an event-end release of ax.
% Figure: ../../figures/g1_diag_v6_side.png. Diagnosis only: nothing here
% changes v6. Output: g1_diag_v6_side_output.txt. Runtime ~5 min.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
figDir = g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_diag_v6_side_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

none = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
Sc = struct('noise', "white", 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
    'heaterOn', [], 'faults', none, 'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
Dc = simulate_node(Sc);
NM = g1_allan_fit(Dc.Y, Dc.S.B);
seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);
SC = g1_scenarios_test();
S0 = SC([SC.name] == "t2-plateau-step").S;  S0.noise = "white";

trc = struct('trace', true);
oA  = struct('trace', true, 'tsrc', "lag");
oI  = struct('trace', true, 'refMask', [true false]);
mz = 9;  ax = 4;

%% 1. Seed 100, mz
D  = simulate_node(seedS(S0, 100));
R6 = g1_detect_v6(D, NM, trc);
RA = g1_detect_v6(D, NM, oA);
RI = g1_detect_v6(D, NM, oI);
th = D.tB / h;
d = abs(R6.zI(:, mz) - RA.zI(:, mz)) + abs(R6.zB(:, mz) - RA.zB(:, mz)) + abs(R6.score(:, mz) - RA.score(:, mz));
k1 = find(d > 1e-9, 1);
fprintf('1. t2 / white / seed 100, mz\n');
fprintf('   flag blocks: v6 %d, noA %d, v6 ICM-only %d\n', nnz(R6.sensorFlag(:, mz)), ...
    nnz(RA.sensorFlag(:, mz)), nnz(RI.sensorFlag(:, mz)));
fprintf('   first block where mz differs between v6 and noA: %s\n', fmtk(k1, th));
fprintf('   BME usable for channels: v6 %d blocks, noA %d blocks (of %d)\n', ...
    nnz(R6.usable(:, 2)), nnz(RA.usable(:, 2)), numel(th));
kOn = find(R6.sensorFlag(:, mz), 1);
fprintf('   first mz flag in v6: %s\n', fmtk(kOn, th));
fprintf('   width choice differs (ICM ref) on %d blocks, (BME ref) on %d blocks\n', ...
    nnz(R6.wBest(:, 1) ~= RA.wBest(:, 1)), nnz(R6.wBest(:, 2) ~= RA.wBest(:, 2)));
fprintf('   CUSUM resets on a width switch: v6 %d, noA %d\n', nnz(R6.switchReset), nnz(RA.switchReset));
if ~isempty(kOn)
    blockTable(R6, RA, D, mz, max(1, kOn - 15):min(numel(th), kOn + 6), 'v6 vs noA');
end

%% 2./3. ax around the step
fprintf('\n3. ax around the step (4.0 h), v6\n');
axTable(R6, D, ax, find(th >= 3.95 & th <= 4.25)');
fprintf('\n   same, v6 ICM-only\n');
axTable(RI, D, ax, find(th >= 3.95 & th <= 4.25)');

%% 4. Seeds 100-109
fprintf('\n4. t2 / white, seeds 100-109: healthy-channel flag blocks (channel: blocks) and ax event-end release\n');
fprintf('%5s | %-28s | %-28s | %-28s | %s\n', 'seed', 'v6', 'noA', 'v6 ICM-only', 'ax event-end release [h] v6 / ICM-only');
for s = 100:109
    D = simulate_node(seedS(S0, s));
    R = {g1_detect_v6(D, NM), g1_detect_v6(D, NM, struct('tsrc', "lag")), ...
         g1_detect_v6(D, NM, struct('refMask', [true false]))};
    txt = strings(1, 3);
    for j = 1:3
        F = R{j}.sensorFlag & ~D.truth.fault & R{j}.valid;
        n = sum(F, 1);
        txt(j) = "-";
        if any(n > 0)
            txt(j) = strjoin(D.names(n > 0) + ":" + string(n(n > 0)), ' ');
        end
    end
    e6 = find(R{1}.releaseType(:, ax) == 1, 1);  eI = find(R{3}.releaseType(:, ax) == 1, 1);
    fprintf('%5d | %-28s | %-28s | %-28s | %s / %s\n', s, txt(1), txt(2), txt(3), ...
        fmtk(e6, D.tB / h), fmtk(eI, D.tB / h));
end

%% Figure (seed 100)
D = simulate_node(seedS(S0, 100));
f = figure('Position', [40 40 1500 800]);
tiledlayout(3, 2);
nexttile;  plot(th, R6.zI(:, mz), th, R6.zB(:, mz));  yline([-3 3], ':');  ylim([-10 10]);
shadeF(th, R6.sensorFlag(:, mz));  grid on;  title('mz z, v6 (shaded: flagged)');  legend('vs ICM', 'vs BME');
nexttile;  plot(th, RA.zI(:, mz), th, RA.zB(:, mz));  yline([-3 3], ':');  ylim([-10 10]);
shadeF(th, RA.sensorFlag(:, mz));  grid on;  title('mz z, noA');  legend('vs ICM', 'vs BME');
nexttile;  plot(th, R6.score(:, mz), th, RA.score(:, mz), th, RI.score(:, mz));  yline(10, 'r--');
grid on;  title('mz CUSUM');  legend('v6', 'noA', 'v6 ICM-only');
nexttile;  plot(th, R6.thB(:, mz, 1), th, R6.thB(:, mz, 2));  grid on;
title('mz tempco b (prior, selected width), v6');  legend('ICM model', 'BME model');
nexttile;  plot(th, R6.zI(:, ax), th, R6.zB(:, ax));  yline([-3 3], ':');  ylim([-15 15]);
shadeF(th, R6.sensorFlag(:, ax));  xline(4, 'k--');  grid on;  title('ax z, v6');  legend('vs ICM', 'vs BME');
nexttile;  plot(th, R6.thA(:, ax, 1), th, R6.thA(:, ax, 2));  xline(4, 'k--');  grid on;
title('ax offset a (prior, selected width), v6');  legend('ICM model', 'BME model');
exportgraphics(f, fullfile(figDir, 'g1_diag_v6_side.png'), 'Resolution', 120);
diary('off');

%% Helpers
function blockTable(R, Q, D, c, ks, lbl)
    th = D.tB / 3600;
    fprintf('\n   block table, %s, channel %s (ref = reference used: I, B or IB = both usable)\n', lbl, D.names(c));
    fprintf('   %5s %6s %6s %6s | %4s %6s %6s %6s %6s %8s %8s | %4s %6s %6s %6s\n', 'k', 't[h]', 'Ticm', 'Tbme', ...
        'ref', 'zI', 'zB', 'S', 'flag', 'bI', 'bB', 'ref', 'zI', 'zB', 'S');
    for k = ks
        fprintf('   %5d %6.2f %6.2f %6.2f | %4s %6.2f %6.2f %6.2f %6d %8.5f %8.5f | %4s %6.2f %6.2f %6.2f\n', ...
            k, th(k), D.TicmB(k), D.TbmeB(k), refs(R.usable(k, :)), R.zI(k, c), R.zB(k, c), ...
            R.score(k, c), R.sensorFlag(k, c), R.thB(k, c, 1), R.thB(k, c, 2), ...
            refs(Q.usable(k, :)), Q.zI(k, c), Q.zB(k, c), Q.score(k, c));
    end
end

function axTable(R, D, c, ks)
    th = D.tB / 3600;
    fprintf('   %5s %6s | %4s %7s %7s %7s %6s %4s %4s\n', 'k', 't[h]', 'ref', 'zI', 'zB', 'used', 'S', 'flag', 'rel');
    for k = ks
        u = R.usable(k, :);  z = [R.zI(k, c), R.zB(k, c)];  z(~u) = NaN;
        [~, j] = min(abs(z));
        fprintf('   %5d %6.2f | %4s %7.2f %7.2f %7.2f %6.2f %4d %4d\n', k, th(k), refs(u), ...
            R.zI(k, c), R.zB(k, c), z(j), R.score(k, c), R.sensorFlag(k, c), R.releaseType(k, c));
    end
end

function s = refs(u)
    s = "";
    if u(1), s = s + "I"; end
    if u(2), s = s + "B"; end
end

function s = fmtk(k, th)
    if isempty(k), s = "-"; else, s = sprintf('block %d (%.2f h)', k, th(k)); end
end

function shadeF(th, m)
    yl = ylim;  hold on;
    on = find(diff([false; m(:); false]) == 1);  off = find(diff([false; m(:); false]) == -1) - 1;
    for i = 1:numel(on)
        patch(th([on(i) off(i) off(i) on(i)]), yl([1 1 2 2]), [1 0.3 0.3], 'FaceAlpha', 0.12, ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    ylim(yl);
end
