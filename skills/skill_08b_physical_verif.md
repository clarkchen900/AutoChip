# skill_08b_physical_verif — Physical Verification (DRC / LVS / ERC)
## Stage 8B | Gate: GATE-08 (shared with skill_08a) | Runs parallel with skill_08a_sta_signoff

**Version:** 1.0
**Agent:** agent:physical_verif (primary), agent:pnr (ECO support), agent:pdk (rule deck management)
**Trigger:** GATE-07 approval from skill_07_pnr

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_07_pnr | `layout/MY_CHIP.gds`, `netlist/MY_CHIP_final.cdl` |
| Upstream | skill_lib_pdk_select | DRC/LVS/ERC rule decks, antenna rules, CMP rules |
| Parallel | skill_08a_sta_signoff | Both run after GATE-07; both needed for GATE-08 |
| On DRC fail | skill_07_pnr | ECO fix in P&R; re-stream GDS; re-run DRC |
| On LVS fail (structural) | skill_07_pnr or skill_04_rtl_design | Fix connectivity; re-synthesize if netlist issue |
| On antenna fail | skill_07_pnr | Insert antenna diode ECO; re-route; re-run |
| On ESD/ERC fail | skill_04_rtl_design or skill_07_pnr | Fix IO pad ring or internal structure |
| LEC-4 | Internal (Conformal/Formality) | Final RTL vs. final extracted netlist equivalence |
| Downstream | skill_08c_gdsii_export | Clean DRC+LVS PASS is hard prerequisite |
| Library | skill_lib_memory | Recall physical_verif tool, PDK deck versions |
| Library | skill_lib_pdk_select | Rule deck paths, layer map |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `layout/MY_CHIP.gds` | skill_07 | Yes — physical layout (with fill) |
| `netlist/MY_CHIP_final.cdl` | skill_07 | Yes — CDL for LVS |
| `rtl/*.sv` (top-level) | skill_04 | Yes — LEC-4 source |
| PDK DRC runset | skill_lib_pdk_select | Yes |
| PDK LVS runset | skill_lib_pdk_select | Yes |
| PDK ERC runset | skill_lib_pdk_select | Yes |
| PDK antenna rules | skill_lib_pdk_select | Yes |
| PDK CMP density rules | skill_lib_pdk_select | Yes |

---

## Tool Detection (Physical Verification Subset)

```
PHYSICAL VERIFICATION TOOLS (from skill_lib_tool_detect):
  DRC / LVS / ERC:  <recalled: Calibre / PVS / IC Validator / Magic+Netgen>
  GDS viewer:        KLayout (open — always available for review)

  If tool = "magic_netgen" (open-source, sky130/GF180):
    DRC:  magic -rcfile $PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc
          → load layout; drc check; export drc_errors.txt
    LVS:  netgen -batch lvs "MY_CHIP.spice MY_CHIP" "sky130B_cells.spice MY_CHIP"
    Note: Magic DRC covers most sky130B rules; confirm with foundry for tape-out.
```

---

## Requirements Gathering

```
STAGE 8B: PHYSICAL VERIFICATION REQUIREMENTS
  (Recalled: pdk=<pdk>, phys_verif_tool=<tool>)

── DRC ─────────────────────────────────────────────────────────────────
  DRC tool:                              [recalled: Calibre / Magic]
  DRC runset:                            [auto: <pdk>_CALIBRE_DRC_<version>.drc]
  Run full DRC (all layers):             [yes]
  Voltage-dependent DRC:                 [yes — specify operating voltages]
    Voltages to check:                   [<Vdd_min>, <Vdd_nom> — from SMS]
  CMP density check:                     [yes — separate DRC deck]
  ESD / antenna combined check:          [yes]
  Hierarchical DRC:                      [yes — faster for large designs]
  DRC clean target:                      [0 violations — ALL must be clean]

── LVS ─────────────────────────────────────────────────────────────────
  LVS tool:                              [recalled: Calibre / Netgen]
  LVS runset:                            [auto: <pdk>_CALIBRE_LVS_<version>.lvs]
  Schematic source:                      [netlist/MY_CHIP_final.cdl]
  Layout source:                         [layout/MY_CHIP.gds]
  Top cell name:                         [MY_CHIP]
  Recognize black boxes:                 [yes — SRAM macros, IO cells, analog IP]
  Analog IP instances:                   [list from arch/ams_requirements.yaml or none]
  LVS clean target:                      [CLEAN — 0 net, device, or pin mismatches]

── ERC ─────────────────────────────────────────────────────────────────
  ERC tool:                              [same as LVS tool]
  ESD protection check:                  [yes — HBM <ESD_kV>kV model]
  Latch-up check:                        [yes — verify substrate/well ties]
  ERC clean target:                      [0 violations]

── LEC-4 (Final Equivalence Check) ─────────────────────────────────────
  LEC-4 tool:                            [recalled: Conformal / Formality]
  Compare:                               [RTL source rtl/*.sv vs. final extracted CDL]
  LEC-4 clean target:                    [EQUIVALENT — mandatory before GATE-08]
```

---

## Execution Steps

```
PHYSICAL VERIFICATION EXECUTION (Calibre — adapt for PVS, Magic, or Netgen):

PHASE 1 — DRC
  Step 1:  Run full-chip DRC
           calibre -drc -hier -turbo <N_CPU>
             -rules <pdk>_calibre.drc
             -in layout/MY_CHIP.gds
             -top MY_CHIP
             -out reports/drc_results.db
  Step 2:  Export DRC report
           calibredrv -rdb reports/drc_results.db -report reports/drc_report.txt
  Step 3:  Classify violations:
             0 violations → PASS → proceed to LVS
             >0 violations → categorize (real vs. waiver candidates)
                           → report to skill_07_pnr for ECO
                           → after ECO: re-stream GDS; re-run DRC
  Step 4:  Voltage-dependent DRC (separate deck run for each voltage)
  Step 5:  CMP density check (run density.drc deck)

PHASE 2 — LVS
  Step 6:  Generate CDL from DEF (if not already done in skill_07):
           calibre -lvs -hier -turbo <N_CPU>
             -rules <pdk>_calibre.lvs
             -sp layout/MY_CHIP_extracted.spice   (from QRC extraction)
             -sp netlist/MY_CHIP_final.cdl         (reference)
             -top MY_CHIP
  Step 7:  Export LVS report → reports/lvs_report.txt
  Step 8:  Check:
             CLEAN → proceed
             Mismatches → categorize:
               net mismatch → trace to P&R connectivity or CDL
               device mismatch → trace to IP integration
               pin mismatch → trace to IO pad ring

PHASE 3 — ERC
  Step 9:  Run ERC
           calibre -erc -rules <pdk>_calibre.erc -in layout/MY_CHIP.gds
  Step 10: Check ESD protection on all IO pads
  Step 11: Check latch-up spacing (substrate/well tap distance rules)
  Step 12: Export ERC report → reports/erc_report.txt

PHASE 4 — LEC-4
  Step 13: Run final LEC
           conformal -nogui -dofile lec/lec4_rtl_vs_final.tcl
             (compare rtl/*.sv vs. netlist/MY_CHIP_final.cdl)
           → Result must be EQUIVALENT
           → If NOT EQUIVALENT: identify non-equiv points; ECO; re-run

PHASE 5 — ANTENNA
  Step 14: Verify antenna clean (should be 0 from skill_07 routing)
           (if any remain → ECO diode insertion → re-stream → re-check)
```

---

## Open-Source Flow (Magic + Netgen for sky130/GF180)

```
MAGIC DRC:
  magic -rcfile $PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc << EOF
    load MY_CHIP.mag
    drc check
    drc catchup
    drc count
    drc save drc_errors
  EOF
  → Parse drc_errors.txt for violation count and types
  → Note: Magic DRC covers layout rules; for full foundry DRC, KLayout + PDK rules also used

NETGEN LVS:
  netgen -batch lvs {MY_CHIP.spice MY_CHIP} \
    {$PDK_ROOT/sky130B/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice MY_CHIP} \
    $PDK_ROOT/sky130B/libs.tech/netgen/sky130B_setup.tcl \
    reports/lvs_report.out
  → Parse: "Cells match" = CLEAN; any other result = investigate
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| DRC clean report | `reports/drc_final_clean.rpt` | GATE-08, skill_08c |
| LVS clean report | `reports/lvs_final_clean.rpt` | GATE-08, skill_08c |
| ERC clean report | `reports/erc_final_clean.rpt` | GATE-08, skill_08c |
| Antenna clean report | `reports/antenna_clean.rpt` | GATE-08, skill_08c |
| CMP density report | `reports/cmp_density.rpt` | GATE-08 |
| LEC-4 report | `reports/lec4_final_equiv.rpt` | GATE-08, skill_08c |
| Voltage-dependent DRC | `reports/vdrc_<V>.rpt` | GATE-08 |

---

## Output Metrics

```
PHYSICAL VERIFICATION RESULTS
─────────────────────────────────────────────────────────────────────────
Check                     Result          Target     Status
─────────────────────────────────────────────────────────────────────────
DRC violations            <N>             0          ?
  (if >0) ECO iterations  <N> → <final>   0 at GATE  ?
LVS status                <CLEAN/FAIL>    CLEAN      ?
  Net mismatches           <N>             0          ?
  Device mismatches        <N>             0          ?
  Pin mismatches           <N>             0          ?
ERC violations            <N>             0          ?
  ESD violations           <N>             0          ?
  Latch-up violations      <N>             0          ?
Antenna violations        <N>             0 (fixed)  ?
CMP density               <in-spec/fail>  in-spec    ?
Voltage DRC (<Vnom>V)     <N>             0          ?
Voltage DRC (<Vmin>V)     <N>             0          ?
LEC-4 (RTL vs. CDL)       <EQUIV/FAIL>    EQUIVALENT ?
─────────────────────────────────────────────────────────────────────────
Overall: <PASS/FAIL> → GATE-08 (physical portion)
```

---

## Quality Gate: GATE-08 (Physical Verification portion)

```
GATE-08 PHYSICAL CRITERIA (human sign-off):
  □ DRC: 0 violations (Calibre/Magic — final deck, final run)
  □ LVS: CLEAN — 0 net, device, pin mismatches
  □ ERC: 0 violations (ESD + latch-up)
  □ Antenna: 0 violations
  □ CMP density: within spec bounds
  □ Voltage-dependent DRC: 0 at all operating voltages
  □ LEC-4: RTL vs. final CDL = EQUIVALENT

Note: GATE-08 requires BOTH skill_08a (STA/power) AND skill_08b (phys. verif) to PASS.
Approvers: Physical Verification Engineer + PDK Engineer
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| DRC violations | Route specific violation layer/type to skill_07_pnr ECO; re-stream; re-DRC |
| LVS net mismatch | Trace to P&R routing ECO or CDL generation; fix; re-LVS |
| LVS device mismatch | Trace to analog IP integration or IO cell; fix; re-LVS |
| ESD violation (IO pad) | Fix IO pad ring structure; return to skill_07_pnr |
| Latch-up violation | Insert substrate/well tap ECO in skill_07_pnr; re-run ERC |
| LEC-4 non-equivalent | Identify divergence point; trace to P&R ECO or synthesis netlist; fix; re-run |
| Antenna violation (residual) | Insert antenna diode in skill_07_pnr ECO; re-route; re-check |
| CMP density fail | Add metal fill or adjust fill density in skill_07_pnr; re-check |

---

## Memory Write

```yaml
execution_history:
  physical_verif:
    - timestamp: <ISO8601>
      result: <PASS/FAIL>
      tool: <physical_verif_tool>
      pdk_deck_version: <version>
      metrics:
        drc_violations: 0
        lvs_status: CLEAN
        erc_violations: 0
        antenna_violations: 0
        cmp_density: in_spec
        lec4_result: EQUIVALENT
      eco_iterations: <N>
      artifacts: [reports/drc_final_clean.rpt, reports/lvs_final_clean.rpt,
                  reports/lec4_final_equiv.rpt]
      gate: GATE-08 (partial)
```

---

*Previous: [`skill_07_pnr.md`](skill_07_pnr.md)*
*Parallel: [`skill_08a_sta_signoff.md`](skill_08a_sta_signoff.md)*
*Next: [`skill_08c_gdsii_export.md`](skill_08c_gdsii_export.md) (after GATE-08 with skill_08a)*
*ECO target: [`skill_07_pnr.md`](skill_07_pnr.md)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
