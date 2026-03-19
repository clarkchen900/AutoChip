# skill_08c_gdsii_export — GDSII Tape-Out Export
## Stage 8C | Final Gate: GATE-08 (tape-out sign-off)

**Version:** 1.0
**Agent:** agent:orch (primary coordinator), agent:physical_verif (GDS verification), agent:pdk (layer map)
**Trigger:** GATE-08 approval — BOTH skill_08a AND skill_08b must PASS

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream (hard prerequisites) | skill_08a_sta_signoff | STA/power sign-off reports — ALL must be PASS |
| Upstream (hard prerequisites) | skill_08b_physical_verif | DRC/LVS/ERC/LEC-4 — ALL must be PASS |
| Upstream | skill_07_pnr | `layout/MY_CHIP.gds` (source layout), `layout/MY_CHIP.def` |
| Upstream | skill_06b_dft | `dft/patterns/MY_CHIP.stil` (ATE patterns for tape-out package) |
| Upstream | skill_lib_pdk_select | Layer map file, cell GDS merge list |
| On ANY prerequisite FAIL | Failing skill | Do NOT proceed — route back to failing skill |
| Downstream | Foundry | GDSII + tape-out package delivered to foundry portal |
| Library | skill_lib_memory | Recall all design ID, PDK, tool choices |

---

## Hard Prerequisites (All must be GREEN before this skill activates)

```
PRE-TAPE-OUT PREREQUISITE CHECK
══════════════════════════════════════════════════════════════════════════
Source Skill        Check                                 Required Status
══════════════════════════════════════════════════════════════════════════
skill_08a           WNS ≥ 0 ps — all corners (setup)     PASS
skill_08a           TNS = 0                               PASS
skill_08a           Hold slack ≥ 0 — all corners          PASS
skill_08a           Scan shift hold OCC ≥ 0 ps            PASS (BLOCKING)
skill_08a           EOL timing WNS ≥ 0                    PASS (AEC-Q100)
skill_08a           Active power ≤ spec                   PASS
skill_08a           Static IR drop ≤ 5% VDD               PASS
skill_08a           Dynamic IR drop ≤ 5% VDD              PASS
skill_08a           EM: 0 violations                      PASS
skill_08b           DRC: 0 violations                     PASS
skill_08b           LVS: CLEAN                            PASS
skill_08b           ERC: 0 violations (ESD + latch-up)   PASS
skill_08b           Antenna: 0 violations                 PASS
skill_08b           CMP density: in-spec                  PASS
skill_08b           LEC-4: EQUIVALENT                     PASS
skill_06b           Stuck-at coverage ≥ 99%               PASS
skill_06b           Transition coverage ≥ 97%             PASS
GATE-08             Human sign-off signatures collected   REQUIRED
══════════════════════════════════════════════════════════════════════════
Any RED item → HALT. Do not proceed. Route to failing skill.
```

---

## Requirements Gathering

```
STAGE 8C: GDSII TAPE-OUT REQUIREMENTS
  (All recalled from SMS — confirm before proceeding)

── OUTPUT FORMAT ────────────────────────────────────────────────────────
  Output format:          [GDSII binary / OASIS compressed / both]
  Top cell name:          [recalled: <design_id>]
  Layer mapping file:     [auto: <pdk>_layer_map.map — confirmed present ✓]
  Merge all sub-cells:    [yes — single stream file with all referenced cells]
  Include fill cells:     [yes — metal fill must be in final GDS]
  Include IO cells:       [yes — IO pad ring GDS merged in]
  Include analog IP GDS:  [yes — merge <PLL>.gds, <ADC>.gds, etc. if present]
  Flatten for foundry:    [no (keep hierarchy — DFM review uses hierarchy)]
  Compress output (gzip): [yes]

── INTEGRITY VERIFICATION ───────────────────────────────────────────────
  Re-run DRC on final streamed GDS:  [yes — mandatory final check]
  KLayout DRC cross-check:           [yes / no — open-source double-check]
  Compute SHA-256 checksum:          [yes — record in tape-out package]
  Verify layer map completeness:     [yes — all used layers must be mapped]

── FOUNDRY SUBMISSION ────────────────────────────────────────────────────
  Foundry:                [TSMC / GF / Samsung / efabless / specify]
  Submission method:      [foundry portal / secure FTP / physical media]
  Foundry DRC deck ver.:  [confirm matches tape-out submission requirement]
  Chip ID / lot mark:     [yes — verify ID layers in layout]
  IP disclosure forms:    [confirm all 3rd-party IP is disclosed]
  NDA / license check:    [confirm all cell library IP licensed for tape-out]

── TAPE-OUT PACKAGE CONTENTS ────────────────────────────────────────────
  [✓] Final GDSII (or OASIS)
  [✓] Final CDL netlist
  [✓] Final SDC (all corners)
  [✓] LEC-4 report (equivalent)
  [✓] Final DRC clean report
  [✓] Final LVS clean report
  [✓] ERC clean report
  [✓] STA sign-off report (all corners)
  [✓] EOL timing report (if AEC-Q100)
  [✓] Power sign-off report
  [✓] DFT ATPG patterns (STIL)
  [✓] DFT coverage report
  [✓] Sign-off checklist (signed)
  [✓] IP disclosure / license forms
```

---

## Execution Steps

```
GDSII EXPORT EXECUTION:

Step 1: FINAL LAYER MAP VERIFICATION
  Verify all GDS layers used in layout are present in <pdk>_layer_map.map
  Any unmapped layer → STOP; resolve with PDK engineer before proceeding

Step 2: GDS STREAM-OUT (Innovus / ICC2 / Magic)
  Innovus:
    streamOut layout/MY_CHIP_final.gds \
      -mapFile $PDK_ROOT/<pdk>_layer_map.map \
      -merge {$PDK_ROOT/stdcell.gds $PDK_ROOT/io.gds $ANALOG_IP_GDS_LIST} \
      -snapToMGrid 1 \
      -libName MY_CHIP
  ICC2:
    write_gds -output layout/MY_CHIP_final.gds \
      -layer_map $PDK_ROOT/<pdk>_layer_map.map \
      -include_pg_pins
  Magic (open-source):
    magic -rcfile $PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc << EOF
      load MY_CHIP
      gds write layout/MY_CHIP_final.gds
    EOF
  OASIS (if required):
    calibredrv -gds2oasis layout/MY_CHIP_final.gds layout/MY_CHIP_final.oas

Step 3: FINAL INTEGRITY DRC ON STREAMED GDS
  Run DRC on layout/MY_CHIP_final.gds (not on in-memory DEF)
  calibre -drc -hier -turbo <N_CPU> \
    -rules <pdk>_calibre.drc \
    -in layout/MY_CHIP_final.gds \
    -top MY_CHIP
  → Result must be 0 violations (confirms stream-out didn't introduce errors)

  KLayout cross-check (open-source, always run):
    klayout layout/MY_CHIP_final.gds \
      -r $PDK_ROOT/<pdk>_klayout.lydrc \
      -rd input=layout/MY_CHIP_final.gds \
      -rd report=reports/klayout_drc_final.lyrdb

Step 4: SHA-256 INTEGRITY CHECK
  sha256sum layout/MY_CHIP_final.gds > tapeout/MY_CHIP_final.gds.sha256
  sha256sum layout/MY_CHIP_final.oas >> tapeout/MY_CHIP_final.oas.sha256

Step 5: TAPE-OUT PACKAGE ASSEMBLY
  mkdir -p tapeout/package/
  cp layout/MY_CHIP_final.gds          tapeout/package/
  cp layout/MY_CHIP_final.oas          tapeout/package/   (if generated)
  cp netlist/MY_CHIP_final.cdl         tapeout/package/
  cp constraints/MY_CHIP_pnr.sdc       tapeout/package/
  cp dft/patterns/MY_CHIP.stil         tapeout/package/
  cp reports/drc_final_clean.rpt       tapeout/package/reports/
  cp reports/lvs_final_clean.rpt       tapeout/package/reports/
  cp reports/erc_final_clean.rpt       tapeout/package/reports/
  cp reports/sta_final_signoff.rpt     tapeout/package/reports/
  cp reports/power_active.rpt          tapeout/package/reports/
  cp reports/em_signoff.rpt            tapeout/package/reports/
  cp reports/lec4_final_equiv.rpt      tapeout/package/reports/
  cp reports/dft_coverage.rpt          tapeout/package/reports/
  cp tapeout/signoff_checklist_final.pdf tapeout/package/
  # IP disclosure forms — added manually by PM
  tar -czf tapeout/MY_CHIP_v1.0_tapeout_package.tar.gz tapeout/package/

Step 6: FOUNDRY SUBMISSION
  Upload to foundry portal or transfer per foundry instructions.
  Record: submission timestamp, foundry job ID, contact name.
  Write to SMS: project.tapeout_submitted = <ISO8601_timestamp>
```

---

## Pre-Tape-Out Sign-Off Checklist (Human-Confirmed)

```
╔══════════════════════════════════════════════════════════════════════════╗
║          TAPE-OUT SIGN-OFF CHECKLIST — ALL ITEMS MUST BE CHECKED        ║
╠══════════════════════════════════════════════════════════════════════════╣
║ TIMING & POWER                                                           ║
║ [✓/✗] DRC: 0 violations (Calibre — final deck version confirmed)        ║
║ [✓/✗] LVS: CLEAN (CDL vs. extracted)                                   ║
║ [✓/✗] ERC: 0 violations (ESD + latch-up)                               ║
║ [✓/✗] Antenna: 0 violations                                             ║
║ [✓/✗] LEC-4: RTL vs. final CDL = EQUIVALENT                           ║
║ [✓/✗] STA: WNS ≥ 0 all corners including EOL (if AEC-Q100)            ║
║ [✓/✗] Scan shift hold on OCC paths: ≥ 0 ps                             ║
║ [✓/✗] Active power ≤ spec; IR drop ≤ 5% VDD; EM clean                 ║
║                                                                          ║
║ DFT                                                                      ║
║ [✓/✗] Stuck-at ≥ 99%, Transition ≥ 97%, PA ≥ 90%, Cell-aware ≥ 98%  ║
║ [✓/✗] ATPG patterns generated and verified (STIL format)               ║
║                                                                          ║
║ PHYSICAL                                                                 ║
║ [✓/✗] IO ring complete: all pads, ESD cells, corner cells present       ║
║ [✓/✗] Chip label / ID / lot marking layers included in GDS              ║
║ [✓/✗] Metal fill inserted (CMP density within bounds)                  ║
║ [✓/✗] GDS layer map matches foundry tape-out submission spec            ║
║ [✓/✗] Final DRC run on streamed GDS (not in-memory DEF)                ║
║ [✓/✗] KLayout cross-check: 0 violations                                ║
║ [✓/✗] SHA-256 checksums computed and recorded                          ║
║                                                                          ║
║ LEGAL / IP                                                               ║
║ [✓/✗] All 3rd-party IP licenses cleared for this foundry / node        ║
║ [✓/✗] IP disclosure forms complete                                      ║
║ [✓/✗] NDA covers all PDK content in submission package                 ║
║ [✓/✗] Foundry DRC deck version matches submission requirement           ║
║                                                                          ║
║ HUMAN SIGN-OFFS                                                          ║
║ [✓/✗] RTL Lead:     _______________________ Date: _______              ║
║ [✓/✗] Verif Lead:   _______________________ Date: _______              ║
║ [✓/✗] STA Engineer: _______________________ Date: _______              ║
║ [✓/✗] PD Lead:      _______________________ Date: _______              ║
║ [✓/✗] Phys. Verif:  _______________________ Date: _______              ║
║ [✓/✗] PM:           _______________________ Date: _______              ║
╚══════════════════════════════════════════════════════════════════════════╝

All items must be [✓] before proceeding.
Type 'CONFIRM TAPE-OUT <design_id>' to finalize.
> _
```

---

## Output Artifacts

| Artifact | Path | Destination |
|----------|------|-------------|
| Final GDSII | `tapeout/MY_CHIP_final.gds` | Foundry |
| Final OASIS (if needed) | `tapeout/MY_CHIP_final.oas` | Foundry |
| Final CDL | `tapeout/package/MY_CHIP_final.cdl` | Foundry |
| Final SDC | `tapeout/package/MY_CHIP_pnr.sdc` | Foundry |
| ATPG patterns (STIL) | `tapeout/package/MY_CHIP.stil` | ATE / Foundry |
| DRC clean report | `tapeout/package/reports/drc_final_clean.rpt` | Foundry |
| LVS clean report | `tapeout/package/reports/lvs_final_clean.rpt` | Foundry |
| STA sign-off report | `tapeout/package/reports/sta_final_signoff.rpt` | Foundry / archive |
| Sign-off checklist | `tapeout/signoff_checklist_final.pdf` | Foundry / legal |
| Tape-out package | `tapeout/MY_CHIP_v1.0_tapeout_package.tar.gz` | Foundry |
| SHA-256 checksums | `tapeout/MY_CHIP_final.gds.sha256` | Archive |

---

## Post-Submission Actions

```
After foundry confirmation of receipt:
  1. Archive tape-out package to secure long-term storage
  2. Record in SMS:
       project.tapeout_submitted = <ISO8601>
       project.foundry_job_id    = <foundry_ref>
  3. Notify team via human_review_gateway MCP
  4. Trigger post-silicon planning (Stage 9 — post-silicon validation)
     → see ASIC_MultiAgent_Framework.md §20 for Stage 9 details
  5. Retain all sign-off reports for minimum 5 years (automotive: 15 years)

TAPE-OUT COMPLETE:
  ✓ <design_id> — <timestamp>
  Foundry: <foundry> | Package: <file> | SHA-256: <hash>
```

---

## Memory Write

```yaml
project:
  tapeout_submitted: <ISO8601>
  foundry_job_id: <id>
execution_history:
  gdsii_export:
    - timestamp: <ISO8601>
      result: PASS
      artifacts:
        gds: tapeout/MY_CHIP_final.gds
        package: tapeout/MY_CHIP_v1.0_tapeout_package.tar.gz
        sha256: <hash>
      checklist_all_green: true
      gate: GATE-08 (tape-out)
      foundry: <foundry>
      foundry_job_id: <id>
```

---

*Previous: [`skill_08a_sta_signoff.md`](skill_08a_sta_signoff.md) + [`skill_08b_physical_verif.md`](skill_08b_physical_verif.md)*
*Orchestrator: [`skill_00_orchestrator.md`](skill_00_orchestrator.md)*
*Post-silicon: see `ASIC_MultiAgent_Framework.md` §20*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
