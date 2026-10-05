%% g1_export_replay.m
% Exports a few G1 runs to JSON for the browser replay viewer
% (viewer/replay.html). The viewer reads only these files; MATLAB is not
% needed to watch a run (ADR-021).
%
% Per run: block times, temperatures (ambient truth, ICM, BME), ground
% truth (heater window, BME fault, EMI, motion faults per channel), the
% full v5 detector (channel z against both references, CUSUM score,
% flags, releases, temperature-source blame) and the temperature-source
% model in two versions: v5 and the v6 candidate L (bulgular section 15).
% The full v6 detector (g1_detect_v6, section 16) is exported as well: its
% channel states (0 healthy, 1 fault, 2 offset event, 3 unreliable).
%
% Check: the temperature-source z of each detector must equal the
% standalone model (printed as max abs difference, v5 and v6).
%
% Output: viewer/data/<id>.json and viewer/data/index.json.
% Runtime ~3-5 min (two 12 h characterization runs + 6 scenarios).

clear; clc;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;
outDir = fullfile(g1, '..', '..', 'viewer', 'data');
if ~isfolder(outDir), mkdir(outDir); end

runs = struct( ...
    'scenario', {"t2-plateau-step", "t2-plateau-step", "t8-cycle-clean", "t9-relax-az", "t6-emi-plateau", "t7-bme-step"}, ...
    'seed',     {100, 100, 100, 100, 100, 100}, ...
    'noise',    {"white", "colored", "white", "white", "colored", "white"}, ...
    'note',     {"Sıcaklık kaynağı kilidi (13D) ve v6 düzeltmesi (15A)", ...
                 "Platoda ivmeölçer basamağı: serbest bırakma basamağı bırakıyor (12B, 13C)", ...
                 "Hızlı sinüs: v5'te yapı uyuşmazlığı (14C)", ...
                 "Gevşeme histerezisi: model biçim uyuşmazlığı, yanlış alarmlar (13B)", ...
                 "EMI ve sonrasında manyetometrenin yavaş çıkışı (12D, 13E)", ...
                 "BME688 sıcaklığında +1 °C basamak arızası"});

% Noise models, identical to the acceptance test characterization
none = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
for nz = ["white", "colored"]
    Sc = struct('noise', nz, 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
        'heaterOn', [], 'faults', none, ...
        'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
    Dc = simulate_node(Sc);
    NM.(char(nz)) = g1_allan_fit(Dc.Y, Dc.S.B);
end

SC = g1_scenarios_test();
seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);
optV5 = struct('structure', "lag",     'gridErr', false, 'frozenFloor', false);
optL  = struct('structure', "leadlag", 'gridErr', false, 'frozenFloor', false);
r4 = @(x) round(double(x), 4);
b01 = @(x) double(x);

index = struct('id', {}, 'file', {}, 'label', {}, 'note', {});
for i = 1:numel(runs)
    sc = SC([SC.name] == runs(i).scenario);
    S = sc.S;  S.noise = runs(i).noise;
    D = simulate_node(seedS(S, runs(i).seed));
    R = g1_detect_v5(D, NM.(char(runs(i).noise)));
    A5 = g1_tsrc_v6(D, optV5);
    A6 = g1_tsrc_v6(D, optL);
    R6 = g1_detect_v6(D, NM.(char(runs(i).noise)));
    fprintf('%-16s %-7s seed %d: max |zT| difference v5 %.3g, v6 %.3g\n', ...
        runs(i).scenario, runs(i).noise, runs(i).seed, max(abs(R.zT - A5.zT)), max(abs(R6.zT - A6.zT)));
    ft = repmat("", 1, 9);
    for f = D.S.faults(:)', ft(f.ch) = f.type; end

    nT = D.S.B / D.S.dtT;
    amb = mean(reshape(D.truth.Tamb, nT, []), 1)';
    id = char(sprintf('%s_%s_%d', runs(i).scenario, runs(i).noise, runs(i).seed));

    J = struct();
    J.meta = struct('id', id, 'scenario', runs(i).scenario, 'tests', sc.tests, ...
        'note', runs(i).note, 'seed', runs(i).seed, 'noise', runs(i).noise, ...
        'B', D.S.B, 'warm', R.opt.warm, 'zU', R.opt.zU, 'h', R.opt.h, 'thrT', R.opt.thrT, ...
        'names', D.names, 'units', ["dps" "dps" "dps" "mg" "mg" "mg" "uT" "uT" "uT"]);
    J.t = r4(D.tB / h);
    J.T = struct('amb', r4(amb), 'icm', r4(D.TicmB), 'bme', r4(D.TbmeB));
    J.truth = struct('heater', b01(D.truth.heater), 'tempFault', b01(D.truth.tempFault), ...
        'emi', b01(D.truth.emi), 'fault', b01(D.truth.fault'), 'faultType', ft);
    J.v5 = struct('zI', r4(R.zI'), 'zB', r4(R.zB'), 'score', r4(R.score'), ...
        'flag', b01(R.sensorFlag'), 'released', b01(R.released'), ...
        'zT', r4(R.zT), 'tf', b01(R.tempFlag), 'blameBme', b01(R.blameBme), ...
        'blameIcm', b01(R.blameIcm), 'ambig', b01(R.tempAmbig), 'common', b01(R.common));
    J.v6 = struct('zI', r4(R6.zI'), 'zB', r4(R6.zB'), 'score', r4(R6.score'), ...
        'state', double(R6.state'), 'releaseType', double(R6.releaseType'), ...
        'r1', r4(R6.r1'), 'blameBme', b01(R6.blameBme), 'blameIcm', b01(R6.blameIcm), ...
        'ambig', b01(R6.tempAmbig), 'unrel', b01(R6.unrel));
    J.tsrc = struct( ...
        'v5', struct('zT', r4(A5.zT), 'eT', r4(A5.eT), 'sT', r4(A5.sT), 'b', r4(A5.b), ...
                     'tau', A5.tau, 'upd', b01(A5.upd), 'tf', b01(A5.tf)), ...
        'v6', struct('zT', r4(A6.zT), 'eT', r4(A6.eT), 'sT', r4(A6.sT), 'b', r4(A6.b), ...
                     'c', r4(A6.c), 'tau', A6.tau, 'upd', b01(A6.upd), 'tf', b01(A6.tf)));
    writeJson(fullfile(outDir, [id '.json']), J);
    index(end+1) = struct('id', id, 'file', [id '.json'], ...
        'label', sprintf('%s · %s · tohum %d', runs(i).scenario, runs(i).noise, runs(i).seed), ...
        'note', runs(i).note); %#ok<SAGROW>
end
writeJson(fullfile(outDir, 'index.json'), struct('runs', index));
fprintf('Wrote %d runs to %s\n', numel(runs), outDir);

function writeJson(file, x)
    fid = fopen(file, 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', jsonencode(x));
    fclose(fid);
end
