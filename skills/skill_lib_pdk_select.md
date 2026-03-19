# skill_lib_pdk_select — PDK Detection & Selection
## Shared Library | Loaded by all stage skills that touch technology data

**Type:** Library (not a standalone stage skill)
**Version:** 1.0
**Used by:** skill_01 (initial selection), skill_06 (cell libs), skill_07 (tech LEF/LEF), skill_08b (rule decks), skill_08c (layer map)

---

## Purpose

Detect available Process Design Kits (PDKs) in the environment, present open-source and commercial options to the user, validate that required components are present for each stage, and persist the selection to SMS.

---

## PDK Detection Procedure

```
STEP 1 — Check environment variables
  PDK_ROOT, PDKPATH, STDCELLS, TIMING_LIBS, TECH_DIR
  CDS_PDK_DIR, SYNOPSYS_CUSTOM_DESIGNER
  OPENLANE_PDK, CARAVEL_ROOT (efabless MPW)

STEP 2 — Scan standard install paths
  /opt/pdk, /opt/open_pdks, /pdk, $HOME/pdk
  /opt/skywater-pdk, /opt/gf180mcu-pdk, /opt/ihp-pdk

STEP 3 — Identify PDK by directory markers
  sky130A/ or sky130B/        → SkyWater 130nm (open, Apache-2.0)
  gf180mcuA/ … gf180mcuD/    → GlobalFoundries 180nm MCU (open, Apache-2.0)
  ihp-sg13g2/                 → IHP BiCMOS 130nm (open, CDL, experimental)
  tsmc*/                      → TSMC node (NDA required)
  samsung*/                   → Samsung node (NDA required)
  gf12*/  gf7*/               → GlobalFoundries advanced (NDA required)
  intel*/                     → Intel 18A / 3 / 4 (NDA required)
  smic*/                      → SMIC node (NDA required)

STEP 4 — Verify PDK components present
  For each detected PDK, check:
    Liberty (.lib) files for at least one corner
    LEF / Tech LEF files
    GDS / CDL cell library files
    DRC runset (Calibre .drc / Magic .magicrc / KLayout .lydrc)
    LVS runset
    SPICE models (.spi / .mod)
```

---

## PDK Selection Dialog

```
╔══════════════════════════════════════════════════════════════════╗
║                    PDK SELECTION                                  ║
╠══════════════════╦═══════════╦══════════════╦════════════════════╣
║ PDK              ║ Status    ║ Node/Foundry ║ License            ║
╠══════════════════╬═══════════╬══════════════╬════════════════════╣
║ sky130B          ║ ?         ║ 130nm / SKW  ║ Open (Apache-2.0)  ║
║ gf180mcuC        ║ ?         ║ 180nm / GF   ║ Open (Apache-2.0)  ║
║ ihp-sg13g2       ║ ?         ║ 130nm / IHP  ║ Open (CDL, beta)   ║
║ tsmc16ffc        ║ ?         ║ 16nm FinFET  ║ NDA required       ║
║ tsmc28hpc+       ║ ?         ║ 28nm / TSMC  ║ NDA required       ║
║ tsmc40lp         ║ ?         ║ 40nm / TSMC  ║ NDA required       ║
║ gf12lp+          ║ ?         ║ 12nm / GF    ║ NDA required       ║
║ samsung5lpe      ║ ?         ║ 5nm / Samsung║ NDA required       ║
║ [custom path]    ║ specify   ║ —            ║ —                  ║
╚══════════════════╩═══════════╩══════════════╩════════════════════╝

RECOMMENDATION (based on design_requirements recalled from SMS):
  <dynamic: e.g., "Target 1 GHz + automotive → tsmc16ffc (production)">
  <dynamic: e.g., "Learning / prototype → sky130B (free MPW via efabless)">

Recalled from SMS: [<pdk_selected or "not set">]
Select PDK [enter name or number]:
> _
```

---

## PDK Capability Matrix

After selection, the skill verifies and reports available components:

```
PDK: <selected_pdk> — Component Check
──────────────────────────────────────────────────────────────────
Component                    Path / Status
──────────────────────────────────────────────────────────────────
Standard Cell Library        <path>             ✓/✗
  ICG Cell Family            <prefix>_cg*       ✓/✗ (needed: skill_06)
  Liberty: WC SS corner      <name>_ss_*.lib    ✓/✗
  Liberty: TC TT corner      <name>_tt_*.lib    ✓/✗
  Liberty: BC FF corner      <name>_ff_*.lib    ✓/✗
Tech LEF                     <name>.tlef         ✓/✗ (needed: skill_07)
Cell LEF                     <name>.lef          ✓/✗
IO Cell Library              <io_name>.*         ✓/✗
SRAM / Memory Compiler       <sram_name>         ✓/✗
Analog IP (PLL, ADC, etc.)   <analog_lib>        ✓/✗
SPICE Models                 <name>.spi          ✓/✗ (needed: skill_05 AMS)
DRC Runset (Calibre)         <name>.drc          ✓/✗ (needed: skill_08b)
LVS Runset (Calibre)         <name>.lvs          ✓/✗ (needed: skill_08b)
ERC Runset                   <name>.erc          ✓/✗
Antenna Rules                antenna.drc         ✓/✗
CMP Density Rules            <name>_density.drc  ✓/✗
Layer Map (GDSII)            <name>_layer.map    ✓/✗ (needed: skill_08c)
──────────────────────────────────────────────────────────────────
Missing components flagged before each dependent stage executes.
```

---

## Open-Source PDK Guide

### SkyWater sky130B (recommended for open-source / learning / MPW)
```
Install:
  git clone https://github.com/google/skywater-pdk.git
  pip install open_pdks
  open_pdks --enable-sky130-pdk --enable-sky130B /install/path

Key specs:
  Node:         130nm CMOS
  Vdd:          1.8V
  Metal layers: 5 (local + M1–M5)
  Std cells:    sky130_fd_sc_hd (high-density), _hs, _ls, _ms, _hdll
  IO cells:     sky130_ef_io
  SRAM:         OpenRAM (must generate separately)
  Fmax:         ~200–400 MHz (typical digital)
  DRC:          Magic + KLayout rules (open)
  MPW access:   efabless caravel MPW shuttles (free, periodic)
```

### GlobalFoundries GF180MCU (recommended for open-source MCU designs)
```
Install:
  git clone https://github.com/google/gf180mcu-pdk.git
  open_pdks --enable-gf180mcu-pdk /install/path

Key specs:
  Node:         180nm CMOS
  Vdd:          3.3V / 5V
  Metal layers: 6
  Fmax:         ~100–200 MHz
  MPW access:   via efabless / chipIgnite
```

### IHP SG13G2 (open, BiCMOS, experimental)
```
  git clone https://github.com/IHP-GmbH/IHP-Open-PDK.git
  Node: 130nm BiCMOS (SiGe HBT + CMOS)
  Status: experimental — verify tool support before committing
```

---

## Commercial PDK Notes

| PDK | Typical Access | Required Tool Support |
|-----|---------------|----------------------|
| TSMC 16FFC | Via TSMC design center; requires design kit license | Calibre DRC/LVS, Cadence/Synopsys |
| TSMC 28HPC+ | Same | Calibre, Cadence/Synopsys |
| GF 12LP+ | Via GF portal | Calibre, Cadence/Synopsys |
| Samsung 5LPE | Via Samsung; restricted | Calibre, Cadence/Synopsys |
| Intel 18A | Very restricted; EDA tool set specified | Intel-specified tools |

**Note:** Commercial PDK Liberty files must not leave a secure design environment. The SMS stores only the PDK name and root path — not file contents.

---

## PDK Per-Stage Requirements

| Stage Skill | Required PDK Components |
|-------------|------------------------|
| skill_06_synthesis | Liberty (.lib) TT/SS/FF, Tech LEF, ICG cell family |
| skill_07_pnr | Tech LEF, cell LEF, Liberty all corners, SPEF model |
| skill_08a_sta_signoff | Liberty all corners + POCV tables, SPICE models (for SI) |
| skill_08b_physical_verif | DRC runset, LVS runset, ERC runset, Antenna rules |
| skill_08c_gdsii_export | Layer map, cell GDS, IO cell GDS |

---

*See also: [`skill_lib_memory.md`](skill_lib_memory.md) — persists PDK selection.*
*See also: [`skill_lib_tool_detect.md`](skill_lib_tool_detect.md) — tool detection (separate from PDK).*
*See also: [`SKILLS_INDEX.md`](SKILLS_INDEX.md) for full skill map.*
