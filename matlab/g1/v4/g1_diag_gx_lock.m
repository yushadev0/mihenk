%% g1_diag_gx_lock.m
% Diagnosis of finding 10E (bulgular.md): in some seeds a gyro x channel
% is flagged on every scored block (false alarms exactly 60/h), whatever
% the scenario - v3/v4nf: white seed 9, colored seed 8; v4: white seed 4,
% colored seed 8.
%
% 1. All 10 seeds, base scenario, both noise types, v3 and v4: first gx
%    flag time, the share of scored blocks with gx flagged, and the unit
%    coefficients the simulator drew (ground truth, for diagnosis only):
%    gyro tempco per axis vs the detector's prior bound sb, ICM offset.
% 2. Locked cases in detail: z of gx against both references and the
%    CUSUM over the run, around the first flag. Figure g1_diag_gx_lock.png.
% Console output is kept in g1_diag_gx_lock_output.txt.

clear; clc; close all;
addpath(fileparts(fileparts(mfilename('fullpath'))));   % g1/
figDir = g1_setup();
here   = fileparts(mfilename('fullpath'));
h      = 3600;
logFile = fullfile(here, 'g1_diag_gx_lock_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

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
sbGyro = 0.005;                                         % detector prior bound [dps/degC]

%% 1. Seed table (base scenario)
fprintf('Base scenario, gx. first flag [h] and share of scored blocks flagged\n');
fprintf('%-8s %4s | %8s %6s | %8s %6s | %24s %8s %8s\n', 'noise', 'seed', 'v3 first', 'share', ...
    'v4 first', 'share', 'gyro tempco/sb (x y z)', 'offIcm', 'gx T0');
cases = {};
for nz = noises
    for s = 0:9
        S = SC(1).S;  S.noise = nz;
        D = simulate_node(seedS(S, s));
        R = {g1_detect_v3(D, NM.(char(nz))), g1_detect_v4(D, NM.(char(nz)))};
        sc = g1_detect_v0(D).valid & R{1}.valid;
        out = cell(1, 4);
        for d = 1:2
            k = find(R{d}.sensorFlag(:, 1), 1);
            out{2*d-1} = ifelse(isempty(k), "-", sprintf('%.2f', D.tB(max([k 1]))/h));
            out{2*d}   = sprintf('%.0f%%', 100*nnz(R{d}.sensorFlag(:, 1) & sc) / nnz(sc));
            if nnz(R{d}.sensorFlag(:, 1) & sc) / nnz(sc) > 0.9
                cases(end+1, :) = {nz, s, d, D, R{d}}; %#ok<SAGROW>
            end
        end
        kb = rad2deg(D.truth.unit.kbGyro) / sbGyro;
        fprintf('%-8s %4d | %8s %6s | %8s %6s | %7.2f %7.2f %7.2f  %8.2f %8.2f\n', nz, s, ...
            out{:}, kb, D.truth.unit.offIcm, D.TicmB(1));
    end
end

%% 2. Locked cases in detail
names = ["v3", "v4"];
fprintf('\nLocked cases (gx flagged on > 90%% of scored blocks): %d\n', size(cases, 1));
nCase = size(cases, 1);
f = figure('Position', [50 50 1400 300*max(nCase, 1)]);
tiledlayout(max(nCase, 1), 3);
for j = 1:nCase
    [nz, s, d, D, R] = cases{j, :};
    th = D.tB / h;
    k0 = find(R.sensorFlag(:, 1), 1);
    fprintf('\n%s seed %d, %s: first gx flag at block %d (%.2f h)\n', nz, s, names(d), k0, th(k0));
    fprintf('  block     t[h]   T_icm   T_bme      zI      zB   score  common  tFlag  amb\n');
    for k = max(31, k0 - 8):min(k0 + 3, numel(th))
        amb = NaN;
        if isfield(R, 'tempAmbig'), amb = R.tempAmbig(k); end
        fprintf('  %5d  %7.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.1f  %6d  %5d  %3g\n', k, th(k), ...
            D.TicmB(k), D.TbmeB(k), R.zI(k, 1), R.zB(k, 1), R.score(k, 1), ...
            R.common(k), R.tempFlag(k), amb);
    end
    kAfter = k0:numel(th);
    fprintf('  after first flag: median |zI| %.2f, median |zB| %.2f, min score %.1f\n', ...
        median(abs(R.zI(kAfter, 1))), median(abs(R.zB(kAfter, 1))), min(R.score(kAfter, 1)));

    nexttile;
    yyaxis left;  plot(th, D.Y(:, 1));  ylabel('gx [dps]');
    yyaxis right; plot(th, D.TicmB, th, D.TbmeB);  ylabel('T [degC]');
    xline(th(k0), 'k--');  grid on;  xlabel('t [h]');
    title(sprintf('%s seed %d (%s): gx and temperatures', nz, s, names(d)));
    nexttile;
    plot(th, R.zI(:, 1), th, R.zB(:, 1));  yline([-3 3], ':');  xline(th(k0), 'k--');
    grid on;  xlabel('t [h]');  ylabel('z');  legend('vs ICM', 'vs BME', 'Location', 'best');
    title('gx innovation z');
    nexttile;
    semilogy(th, max(R.score(:, 1), 1e-2));  yline(R.opt.h, 'r--');  xline(th(k0), 'k--');
    grid on;  xlabel('t [h]');  ylabel('CUSUM');
    title('gx CUSUM (red: alarm level)');
end
exportgraphics(f, fullfile(figDir, 'g1_diag_gx_lock.png'), 'Resolution', 120);
diary('off');

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
