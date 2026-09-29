%% g1_prototype_v0.m
% First prototype of G1: thermal common-mode vs channel-specific
% decomposition on a synthetic heterogeneous node (bulgular.md, section 6).
%
% Scenario: models/simulate_node.m (default). Detector: g1_detect_v0.m.
% Output must stay identical to the original v0 run recorded in bulgular.md.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'models'));
figDir = fullfile(here, '..', 'figures');

D = simulate_node();
R = g1_detect_v0(D);
M = g1_evaluate(D, R);
B = g1_evaluate(D, R, "baseFlag");

h = 3600;
fprintf('G1 prototype v0 - decisions from %.2f h (window warm-up)\n\n', M.firstValidH);
fprintf('Gyro z drift (%.2f dps/h from %.1f h), detection delay:\n', D.S.faultRate, D.S.faultT0/h);
fprintf('  G1       : %s\n', minStr(M.delayMin));
fprintf('  Baseline : %s\n\n', minStr(B.delayMin));
fprintf('False "sensor fault" flags [blocks of 60 s] out of %d valid blocks:\n', M.nValid);
fprintf('  %-8s %6s %9s\n', 'Channel', 'G1', 'Baseline');
for c = 1:numel(D.names)
    fprintf('  %-8s %6d %9d\n', D.names(c), M.falseFlags(c), B.falseFlags(c));
end
fprintf('\nBME688 heater burst (trap):\n');
fprintf('  sensor flags during burst (any channel) : %d blocks\n', M.heaterSensorFlags);
fprintf('  temperature sources disagree            : %d of %d blocks\n', M.heaterTempFlags, M.heaterBlocks);
fprintf('  ... blamed on BME688 / ICM              : %d / %d blocks\n', M.heaterBlameBme, M.heaterBlameIcm);
fprintf('  temperature-source flags outside burst  : %d blocks\n', M.tempFlagsOutside);

%% Plots
th = D.tB / h;
f1 = figure('Position', [100 100 900 700]);
tiledlayout(3, 1);
nexttile;
plot(D.tT/h, D.truth.Tamb, 'k', D.tT/h, D.Ticm, D.tT/h, D.Tbme); grid on;
ylabel('[\circC]'); legend('Ambient', 'ICM readout', 'BME688 readout', 'Location', 'best');
title('Temperatures (readouts include unit offsets)');
nexttile;
plot(th, D.Y(:, 3)); grid on; xline(D.S.faultT0/h, 'r--', 'fault onset');
ylabel('gz [dps]'); title('Gyro z, 60 s means');
nexttile;
plot(th, abs(R.zI(:, 3)), th, abs(R.zB(:, 3)), th, abs(R.z0(:, 3))); grid on;
yline(R.thr, 'k--'); xline(D.S.faultT0/h, 'r--');
set(gca, 'YScale', 'log');
xlabel('Time [h]'); ylabel('|z|');
legend('vs ICM temp', 'vs BME688 temp', 'Baseline (no thermal model)', 'Location', 'best');
title('Gyro z residual scores');

f2 = figure('Position', [100 100 900 600]);
tiledlayout(2, 1);
nexttile;
flagRaster(th, [R.sensorFlag, R.tempFlag], [D.names, "T src"], D);
title('G1 v0: blamed channel (black) - red: fault onset, blue: heater burst');
nexttile;
flagRaster(th, R.baseFlag, D.names, D);
xlabel('Time [h]'); title('Baseline without thermal model');

exportgraphics(f1, fullfile(figDir, 'g1_v0_1.png'), 'Resolution', 150);
exportgraphics(f2, fullfile(figDir, 'g1_v0_2.png'), 'Resolution', 150);

%% Local helpers
function s = minStr(m)
    if isnan(m), s = "not detected"; else, s = sprintf('%.0f min', m); end
end

function flagRaster(th, F, labels, D)
    imagesc(th, 1:size(F, 2), double(F)');
    yticks(1:size(F, 2)); yticklabels(labels); colormap(flipud(gray));
    xline(D.S.faultT0/3600, 'r--'); xline(D.S.heaterOn/3600, 'b--');
end
