%% g1_smoke_v7.m
% Quick check before the ~1.5 h g1_prototype_v7 run: equivalence of v7 with
% D1 and D2 off against v6, and that v7 runs on the runs its changes
% target. Prints counts only, no metrics. ~2-3 min.

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

runs = {"t2-plateau-step", "white"; "t2-plateau-step", "colored"; "t6-emi-plateau", "colored"; "t9-relax-az", "white"};
asV6 = struct('floorMode', "frozen", 'offsetLarge', false);
for j = 1:size(runs, 1)
    S = SC([SC.name] == runs{j, 1}).S;  S.noise = runs{j, 2};
    D = simulate_node(seedS(S, 100));
    nmz = NM.(char(runs{j, 2}));
    R6 = g1_detect_v6(D, nmz);
    E  = g1_detect_v7(D, nmz, asV6);
    R7 = g1_detect_v7(D, nmz);
    eq = max([nnz(R6.state ~= E.state), max(abs(R6.score - E.score), [], 'all'), max(abs(R6.zT - E.zT))]);
    fprintf('%-16s %-7s equivalence %g | fault blocks v6 %d, v7 %d | offset events v6 %d, v7 %d | event-end releases v6 %d, v7 %d\n', ...
        runs{j, 1}, runs{j, 2}, eq, nnz(R6.state == 1), nnz(R7.state == 1), nnz(R6.state == 2), ...
        nnz(R7.state == 2), nnz(R6.releaseType == 1), nnz(R7.releaseType == 1));
    for f = D.S.faults(:)'
        c = f.ch;  th = D.tB / h;
        k6 = find(R6.releaseType(:, c) > 0, 1);  k7 = find(R7.releaseType(:, c) > 0, 1);
        fprintf('   fault %s (%s at %.1f h): first release v6 %s, v7 %s\n', D.names(c), f.type, f.t0 / h, ...
            rel(k6, R6, c, th), rel(k7, R7, c, th));
    end
end

function s = rel(k, R, c, th)
    if isempty(k), s = "none"; return; end
    t = ["", "event-end", "offset"];
    s = sprintf('%.2f h (%s)', th(k), t(R.releaseType(k, c) + 1));
end
