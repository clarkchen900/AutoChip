# ASIC Multi-Agent Skills Framework
## Tool-Aware, PDK-Aware, User-Adaptive Skills for Every Stage of the EDA Flow

**Version:** 1.0
**Status:** Normative Specification
**Parent Document:** `ASIC_MultiAgent_Framework.md` v3.0
**Classification:** Skills + Orchestration Specification

---

## Table of Contents

1. [Skill Execution Model](#1-skill-execution-model)
2. [Memory & Preference System](#2-memory--preference-system)
3. [Tool Detection Protocol](#3-tool-detection-protocol)
4. [PDK Detection & Selection](#4-pdk-detection--selection)
5. [skill:spec_intake — Stage 1 Product Specification](#5-skillspec_intake--stage-1-product-specification)
6. [skill:algo_dev — Stage 2 Algorithm Development](#6-skillalgo_dev--stage-2-algorithm-development)
7. [skill:arch_design — Stage 3 Architecture Design](#7-skillarch_design--stage-3-architecture-design)
8. [skill:rtl_design — Stage 4 RTL Design](#8-skillrtl_design--stage-4-rtl-design)
9. [skill:verification — Stage 5 Functional Verification](#9-skillverification--stage-5-functional-verification)
10. [skill:synthesis — Stage 6 Logic Synthesis](#10-skillsynthesis--stage-6-logic-synthesis)
11. [skill:dft — Stage 6B DFT Insertion](#11-skilldft--stage-6b-dft-insertion)
12. [skill:pnr — Stage 7 Physical Design & P&R](#12-skillpnr--stage-7-physical-design--pr)
13. [skill:sta_signoff — Stage 8 Timing & Power Sign-Off](#13-skillsta_signoff--stage-8-timing--power-sign-off)
14. [skill:physical_verif — Stage 8B Physical Verification](#14-skillphysical_verif--stage-8b-physical-verification)
15. [skill:gdsii_export — Stage 8C GDSII Tape-Out](#15-skillgdsii_export--stage-8c-gdsii-tape-out)
16. [skill:orchestrator — End-to-End & Partial Flow Manager](#16-skillorchestrator--end-to-end--partial-flow-manager)
17. [Skill Interaction Protocol & Error Recovery](#17-skill-interaction-protocol--error-recovery)
18. [Continuous Self-Improvement Engine](#18-continuous-self-improvement-engine)

---

## 1. Skill Execution Model

### 1.1 What a "Skill" Is

In this framework, a **skill** is a structured, interactive procedure executed by an agent. Each skill:

- Detects which tools are available in the current environment
- Prompts the user for stage-specific requirements, offering **industry-default values**
- Launches the appropriate tool(s) with generated configuration
- Validates outputs against quality gates and user intent
- Reports key metrics and flags deviations for human review
- Persists user preferences, decisions, and error history to the **Skill Memory Store**

Skills are **not** static scripts. They are adaptive procedures that evolve with user feedback and recorded execution history.

### 1.2 Skill Lifecycle

```
┌──────────────────────────────────────────────────────────────────────┐
│                        SKILL LIFECYCLE                               │
│                                                                      │
│  [1] ACTIVATE        → receive trigger from orchestrator or user     │
│  [2] RECALL MEMORY   → load user preferences + prior error log       │
│  [3] DETECT TOOLS    → scan environment, present tool choices        │
│  [4] CHECK PDK       → verify PDK availability, prompt if missing    │
│  [5] GATHER REQS     → interactive Q&A with user (defaults shown)    │
│  [6] CONFIRM PLAN    → present execution plan, get user approval     │
│  [7] EXECUTE         → launch tool(s), stream logs                   │
│  [8] VALIDATE OUTPUT → run quality gates, compute metrics            │
│  [9] REPORT          → present metrics, flag issues, ask for review  │
│  [10] RECORD         → save preferences, errors, decisions to memory │
│  [11] SIGNAL         → notify orchestrator: PASS / FAIL / ESCALATE   │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.3 Skill-to-Agent Mapping

| Skill | Primary Agent | Supporting Agents |
|-------|---------------|-------------------|
| skill:spec_intake | agent:pm | agent:algo, agent:arch |
| skill:algo_dev | agent:algo | agent:arch, agent:pm |
| skill:arch_design | agent:arch | agent:rtl, agent:upf, agent:ams |
| skill:rtl_design | agent:rtl[n] | agent:upf, agent:ams |
| skill:verification | agent:verif_lead, agent:tb[n] | agent:formal |
| skill:synthesis | agent:synth | agent:sta, agent:power |
| skill:dft | agent:dft | agent:synth, agent:sta |
| skill:pnr | agent:pnr, agent:fp | agent:sta, agent:power |
| skill:sta_signoff | agent:sta | agent:pnr, agent:power |
| skill:physical_verif | agent:physical_verif | agent:pnr, agent:pdk |
| skill:gdsii_export | agent:orch | agent:physical_verif, agent:pdk |
| skill:orchestrator | agent:orch | ALL |

---

## 2. Memory & Preference System

### 2.1 Skill Memory Store Schema

All skills read from and write to a persistent **Skill Memory Store** (SMS). The SMS is a structured YAML/JSON database with the following schema:

```yaml
# skill_memory_store.yaml — persists across sessions
schema_version: "1.0"

# Global project identity
project:
  name: ""
  design_id: ""                 # e.g., "MY_CHIP_v1.0"
  technology_node: ""           # e.g., "tsmc16ffc", "sky130B"
  pdk_selected: ""
  flow_type: ""                 # "full_custom", "digital", "mixed_signal", "fpga_proto"

# User tool preferences — remembered permanently once set
tool_preferences:
  simulator: ""                 # e.g., "vcs", "questa", "verilator"
  synthesis: ""                 # e.g., "genus", "dc_shell", "yosys"
  pnr: ""                       # e.g., "innovus", "icc2", "openroad"
  sta: ""                       # e.g., "tempus", "primetime", "opensta"
  formal: ""                    # e.g., "jg", "vc_formal", "symbiyosys"
  dft: ""                       # e.g., "modus", "tessent", "openroad_dft"
  lec: ""                       # e.g., "conformal", "formality"
  physical_verif: ""            # e.g., "calibre", "pvs", "magic_netgen"
  power_analysis: ""            # e.g., "voltus", "redhawk", "openroad_power"
  waveform_viewer: ""           # e.g., "simvision", "verdi", "gtkwave"
  backend_flow: ""              # "commercial" | "librelane" | "openroad_standalone"

# Design requirements remembered per project
design_requirements:
  target_frequency_mhz: null
  target_power_mw: null
  die_area_mm2: null
  package_type: ""
  io_count: null
  process_corner: ""            # "typical", "worst", "best"
  voltage_nominal_v: null
  temperature_range: ""         # e.g., "-40 to 125"
  reliability_grade: ""         # "AEC-Q100-G0", "AEC-Q100-G1", "consumer"
  dft_coverage_target: null     # e.g., 99 (stuck-at %)
  clock_domains: []

# Execution history — last N runs per stage
execution_history:
  spec_intake: []
  algo_dev: []
  arch_design: []
  rtl_design: []
  verification: []
  synthesis: []
  dft: []
  pnr: []
  sta_signoff: []
  physical_verif: []
  gdsii_export: []

# Error log — persists for self-improvement
error_log:
  - stage: ""
    timestamp: ""
    tool: ""
    error_class: ""             # "tool_crash", "qos_fail", "license_miss", "timeout", "user_abort"
    error_summary: ""
    resolution: ""
    lesson_learned: ""

# User interaction preferences
interaction_prefs:
  verbosity: "normal"           # "terse" | "normal" | "verbose"
  auto_accept_defaults: false   # if true, skip confirmation dialogs
  always_show_metrics: true
  preferred_report_format: "table"  # "table" | "json" | "text"
  notify_on_gate_pass: true
  notify_on_gate_fail: true
```

### 2.2 Memory Read/Write Rules

| Event | Action |
|-------|--------|
| Skill activation | Read full SMS; load `tool_preferences`, `design_requirements`, `error_log` |
| User selects a tool | Write `tool_preferences.<stage>` immediately |
| User provides a design requirement | Write `design_requirements.<key>` |
| Quality gate fails | Append to `error_log` with `error_class`, summary, lesson_learned |
| User overrides a default | Write to `design_requirements` AND add note to `error_log.lesson_learned` |
| Stage completes (PASS) | Append entry to `execution_history.<stage>` with timestamp, metrics, tool used |
| User explicitly says "remember X" | Parse and store in appropriate field |
| User says "forget X" | Find and clear the relevant field |

### 2.3 Preference Propagation

When the user selects a tool suite (e.g., "Synopsys stack"), the SMS automatically pre-fills all related tool preferences:

```
User selects: "Synopsys"
→ synthesis   := dc_shell / genus (prompt to choose)
→ pnr         := icc2
→ sta         := primetime
→ lec         := formality
→ power       := primepower / redhawk
→ dft         := tessent (if available) else modus
→ physical_verif := pvs / calibre (prompt)
→ simulator   := vcs
→ formal      := vc_formal
```

Similarly for "Cadence stack", "Mentor stack", or "Full open-source (LibreLane)".

---

## 3. Tool Detection Protocol

### 3.1 Detection Procedure

Before presenting tool choices to the user, the skill runs `skill:detect_tools` to inventory the environment:

```
DETECTION SEQUENCE:
─────────────────────────────────────────────────────
1. Scan PATH for tool executables
2. Check license server variables: LM_LICENSE_FILE, SNPSLMD_LICENSE_FILE,
   CDS_LIC_FILE, MGC_HOME
3. Check EDA vendor env vars: SYNOPSYS, CADENCE_HOME, MENTOR_HOME,
   OPENROAD_HOME, YOSYS_ROOT, PDK_ROOT, OPENLANE_ROOT
4. Probe license availability: lmstat -a (if lmgrd accessible)
5. Check module system: module avail (HPC environments)
6. Probe open-source tool versions: yosys --version, openroad --version,
   verilator --version, iverilog -V, magic --version
─────────────────────────────────────────────────────
```

### 3.2 Tool Detection Results Table

After detection, the skill presents a table like:

```
╔══════════════════════════════════════════════════════════════════════╗
║              DETECTED EDA TOOLS IN THIS ENVIRONMENT                 ║
╠══════════════╦══════════════════╦═══════════╦════════════════════════╣
║ Function     ║ Tool             ║ Status    ║ Version / Path         ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Simulation   ║ VCS              ║ ✓ FOUND   ║ 2023.03 /cadtools/vcs  ║
║              ║ Xcelium          ║ ✓ FOUND   ║ 23.09   /cds/xcelium   ║
║              ║ Questa           ║ ✗ NOT FOUND║                       ║
║              ║ Verilator        ║ ✓ FOUND   ║ 5.018   /usr/bin       ║
║              ║ Icarus (iverilog)║ ✓ FOUND   ║ 12.0    /usr/bin       ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Synthesis    ║ Genus            ║ ✓ FOUND   ║ 23.10   /cds/genus     ║
║              ║ DC Shell         ║ ✗ NOT FOUND║                       ║
║              ║ Yosys            ║ ✓ FOUND   ║ 0.38    /usr/bin       ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ P&R          ║ Innovus          ║ ✓ FOUND   ║ 23.11   /cds/innovus   ║
║              ║ ICC2             ║ ✗ NOT FOUND║                       ║
║              ║ OpenROAD         ║ ✓ FOUND   ║ 2.0     /opt/openroad  ║
║              ║ LibreLane        ║ ✓ FOUND   ║ 2.2.8   /opt/librelane ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ STA          ║ Tempus           ║ ✓ FOUND   ║ 23.11   /cds/tempus    ║
║              ║ PrimeTime        ║ ✗ NOT FOUND║                       ║
║              ║ OpenSTA          ║ ✓ FOUND   ║ 2.6.0   /opt/openroad  ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Formal       ║ JasperGold       ║ ✓ FOUND   ║ 23.06   /cds/jg        ║
║              ║ VC Formal        ║ ✗ NOT FOUND║                       ║
║              ║ SymbiYosys       ║ ✓ FOUND   ║ 0.42    /usr/bin       ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ LEC          ║ Conformal        ║ ✓ FOUND   ║ 23.10   /cds/conformal ║
║              ║ Formality        ║ ✗ NOT FOUND║                       ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ DFT          ║ Modus (Cadence)  ║ ✓ FOUND   ║ 23.10   /cds/modus     ║
║              ║ Tessent (Mentor) ║ ✗ NOT FOUND║                       ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Phys. Verif  ║ Calibre (Mentor) ║ ✓ FOUND   ║ 2023.4  /mentor/calib  ║
║              ║ PVS (Cadence)    ║ ✗ NOT FOUND║                       ║
║              ║ Magic + Netgen   ║ ✓ FOUND   ║ 8.3.426 /usr/bin       ║
╚══════════════╩══════════════════╩═══════════╩════════════════════════╝

  Previously remembered preference: Genus + Innovus + Tempus (Cadence stack)
  Press ENTER to accept remembered preferences, or type to override:
```

### 3.3 Tool Suite Quick-Select

```
QUICK SELECT — choose a tool suite:

  [1] Cadence Full Stack     (Xcelium, Genus, Innovus, Tempus, JasperGold, Conformal, Modus, Calibre)
  [2] Synopsys Full Stack    (VCS, DC/Genus-Synopsys, ICC2, PrimeTime, VC-Formal, Formality, Tessent)
  [3] Mentor/Siemens Stack   (Questa, Precision/Catapult, Calibre, Tessent)
  [4] Mixed Commercial       (specify per tool below)
  [5] Full Open Source       (Verilator/Icarus, Yosys, OpenROAD, OpenSTA, SymbiYosys, Magic, Netgen)
  [6] LibreLane Flow         (Yosys + OpenROAD + Magic + Netgen — automated GDSII pipeline)
  [7] Hybrid: OSS front-end + Commercial backend
  [8] Custom (select each tool individually)

  > _
```

### 3.4 Open-Source Full Flow (LibreLane / OpenROAD)

When option [5] or [6] is selected, the skill activates the **LibreLane mode**, which uses the following tool chain:

```
LibreLane / OpenROAD Open-Source EDA Stack
──────────────────────────────────────────────────────────────
Stage           Tool(s)                     Config Format
──────────────────────────────────────────────────────────────
Simulation      Verilator, Icarus iverilog   tb/*.sv, tb/*.v
Synthesis       Yosys (synth_<pdk>)          synth.tcl
LEC             Yosys equiv
Formal          SymbiYosys (.sby files)
Floorplan       OpenROAD (ifp, tapcell)      config.json / .tcl
PDN             OpenROAD (pdngen)            pdn.cfg
Placement       OpenROAD (gpl, dpl)
CTS             OpenROAD (cts)
Routing         OpenROAD (grt, drt / TritonRoute)
STA             OpenSTA (bundled in OpenROAD)
IR Drop         OpenROAD (psm)
Phys. Verif     Magic + Netgen (DRC/LVS)    .magicrc, PDK rules
GDSII export    Magic → .gds / KLayout .gds
Viewing         KLayout (GDS viewer)
──────────────────────────────────────────────────────────────

NOTE: LibreLane is mature for sky130B, GF180MCU, IHP 130nm.
      For advanced nodes (28nm+), commercial tools are recommended.
      LibreLane supports TSMC/GF commercial PDKs with proper
      rule files — requires NDA PDK access.
```

---

## 4. PDK Detection & Selection

### 4.1 PDK Detection Procedure

```
PDK DETECTION SEQUENCE:
───────────────────────────────────────────────────────────────
1. Check env vars:
     PDK_ROOT, PDKPATH, STDCELLS, TIMING_LIBS, TECH_DIR
     CDS_PDK_DIR (Cadence Virtuoso), SYNOPSYS_CUSTOM_DESIGNER
     OPENLANE_PDK, CARAVEL_ROOT (efabless)
2. Check standard install paths:
     /opt/pdk, /pdk, /home/<user>/pdk, $HOME/pdk
     /opt/open_pdks, /opt/skywater-pdk, /opt/gf180mcu-pdk
3. Scan for known PDK markers:
     sky130A/, sky130B/    → SkyWater 130nm CMOS (open)
     gf180mcuA-D/          → GlobalFoundries 180nm MCU (open)
     ihp-sg13g2/           → IHP BiCMOS 130nm (open, experimental)
     tsmc*/                → TSMC (NDA required)
     samsung*/             → Samsung (NDA required)
     gf*/                  → GlobalFoundries advanced (NDA required)
     intel*/               → Intel 18A / 3 / 4 (NDA required)
     smic*/                → SMIC (NDA required)
4. Check for Liberty (.lib), LEF/DEF, GDS cell libraries
   at detected PDK root paths
───────────────────────────────────────────────────────────────
```

### 4.2 PDK Selection Dialog

```
╔══════════════════════════════════════════════════════════════╗
║                    PDK SELECTION                             ║
╠══════════════════╦═══════════╦══════════════╦═══════════════╣
║ PDK              ║ Status    ║ Node / Foundry║ License       ║
╠══════════════════╬═══════════╬══════════════╬═══════════════╣
║ sky130B          ║ ✓ FOUND   ║ 130nm / SKW  ║ Open (Apache) ║
║ gf180mcuC        ║ ✓ FOUND   ║ 180nm / GF   ║ Open (Apache) ║
║ ihp-sg13g2       ║ ✗ NOT FND ║ 130nm / IHP  ║ Open (CDL)    ║
║ tsmc16ffc        ║ ✓ FOUND * ║ 16nm FinFET  ║ NDA required  ║
║ tsmc28hpc+       ║ ✗ NOT FND ║ 28nm / TSMC  ║ NDA required  ║
║ gf12lp+          ║ ✗ NOT FND ║ 12nm / GF    ║ NDA required  ║
║ [Custom path]    ║ — specify ║ —            ║ —             ║
╚══════════════════╩═══════════╩══════════════╩═══════════════╝

  * License file detected but not verified — may require authentication.

RECOMMENDATION based on your design requirements:
  Target freq = 1 GHz, Power = 50 mW → tsmc16ffc (production-grade)
  Prototype / learning → sky130B (fully open, free MPW available via efabless)

Select PDK [sky130B / gf180mcuC / tsmc16ffc / custom path]:
> _
```

### 4.3 PDK Capability Matrix

When the user selects a PDK, the skill reports available cell libraries:

```
PDK: tsmc16ffc — Available Libraries
──────────────────────────────────────────────────────────────
Library Type     Contents                    Status
──────────────────────────────────────────────────────────────
Standard Cells   tcbn16ffcllbwp16p90         ✓ Found
                 tcbn16ffcllbwp16p90cg (ICG) ✓ Found
IO Cells         tphn16ffcllgv18             ✓ Found
Memory Compiler  tsmc_sp_hd_16ffc (SRAM)     ✓ Found
Analog IP        pll_tsmc16ffc_v2p0          ✓ Found
eFuse / OTP      — not detected              ✗ Missing → prompt
Tech LEF         tsmc16ffc.tlef              ✓ Found
DRC Runset       Calibre tsmc16ffc.drc       ✓ Found
LVS Runset       Calibre tsmc16ffc.lvs       ✓ Found
Antenna Rules    antenna.drc                 ✓ Found
──────────────────────────────────────────────────────────────
Missing components will be flagged before each dependent stage.
```

---

## 5. skill:spec_intake — Stage 1 Product Specification

### 5.1 Trigger
Activated by: `orchestrator.stage_start("spec_intake")` | user command `run skill:spec_intake`

### 5.2 Memory Recall
```
RECALL:
  - Prior project name, design ID, technology node
  - Remembered doc format preferences
  - Prior error: "user rejected auto-generated spec template → always show choices"
```

### 5.3 Requirements Gathering Dialog

```
╔══════════════════════════════════════════════════════════════════╗
║            STAGE 1: PRODUCT SPECIFICATION INTAKE                 ║
╚══════════════════════════════════════════════════════════════════╝

I will help you capture the product specification. Please answer
the following. Press ENTER to accept the default [shown in brackets].

── PROJECT IDENTITY ──────────────────────────────────────────────
  Design name:                          [MY_CHIP]
  Version:                              [v1.0]
  Design type:                          [1] Digital  [2] Mixed-Signal  [3] Custom
  Target application:                   [consumer / automotive / industrial / mil-aero]

── PERFORMANCE REQUIREMENTS ──────────────────────────────────────
  Target operating frequency (MHz):     [500]
  Number of clock domains:              [1]
  Clock uncertainty budget (ps):        [50]
  Performance-critical paths:          (describe or skip)

── INTERFACE & IO ────────────────────────────────────────────────
  Primary interface protocol(s):        [AXI4, APB, SPI, I2C, UART, PCIe, DDR, custom]
  IO count (digital / analog):          [100 / 0]
  IO voltage domains:                   [1.8V core, 3.3V IO]

── POWER REQUIREMENTS ────────────────────────────────────────────
  Maximum active power (mW):            [100]
  Maximum leakage (μW):                 [50]
  Power management: sleep / retention:  [yes / no]
  Number of power domains:              [1]

── AREA & PACKAGE ────────────────────────────────────────────────
  Target die area (mm²):                [10]
  Package type:                         [QFP / BGA / CSP / bare die]
  Gate count estimate:                  [1M gates]

── RELIABILITY & ENVIRONMENT ─────────────────────────────────────
  Temperature range (°C):               [-40 to 85]
  Reliability grade:                    [Consumer / AEC-Q100-G2 / AEC-Q100-G1 / AEC-Q100-G0]
  ESD protection level (HBM kV):       [2]
  Operating lifetime (years):           [10]

── VERIFICATION REQUIREMENTS ─────────────────────────────────────
  Functional coverage target (%):       [95]
  DFT stuck-at coverage target (%):     [99]
  Formal verification required:         [yes / no]
  Emulation platform available:         [no / Palladium / Veloce / VCS VIP]

── DELIVERABLES ──────────────────────────────────────────────────
  Final output format:                  [GDSII / OASIS / both]
  Tape-out target date:                 [specify]
  Foundry target:                       [TSMC / GF / Samsung / open-source MPW]

All defaults shown. Provide values to override, or type 'accept all defaults'
```

### 5.4 Output Artifacts

| Artifact | Path | Format |
|----------|------|--------|
| Product specification | `spec/product_spec_v1.0.yaml` | YAML (structured) |
| Human-readable spec | `spec/product_spec_v1.0.md` | Markdown |
| Requirements traceability matrix | `spec/rtm_v1.0.csv` | CSV |
| Clock domain diagram | `spec/clocks.svg` | SVG |

### 5.5 Intent Double-Check

```
╔══════════════════════════════════════════════════════════════════╗
║  SPECIFICATION REVIEW — Please confirm this matches your intent  ║
╚══════════════════════════════════════════════════════════════════╝

KEY DECISIONS:
  ✦ Technology: tsmc16ffc (16nm FinFET)
  ✦ Target: 1.0 GHz, 50 mW, 5 mm² die
  ✦ Application: Automotive (AEC-Q100 Grade 1)
  ✦ Reliability: 10yr / 125°C EOL, guardband required
  ✦ DFT: Stuck-at ≥99%, Transition ≥97%
  ✦ Power domains: 3 (core, periphery, retention)

FEASIBILITY ASSESSMENT:
  ○ Frequency vs. node:     1 GHz at 16nm → FEASIBLE (typical Fmax ~2+ GHz)
  ○ Power vs. area:         50 mW / 5 mm² → FEASIBLE (10 mW/mm²)
  ○ Gate density:           1M gates / 5 mm² → LOW DENSITY — die area may shrink
  ✗ AEC-Q100-G1 + 1 GHz:   Requires ~38% synthesis margin at EOL — NOTE THIS
  ✗ 3 power domains + DFT: PA-GLS is mandatory blocking gate — confirm readiness

RISKS FLAGGED:
  [R1] Retention domain with scan: need OCC on retained clock domain
  [R2] No emulation platform — late bug discovery risk at gate sim stage

Does this match your intent? [yes / edit / abort]
> _
```

### 5.6 Memory Recording
```yaml
# Written to SMS after stage completion
project:
  name: "MY_CHIP"
  design_id: "MY_CHIP_v1.0"
  technology_node: "tsmc16ffc"
design_requirements:
  target_frequency_mhz: 1000
  target_power_mw: 50
  die_area_mm2: 5.0
  reliability_grade: "AEC-Q100-G1"
  dft_coverage_target: 99
execution_history:
  spec_intake:
    - timestamp: "2026-03-19T10:00:00Z"
      result: "PASS"
      artifacts: ["spec/product_spec_v1.0.yaml"]
      decisions: ["AEC-Q100-G1 confirmed", "3 power domains confirmed"]
```

---

## 6. skill:algo_dev — Stage 2 Algorithm Development

### 6.1 Trigger
Activated after GATE-01 approval (`spec_intake` PASS + human sign-off).

### 6.2 Tool Detection — Algorithm Domain

```
ALGORITHM DEVELOPMENT TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Category          Tool              Status    Notes
──────────────────────────────────────────────────────────────────
DSP / Math        MATLAB            ✓ FOUND   R2023b (preferred for baseband)
                  Octave            ✓ FOUND   8.4 (open-source MATLAB compat.)
                  Python/NumPy      ✓ FOUND   3.11 (universal)
                  Julia             ✗ NOT FND
Algorithm Sim     Simulink          ✓ FOUND   (HDL Coder available)
                  Scilab/Xcos       ✓ FOUND   open source
HLS Tools         Catapult HLS      ✗ NOT FND  (Mentor/Siemens)
                  Vitis HLS         ✓ FOUND   2023.2 (Xilinx/AMD)
                  Intel HLS         ✗ NOT FND
                  Bambu HLS         ✓ FOUND   open source
Fixed-point       MATLAB Fixed-Pt   ✓ FOUND   (with Simulink)
                  fxpmath (Python)  ✓ FOUND   pip
Co-simulation     SystemC           ✓ FOUND   2.3.4
                  PyMTL3            ✓ FOUND   open source
SNR/BER bench     GNU Radio         ✓ FOUND   3.10
──────────────────────────────────────────────────────────────────

QUICK SELECT algorithm tool:
  [1] MATLAB + Simulink (full featured, HDL Coder path)
  [2] Python + NumPy/SciPy (open, flexible)
  [3] Octave (MATLAB compatible, open)
  [4] SystemC behavioral model (closest to RTL)
  [5] HLS-first (Catapult / Vitis HLS / Bambu)
```

### 6.3 Requirements Gathering

```
STAGE 2: ALGORITHM DEVELOPMENT REQUIREMENTS

  Algorithm type:        [DSP / ML inference / crypto / control / comms / custom]
  Bit-width requirement: [fixed-point / floating-point / both]
    If fixed-point: int bits / frac bits [16.16 / 32.0 / custom]
  Target SNR/accuracy:   [specify or N/A]
  HLS target:            [yes → go to HLS flow / no → hand-written RTL]
  Performance metric:    [throughput Gbps / latency ns / both]
  Reference model:       [provide path or URL, or generate template]
  Golden test vectors:   [generate / provide / skip for now]
```

### 6.4 Output Validation Metrics

```
ALGORITHM STAGE METRICS — Review Required
────────────────────────────────────────────────────────────
Metric                    Result      Target      Status
────────────────────────────────────────────────────────────
Peak SNR                  54.2 dB     ≥52 dB      ✓ PASS
Throughput (model)        2.4 Gbps    ≥2.0 Gbps   ✓ PASS
Latency (model)           120 ns      ≤150 ns     ✓ PASS
Fixed-point overflow      0 events    0           ✓ PASS
Coverage of test vec.     100%        100%        ✓ PASS
Estimated gate count      850K        ≤1M         ✓ PASS
HLS QoR (if used):
  Latency (cycles)        240         ≤256        ✓ PASS
  Area (LUT equiv)        82K         ≤100K       ✓ PASS
────────────────────────────────────────────────────────────
Overall: PASS — approved for GATE-02
```

### 6.5 Memory Recording
```yaml
execution_history:
  algo_dev:
    - timestamp: "..."
      tool: "MATLAB + Simulink"
      result: "PASS"
      metrics:
        snr_db: 54.2
        throughput_gbps: 2.4
        latency_ns: 120
        gate_count_est: 850000
      artifacts: ["algo/golden_model.m", "algo/test_vectors.csv",
                  "algo/algo_spec_v1.0.md"]
```

---

## 7. skill:arch_design — Stage 3 Architecture Design

### 7.1 Trigger
Activated after GATE-02 approval.

### 7.2 Tool Detection — Architecture Domain

```
ARCHITECTURE TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Category        Tool                  Status
──────────────────────────────────────────────────────────────────
Block diagrams  draw.io / diagrams.net ✓ (web/desktop)
                PlantUML              ✓ FOUND   (text-based UML)
                Mermaid               ✓ FOUND   (markdown-embedded)
Bus analysis    SpreadsheetML         ✓ (any Excel-compat)
Perf. modeling  gem5 simulator        ✗ NOT FND
                CACTI (memory model)  ✓ FOUND
                McPAT (power model)   ✗ NOT FND
Arch. DSL       SPIRIT/IP-XACT        — (check XMLs in spec/)
                SystemRDL             ✓ FOUND   (ordt compiler)
                PeakRDL               ✓ FOUND
CDC Analysis    SpyGlass-CDC (lint)   ✓ FOUND   (early arch lint)
                Meridian CDC          ✗ NOT FND
                Questa CDC            ✗ NOT FND
──────────────────────────────────────────────────────────────────
```

### 7.3 Requirements Gathering

```
STAGE 3: ARCHITECTURE DESIGN REQUIREMENTS

  Top-level partitioning:
    Provide block list or generate template? [generate template]
    Estimated blocks:                        [specify count or leave blank]

  Clock architecture:
    Number of clock domains:                 [recalled: 3]
    Clock sources: PLL / crystal / external  [PLL (on-chip)]
    CDC handling strategy:                   [async FIFO / 2FF sync / handshake]
    ICG policy (clock gating):               [cell-based ICG, no logic gating]

  Memory subsystem:
    On-chip SRAM (KB):                       [256]
    Memory compiler:                         [foundry SRAM / OpenRAM / TSMC TS6N]
    Cache or scratchpad:                     [scratchpad]

  Bus/interconnect:
    Primary bus protocol:                    [AXI4, APB, AHB, NoC, custom]
    Bus width (bits):                        [64]

  Power architecture:
    Power domains:                           [recalled: 3 — confirm boundaries]
    Retention registers needed:              [yes / no]

  Hierarchy:
    Total gate count estimate:               [recalled: 1M]
    Flat or hierarchical:                    [flat if <5M / hier if >5M — auto]
    SoC integration (multiple IP blocks):    [yes / no]
```

### 7.4 Auto-Generated Architecture Artifacts

```
GENERATING ARCHITECTURE ARTIFACTS:
  ✓ arch/block_diagram.svg           — top-level block diagram
  ✓ arch/clock_domains.yaml          — all clocks, frequencies, CDC pairs
  ✓ arch/power_intent.yaml           — power domain boundaries (→ UPF input)
  ✓ arch/bus_matrix.yaml             — master/slave connectivity
  ✓ arch/memory_map.yaml             — address map (→ SystemRDL / IP-XACT)
  ✓ arch/interface_spec.yaml         — IO protocol list
  ✓ arch/perf_model.yaml             — estimated throughput / latency budget
  ✓ spec/arch_spec_v1.0.md           — human-readable architecture doc
```

### 7.5 Output Metrics

```
ARCHITECTURE REVIEW METRICS
────────────────────────────────────────────────────────────
Metric                    Result           Status
────────────────────────────────────────────────────────────
CDC pairs identified      12               documented
Power domains             3 (confirmed)    matches spec
SRAM compiler available   YES (TSMC TS6N)  ✓
Address map complete      YES (no overlap) ✓ PASS
Estimated area            4.2 mm²          ≤5 mm² target ✓
Estimated power (arch)    42 mW            ≤50 mW target ✓
Bus utilization (model)   68%              <80% ✓
Arch CDC lint             0 violations     ✓ PASS
────────────────────────────────────────────────────────────
GATE-03 criteria met? YES → Awaiting human approval
```

---

## 8. skill:rtl_design — Stage 4 RTL Design

### 8.1 Trigger
Activated after GATE-03 approval.

### 8.2 Tool Detection — RTL Domain

```
RTL DESIGN & LINT TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Category        Tool                   Status     Vendor
──────────────────────────────────────────────────────────────────
HDL Editor      VS Code + HDL plugin   ✓ FOUND    Open
                Emacs + verilog-mode   ✓ FOUND    Open
Simulator       VCS                    ✓ FOUND    Synopsys
                Xcelium                ✓ FOUND    Cadence
                Verilator              ✓ FOUND    Open
                Icarus (iverilog)      ✓ FOUND    Open
RTL Lint        SpyGlass               ✓ FOUND    Synopsys/Atrenta
                Jasper Lint (JasperGold)✓ FOUND   Cadence
                Verilator --lint-only  ✓ FOUND    Open
                Slang (lint)           ✗ NOT FND   Open
CDC Analysis    SpyGlass CDC           ✓ FOUND    Synopsys
                Meridian CDC           ✗ NOT FND   Cadence
UPF/Power Lint  SpyGlass Power         ✓ FOUND    Synopsys
                Power Artist           ✗ NOT FND
Version Control Git                    ✓ FOUND    Open
──────────────────────────────────────────────────────────────────
```

### 8.3 Requirements Gathering

```
STAGE 4: RTL DESIGN REQUIREMENTS

  HDL language:               [SystemVerilog (recommended) / VHDL / mixed]
  Coding guidelines:          [company style guide / provide template / use built-in]
  RTL block assignment:
    Auto-partition from arch  [yes — generate stub files per block]
    Manual partitioning       [no — I will provide]

  Quality gates to enforce:
    Lint (syntax + style):    [SpyGlass / Verilator / Jasper Lint]
    CDC lint:                 [SpyGlass CDC / Meridian / Questa CDC]
    UPF/Power lint:           [SpyGlass Power / Power Artist / skip]
    Assertion density target: [1 assertion per 10 lines of RTL]
    Clock gating policy:      [cell-based ICG only — no combinational gates]

  Code coverage target:       [line 100% / branch 95% / toggle 90% / FSM 100%]
  Lint clean target:          [zero errors, zero warnings (waivable with justification)]

  Generate boilerplate:
    Module headers + copyright [yes / no]
    Default parameter values   [yes / no]
    Basic I/O sanity checks    [yes / no]
    FSM template (gray/binary) [yes / no]
```

### 8.4 Automated Quality Gates

The skill runs the following gates after each RTL submission:

```
RTL QUALITY GATES — AUTOMATED
──────────────────────────────────────────────────────────────────────────
Gate   Check                         Tool           Pass Criterion
──────────────────────────────────────────────────────────────────────────
R-QG-01 Syntax clean                 Xcelium/VCS    Zero compile errors
R-QG-02 Lint clean (style)           SpyGlass       0 errors, waived warns logged
R-QG-03 CDC structural clean         SpyGlass CDC   0 unresolved CDC violations
R-QG-04 Clock gating policy         SpyGlass/custom No ungated clocks; ICG only
R-QG-05 UPF/power lint              SpyGlass Power  0 errors on power domains
R-QG-06 Assertion density           wc -l / grep   ≥1 assertion / 10 RTL lines
R-QG-07 No latches inferred         Lint warning   0 latches (unless intentional)
R-QG-08 No tri-state internal nets  Lint           0 internal Z-state nets
R-QG-09 RTL simulation smoke test   Xcelium/VCS    Basic reset/init test PASS
R-QG-10 Code coverage (smoke)       Xcelium/VCS    Line ≥ 50% (full: Stage 5)
──────────────────────────────────────────────────────────────────────────
FAILED GATES → ITERATION: Defects returned to agent:rtl[n] for correction
```

### 8.5 Output Metrics Table

```
RTL DESIGN METRICS
────────────────────────────────────────────────────────────
Metric                  Result       Target       Status
────────────────────────────────────────────────────────────
Total RTL lines         28,450       —            INFO
Module count            47           —            INFO
Lint errors             0            0            ✓ PASS
Lint warnings (waived)  12           documented   ✓ PASS
CDC violations          0            0            ✓ PASS
Latches inferred        0            0            ✓ PASS
UPF power lint errors   0            0            ✓ PASS
Assertion count         3,102        ≥2,845       ✓ PASS
Smoke sim pass          YES          YES          ✓ PASS
Estimated gate count    920K         ≤1M          ✓ PASS
────────────────────────────────────────────────────────────
GATE-04 criteria met? YES → Awaiting human RTL Lead approval
```

### 8.6 Memory Recording
```yaml
error_log:
  - stage: "rtl_design"
    tool: "SpyGlass"
    error_class: "qos_fail"
    error_summary: "CDC violation on domain clk_fast→clk_slow in module xyz"
    resolution: "Added 2FF synchronizer per arch recommendation"
    lesson_learned: "Always add 2FF sync at domain crossings before CDC lint"
tool_preferences:
  simulator: "xcelium"
  lint: "spyglass"
```

---

## 9. skill:verification — Stage 5 Functional Verification

### 9.1 Trigger
Activated in parallel with Stage 4 (after GATE-03). Escalates to blocking at GATE-05.

### 9.2 Tool Detection — Verification Domain

```
VERIFICATION TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Category         Tool                  Status     Vendor
──────────────────────────────────────────────────────────────────
Simulator        VCS                   ✓ FOUND    Synopsys
                 Xcelium               ✓ FOUND    Cadence
                 Questa                ✗ NOT FND  Mentor
                 Verilator             ✓ FOUND    Open (cycle-acc.)
                 Icarus iverilog       ✓ FOUND    Open (event-sim)
Coverage         IMC (Xcelium)         ✓ FOUND    Cadence
                 URG (VCS)             ✓ FOUND    Synopsys
                 Verilator coverage    ✓ FOUND    Open
Formal Verif.    JasperGold            ✓ FOUND    Cadence
                 VC Formal             ✗ NOT FND  Synopsys
                 SymbiYosys            ✓ FOUND    Open
Emulation        Palladium Z1          ✗ NOT FND  Cadence
                 Veloce (Questa)       ✗ NOT FND  Mentor
                 FPGA proto            ✓ (if board available)
VIP / Protocol   Cadence VIP (AXI etc) ✓ FOUND    Cadence
                 Synopsys VIP          ✗ NOT FND
UVM Library      Cadence UVM           ✓ FOUND    Cadence
                 Open UVM (accellera)  ✓ FOUND    Open
──────────────────────────────────────────────────────────────────
```

### 9.3 Requirements Gathering

```
STAGE 5: VERIFICATION REQUIREMENTS

  Verification methodology:    [UVM (recommended) / directed TB / formal-only / hybrid]
  Simulator choice:            [recalled: Xcelium]
  Regression strategy:         [nightly / on-commit / manual trigger]
  Coverage model:
    Functional coverage target [95% (industry default)]
    Code coverage: line/branch [100% / 95%]
    Toggle coverage            [90%]
    FSM coverage               [100% — all arcs]
  Formal verification scope:   [connectivity / control logic / full block / none]
  CDC formal proof:            [yes (recommended) / no]
  UPF PA simulation:           [yes (mandatory for power domains) / no]
  Gate-level simulation:       [post-synth max-SDF / min-SDF / X-optim / X-pessim (all 4 recommended)]
  GLS mode selection:
    [1] All 4 modes (gold standard)
    [2] max-SDF + X-pessimistic only (faster)
    [3] Skip (NOT RECOMMENDED — document risk)
  Regression infrastructure:   [LSF / Kubernetes / local / cloud (AWS Batch)]
  Waveform viewer:             [SimVision / Verdi / GTKWave]
```

### 9.4 Verification Plan Generation

```
GENERATING VERIFICATION PLAN:
  ✓ verif/vplan_v1.0.md          — full verification plan
  ✓ verif/tb_top.sv              — testbench top-level UVM stub
  ✓ verif/env/                   — UVM env, agents, sequences
  ✓ verif/coverage/cov_model.sv  — functional coverage model
  ✓ verif/regression/Makefile    — regression targets
  ✓ verif/formal/jg_tcl/         — JasperGold setup scripts
  ✓ verif/gls/run_gls.tcl        — GLS 4-mode runner

VIP SELECTION:
  AXI4 VIP:    Cadence VIP (AXI-AW, AR, W, R, B channels) → auto-configured
  APB VIP:     Cadence VIP → auto-configured
  Custom VIP:  [describe your custom protocol or skip]
```

### 9.5 Quality Gate Metrics

```
VERIFICATION METRICS (Final Sign-Off)
────────────────────────────────────────────────────────────────
Metric                         Result     Target     Status
────────────────────────────────────────────────────────────────
Functional coverage            96.3%      ≥95%       ✓ PASS
Line coverage                  100%       100%       ✓ PASS
Branch coverage                97.2%      ≥95%       ✓ PASS
Toggle coverage                92.1%      ≥90%       ✓ PASS
FSM coverage                   100%       100%       ✓ PASS
Regression: tests run          4,820      —          INFO
Regression: failures           0          0          ✓ PASS
Formal: properties proven      142        —          INFO
Formal: vacuous assertions     0          0          ✓ PASS
CDC formal: domains proven     12/12      all        ✓ PASS
UPF PA-sim: power violations   0          0          ✓ PASS
GLS max-SDF: X-state failures  0          0          ✓ PASS
GLS min-SDF: hold failures     0          0          ✓ PASS
GLS X-pessim: failures         0          0          ✓ PASS
────────────────────────────────────────────────────────────────
GATE-05 criteria met? YES → Awaiting human Verif Lead approval
```

---

## 10. skill:synthesis — Stage 6 Logic Synthesis

### 10.1 Trigger
Activated after GATE-05 approval.

### 10.2 Tool Detection — Synthesis Domain

```
SYNTHESIS TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Tool                Status    Vendor     Notes
──────────────────────────────────────────────────────────────────
Genus               ✓ FOUND   Cadence    23.10 — recommended
DC Shell            ✗ NOT FND Synopsys
DC Ultra            ✗ NOT FND Synopsys
Yosys               ✓ FOUND   Open       0.38 — use with open PDKs
Yosys + ABC         ✓ FOUND   Open       optimization passes
Bambu HLS→RTL       ✓ FOUND   Open       if HLS was used
Precision (Mentor)  ✗ NOT FND Mentor/Sie FPGA synthesis only
──────────────────────────────────────────────────────────────────
LEC (post-synth):
  Conformal         ✓ FOUND   Cadence
  Formality         ✗ NOT FND Synopsys
  Yosys equiv       ✓ FOUND   Open

Power Analysis (pre-route):
  Joules (Genus)    ✓ FOUND   Cadence
  PrimePower        ✗ NOT FND Synopsys
  OpenROAD psm      ✓ FOUND   Open
──────────────────────────────────────────────────────────────────
```

### 10.3 Requirements Gathering

```
STAGE 6: SYNTHESIS REQUIREMENTS

  Synthesis tool:          [recalled: Genus]
  PDK:                     [recalled: tsmc16ffc]
  Standard cell library:   [tcbn16ffcllbwp16p90 — confirmed available]
  ICG cell library:        [tcbn16ffcllbwp16p90cg — confirmed available]

  CONSTRAINTS:
    Target clock period (ps):       [1000 (= 1 GHz, recalled)]
    Clock uncertainty (setup) ps:   [50]
    Clock uncertainty (hold) ps:    [25]
    Input/output delay (ps):        [200 input, 200 output — or provide SDC]

  OPTIMIZATION MODE:
    [1] timing_effort = high (default production)
    [2] area_effort   = high (area-critical design)
    [3] power_effort  = high (power-critical)
    [4] balanced      (timing + area + power equal weight)
    Your choice:             [1]

  MULTI-CORNER MULTI-MODE (MCMM):
    Enable MCMM synthesis:   [yes (strongly recommended)]
    Corners to target:
      [✓] WC SS 0.72V 125°C (worst-case setup)
      [✓] WC SS 0.72V -40°C (worst-case hold)
      [✓] TC TT 0.8V 25°C   (typical)
      [✓] BC FF 0.88V -40°C (best-case)
    On-chip variation:
      POCV (recommended for 16nm): [yes]
      AOCV (simpler):              [no]

  POWER INTENT:
    Apply UPF during synthesis:    [yes — use arch/power_intent.yaml]
    ICG insertion in synthesis:    [yes]
    ICG coverage target:           [>80% of all register banks]

  DFT PREPARATION:
    Scan enable DFT constraints:   [yes — load dft/scan_mode.sdc]
    OCC scan clock constraints:    [yes — load dft/occ_constraints.sdc]

  QUALITY TARGETS:
    WNS after synthesis (ps):      [≥+200 — 20% margin at 1 GHz]
    TNS:                           [0]
    Max fanout:                    [20]
    Max transition (ps):           [300]
    Max capacitance (fF):          [200]
    Area (μm²):                    [auto — report only]
```

### 10.4 Synthesis Execution Steps

```
SYNTHESIS EXECUTION PLAN (Genus):
  Step 1: Read RTL                   genus -legacy_ui -log genus.log
  Step 2: Read liberty (.lib) files  foreach corner { read_libs ... }
  Step 3: Read tech LEF              read_physical -lef tsmc16ffc.tlef
  Step 4: Apply UPF                  read_power_intent -format upf
  Step 5: Read timing constraints    read_sdc constraints_mcmm.sdc
  Step 6: Elaborate design           elaborate MY_CHIP
  Step 7: Generic synthesis          syn_generic -effort high
  Step 8: Technology mapping         syn_map -effort high
  Step 9: Incremental optimization   syn_opt -effort high
  Step 10: Insert ICG cells          insert_clock_gating -coverage 0.85
  Step 11: Final timing opt          optimize_design -incremental
  Step 12: Write netlist             write_hdl > netlist/MY_CHIP_synth.v
  Step 13: Write SDC                 write_sdc > constraints/MY_CHIP_synth.sdc
  Step 14: Write UPF                 write_power_intent -format upf
  Step 15: LEC checkpoint            conformal -nogui -dofile lec/lec_rtl_vs_netlist.tcl
  Step 16: Generate reports          report_timing / report_area / report_power
```

### 10.5 Output Metrics

```
SYNTHESIS RESULTS — HUMAN REVIEW REQUIRED
─────────────────────────────────────────────────────────────────────
Metric                          Value         Target        Status
─────────────────────────────────────────────────────────────────────
WNS (WC SS 0.72V 125°C) ps      +215          ≥+200         ✓ PASS
TNS                             0             0             ✓ PASS
WNS (hold WC SS -40°C) ps       +45           ≥0            ✓ PASS
Max fanout (violations)         0             0             ✓ PASS
Max transition (violations)     2             0           ✗ WARN → review
Max cap (violations)            0             0             ✓ PASS
Cell count                      920,412       —             INFO
Combinational area (μm²)        1,842,000     —             INFO
Sequential area (μm²)           980,000       —             INFO
Total area (μm²)                3,102,000     ≤4,000,000   ✓ PASS
ICG cell count                  2,847         —             INFO
ICG coverage (register banks)  87%           ≥80%          ✓ PASS
Power (pre-route estimate)      38.2 mW       ≤50 mW        ✓ PASS
LEC RTL vs. netlist             EQUIVALENT    EQUIVALENT    ✓ PASS
─────────────────────────────────────────────────────────────────────
⚠ Max transition: 2 violations on output pads — review IO buffer sizing
  Recommended action: upsize output drivers on pad ring
  [auto-fix / manual review / accept with note]
─────────────────────────────────────────────────────────────────────
GATE-06 criteria met? CONDITIONAL — resolve max_tran violations first
```

---

## 11. skill:dft — Stage 6B DFT Insertion

### 11.1 Trigger
Activated in parallel with or immediately after synthesis, before P&R.

### 11.2 Tool Detection

```
DFT TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Tool              Status    Vendor     Notes
──────────────────────────────────────────────────────────────────
Modus             ✓ FOUND   Cadence    Full ATPG suite
Tessent           ✗ NOT FND Mentor/Sie Industry leading for automotive
TetraMAX          ✗ NOT FND Synopsys
SynTest           ✗ NOT FND SynTest
OpenROAD DFT      ✓ FOUND   Open       Basic scan insertion only
FreePDK DFT       ✗ NOT FND
──────────────────────────────────────────────────────────────────
ATPG Simulation:  Uses primary simulator (recalled: Xcelium) for fault sim
OCC cells:        Check PDK cell library for OCC models... ✓ FOUND (tsmc16ffc)
BIST controllers: Check PDK for MBIST/LBIST macros... ✓ FOUND (Cadence MBIST)
──────────────────────────────────────────────────────────────────
```

### 11.3 Requirements Gathering

```
STAGE 6B: DFT REQUIREMENTS

  DFT tool:                   [recalled: Modus]
  Test architecture:
    Scan insertion:            [yes]
    Scan compression:          [yes — recommended]
      Compression ratio:       [64× (default) / specify]
    MBIST for SRAMs:           [yes — Cadence MBIST detected]
    LBIST:                     [no / yes (higher cost)]
    Boundary scan (JTAG):      [IEEE 1149.1 yes / no]
    OCC for at-speed test:     [yes (recommended for transition/path-delay)]

  Coverage targets:
    Stuck-at fault coverage:   [recalled: 99%]
    Transition fault coverage: [97%]
    Path delay coverage:       [90%]
    Cell-aware coverage:       [98%]

  Test modes:
    Normal mission mode:       [confirmed]
    Slow scan (capture=slow):  [yes]
    Fast capture (transition): [yes — requires OCC]
    IDDQ testing:              [yes / no (PDK dependent)]

  Pattern count target:        [auto-optimize for <5000 patterns]
  Scan chain count:            [auto (target 2000-5000 FF/chain)]
  ATE format:                  [STIL / WGL / ASCII-WGL / Verilog patterns]
```

### 11.4 Output Metrics

```
DFT RESULTS
─────────────────────────────────────────────────────────────────────
Metric                     Value      Target       Status
─────────────────────────────────────────────────────────────────────
Stuck-at coverage          99.3%      ≥99%         ✓ PASS
Transition coverage        97.8%      ≥97%         ✓ PASS
Path delay coverage        91.2%      ≥90%         ✓ PASS
Cell-aware coverage        98.4%      ≥98%         ✓ PASS
Untestable (AU+UO+UU)      0.2%       ≤0.5%        ✓ PASS
Scan chain count           184        —            INFO
FF per scan chain (avg)    5,002      2K–10K       ✓ PASS
Compression ratio          68×        ≥50×         ✓ PASS
Pattern count (ATPG)       3,847      ≤5K          ✓ PASS
MBIST controllers          8          —            INFO
LEC post-DFT netlist       EQUIVALENT EQUIVALENT   ✓ PASS (LEC-2)
DFT area overhead          4.2%       ≤8%          ✓ PASS
─────────────────────────────────────────────────────────────────────
GATE-06 (DFT) criteria met? YES
```

---

## 12. skill:pnr — Stage 7 Physical Design & P&R

### 12.1 Trigger
Activated after GATE-06 approval (synthesis + DFT complete).

### 12.2 Tool Detection — Physical Design Domain

```
PHYSICAL DESIGN TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Category        Tool               Status    Vendor     Notes
──────────────────────────────────────────────────────────────────
Floorplan/P&R   Innovus            ✓ FOUND   Cadence    23.11 — full featured
                ICC2               ✗ NOT FND Synopsys
                OpenROAD           ✓ FOUND   Open       2.0 — production quality
                LibreLane          ✓ FOUND   Open       Full automated flow
STA (sign-off)  Tempus             ✓ FOUND   Cadence    in-design & signoff
                PrimeTime          ✗ NOT FND Synopsys
                OpenSTA            ✓ FOUND   Open       bundled with OpenROAD
IR/EM Analysis  Voltus             ✓ FOUND   Cadence
                RedHawk            ✗ NOT FND Synopsys
                OpenROAD PSM       ✓ FOUND   Open
CTS             Innovus CTS        ✓ FOUND   Cadence
                TritonCTS (OpenROAD)✓ FOUND  Open
Fill/Tap        Innovus Fill       ✓ FOUND   Cadence
                OpenROAD Tapcell   ✓ FOUND   Open
──────────────────────────────────────────────────────────────────

BACKEND FLOW OPTIONS:
  [1] Innovus (commercial — full featured, recommended for production)
  [2] OpenROAD standalone
  [3] LibreLane automated flow (Yosys+OpenROAD+Magic, recommended for sky130/GF180)
  [4] Hybrid: Innovus floorplan → OpenROAD routing (experimental)

NOTE: LibreLane is recommended when PDK = sky130B or gf180mcuC
      For tsmc16ffc, Innovus is strongly preferred.
```

### 12.3 Requirements Gathering

```
STAGE 7: PHYSICAL DESIGN REQUIREMENTS

  P&R tool:                    [recalled or select from above]
  Utilization target (%):      [70 (default — leave room for routing)]
    (typical range: 60-80%; above 80% → routing congestion risk)
  Aspect ratio:                [1.0 (square) / specify]
  Core-to-IO margins (μm):     [50 all sides]

  FLOORPLAN:
    Block floorplan strategy:  [auto / manual / read DEF]
    Hard macro placement:       [auto-place / manual / constraints file]
    Power ring style:           [double ring / single ring / mesh]
    Stripes direction:          [horizontal + vertical (default)]
    VDD/VSS strap width (μm):  [2.0]

  PLACEMENT:
    Placement effort:           [high (default)]
    Timing-driven placement:    [yes]
    Congestion-driven:          [yes]

  CLOCK TREE SYNTHESIS:
    CTS target skew (ps):       [±50 (global, inter-domain)]
      (intra-block target):     [≤8% of clock period = 80 ps at 1 GHz]
    Clock buffer cell family:   [auto from PDK / specify prefix]
    Useful skew optimization:   [yes — steals slack from fast → slow paths]
    OCC clock routing:          [yes — OCC nets treated as shielded]

  ROUTING:
    Routing effort:             [high]
    SI-aware routing:           [yes (recommended)]
    Via optimization:           [yes — via redundancy for reliability]
    Antenna fixing:             [auto-fix during route]
    DRC fixing iterations:      [5 (default)]

  PHYSICAL COMPLETION (mandatory before DRC):
    Tap cell insertion:         [yes — foundry-required]
    End-cap cells:              [yes]
    Standard cell filler:       [yes — metal density requirement]
    Metal fill (dummy):         [yes — CMP planarity requirement]
    Via redundancy:             [yes — EM reliability]
    Shield nets (clocks, power):[yes]

  TIMING SIGNOFF TARGET (in-design):
    WNS target (ps):            [≥0 all corners]
    TNS target:                 [0]
    Hold slack (ps):            [≥0 all corners]
    Scan shift hold (ps):       [≥0 on OCC paths — blocking gate]

  POWER SIGN-OFF TARGET:
    Worst IR drop (mV):         [≤5% of VDD = ≤40 mV at 0.8V]
    EM lifetime target (years): [10 (recalled — AEC-Q100-G1)]

  OPEN SOURCE FLOW (LibreLane):
    If LibreLane selected, provide config.json parameters:
    FP_CORE_UTIL:               [40 (conservative for open PDKs)]
    PL_TARGET_DENSITY:          [0.45]
    CLOCK_PERIOD:               [recalled from synthesis]
    SYNTH_STRATEGY:             [DELAY 1 / AREA 0]
    GLB_RT_ADJUSTMENT:          [0.1 (routing adjustment)]
```

### 12.4 LibreLane Configuration Generation

When LibreLane is selected, the skill auto-generates `config.json`:

```json
{
  "DESIGN_NAME": "MY_CHIP",
  "VERILOG_FILES": "dir::src/*.v",
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 10.0,

  "PDK": "sky130B",
  "STD_CELL_LIBRARY": "sky130_fd_sc_hd",

  "FP_SIZING": "relative",
  "FP_CORE_UTIL": 40,
  "FP_ASPECT_RATIO": 1,
  "FP_PDN_VPITCH": 153.6,
  "FP_PDN_HPITCH": 153.18,

  "PL_TARGET_DENSITY": 0.45,
  "PL_RESIZER_TIMING_OPTIMIZATIONS": 1,
  "PL_RESIZER_MAX_WIRE_LENGTH": 800,

  "CTS_CLK_MAX_WIRE_LENGTH": 800,
  "CTS_SINK_CLUSTERING_MAX_DIAMETER": 50,

  "GLB_RT_ADJUSTMENT": 0.1,
  "ROUTING_CORES": 8,

  "MAGIC_DRC_USE_GDS": 0,
  "RUN_LVS": 1,
  "MAGIC_EXT_USE_GDS": 1,

  "diode_insertion_strategy": 3,
  "FILL_INSERTION": 1,
  "TAP_DECAP_INSERTION": 1
}
```

### 12.5 Output Metrics

```
PHYSICAL DESIGN METRICS — SIGN-OFF READY CHECK
─────────────────────────────────────────────────────────────────────
Metric                          Value      Target        Status
─────────────────────────────────────────────────────────────────────
PLACEMENT
  Utilization (%)               68.4       60–80%        ✓ PASS
  Congestion (overflow cells)   0          0             ✓ PASS
  DRC violations (pre-route)    0          0             ✓ PASS

CLOCK TREE
  Global clock skew (ps)        42         ≤50           ✓ PASS
  Intra-block max skew (ps)     72         ≤80           ✓ PASS
  Clock buffer count            847        —             INFO
  ICG enable timing slack (ps)  +380       ≥0            ✓ PASS

ROUTING
  Total wire length (mm)        18,420     —             INFO
  Via count                     4,218,000  —             INFO
  DRC violations (post-route)   0          0             ✓ PASS
  Antenna violations             0          0             ✓ PASS

TIMING (post-route, sign-off STA)
  WNS (WC SS 125°C setup) ps    +18        ≥0            ✓ PASS
  TNS                           0          0             ✓ PASS
  WNS (WC hold -40°C) ps        +32        ≥0            ✓ PASS
  Scan shift hold (ps)          +24        ≥0 (BLOCKING) ✓ PASS
  SI delta-delay violations     0          0             ✓ PASS

POWER / IR DROP
  Worst IR drop (mV)            28         ≤40 mV        ✓ PASS
  Worst EM (current density)    0 violations EM rules    ✓ PASS
  Active power (post-route)     43.1 mW    ≤50 mW        ✓ PASS

PHYSICAL COMPLETION
  Tap cells inserted:           YES        mandatory     ✓ PASS
  Filler cells inserted:        YES        mandatory     ✓ PASS
  Metal fill (CMP):             YES        mandatory     ✓ PASS
  Via redundancy:               YES        mandatory     ✓ PASS
  Shield nets (clocks/pwr):     YES        recommended   ✓ PASS
─────────────────────────────────────────────────────────────────────
GATE-07 criteria met? YES → Awaiting human PD Lead approval
```

---

## 13. skill:sta_signoff — Stage 8 Timing & Power Sign-Off

### 13.1 Trigger
Activated after GATE-07 approval (P&R complete, DRC-clean layout).

### 13.2 Tool Detection

```
STA / POWER SIGN-OFF TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Function        Tool         Status    Vendor
──────────────────────────────────────────────────────────────────
Static STA      Tempus       ✓ FOUND   Cadence    Gold standard
                PrimeTime    ✗ NOT FND Synopsys
                OpenSTA      ✓ FOUND   Open
Power (static)  Voltus       ✓ FOUND   Cadence
                PrimePower   ✗ NOT FND Synopsys
                OpenROAD PSM ✓ FOUND   Open
Power (dynamic) Voltus + VCD ✓ FOUND   Cadence    needs sim activity
                PrimePower+  ✗ NOT FND Synopsys
Noise (SI)      Tempus SI    ✓ FOUND   Cadence    coupled crosstalk
                PrimeTime SI ✗ NOT FND Synopsys
──────────────────────────────────────────────────────────────────
```

### 13.3 Requirements Gathering

```
STAGE 8: TIMING & POWER SIGN-OFF REQUIREMENTS

  STA tool:                    [recalled: Tempus]

  CORNERS to analyze:
    [✓] WC SS 0.72V 125°C     (worst-case setup)
    [✓] WC SS 0.72V -40°C     (worst-case hold)
    [✓] TC TT 0.8V  25°C      (typical)
    [✓] BC FF 0.88V -40°C     (best-case — check for hold issues)
    [✓] EOL aging corners:     (AEC-Q100-G1: +10yr 125°C NBTI degraded)

  VARIATION MODEL:
    POCV derating:             [yes — mandatory for 16nm]
    Clock path derate:         [specify or use PDK defaults]
    Data path derate:          [specify or use PDK defaults]

  SIGN-OFF CRITERIA:
    WNS all paths (ps):        [≥0]
    TNS:                       [0 (no failing paths)]
    Hold slack (ps):           [≥0 all paths, all corners]
    Scan shift hold (ps):      [≥0 (blocking — OCC paths)]
    Max transition violation:  [0]
    Max capacitance violation: [0]

  SI ANALYSIS:
    Crosstalk delta-delay:     [yes — add SI pessimism to STA]
    Glitch analysis:           [yes for critical paths]

  POWER SIGN-OFF:
    Activity from simulation:  [yes — load VCD from regression]
    VCD file:                  [verif/regression/top_regression.vcd]
    Power modes: active/sleep/retention: [yes — analyze all modes]
    IR drop static:            [yes — Voltus]
    IR drop dynamic:           [yes — Voltus, load VCD]
    EM sign-off:               [yes — report EM-violating nets]

  AGING / RELIABILITY:
    EOL timing margin check:   [yes — mandatory for AEC-Q100]
      Apply NBTI degradation:  [PDK NBTI model — auto-loaded]
      Apply HCI degradation:   [PDK HCI model — auto-loaded]
```

### 13.4 Output Metrics

```
STA SIGN-OFF RESULTS — ALL CORNERS
─────────────────────────────────────────────────────────────────────────
Corner               Mode    WNS(ps) TNS  Hold(ps) Tran  Cap  Status
─────────────────────────────────────────────────────────────────────────
WC SS 0.72V 125°C    func    +18     0    +32      0     0    ✓ PASS
WC SS 0.72V -40°C    func    +92     0    +18      0     0    ✓ PASS
TC TT 0.8V  25°C     func    +215    0    +44      0     0    ✓ PASS
BC FF 0.88V -40°C    func    +380    0    +6       0     0    ✓ PASS (hold tight)
WC SS 0.72V 125°C    scan    +42     0    +24      0     0    ✓ PASS (OCC)
WC 10yr EOL 125°C    func    +2      0    —        0     0    ✓ MARGINAL → review
─────────────────────────────────────────────────────────────────────────
⚠ EOL corner WNS = +2 ps — within spec but very tight.
  Confirm reliability analysis (agent:reliability) EOL guardband.
  [accept with documented risk / trigger ECO / escalate]
─────────────────────────────────────────────────────────────────────────
POWER SIGN-OFF
  Active power (VCD-based):   44.8 mW    ≤50 mW     ✓ PASS
  Leakage power:              38 μW      ≤50 μW     ✓ PASS
  Peak IR drop (static mV):   26         ≤40 mV     ✓ PASS
  Peak IR drop (dynamic mV):  38         ≤40 mV     ✓ MARGINAL → review
  EM violations:              0          0           ✓ PASS
─────────────────────────────────────────────────────────────────────────
⚠ Dynamic IR drop 38 mV — approaching limit of 40 mV.
  Consider: wider power stripes on M6, or reduce burst activity in sim.
  [add power stripe ECO / accept / escalate]
─────────────────────────────────────────────────────────────────────────
GATE-08 criteria met? CONDITIONAL — resolve EOL timing and IR drop first
```

---

## 14. skill:physical_verif — Stage 8B Physical Verification

### 14.1 Trigger
Activated after routing is complete and metal fill is inserted.

### 14.2 Tool Detection

```
PHYSICAL VERIFICATION TOOLS DETECTED:
──────────────────────────────────────────────────────────────────
Function      Tool           Status    Vendor     Notes
──────────────────────────────────────────────────────────────────
DRC           Calibre DRC    ✓ FOUND   Mentor/Sie Gold standard
              PVS DRC        ✗ NOT FND Cadence
              IC Validator   ✗ NOT FND Synopsys
              Magic DRC      ✓ FOUND   Open       Good for sky130/GF180
LVS           Calibre LVS    ✓ FOUND   Mentor/Sie CDL-based
              PVS LVS        ✗ NOT FND Cadence
              Netgen LVS     ✓ FOUND   Open       Paired with Magic
ERC           Calibre ERC    ✓ FOUND   Mentor/Sie
              PVS ERC        ✗ NOT FND
Antenna       Calibre Ant.   ✓ FOUND   Mentor/Sie
              OpenROAD Ant.  ✓ FOUND   Open
CMP Density   Calibre CMP    ✓ FOUND   Mentor/Sie
GDS Viewer    KLayout        ✓ FOUND   Open
              Virtuoso GDS   ✓ FOUND   Cadence
──────────────────────────────────────────────────────────────────
```

### 14.3 Requirements Gathering

```
STAGE 8B: PHYSICAL VERIFICATION REQUIREMENTS

  DRC/LVS tool:             [recalled: Calibre]
  PDK rule decks:           [auto-detected from PDK: tsmc16ffc Calibre decks ✓]

  DRC:
    Run full DRC:           [yes]
    DRC deck version:       [auto: tsmc16ffc_1P12M_CALIBRE_DRC_v2023.4.drc]
    Voltage-dependent DRC:  [yes — select operating voltages: 0.72V, 0.8V]
    Density (CMP) check:    [yes]
    ESD checks:             [yes — antenna + ESD combined]

  LVS:
    Netlist format:          [CDL — auto-generate from Innovus]
    Top-level cell name:     [MY_CHIP — confirmed]
    Recognize black boxes:   [yes — SRAM macros, IO cells]
    Analog IP instances:     [list: pll_tsmc16ffc_v2p0 — recognized]
    LVS deck:                [tsmc16ffc_1P12M_CALIBRE_LVS_v2023.4.lvs]

  ERC:
    Run ERC:                 [yes]
    ESD protection check:    [yes — HBM 2kV model]
    Latch-up check:          [yes — substrate tie, well tie check]

  SIGN-OFF CRITERIA:
    DRC violations:          [0 — ALL must be clean]
    LVS status:              [CLEAN — no net/device mismatches]
    ERC violations:          [0 unresolved]
    Antenna violations:      [0 (should have been fixed in route)]
    CMP density violations:  [0 (should have been fixed by fill)]
```

### 14.4 Output Metrics

```
PHYSICAL VERIFICATION RESULTS
─────────────────────────────────────────────────────────────────────
Check                     Result            Target     Status
─────────────────────────────────────────────────────────────────────
DRC violations            0                 0          ✓ PASS
  (initial DRC errors)    (24 → 0 after ECO)           resolved
LVS status                CLEAN             CLEAN      ✓ PASS
  Net mismatches          0                 0          ✓ PASS
  Device mismatches       0                 0          ✓ PASS
  Pin mismatches          0                 0          ✓ PASS
ERC violations            0                 0          ✓ PASS
  ESD violations          0                 0          ✓ PASS
  Latch-up violations     0                 0          ✓ PASS
Antenna violations        0                 0          ✓ PASS
CMP density              within spec        spec       ✓ PASS
Voltage-dependent DRC     0 at 0.72V/0.8V  0          ✓ PASS
─────────────────────────────────────────────────────────────────────
FINAL LEC (LEC-4):        EQUIVALENT        EQUIVALENT ✓ PASS
─────────────────────────────────────────────────────────────────────
ALL PHYSICAL VERIFICATION CHECKS CLEAN
GATE-08 physical criteria met? YES
```

---

## 15. skill:gdsii_export — Stage 8C GDSII Tape-Out

### 15.1 Trigger
Activated only after ALL sign-off gates pass AND human GATE-08 approval is received.

### 15.2 Pre-Tape-Out Checklist (Mandatory)

```
╔══════════════════════════════════════════════════════════════════════════╗
║           PRE TAPE-OUT CHECKLIST — EVERY ITEM MUST BE GREEN             ║
╠══════════════════════════════════════════════════════════════════════════╣
║ [✓] DRC: 0 violations (Calibre final run with latest deck)             ║
║ [✓] LVS: CLEAN (CDL vs. schematic)                                     ║
║ [✓] ERC: 0 violations (ESD + latch-up)                                 ║
║ [✓] Antenna: 0 violations                                              ║
║ [✓] CMP density: within bounds                                         ║
║ [✓] STA: WNS ≥ 0 all corners including EOL                            ║
║ [✓] LEC-4: RTL→final netlist EQUIVALENT                               ║
║ [✓] DFT coverage: SA≥99%, Trans≥97%, PA≥90%, CA≥98%                  ║
║ [✓] Power sign-off: IR drop ≤ 5% VDD, EM clean                       ║
║ [✓] UPF final: PA-GLS PASS all power modes                            ║
║ [✓] Reliability: EOL margin documented, AEC grade confirmed            ║
║ [✓] GATE-08 sign-off: human expert signatures collected               ║
║ [✓] Foundry DRC deck version matches tape-out submission spec         ║
║ [✓] IO ring complete: all pads, ESD cells, corner cells               ║
║ [✓] GDSII layer mapping confirmed with foundry                        ║
║ [✓] Chip label / ID / lot marking layers included                     ║
║ [✓] Cell library NDAs / IP licenses cleared for tape-out              ║
╚══════════════════════════════════════════════════════════════════════════╝

All items green? Type 'CONFIRM TAPE-OUT' to proceed, or address failures first.
> _
```

### 15.3 GDSII Export Requirements

```
GDSII TAPE-OUT PARAMETERS:

  Output format:              [GDSII (binary) / OASIS (compressed) / both]
  Top cell name:              [MY_CHIP]
  Layer mapping file:         [auto-load: tsmc16ffc_layer_map.map ✓]
  Merge all cells:            [yes — single stream file]
  Flatten for foundry:        [no (keep hierarchy for DFM review)]
  Include fill cells:         [yes — metal fill in output]
  Compress output:            [yes — gzip GDSII]
  Verify stream integrity:    [yes — re-DRC streamed GDS]
  Output path:                [tapeout/MY_CHIP_v1.0_final.gds]

  FOUNDRY SUBMISSION:
    Foundry:                  [TSMC / GF / efabless MPW / specify]
    Submission format:        [foundry tape-out portal / email / FTP]
    Include documents:
      [✓] Final DRC report
      [✓] LVS report
      [✓] STA sign-off report
      [✓] CDL netlist
      [✓] Final SDC
      [✓] IP disclosure forms
      [✓] DFM sign-off report
```

### 15.4 Output Artifacts

```
TAPE-OUT ARTIFACTS GENERATED:
─────────────────────────────────────────────────────────────────────────
Artifact                                Path
─────────────────────────────────────────────────────────────────────────
Final GDSII                             tapeout/MY_CHIP_v1.0_final.gds
Final OASIS (compressed)                tapeout/MY_CHIP_v1.0_final.oas
Final CDL netlist                       tapeout/MY_CHIP_v1.0_final.cdl
Final SDC (all corners)                 tapeout/constraints_final.sdc
Final LEC report (LEC-4)               reports/lec4_final_equiv.rpt
Final DRC clean report                  reports/drc_final_clean.rpt
Final LVS clean report                  reports/lvs_final_clean.rpt
Final STA report (all corners)          reports/sta_final_signoff.rpt
Final power report                      reports/power_final_signoff.rpt
DFT pattern file (STIL)                 dft/patterns/MY_CHIP_final.stil
Tape-out sign-off sheet (PDF)           tapeout/signoff_checklist_final.pdf
─────────────────────────────────────────────────────────────────────────
Tape-out package size: 4.8 GB (compressed: 1.2 GB)
SHA256: <hash automatically computed and recorded>
─────────────────────────────────────────────────────────────────────────
✓ TAPE-OUT COMPLETE — MY_CHIP_v1.0 — 2026-03-19T22:14:53Z
```

---

## 16. skill:orchestrator — End-to-End & Partial Flow Manager

### 16.1 Overview

`skill:orchestrator` is the top-level skill that manages the entire design flow. It can execute:
- **Full flow**: Spec → GDSII (Stages 1–8)
- **Partial flow**: Start from any intermediate stage, use existing artifacts from prior runs
- **Re-run**: Re-execute a specific stage (e.g., re-synthesize after RTL change)
- **Parallel workstreams**: Launch multiple agents simultaneously where stages allow concurrency

### 16.2 Orchestrator Startup Dialog

```
╔══════════════════════════════════════════════════════════════════════╗
║               ASIC DESIGN FLOW ORCHESTRATOR                         ║
║               Multi-Agent EDA Coordinator v1.0                      ║
╚══════════════════════════════════════════════════════════════════════╝

MEMORY RECALL:
  Project:    MY_CHIP v1.0 (previously defined)
  PDK:        tsmc16ffc (previously selected)
  Tools:      Cadence stack — Xcelium, Genus, Innovus, Tempus, JasperGold
  Last run:   Stage 5 (Verification) — PASS (2026-03-18)
  Next stage: Stage 6 (Synthesis) — ready to launch

FLOW SELECTION:
  [1] Full flow (Stage 1 → Stage 8, GDSII)
  [2] Partial flow — start from current stage (Stage 6)
  [3] Partial flow — start from stage: [specify stage number]
  [4] Re-run specific stage only
  [5] Run synthesis + DFT (Stages 6 + 6B) in sequence
  [6] Run physical design + sign-off (Stages 7 + 8) in sequence
  [7] Full back-end only (Stages 6 → 8, RTL already frozen)
  [8] Open-source LibreLane flow (Stages 6 → 8 via LibreLane)
  [9] Show current project status

  > _
```

### 16.3 Orchestrator State Machine

```
ORCHESTRATOR FSM — STAGE TRANSITIONS
─────────────────────────────────────────────────────────────────────────────

  IDLE ──trigger──> STAGE_1_SPEC_INTAKE
                          │
                    GATE-01 (human) ──REJECT──> STAGE_1_SPEC_INTAKE (iterate)
                          │ APPROVE
                          ▼
                    STAGE_2_ALGO_DEV
                          │
                    GATE-02 (human) ──REJECT──> STAGE_2_ALGO_DEV
                          │ APPROVE
                          ▼
                    STAGE_3_ARCH_DESIGN
                          │
                    GATE-03 (human) ──REJECT──> STAGE_3_ARCH_DESIGN
                          │ APPROVE
                          ▼
              ┌──────────────────────────┐
              │ PARALLEL WORKSTREAMS     │  ← launched simultaneously
              │  STAGE_4_RTL_DESIGN      │  agent:rtl[0..N]
              │  STAGE_5_VERIF_PLAN      │  agent:verif_lead + agent:tb[0..N]
              │  STAGE_4B_UPF_GEN        │  agent:upf
              └──────────────────────────┘
                          │ ALL complete
                    GATE-04 (human RTL review)
                    GATE-05 (human verif review)
                          │ APPROVE
                          ▼
              ┌──────────────────────────┐
              │ PARALLEL WORKSTREAMS     │
              │  STAGE_6_SYNTHESIS       │  agent:synth
              │  STAGE_6B_DFT            │  agent:dft (after synth netlist ready)
              └──────────────────────────┘
                          │ DFT COMPLETE
                    LEC-2 (post-DFT) ──FAIL──> agent:dft (ECO)
                          │ PASS
                    GATE-06 (human)
                          │ APPROVE
                          ▼
              ┌──────────────────────────┐
              │ STAGE_7_PNR              │  agent:pnr + agent:fp
              │   Floorplan              │    ← milestones within stage
              │   Placement             │
              │   CTS                   │
              │   Routing               │
              │   Physical Completion   │
              └──────────────────────────┘
                          │
              ┌──────────────────────────┐
              │ PARALLEL SIGN-OFF        │
              │  STAGE_8_STA_SIGNOFF     │  agent:sta + agent:power
              │  STAGE_8B_PHYS_VERIF     │  agent:physical_verif
              │  STAGE_8C_RELIABILITY    │  agent:reliability (EOL check)
              └──────────────────────────┘
                          │ ALL PASS
                    LEC-4 (final) ──FAIL──> ECO → repeat
                          │ PASS
                    GATE-08 (human — ALL sign-off leads)
                          │ APPROVE
                          ▼
                    STAGE_GDSII_EXPORT
                          │
                    TAPE-OUT COMPLETE ─────> IDLE
```

### 16.4 Project Status Dashboard

When the user selects "Show current project status":

```
╔══════════════════════════════════════════════════════════════════════════╗
║                    PROJECT STATUS — MY_CHIP v1.0                        ║
║                    2026-03-19  |  PDK: tsmc16ffc  |  Target: 1 GHz     ║
╠═════════════════╦═══════════╦══════════════╦═══════════════════════════╣
║ Stage           ║ Status    ║ Last Run     ║ Key Metrics               ║
╠═════════════════╬═══════════╬══════════════╬═══════════════════════════╣
║ 1. Spec Intake  ║ ✓ PASS    ║ 2026-03-10   ║ 1GHz, 50mW, AEC-Q100-G1  ║
║ 2. Algo Dev     ║ ✓ PASS    ║ 2026-03-11   ║ SNR=54dB, Tput=2.4Gbps   ║
║ 3. Arch Design  ║ ✓ PASS    ║ 2026-03-12   ║ 3 clk domains, 3 pwr dom ║
║ 4. RTL Design   ║ ✓ PASS    ║ 2026-03-15   ║ 28K lines, 0 lint errors  ║
║ 5. Verification ║ ✓ PASS    ║ 2026-03-18   ║ Fcov=96%, 4820 tests PASS ║
║ 6. Synthesis    ║ ⚡ RUNNING ║ NOW          ║ WNS=+215ps, area=3.1mm²  ║
║ 6B. DFT         ║ ⏳ PENDING ║ —            ║ Waiting on synth netlist  ║
║ 7. P&R          ║ ⏳ PENDING ║ —            ║ —                        ║
║ 8. Sign-Off     ║ ⏳ PENDING ║ —            ║ —                        ║
║ 8B. Phys. Verif ║ ⏳ PENDING ║ —            ║ —                        ║
║ GDSII Export    ║ ⏳ PENDING ║ —            ║ —                        ║
╠═════════════════╩═══════════╩══════════════╩═══════════════════════════╣
║ CURRENT BLOCKER: Synthesis running — monitoring...                      ║
║ OPEN RISKS:  [R1] EOL margin tight — watch STA stage 8                 ║
║              [R2] Dynamic IR at 38mV — add power stripes if needed     ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### 16.5 Sub-Agent Launch & Monitoring

The orchestrator launches sub-agents with the following protocol:

```python
# Orchestrator sub-agent management protocol
class OrchestratorAgent:

    def launch_stage(self, stage_id: str, parallel: bool = False):
        """
        Launch a stage skill as a sub-agent.
        - Load SMS preferences before launch
        - Pass relevant context (PDK, tool choice, constraints)
        - Monitor via artifact_store and job_scheduler MCP servers
        - Set timeout per stage (configurable)
        """
        context = self.sms.load_context_for_stage(stage_id)
        agent = SubAgent(
            skill    = f"skill:{stage_id}",
            context  = context,
            timeout  = STAGE_TIMEOUTS[stage_id],
            parallel = parallel
        )
        job_id = self.job_scheduler.submit(agent)
        self.active_jobs[stage_id] = job_id
        self.artifact_store.register_job(stage_id, job_id)
        return job_id

    def monitor_all(self):
        """Poll active jobs, stream logs, notify human on gate events."""
        for stage_id, job_id in self.active_jobs.items():
            status = self.job_scheduler.poll(job_id)
            if status == "GATE_PENDING":
                self.human_review_gateway.notify(
                    stage = stage_id,
                    artifacts = self.artifact_store.get_latest(stage_id),
                    metrics   = self.artifact_store.get_metrics(stage_id)
                )
            elif status == "FAILED":
                self.handle_failure(stage_id, job_id)
            elif status == "PASSED":
                self.advance_fsm(stage_id)

    def handle_failure(self, stage_id: str, job_id: str):
        """
        On failure:
        1. Read error log from sub-agent
        2. Write to SMS error_log (persistent learning)
        3. Assess: retry automatically or escalate to human
        4. If retryable (lint errors, QoS miss by small margin): auto-retry
        5. If not retryable (tool crash, license miss, arch issue): escalate
        """
        error = self.artifact_store.get_error(job_id)
        self.sms.append_error_log(stage_id, error)

        if error.error_class in ["lint_violations", "minor_qos_fail"]:
            # Auto-iterate: pass error context back to stage agent
            self.launch_stage(stage_id, retry_context=error)
        else:
            self.human_review_gateway.escalate(stage_id, error)
```

### 16.6 Partial Flow Entry Points

```
PARTIAL FLOW — Starting from Stage N:

  When starting from Stage N (not Stage 1), the orchestrator:

  1. VERIFIES PREREQUISITES:
     For each required input artifact of Stage N, check if it exists
     in the artifact_store:

     Stage 6 (Synthesis) requires:
       ✓ RTL netlist (*.v / *.sv) in rtl/
       ✓ Timing constraints (*.sdc) in constraints/
       ✓ UPF file in power/
       ✓ PDK liberty files (.lib) accessible

     Stage 7 (P&R) requires:
       ✓ Gate-level netlist from synthesis
       ✓ Post-synthesis SDC
       ✓ Post-DFT netlist (if DFT complete)
       ✓ UPF (post-synthesis)

     Stage 8 (Sign-Off) requires:
       ✓ Routed DEF from P&R
       ✓ Extracted parasitics (SPEF)
       ✓ Post-route SDC
       ✓ Cell library models (NLDM/CCS .lib)

  2. PROMPTS FOR MISSING ARTIFACTS:
     "The following required inputs are missing. Please provide paths:"
     > Missing: post-synthesis netlist → [enter path or 'generate']

  3. LOADS PRIOR CONTEXT from SMS:
     Tool preferences, design requirements, error history
     → Avoids asking questions already answered in prior sessions

  4. LAUNCHES FROM SPECIFIED STAGE
```

### 16.7 Open-Source LibreLane Automated Flow

When the user selects "LibreLane flow", the orchestrator activates the fully automated open-source pipeline:

```
LibreLane AUTOMATED FLOW — STAGES 6→8

  Prerequisites:
    ✓ RTL (*.v) frozen
    ✓ PDK = sky130B or gf180mcuC selected
    ✓ LibreLane installed and configured
    ✓ OpenLane environment variables set

  Orchestrator launches LibreLane with generated config.json:

  librelane --dockerized run_designs config.json
         └─── Yosys synthesis
         └─── OpenROAD floorplan
         └─── OpenROAD placement
         └─── TritonCTS clock tree
         └─── OpenROAD routing (TritonRoute)
         └─── OpenSTA timing sign-off
         └─── OpenROAD PSM power analysis
         └─── Magic DRC
         └─── Netgen LVS
         └─── Magic GDS stream-out
         └─── KLayout GDS view + DRC

  Orchestrator monitors LibreLane run log in real-time.
  On completion, extracts and presents metrics:

  LIBRELANE RUN SUMMARY
  ─────────────────────────────────────────────────────
  Synthesis: PASS  |  Cells: 12,450  |  Area: 0.14mm²
  Placement: PASS  |  Util: 42%      |  Overflow: 0
  CTS:       PASS  |  Skew: 0.32ns   |  Buf: 124
  Routing:   PASS  |  WL: 2,840mm    |  Vias: 48,200
  STA:       PASS  |  WNS: -0.03ns ⚠ |  TNS: -0.12ns ⚠
  DRC:       PASS  |  0 violations
  LVS:       PASS  |  CLEAN
  ─────────────────────────────────────────────────────
  ⚠ Timing: WNS negative — increase CLOCK_PERIOD or
    reduce design complexity. Options:
    [1] Relax clock to 125 MHz (10% reduction)
    [2] Apply synthesis optimization DELAY 2
    [3] Manual floorplan to reduce wire length
    [4] Accept failing timing (prototype only)
  ─────────────────────────────────────────────────────
  Output: results/MY_CHIP/final/MY_CHIP.gds
```

---

## 17. Skill Interaction Protocol & Error Recovery

### 17.1 Interaction Verbosity Levels

Skills adapt their output to user preference stored in SMS:

| Level | Behavior |
|-------|----------|
| `terse` | Show only PASS/FAIL and key metrics. No explanations. |
| `normal` (default) | Show metrics table, flag warnings with brief explanations, offer choices. |
| `verbose` | Show full tool log, all intermediate metrics, explain every decision. |

Set verbosity: `set verbosity [terse / normal / verbose]`

### 17.2 Standard User Override Commands

At any skill prompt, the user can issue:

```
remember <key> = <value>   → persist to SMS immediately
forget <key>               → clear from SMS
show preferences           → display full SMS for this project
set tool <function> <tool> → override tool for one function
skip <check>               → skip a quality gate (logs warning)
accept defaults            → accept all remaining defaults for this stage
show errors                → show error log for current stage
why <decision>             → explain why a default or recommendation was made
help                       → show available commands
abort                      → halt execution, save state, return to orchestrator
```

### 17.3 Error Classification & Recovery

```
ERROR RECOVERY DECISION TREE
──────────────────────────────────────────────────────────────────────
Error Class          Auto-Retry?   Recovery Action
──────────────────────────────────────────────────────────────────────
tool_crash           NO            Restart tool with debug flags;
                                   escalate if repeated; log to SMS
license_miss         NO            Offer alternative tool (if available);
                                   alert user to check license server
qos_fail_minor       YES (1×)      Pass error context to stage agent,
  (QoS miss <5%)                   run targeted ECO, re-check gate
qos_fail_major       NO            Escalate to human; propose root cause
  (QoS miss >5%)                   analysis (RCA) before re-run
timeout              NO            Check job scheduler; escalate if HPC;
                                   offer to resume from checkpoint
user_abort           NO            Save state; notify orchestrator ABORT
arch_issue           NO            Roll back to architecture stage;
                                   notify human of design change needed
pdk_missing          NO            Prompt user for PDK path;
                                   offer open-source fallback
──────────────────────────────────────────────────────────────────────
All errors written to SMS error_log with lesson_learned field.
```

### 17.4 ECO (Engineering Change Order) Support

When a quality gate fails after a downstream stage, skills support ECOs:

```
ECO WORKFLOW:
  1. Sign-off STA fails with WNS = -15 ps (after P&R)
  2. skill:sta_signoff proposes ECO options:
     [A] Upsizing: upsize 3 cells on critical path → +20 ps gain
     [B] Buffer insertion: add 2 buffers on high-fanout net → +18 ps
     [C] Route fix: re-route 2 nets to reduce coupling → +12 ps SI
     [D] Back-annotate to synthesis: re-synth critical path subset
     [E] Clock period relaxation: reduce target by 2% (980 ps)
  3. User selects ECO option
  4. Orchestrator launches targeted ECO agent:
     - Implements change in Innovus (ECO mode)
     - Re-runs STA on affected paths only
     - Re-runs LEC (LEC-3 per-ECO checkpoint)
     - If PASS → proceeds; if FAIL → offers next option
```

---

## 18. Continuous Self-Improvement Engine

### 18.1 Learning From Errors

Every error recorded in the SMS `error_log` feeds into a pattern-recognition loop:

```
SELF-IMPROVEMENT CYCLE:

  After N runs (configurable, default N=3):
  1. Scan error_log for recurring error classes
  2. Generate "lessons learned" summary:

     RECURRING ISSUES DETECTED:
     ──────────────────────────────────────────────────────
     Pattern: CDC violations at clk_fast→clk_slow
       Seen: 3× across projects (rtl_design stage)
       Root cause: Missing synchronizer instantiation
       Improvement: Pre-check CDC paths in arch_design stage
       Action: Add CDC pre-check to GATE-03 criteria

     Pattern: DRC antenna violations after routing
       Seen: 2× (pnr stage, Innovus)
       Root cause: Diode insertion not enabled by default
       Improvement: Enable diode_insertion_strategy=3 by default
       Action: Update pnr skill default config

  3. Propose updated defaults to user:
     "Based on your history, I recommend updating these defaults.
      Review and approve:"
     [show proposed changes] [accept all] [reject all] [select]
```

### 18.2 Preference Learning Triggers

The skill monitors user overrides and learns from them:

```
PREFERENCE LEARNING:

  User action: Changed WNS target from +0 ps to +50 ps
  → Learned: This user prefers more timing margin (conservative)
  → Updated: Default WNS target for this project = +50 ps
  → Noted in SMS: "conservative_timing_margin = true"

  User action: Selected "accept" on DRC waiver for density rule
  → Learned: Density waiver acceptable for this block
  → Stored: Waiver justification in SMS with timestamp

  User action: Switched from VCS to Xcelium after 2 runs
  → Learned: User prefers Xcelium
  → Updated: simulator preference immediately
  → Note: "user switched from VCS: preferred Xcelium for ..." logged

  User action: Always says 'verbose' at start of each session
  → Learned: User prefers verbose output
  → Updated: verbosity = "verbose" as persistent preference
```

### 18.3 Cross-Project Knowledge Transfer

When a new project is started, the orchestrator offers to import lessons from prior projects:

```
NEW PROJECT SETUP — KNOWLEDGE TRANSFER

  Prior projects found in SMS:
    MY_CHIP_v1.0 (tsmc16ffc, completed, 2026-03-19)
    PREV_CHIP_v2.1 (tsmc28hpc, completed, 2025-11-10)

  Import preferences from MY_CHIP_v1.0?
    Tool stack (Cadence):                [yes / no]
    Design targets (freq, power, area):  [no — new project]
    Lessons learned (error_log):         [yes / no]
    DFT configuration (64× compression): [yes / no]
    Coding guidelines (RTL lint rules):  [yes / no]

  [import selected] [skip] [view lessons first]
```

---

## Appendix A — Tool Installation Guide

### A.1 Open-Source Tools Installation (LibreLane Stack)

```bash
# Install LibreLane (recommended: Docker-based)
docker pull efabless/librelane:latest
# or native install:
pip install librelane

# Install OpenROAD
git clone https://github.com/The-OpenROAD-Project/OpenROAD.git
cd OpenROAD && ./etc/DependencyInstaller.sh && cmake .. && make install

# Install Yosys
git clone https://github.com/YosysHQ/yosys.git
cd yosys && make && make install

# Install Magic
sudo apt install magic  # Debian/Ubuntu
# or build: git clone https://github.com/RTimothyEdwards/magic.git

# Install Netgen (LVS)
sudo apt install netgen
# or: git clone https://github.com/RTimothyEdwards/netgen.git

# Install Verilator
sudo apt install verilator
# or build from source for latest: https://www.veripool.org/verilator

# Install SymbiYosys (formal)
pip install symbiyosys
sudo apt install yices2 boolector z3

# Install open_pdks (sky130B + GF180)
git clone https://github.com/RTimothyEdwards/open_pdks.git
cd open_pdks && ./configure --enable-sky130-pdk --enable-gf180mcu-pdk
make && make install
export PDK_ROOT=/usr/local/share/pdk
```

### A.2 Commercial Tool Environment Setup

```bash
# Cadence (example .bashrc additions)
export CDS_HOME=/opt/cadence
export PATH=$CDS_HOME/XCELIUM2309/tools/bin:$PATH
export PATH=$CDS_HOME/GENUS2310/bin:$PATH
export PATH=$CDS_HOME/INNOVUS2311/bin:$PATH
export PATH=$CDS_HOME/TEMPUS2311/bin:$PATH
export CDS_LIC_FILE=5280@license_server

# Synopsys (example)
export SYNOPSYS=/opt/synopsys
export PATH=$SYNOPSYS/vcs-mx/bin:$PATH
export PATH=$SYNOPSYS/syn/bin:$PATH
export SNPSLMD_LICENSE_FILE=27000@license_server

# Mentor (Siemens EDA, example)
export MENTOR_HOME=/opt/mentor
export PATH=$MENTOR_HOME/calibre/bin:$PATH
export MGC_HOME=$MENTOR_HOME
export LM_LICENSE_FILE=1717@license_server
```

---

## Appendix B — Default Quality Gate Thresholds

| Gate | Metric | Default Target | Notes |
|------|--------|----------------|-------|
| R-QG-01 | Lint errors | 0 | Hard pass required |
| R-QG-02 | CDC violations | 0 | Hard pass required |
| V-QG-01 | Functional coverage | ≥95% | Industry standard |
| V-QG-02 | Code coverage (line) | 100% | High confidence |
| V-QG-03 | Branch coverage | ≥95% | |
| S-QG-01 | WNS (synth) | ≥+200 ps | 20% margin at 1 GHz |
| S-QG-02 | ICG coverage | ≥80% | Regs covered by ICG |
| D-QG-01 | Stuck-at coverage | ≥99% | ATE target |
| D-QG-02 | Transition coverage | ≥97% | |
| D-QG-03 | Cell-aware coverage | ≥98% | |
| P-QG-01 | Utilization | 60–80% | Routing room |
| P-QG-02 | DRC violations | 0 | Hard pass |
| P-QG-03 | IR drop | ≤5% VDD | ≤40 mV @ 0.8V |
| P-QG-04 | Clock skew (global) | ≤50 ps | At 1 GHz target |
| T-QG-01 | STA WNS (post-route) | ≥0 | All corners |
| T-QG-02 | LVS status | CLEAN | 0 mismatches |
| T-QG-03 | Antenna violations | 0 | Hard pass |

*All thresholds are stored as defaults in SMS and can be overridden per project.*

---

*End of ASIC Skills Framework Specification v1.0*
*Parent document: ASIC_MultiAgent_Framework.md v3.0*
*Maintained by: agent:orch on behalf of ASIC design team*
