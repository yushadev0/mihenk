function D = g1_truth_onset(D)
%G1_TRUTH_ONSET Count the block that contains a fault onset as faulty.
%   simulate_node labels a block faulty when its centre D.tB >= t0, so a
%   fault starting in the second half of a block leaves that block labelled
%   healthy although its data already contain part of the fault. A correct
%   detection there was scored as a false alarm (bulgular 22D: the one
%   "T src" flag of bme-step-289). This relabels D.truth.fault and
%   D.truth.tempFault so that every block ending after t0 is faulty.
%   Scoring only; the simulated data do not change. Used by scripts written
%   after section 22; earlier results keep the old labels.

half = D.S.B / 2;
for f = D.S.faults(:)'
    D.truth.fault(:, f.ch) = D.truth.fault(:, f.ch) | D.tB + half > f.t0;
end
if ~isempty(D.S.bmeFault)
    D.truth.tempFault = D.truth.tempFault | D.tB + half > D.S.bmeFault.t0;
end
end
