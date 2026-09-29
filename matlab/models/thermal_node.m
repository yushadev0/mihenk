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
%   Inputs
%     t        [n x 1]  time [s], uniform step
%     Tamb     [n x 1]  ambient temperature [degC]
%     P        [n x m]  power dissipated by each sensor [W]
%     sensors  [1 x m]  struct with fields
%                       tau [s], gradient [degC], Rth [degC/W], hystWidth [degC]
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

    T = u(1);                    % start in equilibrium
    p = T;
    for k = 1:n
        if k > 1
            T = T + a * (u(k-1) - T);
        end
        p = min(max(p, T - w), T + w);   % play operator
        Tdie(k, j) = T;
        Teff(k, j) = p;
    end
end
end
