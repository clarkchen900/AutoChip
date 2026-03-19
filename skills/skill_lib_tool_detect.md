# skill_lib_tool_detect — EDA Tool Detection & Selection
## Shared Library | Loaded by all stage skills

**Type:** Library (not a standalone stage skill)
**Version:** 1.0
**Used by:** ALL stage skills (called at activation before requirements gathering)

---

## Purpose

Detect available EDA tools in the current environment, present options to the user organized by commercial vendor and open-source alternative, and record the selection to `skill_lib_memory` (SMS) so subsequent skills inherit the same choices.

---

## Detection Procedure

Run once per session (or on explicit `detect tools` command). Results cached in SMS.

```
STEP 1 — Scan PATH for executables
  Cadence:   genus, innovus, xcelium, xrun, jg, conformal, modus, tempus, voltus
  Synopsys:  dc_shell, vcs, icc2, pt_shell, vc_formal, formality, tessent, primetime
  Mentor:    questa, modelsim, calibre, tessent (alternate path)
  Open:      yosys, openroad, verilator, iverilog, magic, netgen, klayout,
             opensta, symbiyosys, abc

STEP 2 — Check license server environment variables
  LM_LICENSE_FILE, CDS_LIC_FILE, SNPSLMD_LICENSE_FILE, MGC_HOME
  → Run: lmstat -a 2>/dev/null (if lmgrd accessible)
  → Report which feature tokens are currently available

STEP 3 — Check EDA home environment variables
  SYNOPSYS, CADENCE_HOME, MENTOR_HOME, OPENROAD_HOME,
  YOSYS_ROOT, PDK_ROOT, OPENLANE_ROOT, LIBRELANE_ROOT

STEP 4 — Check HPC module system (if applicable)
  module avail 2>/dev/null | grep -i "cadence\|synopsys\|mentor\|openroad\|yosys"

STEP 5 — Probe open-source tool versions
  yosys --version, openroad --version, verilator --version,
  iverilog -V, magic --version, netgen -batch version, klayout --version
```

---

## Detection Results Table (template)

```
╔══════════════════════════════════════════════════════════════════════╗
║              DETECTED EDA TOOLS IN THIS ENVIRONMENT                 ║
╠══════════════╦══════════════════╦═══════════╦════════════════════════╣
║ Function     ║ Tool             ║ Status    ║ Version / Notes        ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Simulation   ║ VCS              ║ ?         ║                        ║
║              ║ Xcelium          ║ ?         ║                        ║
║              ║ Questa           ║ ?         ║                        ║
║              ║ Verilator        ║ ?         ║ open source            ║
║              ║ Icarus iverilog  ║ ?         ║ open source            ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Synthesis    ║ Genus            ║ ?         ║ Cadence                ║
║              ║ DC Shell/Ultra   ║ ?         ║ Synopsys               ║
║              ║ Yosys            ║ ?         ║ open source            ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ P&R          ║ Innovus          ║ ?         ║ Cadence                ║
║              ║ ICC2             ║ ?         ║ Synopsys               ║
║              ║ OpenROAD         ║ ?         ║ open source            ║
║              ║ LibreLane        ║ ?         ║ open source automated  ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ STA          ║ Tempus           ║ ?         ║ Cadence                ║
║              ║ PrimeTime        ║ ?         ║ Synopsys               ║
║              ║ OpenSTA          ║ ?         ║ open source            ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Formal Verif ║ JasperGold       ║ ?         ║ Cadence                ║
║              ║ VC Formal        ║ ?         ║ Synopsys               ║
║              ║ SymbiYosys       ║ ?         ║ open source            ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ LEC          ║ Conformal        ║ ?         ║ Cadence                ║
║              ║ Formality        ║ ?         ║ Synopsys               ║
║              ║ Yosys equiv      ║ ?         ║ open source (limited)  ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ DFT          ║ Modus            ║ ?         ║ Cadence                ║
║              ║ Tessent          ║ ?         ║ Mentor/Siemens         ║
║              ║ OpenROAD DFT     ║ ?         ║ open source (basic)    ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ CDC Analysis ║ SpyGlass CDC     ║ ?         ║ Synopsys               ║
║              ║ Meridian CDC     ║ ?         ║ Cadence                ║
║              ║ Questa CDC       ║ ?         ║ Mentor                 ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Phys. Verif  ║ Calibre          ║ ?         ║ Mentor/Siemens         ║
║              ║ PVS              ║ ?         ║ Cadence                ║
║              ║ IC Validator     ║ ?         ║ Synopsys               ║
║              ║ Magic + Netgen   ║ ?         ║ open source            ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Power        ║ Voltus           ║ ?         ║ Cadence                ║
║              ║ RedHawk          ║ ?         ║ Synopsys               ║
║              ║ OpenROAD PSM     ║ ?         ║ open source            ║
╠══════════════╬══════════════════╬═══════════╬════════════════════════╣
║ Waveform     ║ SimVision        ║ ?         ║ Cadence                ║
║              ║ Verdi            ║ ?         ║ Synopsys               ║
║              ║ GTKWave          ║ ?         ║ open source            ║
╚══════════════╩══════════════════╩═══════════╩════════════════════════╝
```

---

## Tool Suite Quick-Select

```
TOOL SUITE SELECTION
  Previously remembered: <from SMS or "none set">

  [1] Cadence Full Stack
        Xcelium · Genus · Innovus · Tempus · JasperGold · Conformal · Modus · Voltus · Calibre
  [2] Synopsys Full Stack
        VCS · DC Shell/Ultra · ICC2 · PrimeTime · VC Formal · Formality · Tessent · RedHawk · PVS
  [3] Mentor/Siemens Stack
        Questa · Calibre · Tessent (+ mix commercial for front-end)
  [4] Full Open Source
        Verilator/Icarus · Yosys · OpenROAD · OpenSTA · SymbiYosys · Magic · Netgen · GTKWave
  [5] LibreLane Automated Flow
        Yosys + OpenROAD + TritonCTS + TritonRoute + Magic + Netgen (sky130/GF180 optimized)
  [6] Hybrid: OSS front-end + Commercial back-end
        Verilator/Yosys for sim/synth → Innovus/Tempus/Calibre for PnR/sign-off
  [7] Custom — select each tool individually
        (will be prompted per function below)

  Recalled from SMS: [<value or "none — please select">]
  > _
```

---

## Open-Source Stack Details (LibreLane / OpenROAD)

```
LibreLane / OpenROAD Automated GDSII Pipeline
──────────────────────────────────────────────────────────────────────
Stage              Tool(s)                    Notes
──────────────────────────────────────────────────────────────────────
RTL Lint           Verilator --lint-only      fast, SV2012 support
Simulation         Verilator (cycle-accurate) or Icarus (event-based)
Formal             SymbiYosys + Yices2/Z3    .sby configuration
Synthesis          Yosys (synth_<pdk>)        supports sky130, gf180, ihp
Equivalence        Yosys equiv               (limited vs. commercial LEC)
Floorplan          OpenROAD ifp              config.json or .tcl
PDN                OpenROAD pdngen           pdn.cfg
Placement          OpenROAD gpl + dpl        global + detailed
CTS                TritonCTS (OpenROAD)       clock buffering + skew opt
Routing            TritonRoute (OpenROAD)     detailed router
STA                OpenSTA (in OpenROAD)      SPEF back-annotation
IR Drop            OpenROAD PSM              power grid analysis
DRC                Magic DRC                 sky130/GF180 rule decks
LVS                Netgen                    spice vs. extracted netlist
GDSII              Magic → .gds              or KLayout stream-out
Viewer             KLayout                   GDS/OASIS viewer + DRC
──────────────────────────────────────────────────────────────────────
Supported PDKs:    sky130A, sky130B, gf180mcuA-D, ihp-sg13g2 (beta)
Commercial PDKs:   Possible with proper rule files (NDA + setup required)
Automation:        config.json → full GDSII without manual steps
Production status: Mature for 130-180nm open PDKs; prototype-grade for advanced nodes
──────────────────────────────────────────────────────────────────────
```

---

## Commercial Tool Environment Variables (Reference)

```bash
# Cadence
export CADENCE_HOME=/opt/cadence
export PATH=$CADENCE_HOME/XCELIUM2309/tools/bin:$PATH   # adjust version
export PATH=$CADENCE_HOME/GENUS2310/bin:$PATH
export PATH=$CADENCE_HOME/INNOVUS2311/bin:$PATH
export PATH=$CADENCE_HOME/TEMPUS2311/bin:$PATH
export PATH=$CADENCE_HOME/JG2306/bin:$PATH
export CDS_LIC_FILE=5280@<license_server>

# Synopsys
export SYNOPSYS=/opt/synopsys
export PATH=$SYNOPSYS/vcs-mx/bin:$PATH
export PATH=$SYNOPSYS/syn/bin:$PATH
export PATH=$SYNOPSYS/icc2/bin:$PATH
export PATH=$SYNOPSYS/primetime/bin:$PATH
export SNPSLMD_LICENSE_FILE=27000@<license_server>

# Mentor / Siemens EDA
export MGC_HOME=/opt/mentor
export PATH=$MGC_HOME/calibre/bin:$PATH
export PATH=$MGC_HOME/questasim/bin:$PATH
export LM_LICENSE_FILE=1717@<license_server>

# Open Source
export OPENROAD_HOME=/opt/openroad
export YOSYS_ROOT=/opt/yosys
export PDK_ROOT=/opt/pdk      # for open_pdks
export PATH=$OPENROAD_HOME/bin:$YOSYS_ROOT/bin:$PATH
```

---

## Stage-Specific Tool Subsets

Each stage skill calls this library but only presents the relevant tool subset:

| Stage Skill | Relevant Tool Functions |
|-------------|------------------------|
| skill_04_rtl_design | simulator, lint_tool, cdc_tool |
| skill_05_verification | simulator, formal, waveform_viewer |
| skill_06_synthesis | synthesis, lec, power_analysis |
| skill_06b_dft | dft, simulator (fault sim) |
| skill_07_pnr | pnr, sta (in-design), power_analysis |
| skill_08a_sta_signoff | sta, power_analysis |
| skill_08b_physical_verif | physical_verif |
| skill_08c_gdsii_export | physical_verif (stream-out) |

---

*See also: [`skill_lib_pdk_select.md`](skill_lib_pdk_select.md) for PDK detection.*
*See also: [`skill_lib_memory.md`](skill_lib_memory.md) to persist tool selections.*
*See also: [`SKILLS_INDEX.md`](SKILLS_INDEX.md) for full skill map.*
