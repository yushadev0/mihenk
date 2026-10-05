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
| [`g1/`](g1/) | G1 (thermal common-mode decomposition): shared helpers at the root, one folder per version (`v0/` … `v7/`), `test/` for the acceptance test | `g1_prototype_*.m` |
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
| `g1/v3/g1_prototype_v3.m` | script | Factorial evaluation (8 scenarios x white/colored x 5 seeds) of v0, v1, v3a, v3 |
| `g1/v3/g1_detect_v3.m` | function | v3 detector: Kalman null model from Allan parameters + signed CUSUM |
| `g1/v3/g1_allan_fit.m` | function | Allan variance fit (N, K, Gauss-Markov) -> block-level Kalman parameters |
| `g1/v3/g1_scenarios_v3.m` | function | v3 scenario set (v2 scenarios without the noise setting) |
| `g1/v4/g1_prototype_v4.m` | script | v1, v3, v4 and ablation v4nf over the v3 scenarios x white/colored x 10 seeds |
| `g1/v4/g1_detect_v4.m` | function | v4 detector: v3 + multi-element common mode, ambiguous source state, model-error floor |
| `g1/v4/g1_diag_gx_lock.m` | script | Diagnosis of the channel locked from the start (bulgular 10E/10F) |
| `g1/v5/g1_prototype_v5.m` | script | v4nf, v5 and ablations v5a, v5noC, v5noD over the v3 scenarios x white/colored x 10 seeds |
| `g1/v5/g1_smoke_v5.m` | script | Quick equivalence and run check before the v5 evaluation (no metrics) |
| `g1/v5/g1_detect_v5.m` | function | v5 detector: v4 + CUSUM cap, floor only on frozen channels, growth-based release, reset on model switch |
| `g1/test/g1_scenarios_test.m` | function | Held-out scenario set of the acceptance test (bulgular §11) |
| `g1/test/g1_acceptance_test.m` | script | One-shot G1 acceptance test, PASS/FAIL per declared criterion |
| `g1/test/g1_smoke_test.m` | script | Simulates every held-out scenario without running a detector |
| `g1/v6/g1_diag_tsrc_lock.m` | script | Diagnosis of the temperature-source lock in the acceptance test (bulgular 13D/14), replica of the v5 temperature-source model |
| `g1/v6/g1_tsrc_v6.m` | function | v6 temperature-source model: lead-lag structure, lag-grid error term and frozen covariance growth, each a switch |
| `g1/v6/g1_dev_tsrc_v6.m` | script | Dev run of the v6 temperature-source model vs v5 and ablations (dev set + spent test set), selection by the declared rule |
| `g1/v6/g1_detect_v6.m` | function | v6 detector: v5 + lead-lag temperature source (A), event-end release (B), multi-state output with offset event (C1) and model unreliable (C2) |
| `g1/v6/g1_prototype_v6.m` | script | v6 dev run: v5, v6 and ablations noA/noB/noC1/noC2 on the dev set and the spent test set, selection by the declared rule |
| `g1/v6/g1_smoke_v6.m` | script | Quick equivalence and run check before the v6 dev run |
| `g1/v6/g1_diag_v6_side.m` | script | Diagnosis of the v6 side effects seen in the replay viewer (bulgular 16E): mz false alarm with the BME reference, early event-end release of a step |
| `g1/v7/g1_detect_v7.m` | function | v7 detector: v6 + model error anchored at the freeze (D1) and large non-growing deviation as an offset event (D2) |
| `g1/v7/g1_prototype_v7.m` | script | v7 dev run: v6, v7 and ablations noD1/noD2 on the dev set and the spent test set, regression vs v6, selection by the declared rule |
| `g1/v7/g1_smoke_v7.m` | script | Quick equivalence and run check before the v7 dev run |

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
