# skill_04_rtl_design — RTL & UPF Design
## Stage 4 | Gate: GATE-04 | Runs in parallel with skill_05_verification

**Version:** 1.0
**Agents:** agent:rtl[n] (primary), agent:upf (UPF generation), agent:ams (if AMS blocks present)
**Trigger:** GATE-03 approval from skill_03_arch_design

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_03_arch_design | `arch/block_diagram.yaml`, `arch/clock_domains.yaml`, `arch/power_intent.yaml`, `arch/memory_map.yaml` |
| Parallel | skill_05_verification | RTL commits trigger regression runs; skill_05 reports bugs back here |
| Downstream | skill_05_verification | `rtl/*.sv` (RTL under test) |
| Downstream | skill_06_synthesis | `rtl/*.sv`, `power/MY_CHIP.upf`, `constraints/constraints.sdc` |
| On GATE-04 REJECT | skill_04_rtl_design | Iterate — fix flagged RTL issues |
| On skill_05 reports bug | skill_04_rtl_design | Fix RTL bug; re-commit; signal skill_05 to re-run |
| On skill_06 WNS fail ≤20% | skill_04_rtl_design | Optimize critical path RTL |
| On skill_08b LVS fail (netlist) | skill_04_rtl_design | Fix structural RTL issue |
| Library | skill_lib_memory | Recall tool prefs, lint tool, CDC tool |
| Library | skill_lib_tool_detect | RTL-specific tools (simulator, lint, CDC) |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `arch/block_diagram.yaml` | skill_03 | Yes — module list |
| `arch/clock_domains.yaml` | skill_03 | Yes — CDC pairs, ICG policy |
| `arch/power_intent.yaml` | skill_03 | Yes — UPF domain boundaries |
| `arch/memory_map.yaml` | skill_03 | Yes — register map |
| `algo/hls_rtl/*.v` | skill_02 | Only if HLS was used |
| Prior error log (rtl_design) | skill_lib_memory | Optional |

---

## Tool Detection (RTL Subset)

```
RTL TOOLS (from skill_lib_tool_detect):
  Simulator:        <recalled or select: VCS / Xcelium / Questa / Verilator / Icarus>
  RTL Lint:         <select: SpyGlass / Jasper Lint / Verilator --lint-only>
  CDC Analysis:     <select: SpyGlass CDC / Meridian CDC / Questa CDC>
  UPF / Power Lint: <select: SpyGlass Power / Power Artist / skip>
  Waveform viewer:  <recalled>
```

---

## Requirements Gathering

```
STAGE 4: RTL DESIGN REQUIREMENTS

  HDL language:
    [1] SystemVerilog (recommended — SV2012)
    [2] VHDL
    [3] Mixed (SV top + VHDL legacy blocks)

  Coding guidelines:
    [1] Use built-in guidelines (based on arch/clock_domains.yaml rules)
    [2] Provide company style guide path
    [3] Generate template guidelines document

  Module stub generation:
    Auto-generate stubs from arch/block_diagram.yaml:  [yes / no]
    Boilerplate: module header + copyright:             [yes / no]
    Default parameters:                                 [yes / no]
    FSM template (one-hot / binary / gray):             [one-hot]

  UPF generation:
    Auto-generate UPF from arch/power_intent.yaml:     [yes (recommended)]
    UPF version:   [IEEE 1801-2015]
    Validate UPF with lint:   [yes — SpyGlass Power / Power Artist]

  Quality targets:
    Lint clean:            [0 errors; waived warnings documented]
    CDC clean:             [0 unresolved violations]
    No latches:            [0 (unless explicitly marked intentional)]
    No tri-state internal: [0 internal Z-state nets]
    ICG policy:            [cell-based ICG only; no combinational clock gating]
    Assertion density:     [≥1 assertion per 10 lines of RTL]

  Code coverage target (for smoke run):  [line ≥50% (full: skill_05)]
```

---

## RTL Rules Enforced at Every Commit

The skill runs these checks on every RTL commit before updating skill_05:

```
AUTOMATED RTL QUALITY GATES
──────────────────────────────────────────────────────────────────────────
Gate    Check                           Tool             Pass Criterion
──────────────────────────────────────────────────────────────────────────
R-QG-01 Syntax / compile clean          Xcelium/VCS      0 compile errors
R-QG-02 RTL lint clean (style)          SpyGlass         0 errors, waivers logged
R-QG-03 CDC structural clean            SpyGlass CDC     0 unresolved CDC violations
R-QG-04 Clock gating policy            Custom lint rule  No combinational clock gates
R-QG-05 UPF power lint                 SpyGlass Power   0 errors
R-QG-06 No latches inferred            Lint              0 latches (mark intentional)
R-QG-07 No internal tri-state          Lint              0 Z-state nets
R-QG-08 Assertion density              Script            ≥1 assertion / 10 RTL lines
R-QG-09 Smoke simulation (reset/init)  Xcelium/VCS      Basic power-on reset PASS
R-QG-10 UPF lint (power aware)         SpyGlass Power   All domains have ISO/LS/AO
──────────────────────────────────────────────────────────────────────────
FAIL on any gate → block commit; return to agent:rtl[n] for correction
```

---

## UPF Generation Protocol

When `arch/power_intent.yaml` is present, agent:upf executes:

```
UPF GENERATION STEPS:
  1. Parse arch/power_intent.yaml → extract domains, voltages, AO regions
  2. Generate create_power_domain() for each domain
  3. Insert create_supply_net() / create_supply_port()
  4. Auto-identify isolation cells: outputs crossing from off→on domain
  5. Auto-identify level shifters: outputs crossing voltage domains
  6. Auto-identify retention registers: all FFs in retention domain
  7. Generate set_isolation() / set_level_shifter() / set_retention()
  8. Write power/MY_CHIP.upf (IEEE 1801-2015)
  9. Run UPF lint (SpyGlass Power):
       - Check: no floating always-on nets
       - Check: all domain outputs have isolation
       - Check: all level-shifter crossings declared
  10. Write UPF lint report → power/upf_lint.rpt

  Cross-reference: UPF spec → GAP-002_UPF_Agent_Spec.md (companion doc)
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| RTL source (all modules) | `rtl/*.sv` | skill_05, skill_06 |
| UPF power intent file | `power/MY_CHIP.upf` | skill_05 (PA-sim), skill_06, skill_07 |
| Timing constraints (seed) | `constraints/constraints.sdc` | skill_06 |
| RTL lint report | `reports/rtl_lint.rpt` | GATE-04 review |
| CDC lint report | `reports/cdc_lint.rpt` | GATE-04 review |
| UPF lint report | `reports/upf_lint.rpt` | GATE-04 review |
| Assertion file | `rtl/assertions/*.sv` | skill_05 (bound at sim) |

---

## Output Metrics

```
RTL DESIGN METRICS (at GATE-04 request)
────────────────────────────────────────────────────────────────
Metric                   Result       Target       Status
────────────────────────────────────────────────────────────────
Total RTL lines          <N>          —            INFO
Module count             <N>          —            INFO
Lint errors              <N>          0            ?
Lint warnings (waived)   <N>          documented   INFO
CDC violations           <N>          0            ?
Latches inferred         <N>          0            ?
UPF power lint errors    <N>          0            ?
Assertion count          <N>          ≥RTL/10      ?
Smoke sim pass           <yes/no>     YES          ?
Estimated gate count     <K gates>    ≤<spec>      ?
────────────────────────────────────────────────────────────────
Overall: <PASS/FAIL> → GATE-04
```

---

## Quality Gate: GATE-04

```
GATE-04 CRITERIA (human RTL Lead approval):
  □ All R-QG-01 through R-QG-10 pass
  □ RTL lint clean (0 errors, all warnings waived with justification)
  □ CDC violations: 0 unresolved
  □ UPF: all domains have isolation, level-shifters, retention (where needed)
  □ Assertion density ≥ 1 per 10 RTL lines
  □ Smoke simulation passing on all clock domains
  □ Code review by RTL Lead completed

Approvers: RTL Lead (+ UPF Engineer if >1 power domain)
Note: GATE-04 and GATE-05 (verification) are independent — both required before Stage 6.
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| GATE-04 rejected: lint violations | Fix violations; re-run R-QG-01..R-QG-10 |
| GATE-04 rejected: CDC violations | Add synchronizers per arch/clock_domains.yaml; re-run CDC lint |
| skill_05 reports RTL functional bug | Fix bug; increment RTL version; signal skill_05 to re-run regression |
| skill_06: WNS fail ≤20% of period | Optimize RTL critical path (reduce logic depth; pipeline) |
| skill_06: area over budget | Refactor large modules; share resources; reduce fanout |
| skill_08b: LVS mismatch (structural) | Fix RTL connectivity; re-synthesize |

---

## Memory Write

```yaml
execution_history:
  rtl_design:
    - timestamp: <ISO8601>
      result: <PASS/FAIL>
      tool: <lint_tool>
      metrics:
        rtl_lines: <N>
        module_count: <N>
        lint_errors: 0
        cdc_violations: 0
        assertion_count: <N>
        gate_count_est: <K>
      artifacts: [rtl/*.sv, power/MY_CHIP.upf, constraints/constraints.sdc]
      gate: GATE-04
error_log:        # appended on any gate failure
  - stage: rtl_design
    tool: <tool>
    error_class: qos_fail
    error_summary: <summary>
    resolution: <resolution>
    lesson_learned: <lesson>
```

---

*Previous: [`skill_03_arch_design.md`](skill_03_arch_design.md)*
*Parallel: [`skill_05_verification.md`](skill_05_verification.md)*
*Next: [`skill_06_synthesis.md`](skill_06_synthesis.md) (after GATE-04 + GATE-05)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
