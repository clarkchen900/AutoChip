# skill_06_synthesis — Logic Synthesis
## Stage 6 | Checkpoint: LEC-1 | Gate: GATE-06 (shared with skill_06b_dft)

**Version:** 1.0
**Agent:** agent:synth (primary), agent:sta + agent:power (review)
**Trigger:** GATE-04 + GATE-05 both approved

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_04_rtl_design | `rtl/*.sv`, `power/MY_CHIP.upf`, `constraints/constraints.sdc` |
| Upstream | skill_03_arch_design | `arch/timing_budget.yaml` (synthesis margin targets per block) |
| Upstream | skill_05_verification | Verif sign-off confirms RTL frozen |
| Downstream | skill_06b_dft | `netlist/MY_CHIP_synth.v` (input for scan insertion) |
| Downstream | skill_05_verification | Gate-level netlist + SDF for GLS |
| Downstream | skill_07_pnr | `netlist/MY_CHIP_dft.v`, `constraints/MY_CHIP_synth.sdc`, `power/MY_CHIP_synth.upf` |
| LEC-1 checkpoint | Internal (Conformal/Formality) | RTL vs. gate netlist equivalence — must PASS before skill_06b |
| On WNS fail >20% | skill_03_arch_design | Timing budget revision |
| On WNS fail ≤20% | skill_04_rtl_design | Critical-path RTL optimization |
| On area over budget | skill_03_arch_design | Re-partition / reduce scope |
| Library | skill_lib_memory | Recall synthesis tool, PDK, timing targets |
| Library | skill_lib_pdk_select | Liberty files, ICG cell family |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `rtl/*.sv` | skill_04 | Yes |
| `power/MY_CHIP.upf` | skill_04 | Yes (if >1 power domain) |
| `constraints/constraints.sdc` | skill_04 | Yes |
| `arch/timing_budget.yaml` | skill_03 | Yes |
| PDK liberty files (.lib) | skill_lib_pdk_select | Yes |
| PDK ICG cell family | skill_lib_pdk_select | Yes |

---

## Tool Detection (Synthesis Subset)

```
SYNTHESIS TOOLS (from skill_lib_tool_detect):
  Synthesis:  <recalled: Genus / DC Shell / DC Ultra / Yosys>
  LEC:        <recalled: Conformal / Formality / Yosys equiv>
  Power est.: <recalled: Voltus (Genus Joules) / PrimePower / OpenROAD PSM>

  NOTE: If backend_flow = "librelane", Yosys is auto-selected.
        Commercial PDKs (tsmc, gf) require Genus or DC Shell.
```

---

## Requirements Gathering

```
STAGE 6: SYNTHESIS REQUIREMENTS
  (Recalled: pdk=<pdk>, freq=<MHz>, power=<mW>, tool=<tool>)

── TIMING CONSTRAINTS ──────────────────────────────────────────────────
  Clock period (ps):                    [<1e6/freq_MHz>]  ← auto-calculated
  Clock uncertainty — setup (ps):       [50]
  Clock uncertainty — hold (ps):        [25]
  Input delay budget (ps):              [<period × 0.20>]
  Output delay budget (ps):             [<period × 0.20>]
  SDC file: provide or auto-generate:   [auto-generate from arch/clock_domains.yaml]

── OPTIMIZATION GOAL ───────────────────────────────────────────────────
  [1] Timing-first (default — production)
  [2] Area-first   (cost-sensitive design)
  [3] Power-first  (battery / thermal constrained)
  [4] Balanced     (timing + area + power equal)

── MULTI-CORNER MULTI-MODE (MCMM) ──────────────────────────────────────
  Enable MCMM:                          [yes — strongly recommended]
  Corners to target:
    [✓] WC SS <Vdd_min> 125°C          worst-case setup
    [✓] WC SS <Vdd_min> −40°C         worst-case hold
    [✓] TC TT <Vdd_nom> 25°C           typical
    [✓] BC FF <Vdd_max> −40°C         best-case
  On-chip variation:
    POCV (recommended for ≤28nm):      [yes]
    AOCV (acceptable for ≥40nm):       [no]

── POWER INTENT ────────────────────────────────────────────────────────
  Apply UPF during synthesis:           [yes — use power/MY_CHIP.upf]
  ICG insertion:                        [yes]
  ICG coverage target (%):             [80]
  ICG cell family (from PDK):          [<auto-detected from skill_lib_pdk_select>]

── DFT PREPARATION ─────────────────────────────────────────────────────
  Load scan mode timing constraints:    [yes — dft/scan_mode.sdc]
  Load OCC constraints (if available):  [yes — dft/occ_constraints.sdc]
  (Full DFT insertion done in skill_06b — this step only prepares netlist)

── QUALITY TARGETS (from arch/timing_budget.yaml) ──────────────────────
  WNS after synthesis (ps):            [≥+<period × 0.20>]  ← 20% margin
  TNS:                                 [0]
  Max fanout:                          [20]
  Max transition (ps):                 [<period × 0.30>]
  Area (μm²):                         [auto — report vs. spec]
```

---

## Synthesis Execution Steps

```
SYNTHESIS EXECUTION (Genus example — adapt for DC Shell or Yosys):

  Step 1:  Read RTL           read_hdl -sv rtl/*.sv
  Step 2:  Read liberty       foreach corner { read_libs $lib_path }
  Step 3:  Read tech LEF      read_physical -lef $pdk_root/tlef
  Step 4:  Apply UPF          read_power_intent -format upf power/MY_CHIP.upf
  Step 5:  Read SDC           read_sdc constraints/constraints.sdc
  Step 6:  Elaborate          elaborate MY_CHIP
  Step 7:  Generic synthesis  syn_generic -effort high
  Step 8:  Tech mapping       syn_map -effort high
  Step 9:  Incremental opt    syn_opt -effort high
  Step 10: Insert ICG         insert_clock_gating -coverage 0.80
  Step 11: Timing opt         optimize_design -incremental
  Step 12: Write netlist      write_hdl > netlist/MY_CHIP_synth.v
  Step 13: Write SDC          write_sdc > constraints/MY_CHIP_synth.sdc
  Step 14: Write UPF          write_power_intent > power/MY_CHIP_synth.upf
  Step 15: Write SAIF/VCD     write_saif > power/MY_CHIP_synth.saif
  Step 16: Generate reports   report_timing / report_area / report_power / report_qor

  LEC-1 CHECKPOINT:
  Step 17: Run LEC            conformal -nogui -dofile lec/lec_rtl_vs_netlist.tcl
             → Compare: RTL source vs. netlist/MY_CHIP_synth.v
             → Result must be EQUIVALENT before proceeding to skill_06b
             → If NOT EQUIVALENT: fix synthesis constraints; re-run
```

---

## Yosys / LibreLane Synthesis (Open-Source Path)

```
YOSYS SYNTHESIS (when synthesis tool = "yosys" or LibreLane mode):

  yosys -p "
    read_verilog -sv rtl/*.sv;
    hierarchy -check -top MY_CHIP;
    synth_<pdk> -top MY_CHIP -flatten -abc9 -abc_d <target_delay>;
    write_verilog -noattr netlist/MY_CHIP_synth.v;
    write_json netlist/MY_CHIP_synth.json;
    stat -tech <pdk>;
  "

  LEC via Yosys equiv:
    yosys -p "read_verilog rtl/*.sv; read_verilog netlist/MY_CHIP_synth.v;
              equiv_make MY_CHIP MY_CHIP_equiv; equiv_simple -seq 5; equiv_status"
    Note: Yosys equiv is limited compared to commercial LEC — flag any non-equivalent points.

  Timing: OpenSTA after synthesis
    sta -f scripts/opensta_synth.tcl → report timing / report checks
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| Gate-level netlist | `netlist/MY_CHIP_synth.v` | skill_06b_dft, skill_05 (GLS) |
| Post-synth SDC | `constraints/MY_CHIP_synth.sdc` | skill_06b, skill_07, skill_08a |
| Post-synth UPF | `power/MY_CHIP_synth.upf` | skill_06b, skill_07, skill_08a |
| Power activity (SAIF) | `power/MY_CHIP_synth.saif` | skill_08a (power analysis) |
| LEC-1 report | `reports/lec1_rtl_vs_synth.rpt` | GATE-06 review |
| Timing report | `reports/synth_timing.rpt` | GATE-06 review |
| Area report | `reports/synth_area.rpt` | GATE-06 review |
| Power report | `reports/synth_power.rpt` | GATE-06 review |

---

## Output Metrics

```
SYNTHESIS RESULTS
─────────────────────────────────────────────────────────────────────
Metric                          Value      Target        Status
─────────────────────────────────────────────────────────────────────
WNS (WC SS setup) ps            <value>    ≥+<budget>    ?
TNS                             <value>    0             ?
WNS (hold WC −40°C) ps          <value>    ≥0            ?
Max fanout violations           <N>        0             ?
Max transition violations       <N>        0             ?
Cell count                      <N>        —             INFO
Total area (μm²)                <value>    ≤<spec>       ?
ICG coverage (%)                <value>    ≥80%          ?
Power estimate (mW)             <value>    ≤<spec>       ?
LEC-1 (RTL vs. netlist)        EQUIV/FAIL EQUIVALENT     ?
─────────────────────────────────────────────────────────────────────
⚠ Any WARN or FAIL → investigate before proceeding to skill_06b
```

---

## Quality Gate: GATE-06 (shared with skill_06b_dft)

```
GATE-06 SYNTHESIS CRITERIA (subset — full gate after DFT):
  □ WNS ≥ +<20% of clock period> at worst-case setup corner
  □ TNS = 0 (no failing paths)
  □ Hold slack ≥ 0 at worst-case hold corner
  □ LEC-1: RTL vs. netlist EQUIVALENT
  □ ICG coverage ≥ 80% of register banks
  □ Area within spec budget
  □ Max fanout, max transition, max cap: 0 violations

See skill_06b_dft for full GATE-06 sign-off (after DFT insertion + LEC-2).
Approvers: Synthesis Engineer + STA Engineer
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| WNS fail >20% of period | Route to skill_03_arch_design — timing budget revision |
| WNS fail ≤20% of period | Route to skill_04_rtl_design — critical path RTL optimization |
| Area over budget >15% | Route to skill_03_arch_design — re-partition |
| Area over budget ≤15% | Increase synthesis effort; try area_effort=high |
| ICG coverage <70% | Re-check ICG cell available in PDK; adjust coverage threshold; review RTL enable signals |
| LEC-1 FAIL | Investigate non-equivalent points; adjust constraints or RTL; re-synthesize |
| Max transition violations | Upsize output drivers; re-run syn_opt |

---

## Memory Write

```yaml
execution_history:
  synthesis:
    - timestamp: <ISO8601>
      result: <PASS/FAIL>
      tool: <synthesis_tool>
      corners: [WC_SS_125, WC_SS_m40, TC_TT, BC_FF]
      metrics:
        wns_ps: <value>
        tns: 0
        hold_wns_ps: <value>
        cell_count: <N>
        area_um2: <value>
        icg_coverage_pct: <value>
        power_estimate_mw: <value>
        lec1_result: EQUIVALENT
      artifacts: [netlist/MY_CHIP_synth.v, constraints/MY_CHIP_synth.sdc]
      gate: LEC-1 (GATE-06 partial)
```

---

*Previous: [`skill_04_rtl_design.md`](skill_04_rtl_design.md) + [`skill_05_verification.md`](skill_05_verification.md)*
*Next: [`skill_06b_dft.md`](skill_06b_dft.md)*
*After DFT: [`skill_07_pnr.md`](skill_07_pnr.md)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
