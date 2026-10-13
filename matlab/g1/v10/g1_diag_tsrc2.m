%% g1_diag_tsrc2.m
% Diagnosis of finding 21C (bulgular.md): in the second acceptance test the
% temperature-source check flagged blocks outside the heater window in 12
% of 100 scenarios (55-294 blocks per run), identically for v6 and v10 and
% for white and colored noise (K3b 19.1). Both detectors call the same
% model, g1_tsrc_v6.m (structure "leadlag", no grid term, no frozen floor),
% which reads temperatures only, so it is called here directly and only
% white noise is simulated.
%
% Hypotheses, declared before this script was run (bulgular section 22):
%   H1 heater trigger (14B analogue): a heater burst pushes |zT| past the
%      gate, the model stops updating and does not come back after the
%      truth heater window ends. Confirmed for a run if the same run
%      without heater (heaterOn = []) has no flag outside the BME fault,
%      AND a heater burst lies between the last update and the first
%      outside flag.
%   H2 second-order BME path (ADR-012 structure mismatch): the lead-lag
%      structure is exact only for a first-order BME path. Confirmed for a
%      run with bmeTau2 > 0 if the same run with bmeTau2 = 0 has no flag
%      outside the heater window and the BME fault.
%   H3 neither: flags remain without heater and with a first-order path.
%      Then the run is reported as unexplained, with the first flag's
%      context (profile phase, rate of change, update gap).
%   H1 and H2 can both hold for a run. A run where only the combined
%   counterfactual (no heater and bmeTau2 = 0) removes the flags is
%   reported as "H1+H2 jointly".
%
% Steps:
% 1. Replica check: for every scenario (seeds 200-299) the flags outside
%    the heater window and the BME fault, in the acceptance scoring window
%    (block > warm and v0 valid), must equal tSrcFlagsOutside of v10 /
%    white in g1/test2/g1_acceptance2_runs.csv. Per run: the same count
%    for the descriptive model variants noGate (zU = Inf: update always,
%    which also removes the cap on the lag-selection score),
%    frozenFloor and gridErr; the longest outside run, the first outside
%    flag, the update gap before it and whether a heater lies in it.
% 2. Counterfactuals for every run with outside flags: no heater,
%    bmeTau2 = 0 (only where it is > 0), both. Verdict per run by the rules
%    above.
% 3. Context table around the first outside flag and figure
%    g1_diag_tsrc2.png (temperatures and zT for every flagged run).
%
% Diagnosis only: the second held-out set is spent, nothing here changes
% the acceptance result. Console output: g1_diag_tsrc2_output.txt.
% Runtime: roughly 10-15 min (about 100 + 36 simulations, no detector).

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test2'));
figDir = g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_diag_tsrc2_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

SC = g1_scenarios_test2();
T  = readtable(fullfile(g1, 'test2', 'g1_acceptance2_runs.csv'), 'TextType', 'string');
T  = T(T.detector == "v10" & T.noise == "white", :);

% Options exactly as g1_detect_v6.m / g1_detect_v9.m pass them
base = struct('warm', 30, 'zU', 3, 'thrT', 5, 'lambda', 1 - 1/(24*60), ...
    'tauGrid', 0:20:300, 'sigmaTFloor', 0.02, 'gridErr', false, ...
    'frozenFloor', false, 'structure', "leadlag");
V = struct('name', {"model", "noGate", "frozenFloor", "gridErr"}, ...
    'opt', {base, setfield(base, 'zU', Inf), setfield(base, 'frozenFloor', true), ...
            setfield(base, 'gridErr', true)});

%% 1. Replica check and lock statistics
fprintf('1. Temperature-source flags outside the heater window and the BME fault (white)\n');
fprintf('   csv = acceptance test (v10), rep = replica (must match); noGate, frozenFl,\n');
fprintf('   gridErr = descriptive model variants; lock = longest outside run [blocks];\n');
fprintf('   first = first outside flag; gap = blocks without update before it;\n');
fprintf('   heat = a heater burst lies in that gap\n\n');
fprintf('%-16s %-14s %4s %-4s | %4s %4s %3s | %6s %8s %7s | %4s %6s %4s %4s\n', ...
    'scenario', 'hyst', 'tau2', 'prof', 'csv', 'rep', 'ok', 'noGate', 'frozenFl', 'gridErr', ...
    'lock', 'first', 'gap', 'heat');
nMismatch = 0;
keep = struct();
tic;
for i = 1:numel(SC)
    S = SC(i).S;  S.noise = "white";
    D = simulate_node(S);
    valid = scoreWindow(D, base);
    A = g1_tsrc_v6(D, base);
    st = lockStats(D, A, valid);
    nv = zeros(1, numel(V) - 1);
    for v = 2:numel(V)
        nv(v - 1) = lockStats(D, g1_tsrc_v6(D, V(v).opt), valid).outside;
    end
    csv = T.tSrcFlagsOutside(T.scenario == SC(i).name);
    ok = csv == st.outside;
    nMismatch = nMismatch + ~ok;
    if st.outside > 0 || ~ok
        fprintf('%-16s %-14s %4.0f %-4s | %4d %4d %3s | %6d %8d %7d | %4d %6s %4s %4s\n', ...
            SC(i).name, SC(i).hyst, SC(i).bmeTau2, profileName(S), csv, st.outside, ...
            string(ifelse(ok, 'ok', 'NO')), nv, st.longest, fmt(st.first, '%.2f'), ...
            fmt(st.gap, '%d'), fmt(st.heatInGap, '%d'));
        keep.(key(SC(i).name)) = struct('i', i, 'D', D, 'A', A, 'st', st);
    end
    if mod(i, 10) == 0, fprintf('  %3d / %d scenarios done (%.0f s)\n', i, numel(SC), toc); end
end
fprintf('\nReplica mismatches vs acceptance CSV: %d of %d runs\n', nMismatch, numel(SC));
flagged = fieldnames(keep);
fprintf('Runs with outside flags: %d\n', numel(flagged));

%% 2. Counterfactuals and verdict
fprintf('\n2. Counterfactuals: outside flags with heater removed / bmeTau2 = 0 / both\n');
fprintf('   (no heater: every block outside the BME fault counts)\n\n');
fprintf('%-16s %4s | %5s %7s %6s %5s | %s\n', 'scenario', 'tau2', 'model', 'noHeat', 'tau2=0', 'both', 'verdict');
verdicts = strings(numel(flagged), 1);
for j = 1:numel(flagged)
    k = keep.(flagged{j});
    S = SC(k.i).S;  S.noise = "white";
    nH = cf(setfield(S, 'heaterOn', zeros(0, 2)), base);
    n2 = NaN;  nB = NaN;
    if S.bmeTau2 > 0
        n2 = cf(setfield(S, 'bmeTau2', 0), base);
        nB = cf(setfield(setfield(S, 'bmeTau2', 0), 'heaterOn', zeros(0, 2)), base);
    end
    h1 = nH == 0 && isequal(k.st.heatInGap, true);
    h2 = n2 == 0;
    if h1 && h2,       vd = "H1 and H2";
    elseif h1,         vd = "H1";
    elseif h2,         vd = "H2";
    elseif nB == 0,    vd = "H1+H2 jointly";
    else,              vd = "H3 unexplained";
    end
    if nH == 0 && ~h1, vd = vd + " (no heater -> 0, but no heater in the gap)"; end
    verdicts(j) = vd;
    fprintf('%-16s %4.0f | %5d %7d %6s %5s | %s\n', SC(k.i).name, S.bmeTau2, k.st.outside, ...
        nH, fmt(n2, '%d'), fmt(nB, '%d'), vd);
end
fprintf('\nVerdict counts:\n');
[u, ~, ic] = unique(verdicts);
for j = 1:numel(u), fprintf('  %-60s %d\n', u(j), nnz(ic == j)); end

%% 3. Context around the first outside flag
fprintf('\n3. Context around the first outside flag (selected candidate)\n');
nF = numel(flagged);
f = figure('Position', [30 30 1600 230*ceil(nF/2)]);
tiledlayout(ceil(nF/2), 4, 'TileSpacing', 'compact');
for j = 1:nF
    k = keep.(flagged{j});
    D = k.D;  A = k.A;  st = k.st;  th = D.tB / h;
    dTdt = [0; diff(D.TicmB)] / (D.S.B / h);            % degC/h
    fprintf('\n%s (%s, tau2 %.0f s, %s): first outside flag %s h, last update before it %s h\n', ...
        SC(k.i).name, SC(k.i).hyst, SC(k.i).bmeTau2, profileName(SC(k.i).S), ...
        fmt(st.first, '%.2f'), fmt(D.tB(st.kLast) / h, '%.2f'));
    fprintf('  block    t[h]  T_icm   T_bme  dT/dt  heat  upd     eT     sT     zT  tau      b       c\n');
    for kk = unique([max(31, st.kLast-3):min(st.kLast+3, st.k0), st.k0:min(st.k0+5, numel(th))])
        fprintf('  %5d  %6.2f  %5.2f  %6.2f  %5.1f  %4d  %3d  %6.2f  %5.3f  %6.1f  %3d  %6.3f  %6.1f\n', ...
            kk, th(kk), D.TicmB(kk), D.TbmeB(kk), dTdt(kk), D.truth.heater(kk), A.upd(kk), ...
            A.eT(kk), A.sT(kk), A.zT(kk), A.tau(kk), A.b(kk), A.c(kk));
    end
    out = st.k0:numel(th);
    fprintf('  after the first outside flag: updates %d of %d blocks, |zT| max %.1f, sT %.3f-%.3f\n', ...
        nnz(A.upd(out)), numel(out), max(abs(A.zT(out))), min(A.sT(out)), max(A.sT(out)));

    nexttile;
    plot(th, D.TicmB, th, D.TbmeB);  hold on;  shadeHeater(th, D.truth.heater);
    xline(st.first, 'k--');  grid on;  ylabel('T [degC]');
    title(sprintf('%s, tau2 %.0f', SC(k.i).name, SC(k.i).bmeTau2), 'Interpreter', 'none');
    nexttile;
    plot(th, A.zT);  hold on;  shadeHeater(th, D.truth.heater);
    plot(th(~A.upd), zeros(nnz(~A.upd), 1), 'r.', 'MarkerSize', 4);
    yline([-5 -3 3 5], ':');  ylim([-30 30]);  grid on;  ylabel('zT');
    title(sprintf('zT (red: no update), %s', verdicts(j)), 'Interpreter', 'none');
end
exportgraphics(f, fullfile(figDir, 'g1_diag_tsrc2.png'), 'Resolution', 110);
diary('off');

%% Helpers
function valid = scoreWindow(D, o)
    % Acceptance scoring window: both detectors' valid (block > warm) and v0's
    R0 = g1_detect_v0(D);
    valid = (1:numel(D.tB))' > o.warm & R0.valid;
end

function n = cf(S, o)
    % Outside flags of a counterfactual run
    D = simulate_node(S);
    n = lockStats(D, g1_tsrc_v6(D, o), scoreWindow(D, o)).outside;
end

function st = lockStats(D, A, valid)
    % Flags outside the heater window as K3b counts them (g1_evaluate.m),
    % the longest run of them and the update gap before the first one
    out = A.tf & ~D.truth.heater & ~D.truth.tempFault & valid;
    st.outside = nnz(out);
    r = 0;  st.longest = 0;
    for k = 1:numel(out)
        r = (r + 1) * out(k);
        st.longest = max(st.longest, r);
    end
    st.k0 = find(out, 1);
    [st.first, st.gap, st.heatInGap, st.kLast] = deal(NaN);
    if ~isempty(st.k0)
        st.first = D.tB(st.k0) / 3600;
        st.kLast = find(A.upd(1:st.k0 - 1), 1, 'last');
        st.gap = st.k0 - st.kLast - 1;
        st.heatInGap = any(D.truth.heater(st.kLast:st.k0));
    end
end

function p = profileName(S)
    if numel(S.profileT) > 6, p = "sine";
    elseif numel(S.profileT) == 6, p = "trap";
    else, p = "flat";
    end
end

function s = key(name)
    s = matlab.lang.makeValidName(name);
end

function shadeHeater(th, heater)
    yl = ylim;
    on = find(diff([false; heater; false]) == 1);
    off = find(diff([false; heater; false]) == -1) - 1;
    for i = 1:numel(on)
        patch(th([on(i) off(i) off(i) on(i)]), yl([1 1 2 2]), [1 0.6 0.2], ...
            'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    ylim(yl);
end

function s = fmt(v, f)
    if isnan(v), s = "-"; else, s = string(sprintf(f, v)); end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
