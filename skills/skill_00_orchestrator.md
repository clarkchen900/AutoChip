# skill_00_orchestrator — ASIC Flow Orchestrator
## Stage: All | Master Controller

**Version:** 1.0
**Trigger:** User command, CI system, or direct invocation
**Agent:** agent:orch

---

## Cross-References

| Direction | Skill | Purpose |
|-----------|-------|---------|
| Launches | skill_01 … skill_08c | All stage skills |
| Library | skill_lib_memory | Load/save SMS; project state |
| Library | skill_lib_tool_detect | Initial tool inventory |
| Library | skill_lib_pdk_select | PDK selection at project start |
| On any stage FAIL | See Iteration Table below | Route back to correct upstream skill |

---

## Startup Dialog

```
╔══════════════════════════════════════════════════════════════════════╗
║            ASIC DESIGN FLOW ORCHESTRATOR  v1.0                      ║
║            Multi-Agent EDA Coordinator                               ║
╚══════════════════════════════════════════════════════════════════════╝

[1] Read SMS → recall project, PDK, tool stack, last completed stage
[2] Run skill_lib_tool_detect → inventory environment
[3] Run skill_lib_pdk_select → verify PDK available

RECALLED STATE:
  Project:    <project.name> <project.design_id>
  PDK:        <project.pdk_selected>
  Tools:      <tool_preferences summary>
  Last stage: <last completed stage and PASS/FAIL>
  Next stage: <recommended next stage>

FLOW OPTIONS:
  [1] Full flow            Stage 1 → GDSII (all stages sequential/parallel per FSM)
  [2] Continue flow        Resume from last completed stage
  [3] Start from stage N   Partial flow — verify prerequisites first
  [4] Re-run stage N       Re-execute one stage (e.g., after ECO)
  [5] Back-end only        Stages 6 → 8 (RTL frozen, synthesis onward)
  [6] LibreLane flow       Yosys + OpenROAD automated pipeline (OSS)
  [7] Status dashboard     Show all stage status, open risks, blockers
  [8] New project          Initialize SMS, run tool detect + PDK select

> _
```

---

## Orchestrator FSM

```
IDLE
 │
 ├─[new project]──► INIT: skill_lib_tool_detect + skill_lib_pdk_select + skill_01
 │
 └─[continue]────► RESUME at last incomplete stage
                         │
              ┌──────────▼──────────┐
              │  STAGE_1_SPEC       │  skill_01_spec_intake
              └──────────┬──────────┘
                  GATE-01 (human PM + Arch)
                  ─REJECT─► STAGE_1 (iterate)
                  ─APPROVE─►
              ┌──────────▼──────────┐
              │  STAGE_2_ALGO       │  skill_02_algo_dev
              └──────────┬──────────┘
                  GATE-02 (human)
                  ─REJECT─► STAGE_2 (iterate) or STAGE_1 if spec infeasible
                  ─APPROVE─►
              ┌──────────▼──────────┐
              │  STAGE_3_ARCH       │  skill_03_arch_design
              └──────────┬──────────┘
                  GATE-03 (human Arch Lead + RTL Lead)
                  ─REJECT─► STAGE_3 (iterate) or STAGE_2 if algo mismatch
                  ─APPROVE─►
              ┌──────────┴──────────────────────┐
              │ PARALLEL (launch simultaneously) │
              │  STAGE_4_RTL  skill_04_rtl_design│
              │  STAGE_5_VERIF skill_05_verif    │  both read arch/ artifacts
              └──────────┬──────────────────────┘
                  STAGE_4 signals RTL_FROZEN when lint/CDC clean
                  STAGE_5 runs regression continuously against RTL commits
                  ─STAGE_4 FAIL─► skill_04 internal ECO
                  ─STAGE_5 finds RTL bug─► STAGE_4 (bug fix)
                  GATE-04 (human RTL Lead sign-off on RTL)
                  GATE-05 (human Verif Lead sign-off on coverage)
                  ─BOTH APPROVED─►
              ┌──────────▼──────────┐
              │  STAGE_6_SYNTH      │  skill_06_synthesis
              └──────────┬──────────┘
                  LEC-1 checkpoint (conformal/formality)
                  ─LEC-1 FAIL─► skill_06 ECO
                  ─LEC-1 PASS─►
              ┌──────────▼──────────┐
              │  STAGE_6B_DFT       │  skill_06b_dft
              └──────────┬──────────┘
                  LEC-2 checkpoint (post-DFT)
                  ─LEC-2 FAIL─► skill_06 (ECO netlist)
                  GATE-06 (human Synth+DFT+STA)
                  ─GATE-06 REJECT─► skill_06 re-synth
                  ─GATE-06 APPROVE─►
              ┌──────────▼──────────┐
              │  STAGE_7_PNR        │  skill_07_pnr
              └──────────┬──────────┘
                  in-design STA iterations within skill_07
                  GATE-07 (human PD Lead)
                  ─REJECT─► skill_07 internal ECO or skill_06 re-synth
                  ─APPROVE─►
              ┌──────────┴──────────────────────┐
              │ PARALLEL (launch simultaneously) │
              │  STAGE_8A skill_08a_sta_signoff  │
              │  STAGE_8B skill_08b_physical_verif│
              └──────────┬──────────────────────┘
                  ─STAGE_8A FAIL (timing)─► skill_07 ECO then re-STA
                  ─STAGE_8A FAIL (power) ─► skill_07 PDN ECO
                  ─STAGE_8B FAIL (DRC)   ─► skill_07 DRC ECO
                  ─STAGE_8B FAIL (LVS)   ─► skill_07 or skill_04 (netlist fix)
                  LEC-4 (final RTL vs. final netlist)
                  ─LEC-4 FAIL─► skill_07 ECO + re-LEC
                  GATE-08 (ALL human sign-off leads)
                  ─GATE-08 REJECT─► address specific failing sign-off
                  ─GATE-08 APPROVE─►
              ┌──────────▼──────────┐
              │  STAGE_8C_GDSII     │  skill_08c_gdsii_export
              └──────────┬──────────┘
                  TAPE-OUT COMPLETE ──► IDLE
```

---

## Sub-Agent Launch Protocol

```
For each stage launch:
  1. Load SMS context for that stage (tool, PDK, requirements)
  2. Pass context bundle to sub-agent:
       {stage_id, tool_prefs, design_reqs, error_history, pdk_path}
  3. Register job with job_scheduler MCP server
  4. Monitor via artifact_store MCP server (poll for artifacts)
  5. On GATE_PENDING: notify human via human_review_gateway MCP
  6. On FAIL:
       a. Read error from artifact_store
       b. Append to SMS error_log
       c. Classify error → decide auto-retry or escalate
  7. On PASS: advance FSM, notify next stage(s)

Parallel stage pairs:
  {skill_04_rtl_design, skill_05_verification}  → both need GATE-03 APPROVE
  {skill_08a_sta_signoff, skill_08b_physical_verif} → both need GATE-07 APPROVE
  Parallel stages share artifacts via artifact_store; do NOT block each other.
```

---

## Partial Flow — Prerequisite Check

When starting from Stage N, verify these artifacts exist:

```
Stage 6 (Synthesis) needs:
  ✓ rtl/*.sv or rtl/*.v        (from skill_04)
  ✓ constraints/constraints.sdc (from skill_03 or skill_04)
  ✓ power/MY_CHIP.upf          (from skill_04)
  ✓ PDK liberty files (.lib)   (from skill_lib_pdk_select)

Stage 7 (P&R) needs:
  ✓ netlist/MY_CHIP_dft.v      (from skill_06b)
  ✓ constraints/MY_CHIP_synth.sdc (from skill_06)
  ✓ power/MY_CHIP_synth.upf    (from skill_06)
  ✓ PDK tech LEF + cell LEF   (from skill_lib_pdk_select)

Stage 8A (STA) needs:
  ✓ layout/MY_CHIP.def         (from skill_07)
  ✓ layout/MY_CHIP.spef        (from skill_07)
  ✓ constraints/MY_CHIP_pnr.sdc (from skill_07)

Stage 8B (Phys. Verif) needs:
  ✓ layout/MY_CHIP.gds (stream-in from skill_07)
  ✓ netlist/MY_CHIP_final.cdl  (from skill_07)
  ✓ PDK DRC/LVS runsets        (from skill_lib_pdk_select)
```

---

## Iteration Routing Table

| Failing Stage | Error Class | Route Back To |
|---------------|------------|---------------|
| skill_02_algo_dev | Spec conflict | skill_01_spec_intake |
| skill_03_arch_design | Algo incompatibility | skill_02_algo_dev |
| skill_04_rtl_design | CDC/lint — minor | skill_04 (internal) |
| skill_05_verification | RTL functional bug | skill_04_rtl_design |
| skill_05_verification | Coverage gap in TB | skill_05 (internal) |
| skill_06_synthesis | WNS fail >20% | skill_03_arch_design |
| skill_06_synthesis | WNS fail ≤20% | skill_04_rtl_design |
| skill_06_synthesis | Area over budget | skill_03_arch_design |
| skill_06b_dft | Coverage <97% | skill_06b (ATPG re-run) |
| skill_06b_dft | LEC-2 fail | skill_06_synthesis (ECO) |
| skill_07_pnr | Congestion unresolvable | skill_03_arch_design |
| skill_07_pnr | Timing closure fail | skill_06_synthesis then skill_07 |
| skill_08a_sta_signoff | WNS < 0 | skill_07_pnr (ECO) |
| skill_08a_sta_signoff | IR drop fail | skill_07_pnr (PDN ECO) |
| skill_08b_physical_verif | DRC fail | skill_07_pnr (DRC ECO) |
| skill_08b_physical_verif | LVS fail | skill_07_pnr or skill_04 |
| skill_08c_gdsii_export | Checklist item | Failing upstream skill |

---

## Status Dashboard

```
╔══════════════════════════════════════════════════════════════════════════╗
║              PROJECT STATUS — <design_id>                               ║
╠═════════════════╦═══════════╦══════════════╦════════════════════════════╣
║ Stage           ║ Status    ║ Last Run     ║ Key Metrics                ║
╠═════════════════╬═══════════╬══════════════╬════════════════════════════╣
║ 1. Spec Intake  ║ <status>  ║ <date>       ║ <top metric>               ║
║ 2. Algo Dev     ║ <status>  ║ <date>       ║ <top metric>               ║
║ 3. Arch Design  ║ <status>  ║ <date>       ║ <top metric>               ║
║ 4. RTL Design   ║ <status>  ║ <date>       ║ <top metric>               ║
║ 5. Verification ║ <status>  ║ <date>       ║ <top metric>               ║
║ 6. Synthesis    ║ <status>  ║ <date>       ║ <top metric>               ║
║ 6B. DFT         ║ <status>  ║ <date>       ║ <top metric>               ║
║ 7. P&R          ║ <status>  ║ <date>       ║ <top metric>               ║
║ 8A. STA Sign-Off║ <status>  ║ <date>       ║ <top metric>               ║
║ 8B. Phys. Verif ║ <status>  ║ <date>       ║ <top metric>               ║
║ 8C. GDSII Exp.  ║ <status>  ║ <date>       ║ <top metric>               ║
╠═════════════════╩═══════════╩══════════════╩════════════════════════════╣
║ BLOCKER: <current blocker or "none">                                     ║
║ RISKS:   <open risks from error_log>                                     ║
╚══════════════════════════════════════════════════════════════════════════╝
Status codes: ✓ PASS | ⚡ RUNNING | ⏳ PENDING | ✗ FAIL | ⚠ WARN | — NOT RUN
```

---

## ECO (Engineering Change Order) Workflow

```
ECO TRIGGER: downstream stage detects violation after P&R is complete

1. skill_08a detects: WNS = -15 ps at WC corner
2. Orchestrator receives FAIL signal from skill_08a
3. Orchestrator queries skill_08a for ECO candidates:
     [A] Upsizing 3 cells on critical path → +20 ps
     [B] Buffer insertion on high-fanout net → +18 ps
     [C] Re-route 2 SI-coupled nets → +12 ps
     [D] Re-synthesize critical path subset (skill_06 re-entry)
4. User selects option
5. Orchestrator launches ECO agent (skill_07 in ECO mode):
     → targeted change only — not full re-run
     → LEC-3 checkpoint after ECO (skill_07 triggers LEC-3)
     → re-run STA on affected timing cones only
6. If PASS → continue to skill_08b
   If FAIL → offer next ECO option, or escalate to human
```

---

## LibreLane Automated Flow

```
LIBRELANE MODE (selected when backend_flow = "librelane"):
  Replaces: skill_06, skill_06b (partial), skill_07, skill_08a, skill_08b

  Orchestrator generates config.json from SMS design_requirements:
    DESIGN_NAME, VERILOG_FILES, CLOCK_PORT, CLOCK_PERIOD,
    PDK, STD_CELL_LIBRARY, FP_CORE_UTIL, PL_TARGET_DENSITY,
    GLB_RT_ADJUSTMENT, RUN_LVS, FILL_INSERTION, TAP_DECAP_INSERTION

  Launches: librelane --dockerized run_designs config.json
  Monitors: LibreLane JSON metrics output (parsed in real-time)
  Reports:  synthesis QoR, placement util, CTS skew, routing WL,
            STA WNS/TNS, DRC count, LVS status

  On timing FAIL: presents options →
    [1] Relax clock period (CLOCK_PERIOD ×1.1)
    [2] Increase SYNTH_STRATEGY to DELAY 2
    [3] Reduce FP_CORE_UTIL to reduce routing congestion
    [4] Accept (prototype / learning — document limitation)

  Output: results/<DESIGN_NAME>/final/<DESIGN_NAME>.gds
```

---

*See SKILLS_INDEX.md for full cross-reference map.*
*Iteration routing details: see each stage skill's "Iteration Protocol" section.*
