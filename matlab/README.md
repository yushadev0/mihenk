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
| [`g1/`](g1/) | G1 prototypes (thermal common-mode decomposition), detectors, evaluation | `g1_prototype_*.m` |
| [`figures/`](figures/) | Figures referenced from `bulgular.md` | — |

| File | Kind | What |
|---|---|---|
| `models/thermal_node.m` | function | Per-sensor die temperature: lag, gradient, self-heating, hysteresis |
| `models/simulate_node.m` | function | Synthetic 9-channel node + temperature readouts + ground truth |
| `checks/first_allan_check.m` | script | White noise density via Allan deviation |
| `checks/allan_noise_terms_check.m` | script | Rate random walk, bias instability |
| `checks/thermal_model_check.m` | script | `imuSensor` thermal formula, noise continuity |
| `checks/thermal_node_check.m` | script | `thermal_node.m` (C1–C4) |
| `g1/g1_prototype_v0.m` | script | G1 v0 run |
| `g1/g1_prototype_v1.m` | script | G1 v1 vs v0 vs baseline |
| `g1/g1_detect_v0.m`, `g1_detect_v1.m` | function | Detectors (firmware-visible inputs only) |
| `g1/g1_evaluate.m` | function | Scores a detector against ground truth |

## Running

Open a script and press **F5**. Scripts add `models/` to the path themselves and
save their figures to `figures/`. Function files are not run directly.

## Conventions

- `NoiseType = 'single-sided'` always; bias instability via `fractalcoef(K, 1)` (see `bulgular.md` §1–2).
- Every parameter carries its provenance in a comment: `datasheet` (with revision/table) or `assumed`.
- Seeded random streams everywhere — results are reproducible.
- Detectors receive only firmware-visible data; ground truth (`D.truth`) is for evaluation only (information barrier, `mihenk.md` §S4).
