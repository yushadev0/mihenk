# matlab/

MATLAB first-stage harness: independent reference model and Layer 1 prototypes
(`mihenk.md` §S12, ADR-021). Optional — no MIHENK module depends on it.

Tested with MATLAB R2026a + Sensor Fusion and Tracking Toolbox / Navigation Toolbox.
Findings and the reasoning behind every script are logged in [`../bulgular.md`](../bulgular.md) (Turkish).

## Layout

| Folder | Contents | Runnable? |
|---|---|---|
| [`models/`](models/) | Reusable model functions: per-sensor thermal model, synthetic node | No — called by scripts |
| [`checks/`](checks/) | Self-checks of the reference model (Allan terms, thermal model) | Yes |
| [`g1/`](g1/) | G1 (thermal common-mode decomposition): shared helpers at the root, one folder per version (`v0/`, `v1/`, `v2/`) | `g1_prototype_*.m` |
| [`figures/`](figures/) | Figures referenced from `bulgular.md` | — |

| File | Kind | What |
|---|---|---|
| `models/thermal_node.m` | function | Per-sensor die temperature: lag, gradient, self-heating, hysteresis |
| `models/simulate_node.m` | function | Synthetic 9-channel node + temperature readouts + ground truth |
| `checks/first_allan_check.m` | script | White noise density via Allan deviation |
| `checks/allan_noise_terms_check.m` | script | Rate random walk, bias instability |
| `checks/thermal_model_check.m` | script | `imuSensor` thermal formula, noise continuity |
| `checks/thermal_node_check.m` | script | `thermal_node.m` (C1–C4) |
| `g1/g1_setup.m` | function | Path setup for every G1 script; returns the figures folder |
| `g1/g1_evaluate.m` | function | Scores a detector against ground truth (faults, heater, EMI, BME fault) |
| `g1/g1_flag_raster.m` | function | Blame raster plot |
| `g1/v0/g1_prototype_v0.m` | script | G1 v0 run |
| `g1/v0/g1_detect_v0.m` | function | v0 detector: sliding-window fit |
| `g1/v1/g1_prototype_v1.m` | script | G1 v1 vs v0 vs baseline |
| `g1/v1/g1_detect_v1.m` | function | v1 detector: gated Bayesian model + CUSUM |
| `g1/v2/g1_prototype_v2.m` | script | Evaluation of v0 and v1 over 9 scenarios x 5 seeds |
| `g1/v2/g1_scenarios_v2.m` | function | v2 scenario set |

Detectors receive only firmware-visible inputs.

## Running

Open a script and press **F5**. Scripts put `models/` (and, for G1, every
`g1/v*` folder) on the path themselves and save their figures to `figures/`.
Function files are not run directly.

## Conventions

- `NoiseType = 'single-sided'` always; bias instability via `fractalcoef(K, 1)` (see `bulgular.md` §1–2).
- Every parameter carries its provenance in a comment: `datasheet` (with revision/table) or `assumed`.
- Seeded random streams everywhere — results are reproducible.
- Detectors receive only firmware-visible data; ground truth (`D.truth`) is for evaluation only (information barrier, `mihenk.md` §S4).
