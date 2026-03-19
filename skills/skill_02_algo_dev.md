# skill_02_algo_dev — Algorithm Development
## Stage 2 | Gate: GATE-02

**Version:** 1.0
**Agent:** agent:algo (primary), agent:arch (review)
**Trigger:** GATE-01 approval from skill_01_spec_intake

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_01_spec_intake | `spec/product_spec.yaml`, `spec/clocks.yaml` |
| Downstream | skill_03_arch_design | `algo/algo_spec.md`, `algo/golden_model.*`, `algo/test_vectors.*` |
| Downstream | skill_05_verification | `algo/test_vectors.*` (golden reference for verification) |
| On GATE-02 REJECT | skill_02_algo_dev | Iterate algorithm; revise model |
| If spec conflict | skill_01_spec_intake | Relay infeasibility; update spec targets |
| Library | skill_lib_memory | Recall tool prefs; write exec history |
| Library | skill_lib_tool_detect | Algorithm tool selection (MATLAB/Python/SystemC/HLS) |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `spec/product_spec.yaml` | skill_01_spec_intake | Yes |
| `spec/clocks.yaml` | skill_01_spec_intake | Yes (if DSP/multi-rate) |
| Prior error log (algo_dev) | skill_lib_memory | Optional |

---

## Tool Detection (Algorithm Domain)

Sub-call to skill_lib_tool_detect, filtered for algorithm tools:

```
ALGORITHM TOOLS (subset of full detection):
  MATLAB + Simulink      → preferred for DSP/comms/control + HDL Coder path
  Octave                 → open-source MATLAB-compatible
  Python + NumPy/SciPy   → universal; use fxpmath for fixed-point
  SystemC behavioral     → closest to hardware timing model
  HLS tools:
    Catapult HLS (Mentor) → C++/SystemC → RTL (high quality)
    Vitis HLS (AMD)       → C/C++ → RTL (FPGA + ASIC)
    Bambu HLS             → open source C → RTL
  GNU Radio              → SDR / communications algorithms
  PyMTL3                 → Python-based RTL modeling + co-sim

QUICK SELECT:
  [1] MATLAB + Simulink (HDL Coder available — direct RTL generation path)
  [2] Python + NumPy/SciPy + fxpmath (open, flexible)
  [3] SystemC behavioral model (closest to RTL, hand-off to skill_04)
  [4] HLS-first: Catapult / Vitis HLS / Bambu (→ auto-RTL generation)
  [5] Octave (MATLAB compatible, open source)
```

---

## Requirements Gathering

```
STAGE 2: ALGORITHM REQUIREMENTS
  (Recalled from spec/product_spec.yaml: <key targets>)

  Algorithm type:
    [1] DSP (filter, FFT, FIR/IIR)    [2] ML inference (CNN/RNN/transformer)
    [3] Cryptography (AES/SHA/RSA)     [4] Control (PID/state machine)
    [5] Communications (modem/CODEC)   [6] Image/video processing
    [7] Custom (describe)

  Arithmetic:
    Fixed-point or floating-point:     [fixed-point (recommended for ASIC)]
    If fixed-point: integer.fractional bits: [16.16]
    Overflow handling:                 [saturation / wrap / detected]

  Performance targets (from spec):
    Throughput (Gbps / Msps):          [recalled or specify]
    Latency (ns / cycles):             [recalled or specify]
    Target SNR / BER / accuracy:       [specify or N/A]

  HLS path:
    Use HLS for RTL generation:        [yes → select HLS tool / no → handwritten RTL]
    If yes, HLS target:                [Catapult / Vitis / Bambu]

  Reference model:
    Provide existing model:            [path] or [generate template]
    Golden test vectors:               [generate N vectors / provide file / skip]
    Vector count:                      [1000 (default)]

  Algorithm partitioning:
    Single core or pipelined:         [pipelined (default for throughput)]
    Parallelism factor:                [1 — specify if needed]
```

---

## Execution Steps

```
1. Load product_spec.yaml → extract performance targets
2. Generate or load reference algorithm model
3. Run floating-point simulation → establish golden output
4. Convert to fixed-point → sweep bit-widths → find minimum sufficient
5. Run fixed-point simulation → measure SNR / accuracy loss
6. Generate test vectors (inputs + expected outputs)
7. If HLS selected:
     a. Write HLS-annotated C++/SystemC
     b. Run HLS synthesis → QoR report (latency cycles, area estimate)
     c. Run co-simulation (HLS testbench vs. RTL)
8. Write algo_spec.md (architecture implications, bit-widths, latency budget)
9. Estimate gate count from HLS QoR or algorithmic complexity
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| Algorithm specification | `algo/algo_spec.md` | skill_03_arch_design |
| Golden reference model | `algo/golden_model.*` | skill_05_verification |
| Test vectors (input/output) | `algo/test_vectors.csv` | skill_05_verification |
| HLS-generated RTL (if HLS) | `algo/hls_rtl/*.v` | skill_04_rtl_design |
| HLS QoR report | `algo/hls_qor.rpt` | skill_03_arch_design |
| Fixed-point analysis report | `algo/fixedpoint_analysis.md` | skill_03_arch_design |

---

## Output Metrics

```
ALGORITHM STAGE METRICS
────────────────────────────────────────────────────────────────
Metric                      Result      Target (from spec)  Status
────────────────────────────────────────────────────────────────
Peak SNR / accuracy         <value>     ≥<spec target>      ?
Throughput (model)          <Gbps>      ≥<spec target>      ?
Latency (model)             <ns>        ≤<spec target>      ?
Fixed-point overflow events <N>         0                   ?
Test vector coverage        <pct>%      100%                ?
Gate count estimate         <K gates>   ≤<spec target>      ?
HLS latency (cycles)        <N>         ≤<spec target>      ? (if HLS)
HLS area (LUT/cell est.)    <K>         ≤<spec target>      ? (if HLS)
────────────────────────────────────────────────────────────────
Overall: <PASS/FAIL/WARN> → present to human for GATE-02
```

---

## Quality Gate: GATE-02

```
GATE-02 CRITERIA (human approval required):
  □ Algorithm meets all spec performance targets
  □ Fixed-point analysis complete; bit-widths documented
  □ Golden model validated against floating-point reference
  □ Test vectors generated (minimum 1000 patterns)
  □ Gate count estimate within spec budget (≤ <target>)
  □ algo_spec.md reviewed and signed by Arch Lead

Approvers: Algorithm Engineer + Architecture Lead
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| SNR / accuracy below target | Increase bit-width; revisit algorithm design |
| Throughput below target | Add pipeline stages; increase parallelism |
| Gate count over budget | Simplify algorithm; reduce precision; use sharing |
| HLS QoR unacceptable | Switch to handwritten RTL (disable HLS path) |
| Spec conflict (target unreachable) | Return to skill_01_spec_intake with specific feedback |

---

## Memory Write

```yaml
execution_history:
  algo_dev:
    - timestamp: <ISO8601>
      result: <PASS/FAIL>
      tool: <selected tool>
      metrics:
        snr_db: <value>
        throughput_gbps: <value>
        latency_ns: <value>
        gate_count_est: <value>
        hls_used: <true/false>
      artifacts: [algo/golden_model.*, algo/test_vectors.csv, algo/algo_spec.md]
      gate: GATE-02
```

---

*Previous: [`skill_01_spec_intake.md`](skill_01_spec_intake.md)*
*Next: [`skill_03_arch_design.md`](skill_03_arch_design.md)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
