%% g1_diag_tsrc_lock.m
% Diagnosis of finding 13D (bulgular.md): in the v5 acceptance test the
% temperature-source check flagged blocks outside the heater window only
% in T2 (~180 per run, every seed), T8 (~40, every seed) and T5 (~127,
% seeds 108 and 118 only), identically for white and colored noise.
%
% The temperature-source model of g1_detect_v5.m reads temperatures only
% (D.Ticm, D.TicmB, D.TbmeB), so it is replicated here as tsrcModel():
% same code, same order of operations, plus a switch for its update gate
% and a record of its internal state. No Allan fit and no motion channel
% is needed, and the noise type does not matter (only white is run).
%
% Hypothesis to test (13D): the model is updated only while |zT| < zU.
% Once the error leaves the gate (heater, or a model mismatch), the RLS
% stops, its covariance does not grow while frozen, sT stays constant and
% the error keeps growing with the ramp: a lock with no way back (the
% temperature-source analogue of 7C / 10F).
%
% 1. Replica check: for every scenario and seed 100-119 the replica's
%    flags outside the heater window must equal tSrcFlagsOutside in
%    g1/test/g1_acceptance_results.csv. Then per run: the same count with
%    the gate removed (update always), the longest locked stretch, how long
%    the model went without an update before the first outside flag, and
%    whether a heater burst lies in that stretch.
% 2. Without heater (heaterOn = []), seed 100 and the locking seed of T5:
%    are there outside flags at all?
% 3. Detail figure g1_diag_tsrc_lock.png for T2/100, T5/108 (locks),
%    T5/100 (does not), T8/100: temperatures, zT with and without gate,
%    error vs predicted std, slope b and lag of the selected candidate.
%
% Diagnosis only: the held-out set of section 13 is spent, nothing here
% is used to tune v5. Console output: g1_diag_tsrc_lock_output.txt.
% Runtime: roughly 10-15 min (simulation of 200 + 8 runs).

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
figDir = g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_diag_tsrc_lock_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

SC    = g1_scenarios_test();
seeds = 100:119;
seedS = @(S, s) setfield(setfield(setfield(setfield(S, ...
    'unitSeed', 7 + 100*s), 'icmSeed', 11 + 100*s), 'magSeed', 12 + 100*s), 'noiseSeed', 13 + 100*s);
T = readtable(fullfile(g1, 'test', 'g1_acceptance_results.csv'), 'TextType', 'string');
o = tsrcOptions();

%% 1. Replica check and lock statistics, all scenarios, white
fprintf('1. Temperature-source flags outside the heater window, per run (white)\n');
fprintf('   csv = acceptance test, rep = replica (must match), noGate = update always\n');
fprintf('   lock = longest outside run [blocks], gap = blocks without update before the\n');
fprintf('   first outside flag, heat = a heater burst lies in that gap\n\n');
fprintf('%-16s %4s | %4s %4s %3s | %6s | %5s %8s %5s %4s | %6s %6s\n', 'scenario', 'seed', ...
    'csv', 'rep', 'ok', 'noGate', 'lock', 'first[h]', 'gap', 'heat', 'offIcm', 'offBme');
nMismatch = 0;
keep = struct();
tic;
for i = 1:numel(SC)
    for s = seeds
        S = SC(i).S;  S.noise = "white";
        D = simulate_node(seedS(S, s));
        A = tsrcModel(D, o, true);
        B = tsrcModel(D, o, false);
        st = lockStats(D, A, o);
        csv = T.tSrcFlagsOutside(T.scenario == SC(i).name & T.noise == "white" & T.seed == s);
        ok = csv == st.outside;
        nMismatch = nMismatch + ~ok;
        stB = lockStats(D, B, o);
        fprintf('%-16s %4d | %4d %4d %3s | %6d | %5d %8s %5s %4s | %6.2f %6.2f\n', SC(i).name, s, ...
            csv, st.outside, string(ifelse(ok, 'ok', 'NO')), stB.outside, st.longest, ...
            fmt(st.first, '%.2f'), fmt(st.gap, '%d'), fmt(st.heatInGap, '%d'), ...
            D.truth.unit.offIcm, D.truth.unit.offBme);
        key = sprintf('%s_%d', strrep(SC(i).name, '-', '_'), s);
        keep.(key) = struct('D', D, 'A', A, 'B', B, 'st', st);
    end
    fprintf('%-16s done (%.0f s)\n', SC(i).name, toc);
end
fprintf('\nReplica mismatches vs acceptance CSV: %d of %d runs\n', nMismatch, numel(SC)*numel(seeds));

%% 2. Same runs without the heater
fprintf('\n2. Without heater (heaterOn = []): flags over the whole scored run\n');
fprintf('%-16s %4s | %8s %8s\n', 'scenario', 'seed', 'with', 'without');
noHeat = {"t2-plateau-step", 100; "t5-two-heaters", 100; "t5-two-heaters", 108; ...
    "t5-two-heaters", 118; "t7-bme-step", 100; "t8-cycle-clean", 100};
for j = 1:size(noHeat, 1)
    i = find([SC.name] == noHeat{j, 1});
    S = SC(i).S;  S.noise = "white";  S.heaterOn = [];
    D0 = simulate_node(seedS(S, noHeat{j, 2}));
    A0 = tsrcModel(D0, o, true);
    key = sprintf('%s_%d', strrep(noHeat{j, 1}, '-', '_'), noHeat{j, 2});
    fprintf('%-16s %4d | %8d %8d\n', noHeat{j, 1}, noHeat{j, 2}, ...
        nnz(keep.(key).A.tf), nnz(A0.tf));
end

%% T7 masks its flags after the BME fault starts: show them separately
fprintf('\nT7 (BME step at 4.5 h, excluded from K3b after that): flags before / after the fault\n');
for s = seeds
    k = keep.(sprintf('t7_bme_step_%d', s));
    pre = k.D.tB < k.D.S.bmeFault.t0;
    fprintf('  seed %d: outside heater before fault %d, after fault %d\n', s, ...
        nnz(k.A.tf & ~k.D.truth.heater & pre), nnz(k.A.tf & ~pre));
end

%% 3. Detail cases
cases = {"t2-plateau-step", 100; "t5-two-heaters", 108; "t5-two-heaters", 100; "t8-cycle-clean", 100};
f = figure('Position', [40 40 1500 280*size(cases, 1)]);
tiledlayout(size(cases, 1), 4);
for j = 1:size(cases, 1)
    k  = keep.(sprintf('%s_%d', strrep(cases{j, 1}, '-', '_'), cases{j, 2}));
    D  = k.D;  A = k.A;  B = k.B;  st = k.st;
    th = D.tB / h;
    fprintf('\n%s seed %d: first outside flag %s h, gap %s blocks\n', cases{j, 1}, cases{j, 2}, ...
        fmt(st.first, '%.2f'), fmt(st.gap, '%d'));
    if ~isnan(st.first)
        k0 = st.k0;
        fprintf('  block    t[h]  T_icm   T_bme  heat  upd     eT     sT     zT  tau     b    sd(b)\n');
        for kk = unique([max(o.warm+1, st.kLast-3):min(st.kLast+3, k0), k0:min(k0+5, numel(th))])
            fprintf('  %5d  %6.2f  %5.2f  %6.2f  %4d  %3d  %6.2f  %5.3f  %6.1f  %3d  %5.3f  %6.4f\n', ...
                kk, th(kk), D.TicmB(kk), D.TbmeB(kk), D.truth.heater(kk), A.upd(kk), A.eT(kk), ...
                A.sT(kk), A.zT(kk), A.tau(kk), A.b(kk), A.bsd(kk));
        end
        out = k0:numel(th);
        fprintf('  after the first outside flag: updates %d of %d blocks, sT range %.3f-%.3f\n', ...
            nnz(A.upd(out)), numel(out), min(A.sT(out)), max(A.sT(out)));
    end

    nexttile;
    plot(th, D.TicmB, th, D.TbmeB);  hold on;  shadeHeater(th, D.truth.heater);
    if ~isnan(st.first), xline(st.first, 'k--'); end
    grid on;  xlabel('t [h]');  ylabel('T [degC]');  legend('ICM', 'BME', 'Location', 'best');
    title(sprintf('%s seed %d', cases{j, 1}, cases{j, 2}), 'Interpreter', 'none');

    nexttile;
    plot(th, A.zT, th, B.zT);  hold on;  shadeHeater(th, D.truth.heater);
    yline([-o.thrT -o.zU o.zU o.thrT], ':');  ylim([-30 30]);
    grid on;  xlabel('t [h]');  ylabel('zT');  legend('v5 (gated)', 'no gate', 'Location', 'best');
    title('temperature-source z');

    nexttile;
    plot(th, A.eT);  hold on;
    plot(th, [A.sT, -A.sT], 'Color', [0.5 0.5 0.5]);
    plot(th(~A.upd), zeros(nnz(~A.upd), 1), 'r.', 'MarkerSize', 4);
    grid on;  xlabel('t [h]');  ylabel('[degC]');
    title('error eT, +-sT (red: no update)');

    nexttile;
    yyaxis left;  plot(th, A.b, th, B.b);  ylabel('slope b');
    yyaxis right; plot(th, A.tau, '.', 'MarkerSize', 4);  ylabel('lag [s]');
    grid on;  xlabel('t [h]');  title('selected candidate: b (v5, no gate), lag');
end
exportgraphics(f, fullfile(figDir, 'g1_diag_tsrc_lock.png'), 'Resolution', 120);
diary('off');

%% Helpers
function o = tsrcOptions()
    % The fields of g1_detect_v5.m's options that its temperature-source
    % model reads, with the same defaults
    o = struct('warm', 30, 'zU', 3, 'thrT', 5, 'lambda', 1 - 1/(24*60), ...
        'tauGrid', 0:20:300, 'sigmaTFloor', 0.02);
end

function A = tsrcModel(D, o, gated)
    % Temperature-source model of g1_detect_v5.m, line for line; gated =
    % false updates on every block. Also records the selected candidate's
    % error, predicted std, slope and slope std, and whether it updated.
    nB = numel(D.TbmeB);
    nJ = numel(o.tauGrid);
    LB = zeros(nB, nJ);
    for j = 1:nJ
        L = lagFilter(D.Ticm, o.tauGrid(j), D.S.dtT);
        LB(:, j) = mean(reshape(L, D.S.B/D.S.dtT, nB), 1)';
    end
    L0    = LB(1, :);
    thT   = repmat([D.TbmeB(1); 1], 1, nJ);
    PT    = repmat(diag([25, 0.1^2]), 1, 1, nJ);
    sigT0 = max(std(diff(D.TbmeB(1:o.warm) - D.TicmB(1:o.warm))) / sqrt(2), o.sigmaTFloor);
    sig2T = repmat(sigT0^2, 1, nJ);
    sseT  = zeros(1, nJ);

    [A.zT, A.eT, A.sT, A.b, A.bsd, A.tau] = deal(nan(nB, 1));
    [A.tf, A.upd] = deal(false(nB, 1));
    for k = 1:nB
        decide = k > o.warm;
        eT = zeros(1, nJ);  sT = eT;
        for j = 1:nJ
            x = [1; LB(k, j) - L0(j)];
            eT(j) = D.TbmeB(k) - x' * thT(:, j);
            sT(j) = sqrt(sig2T(j) + x' * PT(:, :, j) * x);
        end
        [~, jb] = min(sseT);
        zT = eT(jb) / sT(jb);
        A.zT(k) = zT;  A.eT(k) = eT(jb);  A.sT(k) = sT(jb);
        A.b(k) = thT(2, jb);  A.bsd(k) = sqrt(PT(2, 2, jb));  A.tau(k) = o.tauGrid(jb);
        A.tf(k) = decide && abs(zT) > o.thrT;
        if ~decide || abs(zT) < o.zU || ~gated
            for j = 1:nJ
                x = [1; LB(k, j) - L0(j)];
                [thT(:, j), PT(:, :, j)] = rlsUpdate(thT(:, j), PT(:, :, j), x, ...
                    D.TbmeB(k), sig2T(j), o.lambda);
            end
            sseT = o.lambda * sseT + min((eT ./ sT).^2, o.zU^2);
            A.upd(k) = true;
        end
    end
end

function st = lockStats(D, A, o)
    % Flags outside the heater window as K3b counts them (g1_evaluate.m),
    % the longest run of them, and the update gap before the first one
    valid = (1:numel(D.tB))' > o.warm;
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
        kLast = find(A.upd(1:st.k0 - 1), 1, 'last');
        st.kLast = kLast;
        st.gap = st.k0 - kLast - 1;
        st.heatInGap = any(D.truth.heater(kLast:st.k0));
    end
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

function [th, P] = rlsUpdate(th, P, x, y, s2, lambda)
    Px = P * x;
    K  = Px / (x' * Px + s2);
    th = th + K * (y - x' * th);
    P  = (P - K * Px') / lambda;
    P  = (P + P') / 2;
end

function L = lagFilter(x, tau, dt)
    L = x;
    if tau == 0, return; end
    a = 1 - exp(-dt / tau);
    for k = 2:numel(x)
        L(k) = L(k-1) + a * (x(k-1) - L(k-1));
    end
end

function s = fmt(v, f)
    if isnan(v), s = "-"; else, s = string(sprintf(f, v)); end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
