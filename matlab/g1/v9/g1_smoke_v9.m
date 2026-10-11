%% g1_smoke_v9.m
% Quick check before the ~1.5-2 h g1_prototype_v9 run: equivalence of v9
% with C2 on and the growth test against v8, dMin per channel, and that v9
% runs on the runs its changes target. Prints counts only, no metrics.
% ~3-4 min.

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

runs = {SCd, "two-faults", "white"; SCd, "day-cycle", "colored"; SCt, "t2-plateau-step", "white"; ...
        SCt, "t9-relax-az", "colored"; SCd, "base", "white"};
dif = @(A, B) max([nnz(A.state ~= B.state), max(abs(A.score - B.score), [], 'all'), max(abs(A.zT - B.zT))]);
asV8 = struct('unreliable', true, 'releaseTest', "growth");
for j = 1:size(runs, 1)
    SC = runs{j, 1};
    S = SC([SC.name] == runs{j, 2}).S;  S.noise = runs{j, 3};
    D = simulate_node(seedS(S, 0));
    nmz = NM.(char(runs{j, 3}));
    R8 = g1_detect_v8(D, nmz);
    E8 = g1_detect_v9(D, nmz, asV8);
    R9 = g1_detect_v9(D, nmz);
    if j == 1 || j == 2
        fprintf('dMin [%s] per hour: %s\n', runs{j, 3}, strjoin(compose('%s %.3g', D.names', R9.dMin')', ', '));
    end
    fprintf('%-16s %-7s equiv v8 %g | fault blocks v8 %d, v9 %d | unreliable v8 %d, v9 %d | offset releases v8 %d, v9 %d\n', ...
        runs{j, 2}, runs{j, 3}, dif(R8, E8), nnz(R8.state == 1), nnz(R9.state == 1), nnz(R8.state == 3), ...
        nnz(R9.state == 3), nnz(R8.releaseType == 2), nnz(R9.releaseType == 2));
    for f = D.S.faults(:)'
        c = f.ch;  th = D.tB / h;
        k8 = find(R8.releaseType(:, c) == 2 & D.tB >= f.t0, 1);  k9 = find(R9.releaseType(:, c) == 2 & D.tB >= f.t0, 1);
        fprintf('   fault %s (%s at %.1f h): first offset release v8 %s, v9 %s\n', D.names(c), f.type, f.t0 / h, ...
            tstr(k8, th), tstr(k9, th));
    end
end

function s = tstr(k, th)
    if isempty(k), s = "none"; else, s = sprintf('%.2f h', th(k)); end
end
