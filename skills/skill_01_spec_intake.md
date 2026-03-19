# skill_01_spec_intake — Product Specification Intake
## Stage 1 | Gate: GATE-01

**Version:** 1.0
**Agent:** agent:pm (primary), agent:algo + agent:arch (review)
**Trigger:** New project, or GATE-01 rejection requiring spec revision

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream (caller) | skill_00_orchestrator | Flow start; new project |
| Downstream | skill_02_algo_dev | Consumes `spec/product_spec.yaml` |
| Downstream | skill_03_arch_design | Consumes `spec/product_spec.yaml`, `spec/rtm.csv` |
| On GATE-01 REJECT | skill_01_spec_intake | Iterate on this skill — revise spec |
| If algo infeasible | skill_01_spec_intake | skill_02 triggers return here |
| Library | skill_lib_memory | Read/write SMS; recall prior answers |
| Library | skill_lib_pdk_select | PDK selection (first time only) |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| User requirements (verbal / doc) | Human | Yes |
| Prior SMS (if project exists) | skill_lib_memory | Optional |
| PDK choice | skill_lib_pdk_select | Yes |

---

## Activation Steps

```
1. Read SMS → recall any prior spec answers for this project
2. If first run: invoke skill_lib_pdk_select → select PDK
3. If first run: invoke skill_lib_tool_detect → select tool suite
4. Run requirements gathering dialog (below)
5. Generate output artifacts
6. Run intent double-check (feasibility review)
7. Request GATE-01 human approval via human_review_gateway MCP
8. Write to SMS
```

---

## Requirements Gathering Dialog

*Recalled values from SMS are shown in [brackets] — press ENTER to accept.*

```
── PROJECT IDENTITY ──────────────────────────────────────────────────────
  Design name:                          [MY_CHIP]
  Version:                              [v1.0]
  Design type:     [1] Digital   [2] Mixed-Signal   [3] Full-Custom
  Target application:
    [1] Consumer   [2] Industrial (−40–85°C)
    [3] Automotive AEC-Q100-G2   [4] Automotive AEC-Q100-G1
    [5] Automotive AEC-Q100-G0   [6] Military / Aerospace

── PERFORMANCE ───────────────────────────────────────────────────────────
  Target operating frequency (MHz):     [500]
  Number of clock domains:              [1]
  Performance-critical paths:           (describe or skip)

── INTERFACE & IO ────────────────────────────────────────────────────────
  Primary interface protocol(s):
    [1] AXI4   [2] APB   [3] AHB   [4] SPI/I2C/UART   [5] PCIe
    [6] DDR    [7] USB   [8] Custom  (multi-select OK)
  IO count (digital / analog):          [100 / 0]
  IO voltage domains:                   [1.8V core, 3.3V IO]

── POWER ─────────────────────────────────────────────────────────────────
  Maximum active power (mW):            [100]
  Maximum leakage (μW):                 [50]
  Power domains (rough count):          [1]
  Sleep / retention required:           [no]

── AREA & PACKAGE ────────────────────────────────────────────────────────
  Target die area (mm²):                [10]
  Package:   [QFP / BGA / CSP / bare die / WLP]
  Gate count estimate:                  [1M]

── RELIABILITY ───────────────────────────────────────────────────────────
  Temperature range (°C):               [−40 to 85]
  ESD protection (HBM kV):             [2]
  Operating lifetime (years):           [10]
  (reliability grade auto-set from application choice above)

── VERIFICATION ──────────────────────────────────────────────────────────
  Functional coverage target (%):       [95]
  DFT stuck-at target (%):             [99]
  Formal verification:                  [yes / no]
  Emulation platform:  [none / Palladium / Veloce / FPGA proto]

── DELIVERABLES ──────────────────────────────────────────────────────────
  Output format:   [GDSII / OASIS / both]
  Tape-out target date:                 [specify]
  Foundry:   [TSMC / GF / Samsung / efabless MPW / other]
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| Product specification (YAML) | `spec/product_spec.yaml` | skill_02, skill_03, skill_00 |
| Product specification (Markdown) | `spec/product_spec.md` | Human review |
| Requirements traceability matrix | `spec/rtm.csv` | all stages (trace IDs) |
| Clock domain summary | `spec/clocks.yaml` | skill_03, skill_04, skill_06 |
| PDK selection record | `.eda_flow/skill_memory_store.yaml` | All skills |

---

## Intent Double-Check

Before requesting GATE-01 approval, present:

```
SPECIFICATION REVIEW — Confirm this matches your intent

KEY DECISIONS:
  ✦ Technology: <pdk_selected>
  ✦ Target: <freq> MHz, <power> mW, <area> mm²
  ✦ Application: <application + reliability grade>
  ✦ Clock domains: <count>
  ✦ Power domains: <count>
  ✦ DFT coverage: stuck-at ≥ <target>%

FEASIBILITY FLAGS:
  ○ Frequency vs. node:   <assessment — FEASIBLE / MARGINAL / CONCERN>
  ○ Power vs. area:       <assessment>
  ○ Gate density:         <assessment>
  ✗ <any concerns>        <explanation + recommended action>

RISKS:
  [R1] <risk> — <mitigation>
  [R2] <risk> — <mitigation>

Does this match your intent? [yes / edit / abort]
```

---

## Quality Gate: GATE-01

```
GATE-01 CRITERIA (human approval required):
  □ Product specification document complete and signed
  □ All performance targets defined (freq, power, area)
  □ Technology node and foundry confirmed
  □ Reliability grade confirmed
  □ RTM v1.0 generated (all requirements have IDs)
  □ Feasibility flags reviewed and accepted

Requesting GATE-01 approval via human_review_gateway...
Approvers: PM + Architecture Lead
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| GATE-01 rejected: spec incomplete | Restart requirements gathering from flagged sections |
| GATE-01 rejected: infeasible targets | Revise targets; re-run feasibility check |
| skill_02 returns "spec infeasible" | Receive specific feedback; re-open flagged requirements |
| skill_03 returns "arch cannot close at target freq" | Escalate: relax frequency target or change PDK |

---

## Memory Write

```yaml
# Written to SMS on GATE-01 APPROVE
project:
  name: <name>
  design_id: <design_id>
  technology_node: <pdk_node>
  pdk_selected: <pdk>
design_requirements:
  target_frequency_mhz: <value>
  target_power_mw: <value>
  die_area_mm2: <value>
  reliability_grade: <grade>
  temperature_range: <range>
  dft_sa_coverage_target: <value>
  functional_coverage_target: <value>
  clock_domains: [<list>]
execution_history:
  spec_intake:
    - timestamp: <ISO8601>
      result: PASS
      gate: GATE-01
      artifacts: [spec/product_spec.yaml, spec/rtm.csv]
```

---

*Next: [`skill_02_algo_dev.md`](skill_02_algo_dev.md)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
