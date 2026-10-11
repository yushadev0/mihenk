function R = g1_detect_v10(D, NM, opt)
%G1_DETECT_V10 G1 v10 detector: v8 without C2 (bulgular.md sections 20,
%   20D-20E). It is g1_detect_v9 with the growth test as release test,
%   i.e. the ablation v9noE of the v9 dev run, operation for operation:
%     v6 (A lead-lag temperature source, B event-end release, C1 offset
%     events) + D1 (model error anchored at the freeze, v7) + R (relaxation
%     hysteresis candidates next to the play widths, v8), with C2 ("model
%     unreliable") off and without the equivalence test E of v9.
%   E is dropped: on ramps it cannot tell a channel frozen before its model
%   was identified (10F) from a drift and brings those locks back (20D),
%   and under colored noise its short-window se is optimistic (20E).
%   Chosen after the v9 dev run, so its dev numbers are seen; the decision
%   is taken on the new held-out set (section 21).
%
%   opt overrides any option of g1_detect_v9.

o = struct('releaseTest', "growth", 'unreliable', false);
if nargin > 2
    for f = fieldnames(opt)', o.(f{1}) = opt.(f{1}); end
end
R = g1_detect_v9(D, NM, o);
R.name = "G1 v10";
end
