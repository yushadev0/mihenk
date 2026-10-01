%% g1_smoke_v5.m
% Quick check (~1-2 min) before the long g1_prototype_v5.m run. Reports no
% evaluation metrics on purpose (acceptance criteria come first).
%   1. v5 with v4 options == v4, and v5 with floor "off" (A, C, D off) == v4nf
%   2. every v5 variant runs; the CUSUM never exceeds Smax; outputs exist
%   3. checkcode messages for the v5 files

clear; clc;
addpath(fileparts(fileparts(mfilename('fullpath'))));   % g1/
g1_setup();
h = 3600;
none = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
for nz = ["white", "colored"]
    Sc = struct('noise', nz, 'Tend', 12*h, 'profileT', [0 12*h], 'profileC', [25 25], ...
        'heaterOn', [], 'faults', none, 'unitSeed', 9007, 'icmSeed', 9011, 'magSeed', 9012, 'noiseSeed', 9013);
    Dc = simulate_node(Sc);
    NM.(char(nz)) = g1_allan_fit(Dc.Y, Dc.S.B);
end
SC = g1_scenarios_v3();
sd = @(S, s) setfield(setfield(setfield(setfield(S, 'unitSeed', 7 + 100*s), ...
    'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);
offAll = struct('Smax', Inf, 'release', false, 'resetOnSwitch', false);
variants = {struct(), struct('floorMode', "off"), struct('release', false), struct('resetOnSwitch', false)};

w = 0;
for i = [1, find([SC.name] == "emi"), find([SC.name] == "hyst-relax")]
    for nz = ["white", "colored"]
        S = SC(i).S;  S.noise = nz;
        D = simulate_node(sd(S, 0));
        nm = NM.(char(nz));
        R4   = g1_detect_v4(D, nm);
        R4nf = g1_detect_v4(D, nm, struct('modelHorizon', Inf));
        oA = offAll;  oA.floorMode = "always";  oB = offAll;  oB.floorMode = "off";
        R5a  = g1_detect_v5(D, nm, oA);
        R5b  = g1_detect_v5(D, nm, oB);
        w = max([w, nnz(R4.sensorFlag ~= R5a.sensorFlag), max(abs(R4.score - R5a.score), [], 'all'), ...
            nnz(R4nf.sensorFlag ~= R5b.sensorFlag), max(abs(R4nf.score - R5b.score), [], 'all')]);
        for v = 1:numel(variants)
            R = g1_detect_v5(D, nm, variants{v});
            assert(isequal(size(R.sensorFlag), size(D.Y)), 'flag size');
            assert(all(R.score(:) <= R.opt.Smax + 1e-12), 'score above Smax');
            assert(isfield(R, 'released') && isfield(R, 'switchReset'), 'outputs');
            M = g1_evaluate(D, R);
            assert(isfield(M, 'heaterAmbig'), 'evaluate fields');
        end
    end
end
fprintf('Equivalence (v4 and v4nf): max difference %g %s\n', w, ...
    string(ifelse(w == 0, '(OK)', '(MISMATCH)')));
fprintf('All v5 variants ran (3 scenarios x 2 noise types)\n');

here = fileparts(mfilename('fullpath'));
for f = ["g1_detect_v5.m", "g1_prototype_v5.m", "g1_smoke_v5.m"]
    m = checkcode(fullfile(here, f));
    fprintf('checkcode %s: %d message(s)\n', f, numel(m));
    for j = 1:numel(m), fprintf('  L%d: %s\n', m(j).line, m(j).message); end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
