%% g1_smoke_test.m
% Checks that every held-out scenario can be simulated and that the test
% files are clean, WITHOUT running any detector (the acceptance test is
% one-shot; this must not reveal results). ~1 min.

clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(here, fileparts(here));
g1_setup();
SC = g1_scenarios_test();
for i = 1:numel(SC)
    S = SC(i).S;  S.noise = "colored";
    D = simulate_node(S);
    assert(size(D.Y, 2) == 9 && all(isfinite(D.Y(:))), 'Y');
    assert(any(D.truth.heater), 'heater truth');
    nf = numel(D.S.faults);
    fprintf('%-16s %-6s blocks %d, faults %d, heater blocks %d, emi blocks %d, BME fault blocks %d\n', ...
        SC(i).name, SC(i).class, size(D.Y, 1), nf, nnz(D.truth.heater), nnz(D.truth.emi), ...
        nnz(D.truth.tempFault));
end
for f = ["g1_scenarios_test.m", "g1_acceptance_test.m", "g1_smoke_test.m"]
    m = checkcode(fullfile(here, f));
    fprintf('checkcode %s: %d message(s)\n', f, numel(m));
    for j = 1:numel(m), fprintf('  L%d: %s\n', m(j).line, m(j).message); end
end
