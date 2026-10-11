%% g1_diag_v8.m
% Diagnosis after the v8 dev run (bulgular section 19). Two parts.
%
% A. Mechanism of the coverage loss (19B). Scenarios two-faults (white,
%    colored), day-cycle / colored (dev, seeds 0-9) and t9-relax-az /
%    colored (spent, seeds 100-109); detectors v6, v8noR, v8noD1, v8. Per
%    faulty channel: coverage, first detection, releases by type
%    (1 event-end, 2 growth test = offset event), blocks lost after the
%    first growth-test release, and whether that release came on a ramp
%    (|T_icm change over the previous 30 blocks| > 1 degC).
%    H1 (declared before the run): in two-faults / white, v8 releases a
%    faulty channel by the growth test on a ramp in >= 9 of 10 seeds, v6
%    and v8noD1 in <= 1, and the blocks lost after that release account
%    for most of the coverage gap.
%    Check: run coverage recomputed here must equal g1_v8_results.csv for
%    v6 and v8 (also confirms that the new simulate_node field hystWidth
%    leaves the default path unchanged).
%    Event log: two-faults / white, seed 0, v8 and v8noD1.
%
% B. Generalization (19D). Fresh seeds 300-309 (diagnostic only; the next
%    held-out set must not use them), parameters off the detector grids:
%      relax90, relax600   relaxation hysteresis tau 90 s and 600 s
%                          (tau grid 60 120 240 480 960)
%      play0.6, play1.6    play width 0.6 and 1.6 degC
%                          (width grid 0.2 0.5 1 1.5 2)
%      two-faults, day-cycle   dev scenarios, new seeds
%    All with the default gz drift unless the scenario defines faults;
%    white and colored; detectors v6, v8noD1, v8.
%    Reading (declared before the run): R generalizes off-grid if v8's
%    advantage over v6 in worst false flags/h and false episodes/h on the
%    relaxation cells persists at tau 90 and 600 s, and if v8 is not worse
%    than v6 on the play cells. The dev differences replicate if the
%    two-faults and day-cycle gaps of 19B reappear on seeds 300-309.
%    This part cannot test a third, unmodelled hysteresis form; only the
%    next held-out set can (19D).
%
% Output: g1_diag_v8_output.txt. Runtime ~25-35 min.

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_diag_v8_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

%% Characterization (identical to v3-v8)
noises = ["white", "colored"];
none   = struct('ch', {}, 't0', {}, 'type', {}, 'mag', {});
NM     = struct();
for nz = noises
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

% Default path of simulate_node with the new field set explicitly
D1a = simulate_node();  D1b = simulate_node(struct('hystWidth', 1.0));
fprintf('simulate_node default vs hystWidth = 1.0: max |dY| %.3g, max |dT| %.3g\n\n', ...
    max(abs(D1a.Y - D1b.Y), [], 'all'), max(abs(D1a.TicmB - D1b.TicmB)));

dets = ["v6", "v8noR", "v8noD1", "v8"];
opts = {[], struct('tauHGrid', []), struct('floorMode', "frozen"), struct()};
runDet = @(d, D, nmz) ifelse(d == 1, @() g1_detect_v6(D, nmz), @() g1_detect_v8(D, nmz, opts{d}));

%% A. Mechanism
fprintf('=== A. Mechanism of the coverage loss ===\n');
CSV = readtable(fullfile(here, 'g1_v8_results.csv'), 'TextType', 'string');
cells = {SCd, "two-faults", "white", 0:9, "dev"; SCd, "two-faults", "colored", 0:9, "dev"; ...
         SCd, "day-cycle", "colored", 0:9, "dev"; SCt, "t9-relax-az", "colored", 100:109, "spent"};
csvWorst = 0;
for j = 1:size(cells, 1)
    SC = cells{j, 1};  sc = SC([SC.name] == cells{j, 2});  nz = cells{j, 3};
    seeds = cells{j, 4};  nmz = NM.(char(nz));
    if isfield(sc.S, 'faults'), F = sc.S.faults;     % simulate_node default otherwise
    else, F = struct('ch', 3, 't0', 4.5*h, 'type', "drift", 'mag', 0.03); end
    nF = numel(F);
    A = struct('cov', nan(numel(seeds), nF, 4), 'delay', nan(numel(seeds), nF, 4), ...
        'nRel1', zeros(numel(seeds), nF, 4), 'nRel2', zeros(numel(seeds), nF, 4), ...
        'lost', zeros(numel(seeds), nF, 4), 'ramp', nan(numel(seeds), nF, 4), 'runCov', nan(numel(seeds), 4));
    for is = 1:numel(seeds)
        S = sc.S;  S.noise = nz;
        D = simulate_node(seedS(S, seeds(is)));
        R = cell(1, 4);
        for d = 1:4, f = runDet(d, D, nmz); R{d} = f(); end
        valid = g1_detect_v0(D).valid;
        for d = 1:4, valid = valid & R{d}.valid; end
        for d = 1:4
            st = R{d}.state;  rt = R{d}.releaseType;
            for i = 1:nF
                c = F(i).ch;  after = D.tB >= F(i).t0;  inF = D.truth.fault(:, c) & valid;
                rep = st(:, c) == 1;
                if F(i).type == "step"
                    ko = find(st(:, c) == 2 & after, 1);
                    if ~isempty(ko), rep(ko:end) = true; end
                end
                A.cov(is, i, d) = nnz(rep & inF) / nnz(inF);
                k1 = find(st(:, c) == 1 & after, 1);
                if ~isempty(k1), A.delay(is, i, d) = (D.tB(k1) - F(i).t0) / 60; end
                A.nRel1(is, i, d) = nnz(rt(:, c) == 1 & after);
                A.nRel2(is, i, d) = nnz(rt(:, c) == 2 & after);
                k2 = find(rt(:, c) == 2 & after, 1);
                if ~isempty(k2)
                    A.lost(is, i, d) = nnz(~rep(k2:end) & inF(k2:end)) / nnz(inF);
                    k0 = max(1, k2 - 30);
                    A.ramp(is, i, d) = abs(D.TicmB(k2) - D.TicmB(k0)) > 1;
                end
            end
            A.runCov(is, d) = mean(A.cov(is, :, d));
            if d == 1 || d == 4                     % check against the dev-run CSV
                kk = CSV.set == cells{j, 5} & CSV.scenario == cells{j, 2} & CSV.noise == nz & ...
                    CSV.seed == seeds(is) & CSV.detector == dets(d);
                csvWorst = max(csvWorst, abs(CSV.coverage(kk) - A.runCov(is, d)));
            end
        end
        if j == 1 && seeds(is) == 0
            eventLog(D, R{4}, F, "v8");  eventLog(D, R{3}, F, "v8noD1");
        end
    end
    fprintf('\n[%s] %s / %s, seeds %d-%d\n', cells{j, 5}, cells{j, 2}, nz, seeds(1), seeds(end));
    fprintf('%-8s %-4s %8s %8s %8s %12s %10s %8s %10s\n', 'det', 'ch', 'cov', 'delay', 'rel1', 'seeds rel2', 'rel2/run', 'lost', 'on ramp');
    for d = 1:4
        for i = 1:nF
            r2 = A.nRel2(:, i, d);  rp = A.ramp(:, i, d);
            fprintf('%-8s %-4s %7.0f%% %8.1f %8.1f %9d/%d %10.1f %7.0f%% %10s\n', dets(d), D.names(F(i).ch), ...
                100*mean(A.cov(:, i, d)), median(A.delay(:, i, d), 'omitnan'), mean(A.nRel1(:, i, d)), ...
                nnz(r2 > 0), numel(seeds), mean(r2), 100*mean(A.lost(:, i, d)), rampStr(rp));
        end
        fprintf('%-8s run coverage %.0f%%\n', dets(d), 100*mean(A.runCov(:, d)));
    end
end
fprintf('\nCheck: run coverage vs g1_v8_results.csv (v6, v8): max |difference| %.2g %s\n', csvWorst, ...
    string(ifelse(csvWorst < 1e-9, '(OK)', '(MISMATCH)')));

%% B. Generalization
fprintf('\n=== B. Generalization: off-grid parameters, fresh seeds 300-309 ===\n');
gen = { "relax90",  struct('hystType', "relax", 'hystTau', 90); ...
        "relax600", struct('hystType', "relax", 'hystTau', 600); ...
        "play0.6",  struct('hystWidth', 0.6); ...
        "play1.6",  struct('hystWidth', 1.6); ...
        "two-faults", SCd([SCd.name] == "two-faults").S; ...
        "day-cycle",  SCd([SCd.name] == "day-cycle").S};
gd = [1 3 4];                                       % v6, v8noD1, v8
seedsB = 300:309;
for j = 1:size(gen, 1)
    for nz = noises
        M = nan(numel(seedsB), 7, numel(gd));
        for is = 1:numel(seedsB)
            S = gen{j, 2};  S.noise = nz;
            D = simulate_node(seedS(S, seedsB(is)));
            R = cell(1, numel(gd));
            for q = 1:numel(gd), f = runDet(gd(q), D, NM.(char(nz))); R{q} = f(); end
            valid = g1_detect_v0(D).valid;
            for q = 1:numel(gd), valid = valid & R{q}.valid; end
            for q = 1:numel(gd)
                Rc = R{q};  Rc.valid = valid;
                N = newMetrics(D, Rc, valid);
                rs = NaN;
                if isfield(Rc, 'tauHBest'), rs = mean(~isnan(Rc.tauHBest(valid, 1))); end
                M(is, :, q) = [N.falsePerH, N.episodesPerH, N.coverage, N.detected, N.delay, rs, N.offsetHealthy];
            end
        end
        fprintf('\n%s / %s\n%-28s', gen{j, 1}, nz, '');
        fprintf('%10s', dets(gd));  fprintf('\n');
        rows = {'false flags/h (worst)', @(x) max(x(:, 1)), '%10.1f'; ...
                'false flags/h (median)', @(x) median(x(:, 1)), '%10.1f'; ...
                'false episodes/h (mean)', @(x) mean(x(:, 2)), '%10.2f'; ...
                'coverage (mean)', @(x) 100*mean(x(:, 3), 'omitnan'), '%9.0f%%'; ...
                'detected (mean)', @(x) 100*mean(x(:, 4), 'omitnan'), '%9.0f%%'; ...
                'delay [min] (median)', @(x) median(x(:, 5), 'omitnan'), '%10.1f'; ...
                'relaxation form (mean)', @(x) 100*mean(x(:, 6)), '%9.0f%%'; ...
                'offset events, healthy', @(x) mean(x(:, 7)), '%10.1f'};
        for m = 1:size(rows, 1)
            fprintf('%-28s', rows{m, 1});
            for q = 1:numel(gd)
                v = rows{m, 2}(M(:, :, q));
                if isnan(v), fprintf('%10s', '-'); else, fprintf(rows{m, 3}, v); end
            end
            fprintf('\n');
        end
    end
end
diary('off');

%% Helpers
function eventLog(D, R, F, name)
    fprintf('\nEvent log, two-faults / white, seed 0, %s\n', name);
    for i = 1:numel(F)
        c = F(i).ch;  st = R.state(:, c);  rt = R.releaseType(:, c);
        fprintf('  %s (fault from %.2f h):', D.names(c), F(i).t0 / 3600);
        on = find(diff([0; st == 1]) == 1);
        ev = sortrows([on, ones(numel(on), 1); find(rt > 0), 1 + double(rt(rt > 0))]);
        lbl = ["flag", "event-end release", "growth release (offset)"];
        for e = 1:size(ev, 1)
            k = ev(e, 1);
            fprintf(' %.2f h %s (zI %.1f, T %.1f)', D.tB(k) / 3600, lbl(ev(e, 2)), R.zI(k, c), D.TicmB(k));
            if e < size(ev, 1), fprintf(';'); end
        end
        fprintf('\n');
    end
end

function s = rampStr(rp)
    rp = rp(~isnan(rp));
    if isempty(rp), s = "-"; else, s = sprintf('%.0f%%', 100*mean(rp)); end
end

function N = newMetrics(D, R, valid)
    st = R.state;  fault = D.truth.fault;  tB = D.tB;
    flag = st == 1;  ofs = st == 2;
    healthy = ~fault & valid;
    if any(D.truth.emi), healthy(D.truth.emi, 7:9) = false; end
    hours = nnz(valid) * D.S.B / 3600;
    N.falsePerH = nnz(flag & healthy) / hours;
    onsets = diff([false(1, size(flag, 2)); flag & healthy]) == 1;
    N.episodesPerH = (nnz(onsets) + nnz(ofs & healthy)) / hours;
    N.offsetHealthy = nnz(ofs & healthy);
    [N.detected, N.delay, N.coverage] = deal(NaN);
    F = D.S.faults;
    if isempty(F), return; end
    det = zeros(1, numel(F));  dl = nan(1, numel(F));  cv = dl;
    for i = 1:numel(F)
        c = F(i).ch;  after = tB >= F(i).t0;
        k = find(flag(:, c) & after, 1);
        if ~isempty(k), det(i) = 1; dl(i) = (tB(k) - F(i).t0) / 60; end
        rep = flag(:, c);
        if F(i).type == "step"
            ko = find(ofs(:, c) & after, 1);
            if ~isempty(ko), rep(ko:end) = true; end
        end
        inFc = fault(:, c) & valid;
        cv(i) = nnz(rep & inFc) / nnz(inFc);
    end
    N.detected = mean(det);  N.delay = max(dl);  N.coverage = mean(cv);
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
