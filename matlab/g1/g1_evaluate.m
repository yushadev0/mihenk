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
if hasT
    M.tempFlagsOutside = nnz(R.tempFlag & ~heater & ~D.truth.tempFault & valid);
end

% EMI: environmental, but only the magnetometer sees it (not common mode)
M.emiMagFlags = NaN;
if any(D.truth.emi)
    M.emiMagFlags = nnz(any(F(:, 7:9), 2) & D.truth.emi & valid) / nnz(D.truth.emi & valid);
end

% The confounder sensor (BME688 temperature) itself fails
[M.tempFaultBlameBme, M.tempFaultSensorFlags] = deal(NaN);
tf = D.truth.tempFault & valid;
if any(tf) && hasT
    M.tempFaultBlameBme    = nnz(R.blameBme & tf) / nnz(tf);
    M.tempFaultSensorFlags = nnz(any(F & ~fault, 2) & tf) / nnz(tf);
end
end
