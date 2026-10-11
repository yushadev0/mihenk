%% g1_export_site.m
% Exports the run behind the "main idea" scene of the project page
% (web/, https://yusa.app/mihenk/). The page plays this file; MATLAB is not
% needed to view it (ADR-021).
%
% The run is the default scenario of simulate_node (as in v0): stationary
% node, 8 h, ambient 25 -> 40 -> 25 degC (common mode), a BME688 heater
% burst at 3.25-3.5 h (temperature-source trap, no fault) and a gyro z
% drift from 4.5 h (the only sensor fault). White noise, default seeds.
%
% Exported per 60 s block: temperatures (ambient truth, ICM, BME readouts),
% the nine raw channels minus their mean over the warm-up, ground truth
% (heater, fault per channel) and the decisions of the G1 detector set in
% `det` (channel states, temperature-source blame, common-mode events).
%
% Output: web/public/data/story.json. Runtime ~1-2 min.

clear; clc;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;
det = "v10";                        % current G1 detector (bulgular section 21)

% Noise characterization, as in every dev run since v3
none = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
Sc = struct('noise', "white", 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
    'heaterOn', [], 'faults', none, 'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
Dc = simulate_node(Sc);
NM = g1_allan_fit(Dc.Y, Dc.S.B);

D = simulate_node();
switch det
    case "v6", R = g1_detect_v6(D, NM);
    case "v8", R = g1_detect_v8(D, NM);
    case "v10", R = g1_detect_v10(D, NM);
    otherwise, error('unknown detector %s', det);
end

warm = R.opt.warm;
Y = D.Y - mean(D.Y(1:warm, :), 1);
r6 = @(x) round(x, 6);

out.meta = struct('detector', det, 'scenario', "simulate_node default (v0)", 'noise', "white", ...
    'B', D.S.B, 'warm', warm, 'heaterOn', D.S.heaterOn / h, 'faultCh', D.S.faults.ch, ...
    'faultT0', D.S.faults.t0 / h, 'generated', string(datetime('now', 'Format', 'yyyy-MM-dd')));
out.names  = D.names;
out.units  = ["°/s" "°/s" "°/s" "mg" "mg" "mg" "µT" "µT" "µT"];
out.t      = r6(D.tB' / h);
out.T      = struct('amb', r6(interp1(D.tT, D.truth.Tamb, D.tB)'), 'icm', r6(D.TicmB'), 'bme', r6(D.TbmeB'));
out.Y      = r6(Y');
out.heater = double(D.truth.heater');
out.fault  = double(D.truth.fault');
out.state  = double(R.state');
out.blameBme = double(R.blameBme');
out.blameIcm = double(R.blameIcm');
out.ambig    = double(R.tempAmbig');
out.common   = double(R.common');
out.valid    = double(R.valid');

outDir = fullfile(g1, '..', '..', 'web', 'public', 'data');
if ~isfolder(outDir), mkdir(outDir); end
fid = fopen(fullfile(outDir, 'story.json'), 'w');
fwrite(fid, jsonencode(out), 'char');
fclose(fid);

fprintf('Detector %s: fault blocks on gz %d of %d after onset, on other channels %d; BME blamed in %d heater blocks, ambiguous %d\n', ...
    det, nnz(R.state(:, 3) == 1 & D.truth.fault(:, 3)), nnz(D.truth.fault(:, 3)), ...
    nnz(R.state(:, [1 2 4:9]) == 1), nnz(R.blameBme & D.truth.heater), nnz(R.tempAmbig & D.truth.heater));
fprintf('Wrote %s\n', fullfile(outDir, 'story.json'));
