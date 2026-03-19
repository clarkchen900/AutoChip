# ASIC Multi-Agent Skills — Index
## EDA Flow Skill Library v1.0

**Parent framework:** `../ASIC_MultiAgent_Framework.md` v3.0
**Monolithic source:** `../ASIC_Skills_Framework.md` (reference only — use individual skills below)

---

## Skill Map

```
ORCHESTRATOR (skill_00)
│
├─► GATE-01 ──► skill_01_spec_intake        Stage 1  Product Specification
├─► GATE-02 ──► skill_02_algo_dev           Stage 2  Algorithm Development
├─► GATE-03 ──► skill_03_arch_design        Stage 3  Architecture Design
│
├─► GATE-04 ─┬─► skill_04_rtl_design        Stage 4  RTL & UPF Design   ─┐ parallel
│            └─► skill_05_verification       Stage 5  Functional Verif   ─┘
│
├─► GATE-05/06 ─┬─► skill_06_synthesis      Stage 6  Logic Synthesis     ─┐ sequential
│               └─► skill_06b_dft           Stage 6B DFT Insertion        ─┘ then parallel
│
├─► GATE-06 ──► skill_07_pnr               Stage 7  Physical Design / P&R
│
└─► GATE-07 ─┬─► skill_08a_sta_signoff     Stage 8A Timing & Power Sign-Off ─┐ parallel
             ├─► skill_08b_physical_verif   Stage 8B Physical Verification    ─┤
             └─► skill_08c_gdsii_export     Stage 8C GDSII Tape-Out  (GATE-08)─┘
```

---

## Skill Files

### Library Skills (shared by all stage skills)
| File | Purpose |
|------|---------|
| [`skill_lib_memory.md`](skill_lib_memory.md) | Skill Memory Store (SMS) schema, read/write protocol, preference learning |
| [`skill_lib_tool_detect.md`](skill_lib_tool_detect.md) | Tool detection, suite quick-select, LibreLane/open-source stack |
| [`skill_lib_pdk_select.md`](skill_lib_pdk_select.md) | PDK detection, selection dialog, capability matrix |

### Orchestration
| File | Stage | Trigger |
|------|-------|---------|
| [`skill_00_orchestrator.md`](skill_00_orchestrator.md) | All | User launch or CI trigger |

### Stage Skills
| File | Stage | Gate In | Gate Out | Parallel With |
|------|-------|---------|----------|---------------|
| [`skill_01_spec_intake.md`](skill_01_spec_intake.md) | 1 — Spec | — | GATE-01 | — |
| [`skill_02_algo_dev.md`](skill_02_algo_dev.md) | 2 — Algo | GATE-01 | GATE-02 | — |
| [`skill_03_arch_design.md`](skill_03_arch_design.md) | 3 — Arch | GATE-02 | GATE-03 | — |
| [`skill_04_rtl_design.md`](skill_04_rtl_design.md) | 4 — RTL | GATE-03 | GATE-04 | skill_05_verification |
| [`skill_05_verification.md`](skill_05_verification.md) | 5 — Verif | GATE-03 | GATE-05 | skill_04_rtl_design |
| [`skill_06_synthesis.md`](skill_06_synthesis.md) | 6 — Synth | GATE-05 | LEC-1 | — |
| [`skill_06b_dft.md`](skill_06b_dft.md) | 6B — DFT | LEC-1 | GATE-06 | — |
| [`skill_07_pnr.md`](skill_07_pnr.md) | 7 — P&R | GATE-06 | GATE-07 | — |
| [`skill_08a_sta_signoff.md`](skill_08a_sta_signoff.md) | 8A — STA | GATE-07 | GATE-08 | skill_08b_physical_verif |
| [`skill_08b_physical_verif.md`](skill_08b_physical_verif.md) | 8B — DRC/LVS | GATE-07 | GATE-08 | skill_08a_sta_signoff |
| [`skill_08c_gdsii_export.md`](skill_08c_gdsii_export.md) | 8C — GDSII | GATE-08 | Tape-Out | — |

---

## Iteration Loops (Fail → Retry)

| Failing Stage | Root Cause Class | Iterate Back To |
|---------------|-----------------|-----------------|
| skill_02_algo_dev | Spec conflict, infeasible target | skill_01_spec_intake |
| skill_03_arch_design | Algo incompatibility | skill_02_algo_dev |
| skill_04_rtl_design | CDC/lint violations | skill_04_rtl_design (internal ECO) |
| skill_05_verification | RTL bug found | skill_04_rtl_design |
| skill_05_verification | Coverage gap in TB | skill_05_verification (internal ECO) |
| skill_06_synthesis | WNS fail >20% | skill_03_arch_design (timing budget) |
| skill_06_synthesis | WNS fail ≤20% | skill_04_rtl_design (critical path RTL) |
| skill_06_synthesis | Area over budget | skill_03_arch_design (re-partition) |
| skill_06b_dft | Coverage <97% | skill_06b_dft (ATPG re-run) |
| skill_06b_dft | LEC-2 fail | skill_06_synthesis (ECO netlist) |
| skill_07_pnr | Congestion unresolvable | skill_03_arch_design (re-floorplan) |
| skill_07_pnr | Timing closure fail | skill_06_synthesis (re-synth) |
| skill_08a_sta_signoff | WNS < 0 | skill_07_pnr (ECO route) then skill_06_synthesis |
| skill_08a_sta_signoff | IR drop fail | skill_07_pnr (PDN ECO) |
| skill_08b_physical_verif | DRC fail | skill_07_pnr (DRC ECO) |
| skill_08b_physical_verif | LVS fail | skill_07_pnr or skill_04_rtl_design |
| skill_08c_gdsii_export | Pre-tape-out checklist fail | Failing upstream skill |

---

## Cross-Reference Quick Lookup

### By Artifact
| Artifact | Produced By | Consumed By |
|----------|-------------|-------------|
| `spec/product_spec.yaml` | skill_01 | skill_02, skill_03, skill_00 |
| `algo/golden_model.*` | skill_02 | skill_03, skill_05 |
| `arch/clock_domains.yaml` | skill_03 | skill_04, skill_06, skill_07 |
| `arch/power_intent.yaml` | skill_03 | skill_04 (UPF), skill_06, skill_07 |
| `rtl/*.sv` | skill_04 | skill_05, skill_06 |
| `power/MY_CHIP.upf` | skill_04 | skill_06, skill_07, skill_08a |
| `netlist/MY_CHIP_synth.v` | skill_06 | skill_06b, skill_05 (GLS), skill_07 |
| `netlist/MY_CHIP_dft.v` | skill_06b | skill_07, skill_05 (GLS) |
| `constraints/MY_CHIP_synth.sdc` | skill_06 | skill_06b, skill_07, skill_08a |
| `layout/MY_CHIP.def` | skill_07 | skill_08a, skill_08b |
| `layout/MY_CHIP.spef` | skill_07 | skill_08a |
| `dft/patterns/*.stil` | skill_06b | skill_08c |
| `tapeout/MY_CHIP_final.gds` | skill_08c | Foundry submission |

### By Gate
| Gate | Blocking Skill | Approver |
|------|---------------|----------|
| GATE-01 | skill_01_spec_intake | PM + Arch Lead |
| GATE-02 | skill_02_algo_dev | Algo + Arch |
| GATE-03 | skill_03_arch_design | Arch Lead + RTL Lead |
| GATE-04 | skill_04_rtl_design | RTL Lead |
| GATE-05 | skill_05_verification | Verif Lead |
| GATE-06 | skill_06b_dft | Synth + DFT + STA |
| GATE-07 | skill_07_pnr | PD Lead |
| GATE-08 | skill_08a + skill_08b | All sign-off leads |
| Tape-Out | skill_08c_gdsii_export | PM + foundry |

---

*Skills are designed to be loaded individually by sub-agents. Each skill file is self-contained with embedded cross-references. Load `skill_lib_memory.md`, `skill_lib_tool_detect.md`, and `skill_lib_pdk_select.md` first as shared context.*
