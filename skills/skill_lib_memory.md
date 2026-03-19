# skill_lib_memory — Skill Memory Store (SMS)
## Shared Library | Loaded by all stage skills

**Type:** Library (not a standalone stage skill)
**Version:** 1.0
**Used by:** ALL stage skills and skill_00_orchestrator

---

## Purpose

The Skill Memory Store (SMS) provides persistent, project-scoped memory across agent sessions. Every stage skill reads preferences and error history from SMS at activation, and writes decisions, metrics, and errors back at completion. This enables:
- No repeated questions for choices already made
- Error pattern learning across iterations
- Cross-project knowledge transfer
- Consistent tool/PDK choices throughout the flow

---

## SMS File Location

```
<project_root>/
  .eda_flow/
    skill_memory_store.yaml     ← primary SMS (read/write)
    error_log.yaml              ← error and lesson log (append-only)
    execution_history.yaml      ← per-stage run records
```

---

## SMS Schema

```yaml
# skill_memory_store.yaml
schema_version: "1.0"

project:
  name: ""                    # e.g., "MY_CHIP"
  design_id: ""               # e.g., "MY_CHIP_v1.0"
  technology_node: ""         # e.g., "tsmc16ffc", "sky130B"
  pdk_selected: ""            # full PDK identifier
  flow_type: ""               # "digital" | "mixed_signal" | "full_custom"
  backend_flow: ""            # "commercial" | "librelane" | "openroad"

tool_preferences:
  simulator: ""               # vcs | xcelium | questa | verilator | icarus
  synthesis: ""               # genus | dc_shell | yosys
  pnr: ""                     # innovus | icc2 | openroad | librelane
  sta: ""                     # tempus | primetime | opensta
  formal: ""                  # jg | vc_formal | symbiyosys
  dft: ""                     # modus | tessent | openroad_dft
  lec: ""                     # conformal | formality | yosys_equiv
  physical_verif: ""          # calibre | pvs | magic_netgen
  power_analysis: ""          # voltus | redhawk | openroad_psm
  waveform_viewer: ""         # simvision | verdi | gtkwave
  cdc_tool: ""                # spyglass_cdc | meridian | questa_cdc
  lint_tool: ""               # spyglass | jasper_lint | verilator_lint

design_requirements:
  target_frequency_mhz: null
  target_power_mw: null
  die_area_mm2: null
  package_type: ""
  io_count: null
  voltage_nominal_v: null
  temperature_range: ""       # e.g., "-40 to 125"
  reliability_grade: ""       # AEC-Q100-G0 | G1 | G2 | consumer
  dft_sa_coverage_target: 99  # stuck-at %
  dft_trans_coverage_target: 97
  dft_pa_coverage_target: 90
  dft_ca_coverage_target: 98
  clock_domains: []
  power_domains: []
  functional_coverage_target: 95
  synth_wns_margin_ps: 200    # post-synthesis timing margin
  max_utilization_pct: 75

interaction_prefs:
  verbosity: "normal"         # terse | normal | verbose
  auto_accept_defaults: false
  always_show_metrics: true
  preferred_report_format: "table"
  notify_on_gate_pass: true
  notify_on_gate_fail: true
```

---

## Read Protocol (at skill activation)

Every stage skill begins with:

```
1. Check if .eda_flow/skill_memory_store.yaml exists
   → YES: load full SMS into working context
   → NO:  initialize SMS with empty schema; run skill_lib_pdk_select + skill_lib_tool_detect

2. Extract relevant fields for this stage:
   - tool_preferences.<stage_tools>
   - design_requirements.*
   - execution_history.<this_stage> (last run, if any)
   - error_log (filter by this stage)

3. Pre-fill all prompts with recalled values (user can override)
```

---

## Write Protocol (at skill completion or on event)

| Event | Written Field | Timing |
|-------|--------------|--------|
| Tool selected | `tool_preferences.<tool>` | Immediately |
| Design req answered | `design_requirements.<key>` | Immediately |
| Stage PASS | `execution_history.<stage>[]` entry | On completion |
| Stage FAIL | `error_log[]` entry | On failure |
| User override | Both field + `error_log[].lesson_learned` | Immediately |
| Human gate APPROVE | `execution_history.<stage>[].gate_approved` | On approval |

---

## Error Log Schema

```yaml
# error_log.yaml  (append-only)
- stage: "rtl_design"
  timestamp: "2026-03-19T10:32:00Z"
  tool: "SpyGlass"
  run_id: "run_004"
  error_class: "qos_fail"     # tool_crash | qos_fail | license_miss | timeout | user_abort | arch_issue
  error_summary: "CDC violation: clk_fast→clk_slow in module uart_rx (2 violations)"
  resolution: "Added 2FF synchronizer instantiation per arch/clock_domains.yaml"
  lesson_learned: "Always instantiate CDC sync cells before RTL lint; check arch/clock_domains.yaml for all crossing pairs"
  auto_retry: true
  retry_count: 1
```

---

## Preference Propagation Rules

When user selects a tool suite, SMS auto-fills related preferences:

```
"Cadence" →
  simulator       = xcelium
  synthesis       = genus
  pnr             = innovus
  sta             = tempus
  formal          = jg
  dft             = modus
  lec             = conformal
  physical_verif  = calibre  (prompt: pvs or calibre)
  power_analysis  = voltus
  waveform_viewer = simvision
  cdc_tool        = spyglass_cdc  (or meridian if found)
  lint_tool       = spyglass

"Synopsys" →
  simulator       = vcs
  synthesis       = dc_shell  (prompt: dc_shell or dc_ultra)
  pnr             = icc2
  sta             = primetime
  formal          = vc_formal
  dft             = tessent   (if found, else modus)
  lec             = formality
  physical_verif  = pvs       (prompt: pvs or calibre)
  power_analysis  = redhawk
  waveform_viewer = verdi

"Mentor/Siemens" →
  simulator       = questa
  dft             = tessent
  physical_verif  = calibre
  (others: prompt individually)

"Open Source / LibreLane" →
  simulator       = verilator  (prompt: verilator or icarus)
  synthesis       = yosys
  pnr             = openroad   (or librelane)
  sta             = opensta
  formal          = symbiyosys
  dft             = openroad_dft  (limited)
  lec             = yosys_equiv
  physical_verif  = magic_netgen
  power_analysis  = openroad_psm
  waveform_viewer = gtkwave
  backend_flow    = librelane
```

---

## Self-Improvement: Pattern Recognition

After 3+ runs of any stage, SMS scans error_log for recurring patterns:

```
PATTERN CHECK (runs automatically after each stage):
  Scan error_log for stage = <current_stage>
  If same error_class appears ≥ 2×:
    → Generate lesson summary
    → Propose default update to user:
      "Recurring issue detected: <summary>
       Recommended default change: <proposed change>
       Accept? [yes / no / view details]"
    → On accept: update skill_memory_store.yaml defaults
```

---

## Cross-Project Transfer

On new project creation, orchestrator offers:

```
IMPORT FROM PRIOR PROJECT:
  Found: MY_CHIP_v1.0 (tsmc16ffc, completed 2026-03-19)

  Import:
  [✓] Tool stack preferences
  [ ] Design targets (project-specific — skip)
  [✓] Error log lessons
  [✓] DFT configuration
  [✓] RTL coding guidelines / lint waivers
  [ ] PDK selection (re-confirm for new project)
```

---

## User Commands for Memory

At any skill prompt:
```
remember <key> = <value>   → persist immediately to SMS
forget <key>               → clear field in SMS
show preferences           → print full SMS for review
show errors                → print error_log for this stage
why <topic>                → explain the recalled default and its source
set verbosity [terse|normal|verbose]
```

---

*Cross-references: used by all skills in `skills/` directory.*
*See SKILLS_INDEX.md for full skill map.*
