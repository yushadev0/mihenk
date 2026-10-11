function [Tdie, Teff] = thermal_node(t, Tamb, P, sensors)
%THERMAL_NODE Per-sensor die temperatures of a heterogeneous sensor node.
%   Fills the gaps of imuSensor's thermal model (bulgular.md, Finding 3D):
%   every sensor gets its own temperature instead of one shared scalar.
%
%   Each sensor is a first-order lumped thermal mass
%       tau * dT/dt = Tamb + gradient + Rth*P - T
%   solved exactly for input held constant over each step (zero-order hold):
%     - tau       thermal lag              -> sensors follow ambient at different speeds
%     - gradient  static board gradient    -> sensors sit at different temperatures
%     - Rth*P     self-heating             -> channel-specific, changes with power mode
%
%   Thermal hysteresis is a play (backlash) operator of width hystWidth on
%   top of the die temperature. The sensor's thermal bias follows Teff
%   (feed it to imuSensor.Temperature); its temperature readout follows
%   Tdie. Heating and cooling paths are hystWidth apart.
%
%   Optional field hystTau [s] > 0 selects a different, rate-dependent
%   hysteresis instead: Teff relaxes towards Tdie with its own time constant
%   (stress relaxation). Used for model-mismatch tests (ADR-012), since the
%   G1 detector assumes the play form.
%
%   Optional field hystWidths [degC], a vector of two or more widths,
%   selects a Prandtl-Ishlinskii operator: equally weighted play operators
%   in parallel, Teff their mean. G1 models neither this form nor its
%   parameters (third form for the held-out set, bulgular section 21).
%
%   Optional field tau2 [s] > 0 adds a second lag stage: the die follows
%   the first thermal mass with its own time constant (second-order path,
%   bulgular section 21). Self-heating enters the first stage.
%
%   Inputs
%     t        [n x 1]  time [s], uniform step
%     Tamb     [n x 1]  ambient temperature [degC]
%     P        [n x m]  power dissipated by each sensor [W]
%     sensors  [1 x m]  struct with fields
%                       tau [s], gradient [degC], Rth [degC/W], hystWidth [degC],
%                       optional hystTau [s], hystWidths [degC], tau2 [s]
%   Outputs
%     Tdie     [n x m]  die temperature [degC]
%     Teff     [n x m]  temperature seen by the thermal bias (hysteresis applied) [degC]

if nargin < 4
    error('thermal_node:usage', ['thermal_node is a function and needs inputs ' ...
        '(t, Tamb, P, sensors). To run the checks, open thermal_node_check.m and press F5.']);
end

dt = t(2) - t(1);
n  = numel(t);
m  = numel(sensors);
Tdie = zeros(n, m);
Teff = zeros(n, m);

for j = 1:m
    s = sensors(j);
    u = Tamb(:) + s.gradient + s.Rth .* P(:, j);   % equilibrium temperature
    a = 1 - exp(-dt / s.tau);
    w = s.hystWidth / 2;
    relax = isfield(s, 'hystTau') && s.hystTau > 0;
    if relax, ah = 1 - exp(-dt / s.hystTau); end
    multi = isfield(s, 'hystWidths') && numel(s.hystWidths) > 1;   % Prandtl-Ishlinskii
    if multi, w = s.hystWidths(:)' / 2; end
    second = isfield(s, 'tau2') && ~isempty(s.tau2) && s.tau2 > 0;   % second-order path
    if second, a2 = 1 - exp(-dt / s.tau2); end

    T = u(1);                    % start in equilibrium
    T2 = T;
    p = T * ones(1, numel(w));
    for k = 1:n
        if k > 1
            if second, T2 = T2 + a2 * (T - T2); end
            T = T + a * (u(k-1) - T);
        end
        Td = T;
        if second, Td = T2; end
        if relax
            p = p + ah * (Td - p);           % relaxation hysteresis
        else
            p = min(max(p, Td - w), Td + w); % play operator (several in parallel: PI)
        end
        Tdie(k, j) = Td;
        Teff(k, j) = mean(p);
    end
end
end
