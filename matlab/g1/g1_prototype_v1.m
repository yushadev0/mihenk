%% g1_prototype_v1.m
% G1 prototype v1 vs v0 vs baseline on the same synthetic node
% (bulgular.md, section 7). Detector changes: see g1_detect_v1.m.
%
% The comparison table uses only blocks where both v0 and v1 decide (v0
% needs 1.68 h of window). The v0 column must equal bulgular.md section 6:
% that confirms the refactor into simulate_node / g1_detect_v0 is faithful.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'models'));
figDir = fullfile(here, '..', 'figures');

D  = simulate_node();
R0 = g1_detect_v0(D);
R1 = g1_detect_v1(D);

both = R0.valid & R1.valid;
R0c = R0;  R0c.valid = both;
R1c = R1;  R1c.valid = both;
Mb = g1_evaluate(D, R0c, "baseFlag");
M0 = g1_evaluate(D, R0c);
M1 = g1_evaluate(D, R1c);
M1all = g1_evaluate(D, R1);

%% Report
fprintf('Comparison on %d common blocks (from %.2f h)\n\n', M0.nValid, M0.firstValidH);
fprintf('%-44s %9s %9s %9s\n', 'Metric', 'Baseline', 'G1 v0', 'G1 v1');
row('gz fault: detection delay [min]',            Mb.delayMin, M0.delayMin, M1.delayMin);
row('gz fault: coverage [% faulty blocks flagged]', 100*Mb.faultCoverage, 100*M0.faultCoverage, 100*M1.faultCoverage);
for c = 1:numel(D.names)
    row(sprintf('false sensor flags: %s', D.names(c)), Mb.falseFlags(c), M0.falseFlags(c), M1.falseFlags(c));
end
row('false sensor flags: total',                  sum(Mb.falseFlags), sum(M0.falseFlags), sum(M1.falseFlags));
row('heater: sensor flags',                       NaN, M0.heaterSensorFlags, M1.heaterSensorFlags);
row('heater: T-source flags',                     NaN, M0.heaterTempFlags, M1.heaterTempFlags);
row('heater: blamed BME688',                      NaN, M0.heaterBlameBme, M1.heaterBlameBme);
row('heater: blamed ICM',                         NaN, M0.heaterBlameIcm, M1.heaterBlameIcm);
row('T-source flags outside heater',              NaN, M0.tempFlagsOutside, M1.tempFlagsOutside);

fprintf('\nv1 on its full decision range (from %.2f h, %d blocks):\n', M1all.firstValidH, M1all.nValid);
fprintf('  false sensor flags total : %d\n', sum(M1all.falseFlags));
fprintf('  T-source flags outside heater : %d\n', M1all.tempFlagsOutside);
fprintf('  common-mode events       : %d blocks\n', nnz(R1.common & R1.valid));
fprintf('  low-confidence share (gz): %.0f %% of valid blocks\n', 100*mean(R1.lowConf(R1.valid, 3)));
fprintf('  lag ICM->BME picked      : %d s (final)\n', R1.tauBest(end));
fprintf('  hysteresis width picked  : %.1f degC vs ICM, %.1f degC vs BME (final)\n', R1.wBest(end, 1), R1.wBest(end, 2));
fc = D.S.faultCh;
inF = D.truth.fault(:, fc) & R1.valid;
fprintf('  gz flagged under low confidence: %d of %d flagged fault blocks\n', ...
    nnz(R1.sensorFlag(:, fc) & R1.lowConf(:, fc) & inF), nnz(R1.sensorFlag(:, fc) & inF));

%% Plots
h  = 3600;
th = D.tB / h;
f1 = figure('Position', [100 100 900 750]);
tiledlayout(3, 1);
nexttile;
plot(th, D.Y(:, fc)); grid on; xline(D.S.faultT0/h, 'r--', 'fault onset');
ylabel('gz [dps]'); title('Gyro z, 60 s means');
nexttile;
plot(th, R0.score(:, fc)); grid on; yline(R0.thr, 'k--'); xline(D.S.faultT0/h, 'r--');
set(gca, 'YScale', 'log'); ylabel('|z|'); title('v0: sliding-window score (gz)');
nexttile;
plot(th, R1.score(:, fc)); grid on; yline(R1.opt.h, 'k--'); xline(D.S.faultT0/h, 'r--');
hold on;
lc = R1.lowConf(:, fc) & R1.valid;
plot(th(lc), max(R1.score(lc, fc), 1e-2), 'm.');
set(gca, 'YScale', 'log'); ylim([1e-2 inf]);
xlabel('Time [h]'); ylabel('CUSUM');
legend('score', 'alarm level', '', 'low confidence', 'Location', 'best');
title('v1: memory model + CUSUM (gz)');

f2 = figure('Position', [100 100 900 650]);
tiledlayout(2, 1);
nexttile;
flagRaster(th, [R0.sensorFlag, R0.tempFlag], [D.names, "T src"], D);
title('G1 v0 (black = blamed) - red: fault onset, blue: heater burst');
nexttile;
flagRaster(th, [R1.sensorFlag, R1.tempFlag], [D.names, "T src"], D);
xlabel('Time [h]'); title('G1 v1');

exportgraphics(f1, fullfile(figDir, 'g1_v1_1.png'), 'Resolution', 150);
exportgraphics(f2, fullfile(figDir, 'g1_v1_2.png'), 'Resolution', 150);

%% Local helpers
function row(label, a, b, c)
    fprintf('%-44s %9s %9s %9s\n', label, num(a), num(b), num(c));
end

function s = num(v)
    if isnan(v), s = "-"; elseif v == round(v), s = sprintf('%d', v); else, s = sprintf('%.1f', v); end
end

function flagRaster(th, F, labels, D)
    imagesc(th, 1:size(F, 2), double(F)');
    yticks(1:size(F, 2)); yticklabels(labels); colormap(flipud(gray));
    xline(D.S.faultT0/3600, 'r--'); xline(D.S.heaterOn/3600, 'b--');
end
