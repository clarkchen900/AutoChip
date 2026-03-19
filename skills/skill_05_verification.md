# skill_05_verification — Functional Verification
## Stage 5 | Gate: GATE-05 | Runs in parallel with skill_04_rtl_design

**Version:** 1.0
**Agents:** agent:verif_lead (primary), agent:tb[n] (testbenches), agent:formal (formal proofs)
**Trigger:** GATE-03 approval (starts planning); gates on GATE-04 RTL freeze for full regression

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_03_arch_design | `arch/perf_model.yaml`, `arch/memory_map.yaml`, `arch/clock_domains.yaml` |
| Upstream | skill_02_algo_dev | `algo/test_vectors.csv`, `algo/golden_model.*` (reference for checking) |
| Live feed | skill_04_rtl_design | `rtl/*.sv` (continuous — re-run regression on each RTL commit) |
| Reports bugs → | skill_04_rtl_design | Signal RTL bug with failing test + waveform path |
| Downstream | skill_06_synthesis | `verif/regression/top_regression.vcd` (for PA-GLS, power analysis) |
| Downstream | skill_06_synthesis | Verif sign-off confirms RTL frozen (prerequisite for synthesis) |
| GLS re-run | skill_05_verification | skill_06 provides gate-level netlist + SDF for GLS re-run |
| On GATE-05 REJECT | skill_05_verification | Improve TB coverage; add tests; re-run regression |
| Library | skill_lib_memory | Recall simulator, formal tool, regression infrastructure |
| Library | skill_lib_tool_detect | Verification tool selection |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `arch/perf_model.yaml`, `arch/memory_map.yaml` | skill_03 | Yes |
| `arch/clock_domains.yaml` | skill_03 | Yes (CDC formal) |
| `algo/test_vectors.csv` | skill_02 | Yes (golden reference) |
| `rtl/*.sv` (live commits) | skill_04 | Yes (continuous) |
| `power/MY_CHIP.upf` | skill_04 | Yes (PA-sim) |
| `netlist/MY_CHIP_dft.v` + SDF | skill_06b | For GLS phase (later) |

---

## Tool Detection (Verification Subset)

```
VERIFICATION TOOLS (from skill_lib_tool_detect):
  Simulator:      <recalled: VCS / Xcelium / Questa / Verilator / Icarus>
  Coverage merge: <recall: IMC (Cadence) / URG (Synopsys) / verilator_cov>
  Formal:         <recall: JasperGold / VC Formal / SymbiYosys>
  Waveform:       <recall: SimVision / Verdi / GTKWave>
  VIP:            <Cadence VIP / Synopsys VIP / open UVM>
  Emulation:      <Palladium / Veloce / FPGA / none (recalled)>
  Regression:     <LSF / Kubernetes / local / cloud (AWS Batch)>
```

---

## Requirements Gathering

```
STAGE 5: VERIFICATION REQUIREMENTS

  Verification methodology:
    [1] UVM (recommended — reusable, industry standard)
    [2] Directed testbench (simpler — for small blocks)
    [3] Formal-only (for control / safety-critical logic)
    [4] Hybrid (UVM + formal)

  Regression strategy:
    [1] Nightly regression (recommended — run full suite daily)
    [2] On every RTL commit (CI-driven)
    [3] Manual trigger only

  Coverage targets:
    Functional coverage (%):         [95]
    Line coverage (%):               [100]
    Branch coverage (%):             [95]
    Toggle coverage (%):             [90]
    FSM coverage (all arcs) (%):     [100]

  Formal verification scope:
    [1] Connectivity checks (lightweight — always recommended)
    [2] Control logic formal proof (medium)
    [3] Full block formal (heavy — for safety-critical blocks)
    [4] Skip formal

  CDC formal proof:                  [yes (recommended) / no]
  UPF power-aware simulation:        [yes (mandatory if >1 power domain) / no]

  Gate-level simulation (GLS) modes:
    (run after netlist available from skill_06b)
    [✓] max-SDF:     setup-timing pessimistic (catch setup timing bugs)
    [✓] min-SDF:     hold-timing pessimistic  (catch hold timing bugs)
    [✓] X-optimistic: fast CDC / initialization check
    [✓] X-pessimistic: conservative X-prop (recommended before tape-out)
    → Industry gold standard = all 4 modes
    [1] All 4 modes   [2] max-SDF + X-pessimistic only   [3] Skip (document risk)

  Regression infrastructure:
    [1] LSF (grid)   [2] Kubernetes   [3] Local   [4] Cloud (AWS Batch)

  Protocol VIP required:
    (auto-suggested from arch/interface_spec.yaml)
    <e.g., AXI4 VIP, APB VIP, SPI VIP — confirm or add>
```

---

## Execution Steps

```
PHASE A — Plan (starts at GATE-03, runs before RTL freeze)
  1. Generate verification plan (verif/vplan.md) from arch/ artifacts
  2. Generate UVM environment skeleton (env, agents, sequences, scoreboard)
  3. Configure functional coverage model from arch/memory_map + algo/golden_model
  4. Set up regression Makefile / CI configuration
  5. Configure VIP for each interface protocol

PHASE B — Continuous Integration (runs during skill_04 RTL development)
  On each RTL commit:
    Compile RTL → run smoke test → report PASS/FAIL to skill_04 agent
    Run CDC formal assertion checks
  Nightly:
    Run full regression suite → collect coverage → report trending

PHASE C — Full Sign-Off (after GATE-04 RTL freeze)
  1. Run full regression to convergence
  2. Measure all coverage types → merge reports
  3. Run formal: connectivity + CDC proofs + safety properties
  4. Run UPF PA-sim: power-aware simulation for all power modes
  5. Identify coverage holes → write directed tests to close
  6. Repeat until all targets met

PHASE D — GLS (after skill_06b provides dft netlist + SDF)
  1. GLS max-SDF mode    (Xcelium/VCS + max SDF annotation)
  2. GLS min-SDF mode    (hold timing validation)
  3. GLS X-optimistic    (CDC / initialization check)
  4. GLS X-pessimistic   (conservative X-prop — catch X-state bugs)
  5. PA-GLS: power-aware GLS with UPF (BLOCKING gate — required)
  All 4 modes must pass with 0 X-state failures before GATE-05
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| Verification plan | `verif/vplan.md` | GATE-05 review |
| UVM environment | `verif/env/` | Internal (regression) |
| Coverage database | `verif/coverage/merged.db` | GATE-05 review |
| Regression VCD | `verif/regression/top_regression.vcd` | skill_08a (power), skill_06 (power est.) |
| Formal proofs log | `verif/formal/proofs.rpt` | GATE-05 review |
| GLS run logs | `verif/gls/gls_*.log` | GATE-05 review |
| Coverage report (HTML) | `reports/coverage_final.html` | Human review |

---

## Bug Reporting Protocol (→ skill_04)

When a failing test reveals an RTL bug:

```
BUG REPORT TO skill_04_rtl_design:
  bug_id:          VER-<NNN>
  failing_test:    <test name>
  waveform_path:   verif/waves/VER-<NNN>.fsdb
  module_suspect:  <module name>
  description:     <one-line summary>
  reproducer:      verif/regression/tests/VER-<NNN>_repro.sv
  severity:        [P1 blocker / P2 major / P3 minor]

  skill_04 is notified via orchestrator signal.
  skill_05 regression blocked for that failing path until fix merged.
```

---

## Output Metrics

```
VERIFICATION SIGN-OFF METRICS (GATE-05)
────────────────────────────────────────────────────────────────────
Metric                         Result    Target     Status
────────────────────────────────────────────────────────────────────
Functional coverage            <pct>%    ≥95%       ?
Line coverage                  <pct>%    100%       ?
Branch coverage                <pct>%    ≥95%       ?
Toggle coverage                <pct>%    ≥90%       ?
FSM coverage (all arcs)        <pct>%    100%       ?
Regression: tests run          <N>       —          INFO
Regression: failures           <N>       0          ?
Formal: properties proven      <N>       —          INFO
Formal: vacuous assertions     <N>       0          ?
CDC formal: domains proven     <N>/<N>   all        ?
UPF PA-sim: violations         <N>       0          ?
GLS max-SDF: failures          <N>       0          ?
GLS min-SDF: hold failures     <N>       0          ?
GLS X-pessim: X-state fails    <N>       0          ?
PA-GLS: power mode failures    <N>       0  BLOCKING ?
────────────────────────────────────────────────────────────────────
Overall: <PASS/FAIL> → GATE-05
```

---

## Quality Gate: GATE-05

```
GATE-05 CRITERIA (human Verif Lead approval):
  □ All coverage targets met (functional, line, branch, toggle, FSM)
  □ Regression: 0 failures
  □ Formal: all connectivity + CDC proofs complete (no vacuous)
  □ PA-sim: 0 power violations (if >1 power domain)
  □ PA-GLS: PASS (blocking — required before synthesis if UPF active)
  □ GLS (all 4 modes): 0 X-state failures
  □ Golden model comparison: 0 output mismatches
  □ Verification plan coverage: all planned scenarios exercised

Approvers: Verification Lead (+ Formal Engineer if formal scope medium/full)
Note: GATE-05 independent from GATE-04 — both must pass before Stage 6.
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| Coverage gap | Write directed tests; run targeted regression |
| Formal property vacuous | Strengthen assumption constraints; re-prove |
| GLS X-failure | Trace X-source in waveform; fix RTL init or CDC — return to skill_04 |
| PA-GLS failure | Fix UPF or RTL power mode control — return to skill_04 |
| RTL bug found in regression | Signal skill_04; wait for fix; re-run failing test |
| GATE-05 rejected: coverage | Close specific holes; re-measure |

---

## Memory Write

```yaml
execution_history:
  verification:
    - timestamp: <ISO8601>
      result: <PASS/FAIL>
      tool: <simulator>
      metrics:
        functional_coverage_pct: <value>
        line_coverage_pct: <value>
        regression_tests: <N>
        regression_failures: 0
        formal_properties_proven: <N>
        gls_modes_passed: <4/4>
        pa_gls_passed: true
      gate: GATE-05
```

---

*Previous: [`skill_03_arch_design.md`](skill_03_arch_design.md)*
*Parallel: [`skill_04_rtl_design.md`](skill_04_rtl_design.md)*
*Next: [`skill_06_synthesis.md`](skill_06_synthesis.md) (after GATE-04 + GATE-05)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
