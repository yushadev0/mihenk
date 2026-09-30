function SC = g1_scenarios_v3()
%G1_SCENARIOS_V3 Factorial scenario set for G1 v3 (bulgular.md, section 9).
%   The v2 scenarios without their noise setting (finding 8F): the v3
%   prototype runs each of them once with white and once with colored noise.
%   "base" is the default scenario (gz drift at 4.5 h) - v2's "white" and
%   "colored" are its two noise levels.

SC = g1_scenarios_v2();
SC([SC.name] == "colored") = [];
SC(1).name  = "base";
SC(1).tests = "default scenario: gz drift during the down-ramp";
for i = 1:numel(SC)
    if isfield(SC(i).S, 'noise'), SC(i).S = rmfield(SC(i).S, 'noise'); end
end
end
