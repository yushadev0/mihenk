%% g1_smoke_v6.m
% Quick check before the ~2 h g1_prototype_v6 run: equivalence of v6 with
% every change off against v5 on one run, and that v6 runs on the three
% runs its changes target. Prints counts only, no metrics. ~2-3 min.

clear; clc;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;

none = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
for nz = ["white", "colored"]
    Sc = struct('noise', nz, 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
        'heaterOn', [], 'faults', none, ...
        'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
    Dc = simulate_node(Sc);
    NM.(char(nz)) = g1_allan_fit(Dc.Y, Dc.S.B);
end
seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);
SC = g1_scenarios_test();

runs = {"t2-plateau-step", "colored"; "t6-emi-plateau", "colored"; "t9-relax-az", "white"};
asV5 = struct('tsrc', "lag", 'eventEnd', false, 'offsetEvent', false, 'unreliable', false);
for j = 1:size(runs, 1)
    S = SC([SC.name] == runs{j, 1}).S;  S.noise = runs{j, 2};
    D = simulate_node(seedS(S, 100));
    nmz = NM.(char(runs{j, 2}));
    R5 = g1_detect_v5(D, nmz);
    E  = g1_detect_v6(D, nmz, asV5);
    R6 = g1_detect_v6(D, nmz);
    eq = max([nnz(R5.sensorFlag ~= E.sensorFlag), max(abs(R5.score - E.score), [], 'all'), ...
        max(abs(R5.zT - E.zT))]);
    fprintf('%-16s %-7s equivalence %g | v5 flag blocks %d | v6: fault %d, offset events %d, unreliable %d, event-end releases %d, T-src flags %d (v5 %d)\n', ...
        runs{j, 1}, runs{j, 2}, eq, nnz(R5.sensorFlag), nnz(R6.state == 1), nnz(R6.state == 2), ...
        nnz(R6.state == 3), nnz(R6.releaseType == 1), nnz(R6.tempFlag), nnz(R5.tempFlag));
end
