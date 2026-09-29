# MIHENK

**Multi-sensor Intrinsic Health Estimation & Numerical Kernel**

A physics–sensor–microcontroller co-simulation environment for reference-free health estimation on heterogeneous, resource-constrained sensor nodes.

> **Status:** planning / architecture phase (M0 not started). The full design lives in the report — see [Documents](#documents).

## Research question

> Can a single, resource-constrained, heterogeneous multi-sensor node — without hardware redundancy, a plant model, an external aiding reference (GNSS), or user-performed calibration manoeuvres — produce a **calibrated, continuous** estimate of the trustworthiness of its own measurements, and at what **resource cost**?

## Central claim

Sensors measuring different physical quantities still share confounders — above all, **temperature**. That sharing yields a reference-free decomposition:

- a change seen across channels with the same thermal signature is **common-mode** → the cause is the environment;
- a change confined to one channel is **channel-specific** → the cause is the sensor.

In short: *existing literature uses sensors to diagnose the world; MIHENK uses the physical constraints of the world to diagnose the sensor.*

## Diagnostic levers (by strength)

1. **Thermal common-mode decomposition** — the central contribution (G1)
2. **Hard physical constraints** — `‖a‖ = g` at rest, `‖m‖ ≈ const`, and 3-way orientation voting (accel + gyro + magnetometer) that can *name* the faulty sensor
3. **Cross-sensitivity sign tests** — gas domain
4. **Streaming Allan deviation** — on-device, fixed memory (a component, not a claim)

## Why a simulator

Simulation is the only place where ground truth exists. MIHENK runs, on one deterministic time base:

- **Physics** — 6-DOF rigid body, thermal field (gradients, hysteresis, self-heating), well-mixed scalar environment
- **Sensor & degradation models** — IMU, magnetometer, gas, T/RH/P; Allan-consistent noise; labelled fault injection
- **Real firmware** on emulated MCUs (simavr, Espressif QEMU) behind a process-level **information barrier**
- **The diagnostic kernel** — Layer 1 statistical/physical tests (fixed-point), Layer 2 tiny NN on residual features, outputting a calibrated continuous trust score (no binary flags)

## Target hardware

| MCU | SRAM | Backend | Fidelity |
|---|---|---|---|
| ATmega328P (Arduino Nano/Uno) | 2 KB | simavr | L1 register-accurate, deterministic |
| ATmega2560 (Arduino Mega) | 8 KB | simavr | L1 register-accurate, deterministic |
| ESP32-S3 | 512 KB | Espressif QEMU + real HW | L2 HAL-shim / L3 HIL |

The 2 KB → 512 KB span (256×) is used to measure the Pareto trade-off between diagnostic cost and diagnostic power.

## Planned stack

Python 3.11+ core (NumPy/SciPy, Numba/C hot loops) · simavr & Espressif QEMU · fixed-point C firmware (AVR-GCC, ESP-IDF) · PyTorch → int8 C codegen / TFLite Micro · Parquet + JSON manifests · FastAPI + React/Vite/TS (MIHENK Studio) · MATLAB/Simulink as an optional, independent first-stage reference (never part of the shipped pipeline) · Linux x86_64 as the canonical reference platform.

## Roadmap (summary)

M0 skeleton & determinism gate → M0.5 fixed-point feasibility spike on ATmega328P → M1 physics + IMU/mag models (+ M1-M MATLAB track) → M2 MCU emulation layer → M3 scenario DSL & dataset → M4 HIL → M5 fixed-point kernel & Pareto → M6 gas domain → M7 NN chain → M8 Studio → M9 sim2real → M10 active learning → M11 release. ≈ 20 months total; minimum publishable core in 5–7 months.

## Documents

| File | Contents |
|---|---|
| [`mihenk.md`](mihenk.md) | Architecture design & project plan (Turkish, Markdown source) — subsystems, ADRs, quality gates, roadmap, risks, evaluation, hardware list |
| [`mihenk_rapor.pdf`](mihenk_rapor.pdf) | The same report, typeset as PDF |

## Team

Yuşa Göverdik · Batuhan Koca — Advisor: Assoc. Prof. Dr. Emre Avuçlu
Aksaray University, Faculty of Engineering, Department of Software Engineering

## License

Planned: Apache-2.0 for the core; a separate GPL-3.0 bridge component (`mihenk-avr-bridge`) that links simavr. License files will be added with the code skeleton.
