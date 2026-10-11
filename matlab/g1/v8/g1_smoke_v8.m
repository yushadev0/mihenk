%% g1_smoke_v8.m
% Quick check before the ~2-2.5 h g1_prototype_v8 run: the two equivalences
% (v8 with R off and floor frozen vs v6, v8 with R off vs v7 with D2 off)
% and that v8 runs on the runs R targets. Prints counts and the chosen
% hysteresis form only, no metrics. ~3-4 min.

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
SCd = g1_scenarios_v3();
SCt = g1_scenarios_test();

runs = {SCd, "hyst-relax", "white"; SCd, "hyst-relax", "colored"; SCt, "t9-relax-az", "white"; ...
        SCt, "t2-plateau-step", "white"; SCd, "base", "white"};
dif = @(A, B) max([nnz(A.state ~= B.state), max(abs(A.score - B.score), [], 'all'), max(abs(A.zT - B.zT))]);
for j = 1:size(runs, 1)
    SC = runs{j, 1};
    S = SC([SC.name] == runs{j, 2}).S;  S.noise = runs{j, 3};
    D = simulate_node(seedS(S, 0));
    nmz = NM.(char(runs{j, 3}));
    R6  = g1_detect_v6(D, nmz);
    E6  = g1_detect_v8(D, nmz, struct('floorMode', "frozen", 'tauHGrid', []));
    R7  = g1_detect_v7(D, nmz, struct('offsetLarge', false));
    E7  = g1_detect_v8(D, nmz, struct('tauHGrid', []));
    R8  = g1_detect_v8(D, nmz);
    th  = R8.tauHBest(R8.valid, 1);
    fprintf('%-16s %-7s equiv v6 %g, v7noD2 %g | fault blocks v6 %d, v8 %d | offset events v6 %d, v8 %d | ICM ref relaxation %.0f%% of blocks, last form %s\n', ...
        runs{j, 2}, runs{j, 3}, dif(R6, E6), dif(R7, E7), nnz(R6.state == 1), nnz(R8.state == 1), ...
        nnz(R6.state == 2), nnz(R8.state == 2), 100*mean(~isnan(th)), form(R8, numel(D.tB)));
end

function s = form(R, k)
    if isnan(R.tauHBest(k, 1)), s = sprintf('play w=%.1f', R.wBest(k, 1));
    else, s = sprintf('relax tau=%d s', R.tauHBest(k, 1)); end
end
