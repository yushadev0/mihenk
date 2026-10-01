%% g1_acceptance_test.m
% One-shot acceptance test of the G1 simulation stage (bulgular.md,
% section 11). Criteria, scenarios (g1_scenarios_test.m) and seeds were
% declared and committed before any v5 result was seen. Run once; a failed
% criterion is reported, not tuned away. Only bug fixes that do not change
% the detector's logic are allowed.
%
% Candidate: v5, unless the development run (g1_prototype_v5.m) selects a
% simpler ablation by the declared rule (section 11) - then set the
% candidate's options below to that ablation and say so in bulgular.
%
% Runtime: roughly 15-25 min.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(here, fileparts(here));                          % test/, g1/
figDir = g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_acceptance_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

candidate = struct('name', "v5", 'opt', struct());       % see header

%% Characterization (identical to development)
noises = ["white", "colored"];
none   = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
for nz = noises
    Sc = struct('noise', nz, 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
        'heaterOn', [], 'faults', none, ...
        'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
    Dc = simulate_node(Sc);
    NM.(char(nz)) = g1_allan_fit(Dc.Y, Dc.S.B);
end

%% Runs
SC    = g1_scenarios_test();
seeds = 100:119;
seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);
rows = {};
tic;
for i = 1:numel(SC)
    for nz = noises
        for s = seeds
            S = SC(i).S;  S.noise = nz;
            D = simulate_node(seedS(S, s));
            R = g1_detect_v5(D, NM.(char(nz)), candidate.opt);
            R.valid = R.valid & g1_detect_v0(D).valid;   % same scoring window as development
            M = g1_evaluate(D, R);

            % K1: false flags on fault-free channels, without the magnetometer
            % during an EMI event (out of scope, finding 8D)
            Ff = R.sensorFlag & ~D.truth.fault & R.valid;
            Ff(D.truth.emi, 7:9) = false;
            hours = nnz(R.valid) * D.S.B / h;
            onsets = sum(diff([false(1, 9); Ff]) == 1, 'all');

            delay = NaN;  cov = NaN;
            if ~isempty(M.delayAll), delay = max(M.delayAll); cov = mean(M.coverageAll); end
            rows(end+1, :) = {SC(i).name, SC(i).class, nz, s, nnz(Ff)/hours, onsets/hours, ...
                delay, cov, M.heaterSensorFlags, M.tempFlagsOutside, M.emiAfterMagFlags, ...
                M.tempFaultSensorFlags, M.tempFaultBlameIcm, M.tempFaultBlameBme + M.tempFaultAmbig}; %#ok<SAGROW>
        end
    end
    fprintf('%-16s done (%.0f s)\n', SC(i).name, toc);
end
T = cell2table(rows, 'VariableNames', {'scenario', 'class', 'noise', 'seed', 'falsePerH', ...
    'falseEpisodesPerH', 'delayMin', 'coverage', 'heaterSensorFlags', 'tSrcFlagsOutside', ...
    'emiAfterMagShare', 'bmeSensorShare', 'bmeIcmShare', 'bmeOrAmbigShare'});
T.scenario = string(T.scenario);  T.class = string(T.class);  T.noise = string(T.noise);
writetable(T, fullfile(here, 'g1_acceptance_results.csv'));

%% Criteria (declared in bulgular.md section 11 before any v5 result)
fprintf('\nCandidate: %s\n', candidate.name);
allPass = true;
for nz = noises
    fprintf('\n[%s]\n', nz);
    A  = T(T.noise == nz, :);
    F  = A(A.class == "fault", :);
    Sl = A(A.class == "slow", :);
    det = F.delayMin <= 120;                              % detected within 120 min
    C = {
        'K1a false flags/h, median <= 0.5',          median(A.falsePerH),            @(v) v <= 0.5
        'K1b false flags/h, every run <= 6',         max(A.falsePerH),               @(v) v <= 6
        'K1c false episodes/h, mean <= 0.12',        mean(A.falseEpisodesPerH),      @(v) v <= 0.12
        'K2a detected within 120 min, share >= 0.95', mean(det),                     @(v) v >= 0.95
        'K2b median delay [min] (w <= 15, c <= 40)', median(F.delayMin(det)),        @(v) v <= ifelse(nz == "white", 15, 40)
        'K2c mean coverage >= 0.80',                 mean(F.coverage, 'omitnan'),    @(v) v >= 0.80
        'K2d slow drift within 180 min, share >= 0.80', mean(Sl.delayMin <= 180),   @(v) v >= 0.80
        'K3a heater sensor flags/run, mean <= 1',    mean(A.heaterSensorFlags, 'omitnan'), @(v) v <= 1
        'K3b T-src flags outside/run, mean <= 1',    mean(A.tSrcFlagsOutside, 'omitnan'),  @(v) v <= 1
        'K3c EMI: mag flagged after event <= 0.10',  mean(A.emiAfterMagShare, 'omitnan'),  @(v) v <= 0.10
        'K3d BME fault: motion channel blamed <= 0.05', mean(A.bmeSensorShare, 'omitnan'), @(v) v <= 0.05
        'K3e BME fault: ICM blamed <= 0.05',         mean(A.bmeIcmShare, 'omitnan'),       @(v) v <= 0.05
        'K3f BME fault: BME or ambiguous >= 0.90',   mean(A.bmeOrAmbigShare, 'omitnan'),   @(v) v >= 0.90
        };
    for j = 1:size(C, 1)
        ok = C{j, 3}(C{j, 2});
        allPass = allPass && ok;
        fprintf('  %-48s %8.3f  %s\n', C{j, 1}, C{j, 2}, string(ifelse(ok, 'PASS', 'FAIL')));
    end
end
fprintf('\nOVERALL: %s\n', string(ifelse(allPass, 'PASS', 'FAIL')));

fprintf('\nPer scenario (median over seeds): false flags/h, delay [min]\n');
for i = 1:numel(SC)
    for nz = noises
        B = T(T.scenario == SC(i).name & T.noise == nz, :);
        fprintf('  %-16s %-8s %7.2f [max %6.2f]  %7.1f\n', SC(i).name, nz, median(B.falsePerH), ...
            max(B.falsePerH), median(B.delayMin, 'omitnan'));
    end
end
diary('off');

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
