# skill_06b_dft — DFT Insertion & ATPG
## Stage 6B | Checkpoint: LEC-2 | Gate: GATE-06 (full sign-off)

**Version:** 1.0
**Agent:** agent:dft (primary), agent:synth + agent:sta (review)
**Trigger:** LEC-1 PASS from skill_06_synthesis (gate-level netlist available)

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_06_synthesis | `netlist/MY_CHIP_synth.v`, `constraints/MY_CHIP_synth.sdc`, `power/MY_CHIP_synth.upf` |
| Downstream | skill_07_pnr | `netlist/MY_CHIP_dft.v`, `constraints/MY_CHIP_dft.sdc` (DFT-aware constraints) |
| Downstream | skill_05_verification | `netlist/MY_CHIP_dft.v` + SDF for GLS phase |
| Downstream | skill_08c_gdsii_export | `dft/patterns/MY_CHIP_final.stil` (ATE patterns) |
| LEC-2 checkpoint | Internal (Conformal/Formality) | Pre-DFT vs. post-DFT netlist equivalence |
| On LEC-2 FAIL | skill_06_synthesis | ECO on synthesis netlist before DFT re-run |
| On coverage <97% | skill_06b_dft | ATPG re-run (internal iteration) |
| Library | skill_lib_memory | Recall DFT tool, coverage targets |
| Library | skill_lib_pdk_select | OCC cell models, BIST macros from PDK |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `netlist/MY_CHIP_synth.v` | skill_06 | Yes |
| `constraints/MY_CHIP_synth.sdc` | skill_06 | Yes |
| `power/MY_CHIP_synth.upf` | skill_06 | Yes (for PA-aware DFT) |
| OCC cell models | skill_lib_pdk_select | Yes (for at-speed test) |
| MBIST macros (if SRAM present) | skill_lib_pdk_select | Conditional |

---

## Tool Detection (DFT Subset)

```
DFT TOOLS (from skill_lib_tool_detect):
  DFT tool:     <recalled: Modus (Cadence) / Tessent (Mentor-Siemens) / OpenROAD DFT (basic)>
  Fault sim:    Uses primary simulator (recalled: <simulator>)
  BIST:         <Cadence MBIST / Mentor MBIST / custom / none>
  ATE format:   STIL / WGL / ASCII-WGL / Verilog patterns

  PDK OCC cells:  <check PDK for OCC models — required for transition/path-delay ATPG>
  PDK BIST ctrl:  <check PDK for embedded BIST IP>
```

---

## Requirements Gathering

```
STAGE 6B: DFT REQUIREMENTS
  (Recalled: sa_target=<pct>%, trans_target=<pct>%, ca_target=<pct>%)

── TEST ARCHITECTURE ───────────────────────────────────────────────────
  Scan insertion:                        [yes]
  Scan compression:                      [yes (reduces test time & cost)]
    Compression ratio:                   [64× default — range 32–128×]
  Memory BIST (MBIST):                   [yes if SRAM present / no]
  Logic BIST (LBIST):                    [no (adds area) / yes]
  Boundary scan (IEEE 1149.1 JTAG):     [yes / no]
  OCC for at-speed test:                 [yes — required for transition & path-delay]

── FAULT COVERAGE TARGETS ──────────────────────────────────────────────
  Stuck-at fault coverage (%):          [recalled: 99]
  Transition fault coverage (%):        [recalled: 97]
  Path delay fault coverage (%):        [recalled: 90]
  Cell-aware ATPG coverage (%):         [recalled: 98]
  Untestable faults (AU+UO+UU) (%):    [≤0.5]

── TEST MODES ──────────────────────────────────────────────────────────
  Normal mission mode:                   [yes — always]
  Slow-speed scan (capture = slow):      [yes]
  Fast capture / at-speed (transition):  [yes — requires OCC]
  IDDQ testing:                          [yes / no — depends on PDK]
  Differential power analysis guards:    [yes for security IPs / no]

── SCAN ARCHITECTURE ───────────────────────────────────────────────────
  Target FFs per scan chain:             [2000–5000 (default auto)]
  Scan chain count:                      [auto — calculated from FF count]
  ATE pattern count target:              [≤5000 patterns]
  ATE format:                            [STIL (default) / WGL / Verilog]

── POWER DOMAIN AWARENESS ──────────────────────────────────────────────
  Always-on scan path through retention domain: [yes — maintain scan path]
  OCC clock routing (shielded):          [yes — OCC nets treated as clock nets]
  Scan shift IR drop check:              [yes — worst-case switching in shift mode]
```

---

## Execution Steps

```
DFT EXECUTION (Modus / Tessent — adapt as needed):

  Step 1:  Read synthesis netlist  read_netlist netlist/MY_CHIP_synth.v
  Step 2:  Read SDC               read_sdc constraints/MY_CHIP_synth.sdc
  Step 3:  Read UPF               read_power_intent power/MY_CHIP_synth.upf
  Step 4:  DFT rules check        check_dft_rules
  Step 5:  Insert scan            insert_dft -scan_compression -ratio 64
  Step 6:  Insert OCC             insert_occ -clock <list>
  Step 7:  MBIST insertion        (if SRAM present) insert_mbist -srams <list>
  Step 8:  ATPG patterns          atpg -stuck_at / -transition / -path_delay / -cell_aware
  Step 9:  Fault simulation       fault_simulate → measure coverage per fault class
  Step 10: Compress patterns      compress_patterns -target_count 5000
  Step 11: Write DFT netlist      write_verilog > netlist/MY_CHIP_dft.v
  Step 12: Write DFT SDC          write_sdc > constraints/MY_CHIP_dft.sdc
  Step 13: Write STIL patterns    write_patterns > dft/patterns/MY_CHIP.stil -format STIL
  Step 14: Write ATPG report      report_coverage > reports/dft_coverage.rpt

  LEC-2 CHECKPOINT:
  Step 15: Run LEC               conformal -dofile lec/lec_synth_vs_dft.tcl
             → Compare: netlist/MY_CHIP_synth.v vs. netlist/MY_CHIP_dft.v
             → Result must be EQUIVALENT
             → If NOT EQUIVALENT: diagnose scan insertion issue; fix; re-run
```

---

## OCC (On-Chip Clock Controller) Protocol

```
OCC INSERTION:
  OCC cells are inserted at every clock root in the design.
  OCC functions:
    Mission mode:   pass functional clock through unmodified
    Scan shift:     slow clock (e.g., 10 MHz) for shift operations
    Capture:        fast functional clock (1 GHz) for at-speed capture

  OCC net constraints (added to DFT SDC):
    - OCC output treated as generated clock in STA
    - OCC paths included in max-SDF GLS
    - Scan shift hold timing on OCC paths = BLOCKING gate in skill_08a

  Verify OCC in simulation:
    skill_05 GLS modes include OCC clock switching — validate in GLS
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| DFT gate-level netlist | `netlist/MY_CHIP_dft.v` | skill_07_pnr, skill_05 (GLS) |
| DFT-aware SDC | `constraints/MY_CHIP_dft.sdc` | skill_07_pnr, skill_08a |
| ATPG patterns (STIL) | `dft/patterns/MY_CHIP.stil` | skill_08c (tape-out package) |
| MBIST controller netlist | `netlist/mbist_ctrl.v` | skill_07_pnr |
| LEC-2 report | `reports/lec2_synth_vs_dft.rpt` | GATE-06 review |
| DFT coverage report | `reports/dft_coverage.rpt` | GATE-06 review |
| Scan chain file | `dft/scan_chains.def` | skill_07_pnr (scan ordering) |

---

## Output Metrics

```
DFT RESULTS
─────────────────────────────────────────────────────────────────────
Metric                     Value      Target        Status
─────────────────────────────────────────────────────────────────────
Stuck-at coverage (%)      <value>    ≥99%          ?
Transition coverage (%)    <value>    ≥97%          ?
Path delay coverage (%)    <value>    ≥90%          ?
Cell-aware coverage (%)    <value>    ≥98%          ?
Untestable faults (%)      <value>    ≤0.5%         ?
Scan chain count           <N>        —             INFO
FFs per chain (avg)        <N>        2000–5000     ?
Compression ratio          <N>×       ≥50×          ?
Pattern count (ATPG total) <N>        ≤5000         ?
MBIST controllers          <N>        —             INFO
DFT area overhead (%)      <value>    ≤8%           ?
LEC-2 (synth vs. DFT)      <result>   EQUIVALENT    ?
─────────────────────────────────────────────────────────────────────
Overall: <PASS/FAIL> → GATE-06 (full)
```

---

## Quality Gate: GATE-06 (Full — synthesis + DFT combined)

```
GATE-06 CRITERIA (human Synth + DFT + STA approval):
  From skill_06_synthesis:
  □ WNS ≥ +<20% period> all setup corners
  □ TNS = 0; hold slack ≥ 0
  □ LEC-1: EQUIVALENT
  □ ICG coverage ≥ 80%

  From skill_06b_dft:
  □ Stuck-at coverage ≥ 99%
  □ Transition coverage ≥ 97%
  □ Path delay coverage ≥ 90%
  □ Cell-aware coverage ≥ 98%
  □ Untestable faults ≤ 0.5%
  □ OCC insertion verified
  □ LEC-2 (synth vs. DFT netlist): EQUIVALENT
  □ DFT SDC updated with OCC constraints
  □ MBIST coverage (if SRAM): ≥99%

Approvers: Synthesis Engineer + DFT Engineer + STA Engineer
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| Stuck-at coverage <97% | Identify untestable faults; add test points; re-run ATPG |
| Transition coverage <95% | Check OCC insertion; add more transition patterns |
| LEC-2 FAIL | Diagnose non-equivalent points; fix scan insertion constraints; re-run DFT |
| DFT area overhead >10% | Reduce compression ratio; remove LBIST if present |
| Pattern count >8000 | Increase compression; apply pattern compaction |
| OCC timing violation | Adjust OCC constraints in SDC; re-run STA |

---

## Memory Write

```yaml
execution_history:
  dft:
    - timestamp: <ISO8601>
      result: <PASS/FAIL>
      tool: <dft_tool>
      metrics:
        sa_coverage_pct: <value>
        trans_coverage_pct: <value>
        pa_coverage_pct: <value>
        ca_coverage_pct: <value>
        scan_chains: <N>
        compression_ratio: <N>
        pattern_count: <N>
        area_overhead_pct: <value>
        lec2_result: EQUIVALENT
      artifacts: [netlist/MY_CHIP_dft.v, dft/patterns/MY_CHIP.stil]
      gate: GATE-06
```

---

*Previous: [`skill_06_synthesis.md`](skill_06_synthesis.md)*
*Next: [`skill_07_pnr.md`](skill_07_pnr.md)*
*GLS feeds back to: [`skill_05_verification.md`](skill_05_verification.md)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
