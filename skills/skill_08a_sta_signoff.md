# skill_08a_sta_signoff — Timing & Power Sign-Off
## Stage 8A | Gate: GATE-08 (shared with skill_08b) | Runs parallel with skill_08b_physical_verif

**Version:** 1.0
**Agents:** agent:sta (primary), agent:power, agent:reliability (EOL margins)
**Trigger:** GATE-07 approval from skill_07_pnr

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_07_pnr | `layout/MY_CHIP.spef`, `layout/MY_CHIP_max.sdf`, `layout/MY_CHIP_min.sdf`, `constraints/MY_CHIP_pnr.sdc` |
| Upstream | skill_05_verification | `verif/regression/top_regression.vcd` (activity for dynamic power) |
| Parallel | skill_08b_physical_verif | Both run after GATE-07; both required for GATE-08 |
| On WNS < 0 | skill_07_pnr | ECO: resize/buffer on critical path; or re-route SI nets |
| On WNS < 0 (severe) | skill_06_synthesis | Re-synthesize critical path subset |
| On IR drop fail | skill_07_pnr | PDN ECO: widen stripes or add vias |
| On EOL margin fail | skill_03_arch_design | Revisit timing budget; increase guardband |
| Downstream | skill_08c_gdsii_export | Sign-off STA report included in tape-out package |
| Library | skill_lib_memory | Recall STA tool, corners, POCV settings |
| Library | skill_lib_pdk_select | Liberty files (all corners), POCV tables, aging models |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `layout/MY_CHIP.spef` | skill_07 | Yes — back-annotated parasitics |
| `layout/MY_CHIP_max.sdf` | skill_07 | Yes — setup timing |
| `layout/MY_CHIP_min.sdf` | skill_07 | Yes — hold timing |
| `constraints/MY_CHIP_pnr.sdc` | skill_07 | Yes |
| `power/MY_CHIP_synth.upf` | skill_06 | Yes (power mode analysis) |
| `verif/regression/top_regression.vcd` | skill_05 | Yes (dynamic power) |
| PDK liberty (.lib) — all corners | skill_lib_pdk_select | Yes |
| PDK POCV/AOCV tables | skill_lib_pdk_select | Yes (for ≤28nm) |
| PDK NBTI/HCI aging models | skill_lib_pdk_select | Yes (for automotive / AEC-Q100) |

---

## Tool Detection (STA / Power Subset)

```
SIGN-OFF TOOLS (from skill_lib_tool_detect):
  STA:          <recalled: Tempus / PrimeTime / OpenSTA>
  Power:        <recalled: Voltus / RedHawk / OpenROAD PSM>
  SI (noise):   <STA tool SI mode — Tempus SI / PrimeTime SI>
```

---

## Requirements Gathering

```
STAGE 8A: TIMING & POWER SIGN-OFF REQUIREMENTS
  (Recalled: freq=<MHz>, pdk=<pdk>, reliability_grade=<grade>)

── STA CORNERS ─────────────────────────────────────────────────────────
  Corners to analyze (MCMM):
    [✓] WC SS <Vdd_min> 125°C     worst-case setup
    [✓] WC SS <Vdd_min> −40°C    worst-case hold
    [✓] TC TT <Vdd_nom> 25°C      typical (informational)
    [✓] BC FF <Vdd_max> −40°C    best-case (verify no hold violations)
    [✓] EOL aging (<reliability_grade>):
          NBTI-degraded WC corner at <EOL_years>yr/<Tmax>°C
          (mandatory for AEC-Q100 — auto-configured if grade recalled)

── VARIATION MODEL ──────────────────────────────────────────────────────
  POCV derating:                         [yes — mandatory for ≤28nm]
    Use PDK POCV tables:                 [yes — auto-load from PDK]
  AOCV (acceptable for ≥40nm):          [no by default — specify if needed]
  SI (crosstalk) analysis:              [yes — add delta-delay pessimism]
  Glitch analysis (critical paths):     [yes / no]

── SIGN-OFF CRITERIA ────────────────────────────────────────────────────
  WNS — all paths, all corners (ps):   [≥0]
  TNS (no failing paths):              [0]
  Hold slack — all paths (ps):         [≥0]
  Scan shift hold on OCC paths (ps):  [≥0 BLOCKING]
  Max transition violations:           [0]
  Max capacitance violations:          [0]
  SI delta-delay violations:           [0]

── POWER SIGN-OFF ───────────────────────────────────────────────────────
  Activity source:
    VCD from simulation:               [yes — top_regression.vcd]
    Switching activity (α):            [0.2 default if VCD missing]
  Power analysis modes:
    Active (functional):               [yes]
    Scan shift (worst-case switching): [yes — ICGs bypassed]
    Sleep / retention:                 [yes — if power domains present]
  IR drop — static:                   [yes — worst power grid stress]
  IR drop — dynamic:                  [yes — burst activity from VCD]
  EM sign-off:                        [yes — report all violating nets]
  Worst IR drop limit (mV):           [≤<0.05 × Vdd_nom × 1000>]
  EM current density limit:           [per PDK rules — auto-loaded]

── AGING / RELIABILITY (auto-activated for AEC-Q100) ──────────────────
  EOL timing analysis:                [yes — mandatory for AEC-Q100]
    Mission life (years):            [recalled: <lifetime>]
    Peak temperature (°C):           [recalled: <Tmax>]
    Degradation model:               NBTI (pMOS Vth shift) + HCI (nMOS)
    Apply EOL derate to liberty:     [yes — per PDK aging tables]
  EOL WNS acceptance threshold (ps): [≥0 — any negative = FAIL]
  If EOL WNS within 10ps of 0:      [flag as MARGINAL → human review]
```

---

## Execution Steps

```
STA EXECUTION (Tempus — adapt for PrimeTime or OpenSTA):

  Step 1: Read netlist          read_netlist netlist/MY_CHIP_dft.v -top MY_CHIP
  Step 2: Read liberty (MCMM)  foreach corner { read_libs $lib_$corner }
  Step 3: Read SPEF            read_parasitics layout/MY_CHIP.spef
  Step 4: Read SDC             read_sdc constraints/MY_CHIP_pnr.sdc
  Step 5: Read UPF             read_power_intent power/MY_CHIP_synth.upf
  Step 6: Apply POCV           set_timing_derate -cell_delay -early 0.97 -late 1.03
                                (values from PDK POCV table — adjust per node)
  Step 7: Enable SI            set_analysis_mode -analysisType bcwc -si true
  Step 8: Run STA (all corners) report_timing -max_paths 500 -path_type full_clock
           foreach corner:
             report_timing     > reports/sta_<corner>.rpt
             report_checks     > reports/checks_<corner>.rpt

  Step 9: EOL aging analysis:
           read_libs $lib_EOL_NBTI_HCI_<corner>   ← degraded liberty
           report_timing -max_paths 100 > reports/sta_EOL.rpt

  Step 10: SI analysis         report_si_delay > reports/si_delay.rpt
                                report_noise_analysis > reports/noise.rpt

POWER EXECUTION (Voltus):

  Step 11: Load netlist + DEF  read_netlist + read_def
  Step 12: Load UPF            read_power_intent
  Step 13: Load VCD            read_activity -vcd verif/regression/top_regression.vcd -scope /tb/dut
  Step 14: Static IR drop      analyze_power_rail -rail VDD -mode static
                                → report reports/ir_static.rpt
  Step 15: Dynamic IR drop     analyze_power_rail -rail VDD -mode dynamic
                                → report reports/ir_dynamic.rpt
  Step 16: EM analysis         report_em > reports/em_signoff.rpt
  Step 17: Power by mode       report_power -mode active > reports/power_active.rpt
                                report_power -mode scan_shift > reports/power_scan.rpt
                                report_power -mode sleep > reports/power_sleep.rpt
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| STA sign-off report (all corners) | `reports/sta_final_signoff.rpt` | GATE-08, skill_08c |
| EOL timing report | `reports/sta_EOL.rpt` | GATE-08 review |
| SI delay report | `reports/si_delay.rpt` | GATE-08 review |
| Power report (active) | `reports/power_active.rpt` | GATE-08, skill_08c |
| IR drop report (static) | `reports/ir_static.rpt` | GATE-08 review |
| IR drop report (dynamic) | `reports/ir_dynamic.rpt` | GATE-08 review |
| EM sign-off report | `reports/em_signoff.rpt` | GATE-08, skill_08c |
| Timing sign-off sign-off sheet | `reports/sta_signoff_checklist.md` | GATE-08 review |

---

## Output Metrics

```
STA SIGN-OFF — ALL CORNERS
──────────────────────────────────────────────────────────────────────────────
Corner                    Mode    WNS(ps) TNS  Hold(ps) Tran Cap  SI   Status
──────────────────────────────────────────────────────────────────────────────
WC SS <Vmin> 125°C        func    <v>     <v>  —        <v>  <v>  <v>  ?
WC SS <Vmin> −40°C        func    —       —    <v>      <v>  <v>  —    ?
TC TT <Vnom> 25°C         func    <v>     <v>  <v>      <v>  <v>  <v>  ?
BC FF <Vmax> −40°C        func    <v>     <v>  <v>      <v>  <v>  —    ?
WC SS <Vmin> 125°C        scan    <v>     <v>  <v>OCC   —    —    —    ?
EOL WC <Tmax> <N>yr       func    <v>     <v>  —        —    —    —    ?
──────────────────────────────────────────────────────────────────────────────
⚠ Flag MARGINAL if EOL WNS < +10 ps → human review required

POWER SIGN-OFF
──────────────────────────────────────────────────────────────────────────
Metric                      Value      Target          Status
──────────────────────────────────────────────────────────────────────────
Active power (VCD-based, mW) <value>    ≤<spec>         ?
Leakage power (μW)           <value>    ≤<spec>         ?
Scan shift power (mW)        <value>    — (informational) INFO
Peak static IR drop (mV)     <value>    ≤<5% VDD>       ?
Peak dynamic IR drop (mV)    <value>    ≤<5% VDD>       ?
EM violations                <N>        0               ?
──────────────────────────────────────────────────────────────────────────
Overall STA + Power: <PASS / FAIL / MARGINAL>
```

---

## Quality Gate: GATE-08 (STA portion)

```
GATE-08 STA CRITERIA (human STA + Power Engineer approval):
  □ WNS ≥ 0 ps — all paths, all setup corners
  □ TNS = 0 (no failing paths)
  □ Hold slack ≥ 0 ps — all corners
  □ Scan shift hold on OCC paths ≥ 0 ps (BLOCKING)
  □ Max transition: 0 violations
  □ Max capacitance: 0 violations
  □ SI delta-delay: 0 violations
  □ EOL timing: WNS ≥ 0 ps (AEC-Q100 — mandatory)
  □ Active power ≤ spec target
  □ Static IR drop ≤ 5% VDD
  □ Dynamic IR drop ≤ 5% VDD
  □ EM: 0 violations

Note: GATE-08 requires BOTH skill_08a AND skill_08b to PASS.
Approvers: STA Engineer + Power Engineer + (Reliability Engineer if AEC-Q100)
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| WNS < 0 (≤5 paths) | ECO in skill_07_pnr: cell upsize / buffer insert; run LEC-3; re-run STA |
| WNS < 0 (>5 paths, systemic) | Return to skill_06_synthesis for targeted re-synthesis |
| Hold violation | ECO hold fix in skill_07_pnr: insert delay cells; re-run STA |
| OCC scan shift hold fail | Fix OCC SDC constraints; re-run CTS in skill_07_pnr |
| SI delta-delay violation | Re-route aggressor/victim nets in skill_07_pnr; re-extract SPEF |
| EOL WNS marginally negative | Add synthesis guardband; return to skill_06_synthesis |
| IR drop static >5% VDD | Widen power stripes in skill_07_pnr PDN ECO |
| IR drop dynamic >5% VDD | Widen peak-switching-layer stripes; or reduce burst activity |
| EM violation | Upsize wire or add parallel route in skill_07_pnr ECO |

---

## Memory Write

```yaml
execution_history:
  sta_signoff:
    - timestamp: <ISO8601>
      result: <PASS/FAIL/MARGINAL>
      tool: <sta_tool>
      corners: [WC_SS_125, WC_SS_m40, TC_TT, BC_FF, EOL]
      metrics:
        wns_setup_ps: <value>
        tns: 0
        wns_hold_ps: <value>
        occ_hold_ps: <value>
        si_violations: 0
        eol_wns_ps: <value>
        power_active_mw: <value>
        ir_static_mv: <value>
        ir_dynamic_mv: <value>
        em_violations: 0
      gate: GATE-08 (partial)
```

---

*Previous: [`skill_07_pnr.md`](skill_07_pnr.md)*
*Parallel: [`skill_08b_physical_verif.md`](skill_08b_physical_verif.md)*
*Next: [`skill_08c_gdsii_export.md`](skill_08c_gdsii_export.md) (after GATE-08 with skill_08b)*
*ECO target: [`skill_07_pnr.md`](skill_07_pnr.md) or [`skill_06_synthesis.md`](skill_06_synthesis.md)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
