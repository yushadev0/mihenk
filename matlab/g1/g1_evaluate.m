function M = g1_evaluate(D, R, flagField)
%G1_EVALUATE Score a G1 detector result R against the ground truth in D.
%   flagField selects the sensor-flag matrix (default "sensorFlag"; use
%   "baseFlag" for the no-thermal-model baseline).

if nargin < 3, flagField = "sensorFlag"; end
F      = R.(flagField);
valid  = R.valid;
fault  = D.truth.fault;
heater = D.truth.heater;
tB     = D.tB;
fc     = D.S.faultCh;
t0     = D.S.faultT0;

k = find(F(:, fc) & tB >= t0, 1);
if isempty(k)
    M.delayMin = NaN;
else
    M.delayMin = (tB(k) - t0) / 60;
end
inFault         = fault(:, fc) & valid;
M.faultCoverage = nnz(F(:, fc) & inFault) / nnz(inFault);   % share of faulty blocks flagged
M.falseFlags    = sum(F & ~fault & valid, 1);               % per channel
M.nValid        = nnz(valid);
M.firstValidH   = tB(find(valid, 1)) / 3600;

M.heaterSensorFlags = nnz(any(F, 2) & heater & ~fault(:, fc));
if isfield(R, 'tempFlag') && flagField == "sensorFlag"
    M.heaterBlocks     = nnz(heater & valid);
    M.heaterTempFlags  = nnz(R.tempFlag & heater);
    M.heaterBlameBme   = nnz(R.blameBme & heater);
    M.heaterBlameIcm   = nnz(R.blameIcm & heater);
    M.tempFlagsOutside = nnz(R.tempFlag & ~heater & valid);
end
end
