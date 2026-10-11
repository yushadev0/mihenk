%% g1_diag_v9.m
% Diagnosis after the v9 dev run (bulgular section 20, finding 20B): why the
% equivalence test (E) leaves some false alarms unreleased, and why it took
% the T10 slow drift for an offset event. Uses the diagnostic trace of
% g1_detect_v9 (opt.trace: residual, slope and se of every E evaluation, and
% the verdict the growth test would give on the same history).
%
% 0. The trace changes nothing (state and score identical with trace on/off),
%    and this script's false flags/h reproduce g1_v9_results.csv.
% A. The false-alarm tail of v9: dev base / white seed 9, dev base / colored
%    seed 8 (the same value in every dev scenario of that seed), spent
%    t6-emi-plateau / white seed 103, spent t1-fast-ramp / white seed 108;
%    control dev base / white seed 0. Per false-alarm episode of at least
%    Wrel blocks (where E is evaluated): channel, time, how it ended, heater
%    overlap, ICM temperature range, E statistics, residual against
%    temperature, when the growth test would have released it, and what
%    v9noE does on that channel.
% B. T10 slow drift / colored (gx, 0.015 dps/h, about 1.3 x colored dMin):
%    the seeds where v9 made an offset event on the faulty channel (read
%    from g1_v9_results.csv) and one seed without, slope and se at release.
%
% Reading rule (declared before the run):
%   H2 (dMin ignores the frozen model's prediction error) holds for an
%     episode if E fails through the slope itself (|slope| >= dMin in
%     >= 80 % of its evaluations), the residual follows the temperature
%     (R^2 >= 0.8 against the ICM temperature within the episode) and the
%     growth test would have released the channel inside the episode.
%   H3 (power / window, not the model) holds if E fails through the
%     uncertainty instead (|slope| < dMin but |slope| + tCrit*se >= dMin in
%     >= 80 % of the evaluations).
%   Otherwise the episode is "unexplained". H2 is taken as the mechanism of
%   20B if it holds for the longest episode of every tail run.
%   B: if at release |slope| < dMin although the true rate is 0.015, the
%     slope estimate fell below dMin through noise over the window: dMin is
%     too close to the smallest drift G1 must detect (K2b), a separate
%     problem from H2.
%
% Output: g1_diag_v9_output.txt. Runtime ~2-3 min.

clear; clc;
here = fileparts(mfilename('fullpath'));
g1   = fileparts(here);
addpath(g1, fullfile(g1, 'test'));
g1_setup();
h = 3600;
logFile = fullfile(here, 'g1_diag_v9_output.txt');
if isfile(logFile), delete(logFile); end
diary(logFile);

%% Characterization (identical to v3-v9)
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
CSV = readtable(fullfile(here, 'g1_v9_results.csv'), 'TextType', 'string');
tr  = struct('trace', true);
noE = struct('releaseTest', "growth");
pick = @(SC, name, nz, s) simulate_node(seedS(setfield(SC([SC.name] == name).S, 'noise', nz), s));

%% 0. Trace changes nothing
D = pick(SCd, "base", "white", 9);
Ra = g1_detect_v9(D, NM.white);  Rb = g1_detect_v9(D, NM.white, tr);
d0 = max(nnz(Ra.state ~= Rb.state), max(abs(Ra.score - Rb.score), [], 'all'));
fprintf('Trace on vs off: max difference %g %s\n\n', d0, string(ifelse(d0 == 0, '(OK)', '(MISMATCH)')));

%% A. False-alarm tail of v9
cases = {"dev", SCd, "base", "white", 9; "dev", SCd, "base", "colored", 8; ...
         "spent", SCt, "t6-emi-plateau", "white", 103; "spent", SCt, "t1-fast-ramp", "white", 108; ...
         "dev", SCd, "base", "white", 0};
fprintf('A. False-alarm episodes of v9 (>= %d blocks, longest 3 per run)\n', Ra.opt.Wrel);
for j = 1:size(cases, 1)
    [sn, SC, name, nz, s] = cases{j, :};
    D = pick(SC, name, nz, s);
    R9 = g1_detect_v9(D, NM.(char(nz)), tr);
    RE = g1_detect_v9(D, NM.(char(nz)), noE);
    valid = R9.valid & RE.valid & g1_detect_v0(D).valid;
    healthy = healthyMask(D, valid);
    hours = nnz(valid) * D.S.B / h;
    f9 = nnz(R9.state == 1 & healthy) / hours;  fE = nnz(RE.state == 1 & healthy) / hours;
    c9 = csvVal(CSV, sn, name, nz, s, "v9");   cE = csvVal(CSV, sn, name, nz, s, "v9noE");
    fprintf('\n[%s] %s / %s seed %d: false flags/h v9 %.1f (csv %.1f), v9noE %.1f (csv %.1f)\n', ...
        sn, name, nz, s, f9, c9, fE, cE);
    ep = episodes(R9.state == 1 & healthy);
    ep = ep(ep(:, 3) - ep(:, 2) + 1 >= R9.opt.Wrel, :);
    [~, o] = sort(ep(:, 3) - ep(:, 2), 'descend');
    ep = ep(o(1:min(3, end)), :);
    if isempty(ep), fprintf('  no episode of >= %d blocks\n', R9.opt.Wrel); end
    epE = episodes(RE.state == 1 & healthy);
    for i = 1:size(ep, 1)
        describe(D, R9, ep(i, :), epE, RE, i == 1);
    end
end

%% B. T10 slow drift / colored: offset events on the faulty channel
fprintf('\nB. t10-slow-drift / colored, gx drift 0.015 dps/h\n');
rows = CSV(CSV.scenario == "t10-slow-drift" & CSV.noise == "colored" & CSV.detector == "v9", :);
sB = [rows.seed(rows.offsetFault > 0); rows.seed(find(rows.offsetFault == 0, 1))]';
for s = sB
    D = pick(SCt, "t10-slow-drift", "colored", s);
    R9 = g1_detect_v9(D, NM.colored, tr);
    f = D.S.faults(1);  c = f.ch;
    toH = h / (D.tB(2) - D.tB(1));
    dm = R9.dMin(c);
    after = D.tB >= f.t0;
    ev = after & ~isnan(R9.eqBeta(:, c));
    fprintf('seed %d: dMin %.4f, true rate %.4f (%.2f x dMin); E evaluations after the fault %d, median slope / true %.2f\n', ...
        s, dm, f.mag, f.mag / dm, nnz(ev), median(R9.eqBeta(ev, c) * toH) / f.mag);
    kr = find(R9.releaseType(:, c) == 2 & after)';
    if isempty(kr)
        q = (abs(R9.eqBeta(ev, c)) + R9.opt.tCrit * R9.eqSe(ev, c)) * toH / dm;
        fprintf('   no offset event; best (|slope| + t*se) / dMin %.2f\n', min(q));
    end
    for k = kr
        nw = R9.eqNw(k, c);  w = k - nw + 1 : k;
        b = R9.eqBeta(k, c) * toH;  se = R9.eqSe(k, c) * toH;
        fprintf('   offset event at %.2f h: slope %.4f (%.2f x true, %.2f x dMin), t*se %.4f, window %d blocks, ICM T range %.2f degC%s\n', ...
            D.tB(k) / h, b, b / f.mag, abs(b) / dm, R9.opt.tCrit * se, nw, ...
            max(D.TicmB(w)) - min(D.TicmB(w)), string(ifelse(any(D.truth.heater(w)), ', heater in window', '')));
    end
end

diary off;

%% Helpers
function healthy = healthyMask(D, valid)
    healthy = ~D.truth.fault & valid;
    if any(D.truth.emi), healthy(D.truth.emi, 7:9) = false; end
end

function E = episodes(M)
% rows [channel, first block, last block] of every run of true in M
    E = zeros(0, 3);
    for c = 1:size(M, 2)
        d = diff([false; M(:, c); false]);
        s = find(d == 1);  e = find(d == -1) - 1;
        E = [E; repmat(c, numel(s), 1), s, e]; %#ok<AGROW>
    end
end

function s = endType(R, c, e)
    if e == size(R.state, 1), s = "run end"; return; end
    switch R.releaseType(e + 1, c)
        case 1, s = "event-end release";
        case 2, s = "offset event";
        otherwise, s = "CUSUM fell";
    end
end

function describe(D, R, ep, epE, RE, longest)
    h = 3600;  c = ep(1);  k = (ep(2):ep(3))';
    dtB = D.tB(2) - D.tB(1);  toH = h / dtB;  dm = R.dMin(c);
    T = D.TicmB(k);
    fprintf('  %s %.2f-%.2f h (%.0f min), ends: %s, heater in episode: %s, ICM T range %.2f degC\n', ...
        D.names(c), D.tB(k(1)) / h, D.tB(k(end)) / h, numel(k) * dtB / 60, endType(R, c, ep(3)), ...
        string(ifelse(any(D.truth.heater(k)), 'yes', 'no')), max(T) - min(T));
    ok = ~isnan(R.eqBeta(k, c));
    bA = abs(R.eqBeta(k(ok), c)) * toH / dm;
    sA = R.opt.tCrit * R.eqSe(k(ok), c) * toH / dm;
    fSlope = mean(bA >= 1);  fSe = mean(bA < 1 & bA + sA >= 1);
    fprintf('     E evaluations %d: |slope| >= dMin in %.0f%%, only via t*se in %.0f%%; median |slope|/dMin %.2f, median t*se/dMin %.2f, best (|slope|+t*se)/dMin %.2f\n', ...
        nnz(ok), 100*fSlope, 100*fSe, median(bA), median(sA), min(bA + sA));
    r2 = NaN;  g = NaN;
    if max(T) - min(T) >= 0.05
        e = R.eRaw(k, c);
        cc = corrcoef(e, T);  r2 = cc(1, 2)^2;
        p = polyfit(T, e, 1);  g = p(1);
    end
    fprintf('     residual vs ICM T in the episode: R^2 %.2f, slope %.3g %s/degC\n', r2, g, chUnit(c));
    kg = find(R.grRel(k, c), 1);
    if isempty(kg)
        fprintf('     growth test would release: never in the episode\n');
    else
        fprintf('     growth test would release: at %.2f h (%.0f min after the start)\n', ...
            D.tB(k(kg)) / h, kg * dtB / 60);
    end
    oE = epE(epE(:, 1) == c & epE(:, 3) >= ep(2) & epE(:, 2) <= ep(3), :);
    if isempty(oE)
        fprintf('     v9noE on %s: no flag in this interval\n', D.names(c));
    end
    for i = 1:size(oE, 1)
        fprintf('     v9noE on %s: %.2f-%.2f h (%.0f min), ends: %s\n', D.names(c), D.tB(oE(i, 2)) / h, ...
            D.tB(oE(i, 3)) / h, (oE(i, 3) - oE(i, 2) + 1) * dtB / 60, endType(RE, c, oE(i, 3)));
    end
    if fSlope >= 0.8 && r2 >= 0.8 && ~isempty(kg), v = "H2";
    elseif fSe >= 0.8, v = "H3";
    else, v = "unexplained"; end
    fprintf('     -> %s%s\n', v, string(ifelse(longest, ' (longest episode of the run)', '')));
end

function u = chUnit(c)
    U = ["dps" "dps" "dps" "mg" "mg" "mg" "uT" "uT" "uT"];
    u = U(c);
end

function v = csvVal(T, sn, name, nz, s, det)
    r = T.set == sn & T.scenario == name & T.noise == nz & T.seed == s & T.detector == det;
    v = T.falsePerH(r);
    if isempty(v), v = NaN; end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
