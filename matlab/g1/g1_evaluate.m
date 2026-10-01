function M = g1_evaluate(D, R, flagField)
%G1_EVALUATE Score a G1 detector result R against the ground truth in D.
%   flagField selects the sensor-flag matrix (default "sensorFlag"; use
%   "baseFlag" for the no-thermal-model baseline).
%
%   Per injected fault (D.S.faults): delay [min] and coverage (share of
%   faulty blocks flagged). Fields delayMin / faultCoverage refer to the
%   first fault (as reported for v0 and v1). False flags are flags on a
%   channel that is not faulty at that block. Trap-specific counts are NaN
%   when the scenario has no such event.

if nargin < 3, flagField = "sensorFlag"; end
F      = R.(flagField);
valid  = R.valid;
fault  = D.truth.fault;
tB     = D.tB;
faults = D.S.faults;
nF     = numel(faults);

M.delayAll    = nan(1, nF);
M.coverageAll = nan(1, nF);
for i = 1:nF
    ch = faults(i).ch;
    k = find(F(:, ch) & tB >= faults(i).t0, 1);
    if ~isempty(k), M.delayAll(i) = (tB(k) - faults(i).t0) / 60; end
    inFault = fault(:, ch) & valid;
    M.coverageAll(i) = nnz(F(:, ch) & inFault) / nnz(inFault);
end
M.delayMin      = NaN;  M.faultCoverage = NaN;
if nF > 0
    M.delayMin      = M.delayAll(1);
    M.faultCoverage = M.coverageAll(1);
end

M.falseFlags  = sum(F & ~fault & valid, 1);                  % per channel
M.nValid      = nnz(valid);
M.firstValidH = tB(find(valid, 1)) / 3600;
M.falsePerH   = sum(M.falseFlags) / (M.nValid * D.S.B / 3600);
anyFault      = any(fault, 2);

hasT = isfield(R, 'tempFlag') && flagField == "sensorFlag";
[M.heaterSensorFlags, M.heaterBlocks, M.heaterTempFlags, M.heaterBlameBme, ...
    M.heaterBlameIcm, M.tempFlagsOutside] = deal(NaN);
heater = D.truth.heater;
if any(heater)
    M.heaterSensorFlags = nnz(any(F, 2) & heater & ~anyFault);
    if hasT
        M.heaterBlocks    = nnz(heater & valid);
        M.heaterTempFlags = nnz(R.tempFlag & heater);
        M.heaterBlameBme  = nnz(R.blameBme & heater);
        M.heaterBlameIcm  = nnz(R.blameIcm & heater);
    end
end
M.heaterAmbig = NaN;
if any(heater) && hasT && isfield(R, 'tempAmbig')
    M.heaterAmbig = nnz(R.tempAmbig & heater);
end
if hasT
    M.tempFlagsOutside = nnz(R.tempFlag & ~heater & ~D.truth.tempFault & valid);
end

% EMI: environmental, but only the magnetometer sees it (not common mode).
% emiMagFlags covers the event window only; emiAfterMagFlags the rest of
% the run after it (lock-in, finding 9E); emiCommon the share of event
% blocks taken as a common-mode event (the 9E mechanism).
[M.emiMagFlags, M.emiAfterMagFlags, M.emiCommon] = deal(NaN);
if any(D.truth.emi)
    ev = D.truth.emi & valid;
    M.emiMagFlags = nnz(any(F(:, 7:9), 2) & ev) / nnz(ev);
    after = tB >= D.S.emi.t1 & ~D.truth.emi & valid;
    M.emiAfterMagFlags = nnz(any(F(:, 7:9), 2) & after) / nnz(after);
    if hasT, M.emiCommon = nnz(R.common & ev) / nnz(ev); end
end

% The confounder sensor (BME688 temperature) itself fails
[M.tempFaultBlameBme, M.tempFaultSensorFlags, M.tempFaultBlameIcm, M.tempFaultAmbig] = deal(NaN);
tf = D.truth.tempFault & valid;
if any(tf) && hasT
    M.tempFaultBlameBme    = nnz(R.blameBme & tf) / nnz(tf);
    M.tempFaultSensorFlags = nnz(any(F & ~fault, 2) & tf) / nnz(tf);
    M.tempFaultBlameIcm    = nnz(R.blameIcm & tf) / nnz(tf);
    if isfield(R, 'tempAmbig'), M.tempFaultAmbig = nnz(R.tempAmbig & tf) / nnz(tf); end
end
end
