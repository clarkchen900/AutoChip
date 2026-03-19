# skill_07_pnr — Physical Design & Place-and-Route
## Stage 7 | Gate: GATE-07

**Version:** 1.0
**Agents:** agent:pnr (primary), agent:fp (floorplan), agent:sta (in-design), agent:power (IR/EM)
**Trigger:** GATE-06 approval from skill_06b_dft

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_06b_dft | `netlist/MY_CHIP_dft.v`, `constraints/MY_CHIP_dft.sdc`, `power/MY_CHIP_synth.upf` |
| Upstream | skill_06b_dft | `dft/scan_chains.def` (scan chain ordering for routing) |
| Upstream | skill_03_arch_design | `arch/block_diagram.yaml` (block hierarchy for floorplan) |
| Upstream | skill_lib_pdk_select | Tech LEF, cell LEF, IO cell library |
| Downstream | skill_08a_sta_signoff | `layout/MY_CHIP.def`, `layout/MY_CHIP.spef`, `constraints/MY_CHIP_pnr.sdc` |
| Downstream | skill_08b_physical_verif | `layout/MY_CHIP.gds` (or streamed from DEF), `netlist/MY_CHIP_final.cdl` |
| On timing closure fail | skill_06_synthesis | Request synthesis re-run with tighter targets |
| On congestion unresolvable | skill_03_arch_design | Floorplan strategy revision |
| ECO from skill_08a | skill_07_pnr | Re-enter P&R for timing/power ECO; run LEC-3 |
| ECO from skill_08b | skill_07_pnr | Re-enter P&R for DRC ECO |
| Library | skill_lib_memory | Recall PnR tool, utilization, IR targets |
| Library | skill_lib_pdk_select | ICG cell family, filler cells, tap cells |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `netlist/MY_CHIP_dft.v` | skill_06b | Yes |
| `constraints/MY_CHIP_dft.sdc` | skill_06b | Yes |
| `power/MY_CHIP_synth.upf` | skill_06 | Yes |
| `dft/scan_chains.def` | skill_06b | Yes (scan routing) |
| `arch/block_diagram.yaml` | skill_03 | Yes (hierarchy) |
| PDK Tech LEF, Cell LEF, IO LEF | skill_lib_pdk_select | Yes |
| PDK DRC rules (for DRC-driven routing) | skill_lib_pdk_select | Yes |

---

## Tool Detection (P&R Subset)

```
PHYSICAL DESIGN TOOLS (from skill_lib_tool_detect):
  P&R:            <recalled: Innovus / ICC2 / OpenROAD / LibreLane>
  In-design STA:  <recalled: Tempus / PrimeTime / OpenSTA>
  IR/EM analysis: <recalled: Voltus / RedHawk / OpenROAD PSM>
  Waveform:       <recalled (for timing debug)>

  If LibreLane selected: full automated flow — see LibreLane section below.
```

---

## Requirements Gathering

```
STAGE 7: PHYSICAL DESIGN REQUIREMENTS
  (Recalled: pdk=<pdk>, die_area=<mm²>, freq=<MHz>, pnr_tool=<tool>)

── FLOORPLAN ───────────────────────────────────────────────────────────
  Core utilization (%):                 [70]  ← 60–80% recommended
  Aspect ratio (W:H):                   [1.0 (square)]
  Core-to-IO margins (μm):             [50 all sides]
  Hard macro placement:                 [auto / manual / constraints DEF]
  IO pad placement:                     [auto / read pad file]
  Power ring style:                     [double ring / single / mesh]
  VDD/VSS strap width (μm):            [2.0]
  Power strap pitch (μm):              [100 horizontal + 100 vertical]

── PLACEMENT ───────────────────────────────────────────────────────────
  Placement effort:                     [high]
  Timing-driven placement:              [yes]
  Congestion-driven placement:          [yes]
  Multi-voltage placement (UPF-aware):  [yes — from power/MY_CHIP_synth.upf]

── CLOCK TREE SYNTHESIS ────────────────────────────────────────────────
  CTS intra-block skew target (ps):    [≤<period × 0.08>]   ← 8% of period
  CTS global inter-block skew (ps):    [≤<period × 0.05>]   ← 5% of period
  Clock buffer cell family:             [auto from PDK]
  Useful skew optimization:             [yes — redistributes slack budget]
  OCC clock routing:                    [yes — route as shielded clock nets]
  Clock net shielding:                  [yes — ground shields on M4/M5]

── ROUTING ─────────────────────────────────────────────────────────────
  Routing effort:                       [high]
  SI-aware routing:                     [yes — recommended for ≤28nm]
  Via optimization (redundant vias):    [yes — EM / yield improvement]
  Antenna fixing strategy:              [auto diode insertion during route]
  Antenna diode insertion:              [yes]
  DRC fixing iterations:                [5]
  Scan chain routing:                   [follow scan_chains.def ordering]

── PHYSICAL COMPLETION (mandatory before DRC sign-off) ─────────────────
  Tap cell insertion:                   [yes — foundry required spacing]
  End-cap cells:                        [yes]
  Standard cell filler:                 [yes — metal density / LVS]
  Metal fill (dummy — CMP):            [yes — planarity / DRC density rules]
  Via redundancy pass:                  [yes — EM reliability improvement]
  Power net shielding (clocks):        [yes]

── TIMING SIGN-OFF TARGETS (in-design) ─────────────────────────────────
  WNS all corners (ps):                [≥0]
  TNS:                                 [0]
  Hold slack (ps):                     [≥0 all corners]
  Scan shift hold on OCC paths (ps):  [≥0 — blocking]
  SI delta-delay violations:           [0]

── POWER / IR DROP ─────────────────────────────────────────────────────
  Worst static IR drop (mV):           [≤5% VDD = ≤<0.05 × Vdd_nom × 1000> mV]
  Worst dynamic IR drop (mV):          [≤5% VDD]
  EM current density limit:            [per PDK EM rules — auto-loaded]
  Active power (post-route target, mW):[≤<spec>]
```

---

## Execution Flow

```
P&R EXECUTION MILESTONES (Innovus — adapt for ICC2 or OpenROAD):

MILESTONE 1 — FLOORPLAN
  init_design -lef $tech_lef -lef $cell_lef -lef $io_lef
  read_mmmc mmmc.view                      ← MCMM corner definitions
  read_physical -lef ...
  read_netlist netlist/MY_CHIP_dft.v
  read_sdc constraints/MY_CHIP_dft.sdc
  read_power_intent power/MY_CHIP_synth.upf
  floorPlan -die <W> <H> -core <margins>
  place_io -file io_placement.iocells
  addRing -nets {VDD VSS} -width 2.0 -spacing 1.0
  addStripe -nets {VDD VSS} -layer M6 -width 2.0 -pitch 100

MILESTONE 2 — PLACEMENT
  place_opt_design -effort high -timing_driven -congestion

MILESTONE 3 — CTS
  setCTSMode -target_skew <skew_target> -clk_gating_aware true
  clock_design -routing_tree_type h-tree
  optDesign -postCTS -hold

MILESTONE 4 — ROUTING
  setNanoRouteMode -drouteViaOpt true -drouteFixAntenna true
  routeDesign -globalDetail -viaOpt
  optDesign -postRoute -hold -si -effort high
  setAnalysisMode -analysisType bcwc -cppr both

MILESTONE 5 — PHYSICAL COMPLETION
  addTapCell -cell <tap_cell> -distance <foundry_spec>
  addEndCap -preBoundaryCell <ec_cell>
  addFiller -cell <filler_cells>
  addMetalFill -layer {M1 M2 M3 M4 M5 M6} -density 40
  addViaFill -allLayers -viaOpt

MILESTONE 6 — IN-DESIGN SIGN-OFF STA
  tempus -db timing_db                     ← or equivalent for tool
  report_timing -max_paths 100 > reports/pnr_timing.rpt
  report_si_delay > reports/pnr_si.rpt
  (if violations remain → iterate optDesign or ECO)

MILESTONE 7 — IR DROP
  voltus -qrc_tech $qrc_tech              ← or RedHawk / OpenROAD PSM
  analyze_power_rail -rail_name VDD -mode static
  analyze_power_rail -rail_name VDD -mode dynamic -vcd verif/regression/top_regression.vcd

MILESTONE 8 — STREAM OUT
  streamOut layout/MY_CHIP.gds -mapFile pdk_layer_map.map -merge {std_cell.gds io_cell.gds}
  write_def layout/MY_CHIP.def
  write_sdf layout/MY_CHIP_max.sdf -min_view WC_SS_setup -max_view WC_SS_setup
  write_sdf layout/MY_CHIP_min.sdf -min_view BC_FF_hold  -max_view BC_FF_hold
  extractRC -output layout/MY_CHIP.spef -coupled

  LEC-3 (per ECO — run if any netlist change was made):
    conformal -dofile lec/lec_dft_vs_final.tcl
    → Compare: netlist/MY_CHIP_dft.v vs. final extracted netlist
    → Must be EQUIVALENT before proceeding to sign-off
```

---

## LibreLane / OpenROAD Automated Path

```
LIBRELANE P&R (when backend_flow = "librelane"):
  Generated config.json includes:
    FP_CORE_UTIL, PL_TARGET_DENSITY, CLOCK_PERIOD,
    GLB_RT_ADJUSTMENT, ROUTING_CORES,
    FILL_INSERTION: 1, TAP_DECAP_INSERTION: 1,
    diode_insertion_strategy: 3

  librelane run_designs config.json
    → Floorplan (ifp + tapcell + pdngen)
    → Placement (gpl + dpl)
    → CTS (TritonCTS)
    → Routing (TritonRoute)
    → OpenSTA timing → report WNS/TNS
    → OpenROAD PSM → IR drop
    → Magic DRC (preliminary)
    → Netgen LVS (preliminary)
    → Magic GDS stream-out

  Orchestrator parses LibreLane JSON metrics.
  If WNS < 0: present options (relax period / re-synth / accept).
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| Routed DEF | `layout/MY_CHIP.def` | skill_08a, skill_08b |
| GDSII (interim) | `layout/MY_CHIP.gds` | skill_08b (DRC/LVS) |
| SPEF (parasitics) | `layout/MY_CHIP.spef` | skill_08a (STA) |
| Post-route SDF (max) | `layout/MY_CHIP_max.sdf` | skill_05 (GLS), skill_08a |
| Post-route SDF (min) | `layout/MY_CHIP_min.sdf` | skill_05 (GLS hold), skill_08a |
| Final CDL netlist | `netlist/MY_CHIP_final.cdl` | skill_08b (LVS) |
| Post-route SDC | `constraints/MY_CHIP_pnr.sdc` | skill_08a |
| LEC-3 report (if ECO) | `reports/lec3_eco_<N>.rpt` | GATE-07 review |
| IR drop report | `reports/ir_drop.rpt` | GATE-07 review |
| EM report | `reports/em_signoff.rpt` | GATE-07 review |

---

## Output Metrics

```
PHYSICAL DESIGN METRICS — GATE-07
─────────────────────────────────────────────────────────────────────────
Metric                          Value      Target           Status
─────────────────────────────────────────────────────────────────────────
PLACEMENT
  Core utilization (%)          <value>    60–80%           ?
  Congestion overflow cells      <N>       0                ?

CLOCK TREE
  Intra-block max skew (ps)     <value>    ≤<period × 0.08> ?
  Global inter-block skew (ps)  <value>    ≤<period × 0.05> ?
  ICG enable slack (ps)         <value>    ≥0               ?

ROUTING
  DRC violations (post-route)   <N>        0                ?
  Antenna violations             <N>        0 (fixed)        ?
  SI delta-delay violations     <N>        0                ?

TIMING (in-design sign-off)
  WNS — WC SS setup (ps)        <value>    ≥0               ?
  TNS                           <value>    0                ?
  WNS — WC hold (ps)            <value>    ≥0               ?
  Scan shift hold OCC (ps)      <value>    ≥0 BLOCKING      ?

POWER / IR DROP
  Static IR drop (mV)           <value>    ≤<5% VDD>        ?
  Dynamic IR drop (mV)          <value>    ≤<5% VDD>        ?
  EM violations                 <N>        0                ?
  Post-route power (mW)         <value>    ≤<spec>          ?

PHYSICAL COMPLETION
  Tap cells inserted             <yes/no>  YES              ?
  Filler cells inserted          <yes/no>  YES              ?
  Metal fill (CMP)               <yes/no>  YES              ?
  Via redundancy                 <yes/no>  YES              ?
─────────────────────────────────────────────────────────────────────────
Overall: <PASS/FAIL> → GATE-07
```

---

## Quality Gate: GATE-07

```
GATE-07 CRITERIA (human PD Lead approval):
  □ DRC violations post-route: 0
  □ Antenna violations: 0 (fixed during route)
  □ Timing: WNS ≥ 0 all corners (setup + hold)
  □ Scan shift hold on OCC paths: ≥ 0 ps (blocking)
  □ SI delta-delay: 0 violations
  □ Static IR drop: ≤ 5% VDD
  □ Dynamic IR drop: ≤ 5% VDD
  □ EM: 0 violations against PDK EM rules
  □ Physical completion: tap, filler, metal fill, via redundancy all inserted
  □ LEC-3: EQUIVALENT (if any ECO was performed)
  □ SPEF extracted, SDF generated (max + min)
  □ CDL netlist generated

Approvers: PD Lead + STA Engineer + Power Engineer
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| Timing closure fail after P&R | Run optDesign -postRoute; or ECO resize/buffer; or re-synthesize critical paths (skill_06) |
| Congestion unresolvable (overflow >0) | Reduce utilization target; return to skill_03_arch_design |
| Static IR drop >5% VDD | Widen power stripes; add more vias; re-analyze |
| Dynamic IR drop >5% VDD | Widen stripes on peak switching layers; reduce burst activity |
| EM violation | Upsize offending wire; add parallel wires; re-route |
| Scan hold violation on OCC | Fix OCC constraints; re-run CTS; re-run hold optimization |
| Antenna DRC after route | Insert diode; run antenna fix; re-DRC |
| skill_08a reports WNS < 0 | Re-enter P&R ECO mode; run LEC-3 after ECO |
| skill_08b reports DRC fail | Re-enter P&R ECO mode; fix specific DRC layer; re-stream |

---

## Memory Write

```yaml
execution_history:
  pnr:
    - timestamp: <ISO8601>
      result: <PASS/FAIL>
      tool: <pnr_tool>
      metrics:
        utilization_pct: <value>
        cts_skew_ps: <value>
        drc_violations: 0
        wns_setup_ps: <value>
        wns_hold_ps: <value>
        occ_hold_ps: <value>
        ir_drop_static_mv: <value>
        ir_drop_dynamic_mv: <value>
        power_mw: <value>
        physical_completion: true
      artifacts: [layout/MY_CHIP.def, layout/MY_CHIP.gds, layout/MY_CHIP.spef]
      gate: GATE-07
error_log:
  - stage: pnr
    error_class: <class>
    error_summary: <summary>
    resolution: <resolution>
    lesson_learned: <lesson>
```

---

*Previous: [`skill_06b_dft.md`](skill_06b_dft.md)*
*Next (parallel): [`skill_08a_sta_signoff.md`](skill_08a_sta_signoff.md) + [`skill_08b_physical_verif.md`](skill_08b_physical_verif.md)*
*ECO re-entry: skill_07_pnr (this skill) via skill_00_orchestrator ECO workflow*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
