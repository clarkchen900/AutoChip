# Multi-Agent ASIC Design Flow Framework
## End-to-End: Product Specification → GDSII

**Version:** 3.0
**Status:** Draft — All critical gaps resolved; companion specs complete
**Classification:** Architecture Reference Document

---

## Table of Contents

1. [Executive Overview](#1-executive-overview)
2. [Agent Team Organization](#2-agent-team-organization)
3. [Master Orchestration Architecture](#3-master-orchestration-architecture)
4. [Stage 1 — Product Specification](#4-stage-1--product-specification)
5. [Stage 2 — Algorithm Development](#5-stage-2--algorithm-development)
6. [Stage 3 — Architecture Design](#6-stage-3--architecture-design)
7. [Stage 4 — RTL Design](#7-stage-4--rtl-design)
8. [Stage 5 — Functional Verification](#8-stage-5--functional-verification)
9. [Stage 6 — Logic Synthesis](#9-stage-6--logic-synthesis)
10. [Stage 7 — Physical Design (Backend)](#10-stage-7--physical-design-backend)
11. [Stage 8 — Sign-Off & GDSII Tape-Out](#11-stage-8--sign-off--gdsii-tape-out)
12. [Cross-Cutting: Iteration & Feedback Loops](#12-cross-cutting-iteration--feedback-loops)
13. [Tool Registry](#13-tool-registry)
14. [MCP Server & Skill Placeholders](#14-mcp-server--skill-placeholders)
15. [Human Expert Checkpoints](#15-human-expert-checkpoints)
16. [Quality Gates & Automated Checks](#16-quality-gates--automated-checks)
17. [Data Model & Artifact Tracking](#17-data-model--artifact-tracking)
18. [Risk Matrix & Mitigation](#18-risk-matrix--mitigation)
19. [Known Gaps & Open Issues](#19-known-gaps--open-issues)
20. [Post-Silicon Validation — Stage 9](#20-post-silicon-validation--stage-9)

---

## 1. Executive Overview

### 1.1 Purpose

This document defines a **multi-agent AI-assisted ASIC design framework** that mirrors how a best-in-class commercial semiconductor design team operates — from initial product concept through physical tape-out to GDSII delivery. AI agents augment, not replace, human engineers. Every stage provides explicit human expert review gates.

### 1.2 Design Principles

| Principle | Description |
|-----------|-------------|
| **Human-in-the-Loop** | Every stage has defined human expert checkpoints; no autonomous tape-out without sign-off |
| **Spec Traceability** | Every artifact traces back to a requirement ID in the Product Spec |
| **Fail Fast** | Automated quality gates catch issues at the cheapest possible stage |
| **Iterative Refinement** | Explicit feedback loops allow upstream re-work when downstream checks fail |
| **Tool Agnosticism** | Agent interfaces are tool-agnostic; commercial/open-source tools are plugins |
| **Concurrent Workstreams** | RTL + Verification develop in parallel; DFT + PD partially overlap; not strictly sequential |
| **Co-optimization Protocols** | Synthesis ↔ STA ↔ PD agents share a co-opt channel for timing closure; DFT ↔ STA consult before and after scan insertion |
| **Auditability** | All agent decisions, tool invocations, and outputs are logged and version-controlled |

### 1.3 System Context Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        HUMAN EXPERT COUNCIL                             │
│  [PM] [Algo Eng] [Arch Lead] [RTL Lead] [Verif Lead] [PD Lead] [DFM]   │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ approvals / escalations / overrides
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    MASTER ORCHESTRATOR AGENT                            │
│         (project state machine, inter-agent routing, spec tracking)     │
└──┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────────┘
   │          │          │          │          │          │
   ▼          ▼          ▼          ▼          ▼          ▼
[Spec]    [Algo]    [Arch]    [RTL]    [Verif]   [Synth]   [PD]   [SignOff]
Agent     Agent     Agent    Agent(s)  Agent(s)   Agent    Agent    Agent
   │          │          │          │          │          │          │
   └──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
                                    │
                              ARTIFACT STORE
                    (Git + PDK vault + results DB)
```

---

## 2. Agent Team Organization

The agent team is modeled after a real ASIC design organization. Each agent maps to a human role or sub-team.

### 2.1 Agent Roster

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  ROLE                     │  AGENT ID              │  Primary Responsibility │
├──────────────────────────────────────────────────────────────────────────────┤
│  Program Manager          │  agent:pm              │  Spec ownership, milestone tracking    │
│  Algorithm Engineer       │  agent:algo            │  Math modeling, fixed-point conversion │
│  Architecture Lead        │  agent:arch            │  Micro-arch, block partitioning        │
│  RTL Designer (x N)       │  agent:rtl[n]          │  HDL coding, IP integration            │
│  Verification Lead        │  agent:verif_lead      │  Plan, coverage, sign-off              │
│  UVM/TB Engineer (x N)    │  agent:tb[n]           │  Testbench, sequences, checks          │
│  Formal Verification Eng  │  agent:formal          │  Property checking, equivalence, CDC   │
│  Synthesis Engineer       │  agent:synth           │  Logic synthesis, MCMM, constraints    │
│  Low-Power / UPF Engineer │  agent:upf             │  UPF gen, PA-sim, formal LP, AO/ISO/LS │
│                           │                        │  retention, Stage A–D verification     │
│  AMS / Analog Engineer    │  agent:ams             │  Analog IP intake, SPICE sim, AMS co-  │
│                           │                        │  sim, post-layout sign-off, wrapper RTL│
│  Reliability Engineer     │  agent:reliability     │  NBTI/HCI/TDDB aging, EM lifetime,    │
│                           │                        │  AEC-Q100/JEDEC, EOL timing margins    │
│  Floorplan Engineer       │  agent:fp              │  Floorplan, power planning             │
│  Place & Route Engineer   │  agent:pnr             │  Placement, CTS, routing               │
│  STA Engineer             │  agent:sta             │  Timing sign-off, ECO, ILM/ETM (hier) │
│  Power Engineer           │  agent:power           │  IR drop, EM BOL, dynamic power        │
│  DRC/LVS Engineer         │  agent:physical_verif  │  DRC, LVS, antenna, ERC, ESD           │
│  DFT Engineer             │  agent:dft             │  Scan, OCC, compression, BIST, JTAG   │
│  PDK/IP Librarian         │  agent:pdk             │  Cell library, IP validation, aging lib│
│  Orchestrator             │  agent:orch            │  State machine, routing, wave sched.   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Agent Communication Protocol

All inter-agent communication uses a structured message envelope:

```json
{
  "msg_id": "uuid-v4",
  "from": "agent:rtl[0]",
  "to": "agent:verif_lead",
  "stage": "RTL_DESIGN",
  "artifact_refs": ["git:sha/rtl/core/alu.sv", "git:sha/rtl/core/ctrl.sv"],
  "handoff_type": "STAGE_COMPLETE | REVIEW_REQUEST | ESCALATION | QUERY",
  "quality_gate_results": { "lint": "PASS", "cdc": "WARN:3" },
  "human_review_required": false,
  "payload": { ... }
}
```

---

## 3. Master Orchestration Architecture

### 3.1 Orchestrator State Machine

Real ASIC projects run several tracks concurrently. The orchestrator manages parallel workstreams, not a single serial pipeline.

```
         ┌─────────────────────────────────────────────────────────────┐
         │                     ORCHESTRATOR FSM                        │
         │            (parallel tracks, gated handoffs)                │
         └─────────────────────────────────────────────────────────────┘

  IDLE ──► SPEC_CAPTURE ──► ALGO_DEV ──► ARCH_DESIGN
                                               │
               ┌───────────────────────────────┤
               │  GATE-03 (Architecture Approval) unlocks both tracks  │
               │                                                        │
               ▼                                                        ▼
        TRACK A: RTL                                         TRACK B: VERIFICATION PREP
        RTL_CODING (parallel blocks)                         VPLAN + TB_BUILD (parallel)
               │                                                        │
               │  GATE-04 (RTL Freeze) ─────────────────────────────── │
               │                                                        │
               └──────────────────► VERIFICATION (simulation + formal) ◄┘
                                          │
                                          │  GATE-05 (Verif Closure)
                                          │
                                          ▼
                         SYNTHESIS (+ concurrent DFT insertion)
                                          │  ← LEC: RTL vs netlist
                                          │  GATE-06 (Synth Review)
                                          │
               ┌───────────────────────────────────────────────────────┐
               │  PHYSICAL DESIGN SUB-STATES (sequential within PD):   │
               │  FLOORPLAN ──► POWER_PLAN ──► PLACEMENT ──►           │
               │  CTS ──► ROUTING ──► POST_ROUTE_OPT                   │
               │  (incremental DRC/LVS checks throughout)              │
               └───────────────────────────────────────────────────────┘
                                          │  GATE-07 (PD Review)
                                          │
                                    SIGNOFF (all checks)
                                          │  ← LEC: post-ECO
                                          │  GATE-08 (Tape-out Review)
                                          │
                                   GDSII_DELIVERY
                                          │
                                   POST_SILICON (Stage 9)

              ◄── any stage can trigger REWORK to an earlier stage ───►
              (iteration counter tracked; escalate after N failures)
```

### 3.2 Stage Transition Conditions

| From → To | Transition Condition | Blocker if FAIL |
|-----------|---------------------|-----------------|
| SPEC → ALGO | Human PM approval of spec doc | Halt, revise spec |
| ALGO → ARCH | SNR/BER/performance targets met in simulation | Return to ALGO |
| ARCH → RTL | Architecture Review Board sign-off | Revise arch |
| RTL → VERIF | Lint clean, CDC clean, all modules coded | Fix RTL |
| VERIF → SYNTH | 100% functional coverage, 95%+ code coverage | Enhance TB or fix RTL |
| SYNTH → PD | Timing met in synthesis (with margin), DFT inserted | Revise constraints or RTL |
| PD → SIGNOFF | Routing complete, no unrouted nets | PD iteration |
| SIGNOFF → GDSII | All sign-off checks pass | Targeted ECOs |

### 3.3 Orchestrator Responsibilities

- **Spec Traceability Matrix**: Maps every artifact to spec requirement IDs
- **Iteration Counter**: Tracks rework loops per stage; escalates to human after N failures
- **Parallel Workstream Manager**: Allows concurrent RTL coding across multiple blocks
- **Tool License Broker**: Queries license server before dispatching tool jobs
- **Artifact Version Manager**: Tags every output with stage, iteration, and tool version
- **Escalation Manager**: Routes unresolved issues to appropriate human expert

---

## 4. Stage 1 — Product Specification

### 4.1 Goal
Convert market/customer requirements into a complete, unambiguous, verifiable technical specification that drives all subsequent design stages.

### 4.2 Agents Involved
- **Primary**: `agent:pm`
- **Support**: `agent:arch` (technical feasibility review)
- **Human Roles**: Product Manager, System Architect, Customer/Marketing

### 4.3 Process Flow

```
Customer Requirements
        │
        ▼
┌───────────────────┐
│  agent:pm         │  ← Natural language parsing, requirement extraction
│  SPEC CAPTURE     │    Classification: functional / performance / interface /
│                   │    power / area / cost / schedule
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  Requirement DB   │  ← Structured requirement objects with IDs (REQ-XXX)
│  (JSON / YAML)    │    Priority: MUST / SHOULD / NICE-TO-HAVE
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  agent:arch       │  ← Technical feasibility: area, power, process node,
│  FEASIBILITY      │    schedule, IP availability
│  CHECK            │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  *** HUMAN GATE ***│  ← Full review by PM + System Architect
│  Spec Review      │    Approval required before proceeding
└─────────┬─────────┘
          │ APPROVED
          ▼
     SPEC BASELINE
    (version-locked)
```

### 4.4 Artifacts

| Artifact | Format | Owner | Description |
|----------|--------|-------|-------------|
| `PRD.md` | Markdown | agent:pm | Product Requirements Document |
| `requirements.yaml` | YAML | agent:pm | Machine-readable requirement objects |
| `feasibility_report.md` | Markdown | agent:arch | Technical feasibility assessment |
| `spec_traceability_matrix.xlsx` | Spreadsheet | agent:orch | REQ-ID → artifact mapping |

### 4.5 Tool Placeholders

```yaml
# PLACEHOLDER: Requirement Management
tools:
  - id: req_mgmt
    name: "Jama Connect / IBM DOORS / Confluence"
    type: commercial_or_oss
    purpose: "Requirements capture, traceability, change management"
    mcp_skill: "skill:requirement_manager"
    api_hook: "POST /requirements, GET /requirements/{id}"

  - id: llm_spec_parser
    name: "Claude API + custom prompt chain"
    type: ai_agent
    purpose: "Parse freeform customer docs into structured requirements"
    mcp_skill: "skill:spec_parser"
```

### 4.6 Requirement Categories (agent:pm enforces)

| Category | Examples |
|----------|---------|
| Functional | Feature list, modes of operation, protocol compliance |
| Performance | Throughput, latency, frequency, data rates |
| Interface | External pin counts, voltage levels, protocol standards |
| Power | Active/standby/leakage budgets per supply rail |
| Area | Die area, core utilization target |
| Reliability | Qualification level (AEC-Q100, JEDEC), MTBF, lifetime (years/°C) |
| Safety | SIL/ASIL level, lockstep/redundancy requirements, ISO 26262 |
| Security | Side-channel resistance, secure boot, key storage, debug disable |
| Test | DFT coverage targets, test time budget, ATE platform |
| Regulatory | EMC/EMI, RoHS, export control classification |

### 4.7 Quality Gates

- [ ] All requirements have unique IDs (REQ-XXX format)
- [ ] Each requirement is testable/verifiable (has numeric acceptance criterion)
- [ ] No conflicting requirements exist
- [ ] Power, area, and performance targets are numerically specified with corner/PVT conditions
- [ ] Process node, foundry, and PDK version confirmed
- [ ] Target PVT corners and operating modes fully defined
- [ ] Reliability/qualification target specified (JEDEC grade, AEC-Q100 grade if applicable)
- [ ] Safety integrity level (SIL/ASIL) documented if applicable
- [ ] Security requirements captured if applicable
- [ ] Human PM sign-off recorded with timestamp

---

## 5. Stage 2 — Algorithm Development

### 5.1 Goal
Develop and validate the mathematical algorithms underpinning the chip, convert to fixed-point, and produce a golden reference model that will serve as the verification oracle.

### 5.2 Agents Involved
- **Primary**: `agent:algo`
- **Support**: `agent:arch` (hardware complexity feedback)
- **Human Roles**: Algorithm Engineer, DSP/ML Scientist

### 5.3 Process Flow

```
Spec Baseline (REQ IDs)
        │
        ▼
┌──────────────────────┐
│  agent:algo          │  ← Floating-point behavioral model
│  FLOAT-PT MODEL      │    Python/MATLAB/Julia
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Performance         │  ← SNR, BER, latency, throughput vs. spec targets
│  Simulation          │    Monte Carlo, corner analysis
└──────────┬───────────┘
           │  targets met?
           │  NO ──► iterate algorithm
           │  YES
           ▼
┌──────────────────────┐
│  agent:algo          │  ← Word-length optimization
│  FIXED-POINT         │    SQNR analysis, overflow/saturation strategy
│  CONVERSION          │    Tools: MATLAB FPA, PyMTL, FloPoCo, fxpmath
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  GOLDEN REF MODEL    │  ← C/C++ or SystemC fixed-point model
│  (transaction-level) │    Used by verification as oracle
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  *** HUMAN GATE ***  │  ← Algorithm Engineer + DSP Lead review
│  Algo Review         │    Fixed-point accuracy approved
└──────────┬───────────┘
           │ APPROVED
           ▼
     ALGO BASELINE + GOLDEN REF MODEL
```

### 5.4 Artifacts

| Artifact | Format | Description |
|----------|--------|-------------|
| `algo/float_model.py` | Python | Floating-point reference |
| `algo/fixed_model.cpp` | C++ | Fixed-point golden reference model |
| `algo/accuracy_report.md` | Markdown | SQNR, SNR, error analysis |
| `algo/wordlengths.yaml` | YAML | Signal word-length specification |
| `algo/test_vectors/` | Directory | Input/output stimulus for verification |

### 5.5 Tool Placeholders

```yaml
tools:
  - id: algo_float
    options: ["Python/NumPy/SciPy", "MATLAB", "Julia"]
    mcp_skill: "skill:algo_simulator"

  - id: fixed_point
    options: ["MATLAB Fixed-Point Toolbox", "fxpmath (OSS)", "FloPoCo (OSS)",
              "Synopsys Synphony HLS"]
    mcp_skill: "skill:fixed_point_converter"

  - id: golden_ref
    options: ["SystemC TLM (OSS)", "Accellera SystemC", "PyMTL3 (OSS)"]
    mcp_skill: "skill:golden_ref_generator"
```

### 5.6 Quality Gates

- [ ] Float model meets all performance targets from spec
- [ ] Fixed-point model SQNR within spec limits
- [ ] No overflow conditions under corner-case inputs
- [ ] Test vector suite generated (min/max/random/corner cases)
- [ ] Golden reference model compiles and runs standalone
- [ ] Human algorithm engineer sign-off

---

## 6. Stage 3 — Architecture Design

### 6.1 Goal
Define the complete micro-architecture: block partitioning, interfaces, clocking strategy, memory architecture, power domains, and pipeline structure. Produce a detailed architecture spec that RTL designers can directly implement.

### 6.2 Agents Involved
- **Primary**: `agent:arch`
- **Support**: `agent:pdk` (cell library capability), `agent:power` (power domain plan), `agent:dft` (DFT hooks)
- **Human Roles**: Architecture Lead, Senior RTL Engineers, DFT Lead

### 6.3 Process Flow

```
Algo Baseline + Spec
        │
        ▼
┌─────────────────────────┐
│  agent:arch             │  ← Block decomposition
│  BLOCK PARTITIONING     │    Datapath vs. control separation
│                         │    Pipeline staging decisions
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  INTERFACE DEFINITION   │  ← AXI / APB / AHB / custom
│                         │    Clock/reset architecture
│                         │    External memory interfaces
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  POWER ARCHITECTURE     │  ← Power domains, UPF/CPF planning
│  (agent:power assist)   │    Voltage islands, level shifters, isolation cells
│                         │    Power gating strategy
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  MEMORY ARCHITECTURE    │  ← SRAM/ROM sizing and placement hints
│                         │    Memory compiler selection
│                         │    Retention strategy
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  DFT ARCHITECTURE       │  ← Scan chain planning
│  (agent:dft assist)     │    MBIST topology
│                         │    JTAG / boundary scan
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  AREA/POWER/PERF        │  ← Back-of-envelope estimates
│  ESTIMATION             │    Tools: Synopsys DesignWare, CACTI
│                         │    Validate against spec targets
└───────────┬─────────────┘
            │  estimate meets spec?
            │  NO ──► revise architecture
            │  YES
            ▼
┌─────────────────────────┐
│  *** HUMAN GATE ***     │  ← Architecture Review Board
│  Architecture Review    │    ALL senior engineers attend
└───────────┬─────────────┘
            │ APPROVED
            ▼
     ARCHITECTURE SPEC BASELINE
```

### 6.4 Artifacts

| Artifact | Format | Description |
|----------|--------|-------------|
| `arch/microarch_spec.md` | Markdown | Full micro-architecture document |
| `arch/block_diagram.drawio` | Draw.io | Top-level and sub-block diagrams |
| `arch/interface_spec.yaml` | YAML | All interface port definitions |
| `arch/clocking_spec.yaml` | YAML | Clock domains, frequencies, relationships |
| `arch/power_intent.upf` | UPF | Power domain specification (IEEE 1801) |
| `arch/memory_map.yaml` | YAML | Register map and address decode |
| `arch/area_power_estimates.md` | Markdown | PPA estimates |
| `arch/dft_plan.md` | Markdown | Scan/BIST/JTAG architecture |

### 6.5 Tool Placeholders

```yaml
tools:
  - id: arch_modeling
    options: ["SystemC TLM (OSS)", "Gem5 (OSS)", "Synopsys Platform Architect (commercial)"]
    mcp_skill: "skill:arch_modeler"

  - id: memory_compiler
    options: ["ARM Memory Compiler", "Synopsys Memory Compiler",
              "Foundry-provided SRAM compilers", "OpenRAM (OSS)"]
    mcp_skill: "skill:memory_compiler"

  - id: reg_file_gen
    options: ["Systemrdl-compiler (OSS)", "PeakRDL (OSS)",
              "Synopsys IPXACT", "Cadence Socrates"]
    mcp_skill: "skill:regfile_generator"

  - id: ppa_estimator
    options: ["CACTI (OSS)", "McPAT (OSS)",
              "Synopsys DesignWare IP", "Custom estimation scripts"]
    mcp_skill: "skill:ppa_estimator"
```

### 6.6 Quality Gates

- [ ] All spec requirements mapped to architecture blocks (traceability)
- [ ] No orphaned blocks (every block serves at least one requirement)
- [ ] Clock domain crossings explicitly documented
- [ ] Power domains consistent with UPF
- [ ] Memory sizing validated against algorithm requirements
- [ ] DFT hooks defined at architecture level
- [ ] PPA estimates within 2× of spec targets (accounting for estimation error)
- [ ] Architecture Review Board sign-off

---

## 7. Stage 4 — RTL Design

### 7.1 Goal
Implement the micro-architecture in synthesizable RTL (SystemVerilog preferred). Each block agent codes its assigned module, integrates IPs, and ensures the RTL is clean, lint-free, and CDC-clean before handoff to verification.

### 7.2 Agents Involved
- **Primary**: `agent:rtl[0..N]` (one agent per major block or cluster)
- **Support**: `agent:pdk` (IP integration), `agent:dft` (scan insertion prep), `agent:arch` (clarifications)
- **Human Roles**: RTL Lead, Senior RTL Engineers, IP Integration Engineer

### 7.3 Process Flow

```
Architecture Spec + Interface Spec + Word-Length Spec
        │
        ├─────────────────────┬─────────────────────┐
        ▼                     ▼                     ▼
 agent:rtl[0]          agent:rtl[1]          agent:rtl[N]
 Block A coding        Block B coding        Block C coding
 (parallel)            (parallel)            (parallel)
        │                     │                     │
        ▼                     ▼                     ▼
 Block-level            Block-level           Block-level
 auto-lint              auto-lint             auto-lint
 (Spyglass/Verilator)   checks                checks
        │                     │                     │
        └──────────┬──────────┘─────────────────────┘
                   │  all blocks lint-clean?
                   ▼
        ┌──────────────────────┐
        │  IP INTEGRATION      │  ← Vendor IP instantiation
        │  (agent:pdk assist)  │    AMBA interconnect
        │                      │    Memory macro instantiation
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  TOP-LEVEL           │  ← Integration of all blocks
        │  INTEGRATION         │    Wrapper generation
        │  (agent:rtl[0])      │    Tie-off strategy
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  AUTOMATED RTL       │  ← Lint (Spyglass / Verilator)
        │  QUALITY CHECKS      │    CDC analysis (VC SpyGlass CDC / Meridian CDC)
        │                      │    RDC (Reset Domain Crossing)
        │                      │    Synthesis DRC
        │                      │    Power-aware lint (UPF check)
        └──────────┬───────────┘
                   │  checks pass?
                   │  NO ──► agent:rtl fixes and resubmits
                   │  YES
                   ▼
        ┌──────────────────────┐
        │  *** HUMAN GATE ***  │  ← RTL Lead code review
        │  RTL Code Review     │    Senior engineer review of critical paths
        └──────────┬───────────┘
                   │ APPROVED
                   ▼
            RTL FREEZE BASELINE
```

### 7.4 Coding Conventions (Agent-Enforced)

```systemverilog
// Agent:rtl enforces these rules automatically:
// 1.  Synchronous reset, active-low preferred (rst_n)
// 2.  Single clock edge per FF: always_ff @(posedge clk or negedge rst_n)
// 3.  No latches (always_comb with complete sensitivity list)
// 4.  No combinational loops
// 5.  All FSMs: one-hot or gray-coded with default state AND default case branch
// 6.  ALL case/casez/casex statements must have explicit default branch
// 7.  CDC: all async signals registered through 2-FF synchronizer module
// 8.  Parameters over magic numbers; localparams for internal constants
// 9.  Port widths match interface spec exactly (auto-checked vs interface_spec.yaml)
// 10. File header template with REQ-ID traceability comment
// 11. No `define macros in synthesizable RTL
// 12. No initial blocks in synthesizable RTL (only in simulation files)
// 13. Clock enable (CE) policy: use FF CE port for low-power gating; avoid
//     combinational gating unless explicitly UPF-governed
// 14. Pipeline register naming: <block>_<signal>_r<stage> (enables auto-SDC gen)
// 15. SystemVerilog interfaces: allowed for testbench; banned in synthesizable RTL
//     unless explicitly approved by RTL Lead (some synthesis tools handle poorly)
// 16. Port ordering: clocks first, resets second, control inputs, data inputs,
//     data outputs, status outputs — consistent across all modules
```

### 7.5 Artifacts

```
rtl/
├── top/
│   ├── chip_top.sv
│   └── chip_top_wrapper.sv
├── core/
│   ├── datapath.sv
│   ├── controller.sv
│   └── pipeline_stage[N].sv
├── mem/
│   ├── sram_wrapper.sv
│   └── rom_wrapper.sv
├── io/
│   ├── axi_slave.sv
│   └── pad_ring.sv
├── dft/
│   └── scan_wrapper.sv
├── ip/
│   └── [vendor_ip_instances]/
└── constraints/
    ├── top.sdc
    └── block_[N].sdc
```

### 7.6 Tool Placeholders

```yaml
tools:
  # HDL Simulators (pre-synthesis smoke check)
  - id: hdl_sim_oss
    options: ["Verilator (OSS)", "Icarus Verilog (OSS)", "GHDL (OSS-VHDL)"]
    mcp_skill: "skill:hdl_simulator"

  - id: hdl_sim_commercial
    options: ["Synopsys VCS", "Cadence Xcelium", "Mentor QuestaSim/ModelSim",
              "Aldec Active-HDL"]
    mcp_skill: "skill:hdl_simulator_commercial"

  # Lint & Static Checks
  - id: lint_oss
    options: ["Verilator --lint-only (OSS)", "svlint (OSS)", "slang (OSS)"]
    mcp_skill: "skill:rtl_linter"

  - id: lint_commercial
    options: ["Synopsys SpyGlass", "Cadence HAL", "Mentor Questa Lint",
              "Real Intent Ascent Lint"]
    mcp_skill: "skill:rtl_linter_commercial"

  # CDC Analysis
  - id: cdc_tool
    options: ["Synopsys SpyGlass CDC", "Cadence Meridian CDC",
              "Real Intent Ascent CDC", "OneSpin (formal-based)"]
    mcp_skill: "skill:cdc_analyzer"

  # RTL Editors / Code Gen
  - id: rtl_codegen
    options: ["Claude API (LLM-based)", "ChipChat", "RTLCoder models",
              "Custom Jinja2 templates"]
    mcp_skill: "skill:rtl_generator"

  # Register File / IP Generation
  - id: reg_gen
    options: ["PeakRDL (OSS)", "SystemRDL compiler (OSS)",
              "Cadence Socrates", "Synopsys IPXACT tools"]
    mcp_skill: "skill:register_generator"
```

### 7.7 Quality Gates

- [ ] Zero lint errors (warnings reviewed and waived/fixed)
- [ ] Zero CDC errors (warnings documented with waiver rationale)
- [ ] Zero RDC (Reset Domain Crossing) errors
- [ ] All modules have corresponding interface spec entries
- [ ] No undriven outputs or floating inputs
- [ ] UPF power intent consistency check passes
- [ ] RTL compiles in both OSS and commercial simulators
- [ ] All REQ-IDs referenced in file headers
- [ ] Human RTL Lead code review sign-off

---

## 8. Stage 5 — Functional Verification

### 8.1 Goal
Achieve complete functional correctness of the RTL against the spec. This is the most resource-intensive stage. Goal is 100% functional coverage closure and ≥95% code coverage, with all regression tests passing.

### 8.2 Agents Involved
- **Primary**: `agent:verif_lead`, `agent:tb[0..N]`, `agent:formal`
- **Support**: `agent:rtl` (bug fixes), `agent:algo` (golden ref queries)
- **Human Roles**: Verification Lead, UVM Engineers, Formal Verification Engineer

### 8.3 Verification Strategy

```
┌────────────────────────────────────────────────────────────────────────┐
│                      VERIFICATION PLAN (VPlan)                         │
│  Generated by agent:verif_lead from spec + architecture                │
├────────────────┬────────────────┬────────────────┬─────────────────────┤
│  UNIT LEVEL    │  BLOCK LEVEL   │  CHIP LEVEL    │  FORMAL             │
│  (per module)  │  (per cluster) │  (integration) │  (properties)       │
└────────────────┴────────────────┴────────────────┴─────────────────────┘
```

### 8.4 Process Flow

```
RTL Freeze + Golden Ref Model + Test Vectors
        │
        ▼
┌──────────────────────────┐
│  agent:verif_lead        │  ← Verification Plan generation
│  VPLAN GENERATION        │    Coverage goals per REQ-ID
│                          │    Test categories: directed / constrained-random
│                          │    Assertion plan (SVA)
└────────────┬─────────────┘
             │
             ├────────────────────────────────────────┐
             ▼                                        ▼
┌────────────────────────┐               ┌────────────────────────┐
│  agent:tb[N]           │               │  agent:formal          │
│  UVM TESTBENCH BUILD   │               │  FORMAL VERIFICATION   │
│  - UVM env/agent/seq   │               │  - Property writing    │
│  - Scoreboard          │               │  - Bounded model check │
│  - Coverage collector  │               │  - Equivalence check   │
│  - Assertions (SVA)    │               │  - CDC formal proofs   │
└────────────┬───────────┘               └────────────┬───────────┘
             │                                        │
             ▼                                        │
┌────────────────────────┐                            │
│  REGRESSION RUNS       │  ← Nightly CI regression  │
│  (parallel simulation) │    Seed-based random      │
│  Directed tests first  │    Coverage-driven gen     │
└────────────┬───────────┘                            │
             │                                        │
             ▼                                        │
┌────────────────────────┐                            │
│  COVERAGE ANALYSIS     │  ← agent:verif_lead        │
│  & GAP CLOSURE         │    Identifies uncovered    │
│                        │    scenarios               │
│                        │    Generates new tests     │
└────────────┬───────────┘                            │
             │  coverage goals met?                   │
             │  NO ──► generate targeted tests        │
             │  YES                                   │
             ▼                                        │
┌────────────────────────┐  ◄─────────────────────────┘
│  BUG TRIAGE &          │  ← agent:verif_lead classifies bugs
│  RTL FIX LOOP          │    agent:rtl fixes RTL
│                        │    Re-regression after fix
└────────────┬───────────┘
             │  zero open bugs + coverage closed?
             ▼
┌────────────────────────┐
│  *** HUMAN GATE ***    │  ← Verification Lead sign-off
│  Verification Closure  │    Coverage waivers reviewed
│  Review                │    Formal proof review
└────────────┬───────────┘
             │ APPROVED
             ▼
       VERIFICATION SIGN-OFF
```

### 8.5 UVM Testbench Architecture (Agent-Generated)

```
tb/
├── env/
│   ├── chip_env.sv          ← top-level UVM env
│   ├── agent_[N]/           ← per-interface UVM agents
│   │   ├── [N]_agent.sv
│   │   ├── [N]_driver.sv
│   │   ├── [N]_monitor.sv
│   │   └── [N]_sequencer.sv
│   ├── scoreboard.sv        ← golden ref model comparison
│   └── coverage/
│       ├── func_cov.sv      ← functional coverage groups
│       └── cov_collector.sv
├── sequences/
│   ├── base_seq.sv
│   ├── directed_seq[N].sv   ← per-requirement directed tests
│   └── random_seq.sv        ← constrained-random sequences
├── tests/
│   ├── base_test.sv
│   ├── smoke_test.sv
│   ├── regression_test.sv
│   └── corner_case_test.sv
├── assertions/
│   └── chip_assertions.sv   ← SVA protocol and interface assertions
└── sim_top.sv               ← simulation top wrapper
```

### 8.6 Tool Placeholders

```yaml
tools:
  # Simulators
  - id: sim_oss
    options: ["Verilator (OSS)", "Icarus Verilog (OSS)"]
    mcp_skill: "skill:simulator_oss"

  - id: sim_commercial
    options: ["Synopsys VCS + DVE/Verdi", "Cadence Xcelium + SimVision",
              "Mentor QuestaSim", "Aldec Riviera-PRO"]
    mcp_skill: "skill:simulator_commercial"

  # Formal Verification
  - id: formal_commercial
    options: ["Synopsys VC Formal", "Cadence JasperGold",
              "Mentor Questa Formal", "OneSpin 360"]
    mcp_skill: "skill:formal_verifier"

  - id: formal_oss
    options: ["Yosys/SymbiYosys (OSS)", "EBMC (OSS)", "CBMC (OSS)"]
    mcp_skill: "skill:formal_oss"

  # Coverage & Regression Management
  - id: coverage_mgmt
    options: ["Synopsys Tmax / VCS URG", "Cadence IMC",
              "Mentor QuestaSim Coverage", "Aldec Coverage"]
    mcp_skill: "skill:coverage_manager"

  - id: regression_mgr
    options: ["Jenkins CI (OSS)", "GitHub Actions (OSS)",
              "Synopsys Virtualizer", "Custom LSF/SLURM scripts"]
    mcp_skill: "skill:regression_runner"

  # UVM Testbench Generation
  - id: tb_gen
    options: ["Mentor Questa Verification IP", "Synopsys VC VIP",
              "LLM-based UVM gen (Claude API)", "uvmf_template_gen (OSS)"]
    mcp_skill: "skill:tb_generator"

  # Emulation (for large designs)
  - id: emulation
    options: ["Cadence Palladium Z2", "Synopsys ZeBu",
              "Mentor Veloce", "AWS F1 FPGA prototyping"]
    mcp_skill: "skill:emulator"
```

### 8.7 UPF / Low-Power Verification Sub-Flow

For any design with multiple power domains:

```
RTL + UPF
    │
    ▼
┌─────────────────────────────────────────────┐
│  POWER-AWARE RTL SIMULATION                  │  ← VCS MVRC or Xcelium CPF/UPF mode
│  (agent:tb runs with UPF loaded)             │    Isolation cell behavior verified
│                                              │    Level shifter correctness
│                                              │    Retention save/restore sequences
│                                              │    Always-on net connectivity
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  FORMAL LOW-POWER VERIFICATION               │  ← JasperGold Low Power App or
│  (agent:formal)                              │    VC Formal Low Power
│                                              │    Power state table (PST) proofs
│                                              │    Always-on buffer insertion check
└────────────────┬────────────────────────────┘
                 │ UPF sim clean + LP formal PASS
                 ▼
           LP VERIFICATION SIGN-OFF
```

### 8.8 Logical Equivalence Check (LEC) — Placement in Flow

LEC is not a single check. It must run at each netlist transformation:

| LEC Checkpoint | From | To | Tool | Gate |
|---------------|------|----|------|------|
| **LEC-1** | RTL | Synthesized netlist | Synopsys Formality / Cadence Conformal | GATE-06 |
| **LEC-2** | Pre-DFT netlist | Post-DFT netlist | Formality / Conformal | GATE-06 |
| **LEC-3** | Pre-ECO netlist | Post-ECO netlist | Formality / Conformal (incremental) | Per ECO |
| **LEC-4** | Post-route netlist | Final sign-off netlist | Formality / Conformal | GATE-08 |

**LEC-1 and LEC-2 are blocking gates.** LEC-3 runs after every physical ECO before re-DRC. LEC-4 is a final tape-out check.

### 8.9 SAIF / Switching Activity Capture

Power analysis (Stage 7 and sign-off) requires switching activity from simulation. The verification stage must explicitly capture this:

```yaml
saif_capture:
  tool: "simulator SAIF annotation (VCS -saif / Xcelium saif)"
  test_modes:
    - normal_operation_typical_stimulus
    - worst_case_switching_scenario
    - scan_shift_mode            # often worst-case dynamic IR drop
    - low_power_mode
  output: "verif/saif/chip_top_<mode>.saif"
  used_by: [agent:power, agent:sta_signoff]
```

### 8.10 Quality Gates

- [ ] Verification Plan reviewed and approved by human Verif Lead
- [ ] Minimum 500 unique random seeds executed in regression
- [ ] 100% functional coverage (all VPlan items covered)
- [ ] 100% FSM state coverage; 100% FSM transition arc coverage
- [ ] ≥95% toggle coverage (waivable with rationale)
- [ ] ≥95% statement/branch/expression code coverage
- [ ] Cross-coverage bins defined for key feature interactions; all hit
- [ ] Zero SVA assertion failures in regression (assertion pass gate)
- [ ] Assertion firing rate ≥ 1 fire per assertion across regression (dead assertion detection)
- [ ] Zero open P1/P2 bugs; all P3+ triaged and accepted
- [ ] Formal property proofs complete (bounded or full); CDC formal convergence documented
- [ ] **LEC-1 PASS** (RTL vs. synthesized netlist) — blocking
- [ ] Power-aware simulation (PA-GLS with UPF) PASS — required for multi-domain designs
- [ ] Formal low-power verification PASS — required for multi-domain designs
- [ ] SAIF files captured for all key test modes
- [ ] Coverage waivers reviewed and approved with written rationale
- [ ] Human Verification Lead sign-off

---

## 9. Stage 6 — Logic Synthesis

### 9.1 Goal
Convert verified RTL to a gate-level netlist using the target PDK cell library. Achieve timing closure at synthesis with appropriate constraints, minimize area and power consistent with spec targets.

### 9.2 Agents Involved
- **Primary**: `agent:synth`
- **Support**: `agent:sta` (timing constraints), `agent:dft` (scan insertion), `agent:pdk` (library validation)
- **Human Roles**: Synthesis Engineer, STA Engineer, DFT Lead

### 9.3 Process Flow

```
Verified RTL + SDC Constraints + PDK Liberty Files + UPF
        │
        ▼
┌──────────────────────────┐
│  agent:synth             │  ← SDC constraint validation (completeness check):
│  CONSTRAINT VALIDATION   │    create_clock (all clocks including generated)
│                          │    set_input/output_delay (derived from sys timing)
│                          │    false paths / MCPs (each requires written rationale)
│                          │    max_transition / max_capacitance
│                          │    MCMM scenario setup: setup corners (SS/cold) +
│                          │      hold corners (FF/hot) defined simultaneously
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  LOGIC SYNTHESIS (MCMM)  │  ← Technology mapping against MCMM corners
│  (analyze → elaborate    │    Simultaneous setup + hold optimization
│   → compile_ultra)       │    Clock gating insertion (cover all qualifying enables)
│                          │    Retiming (register balancing for timing)
│                          │    Power-aware optimization (switching activity from SAIF)
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  DFT INSERTION           │  ← Scan architecture per dft_plan.md:
│  (agent:dft)             │    Scan compression (EDT/DFTMAX, 50–100× compression)
│                          │    On-Chip Clock Controller (OCC) for at-speed tests
│                          │    MBIST controller insertion
│                          │    Boundary scan / JTAG (IEEE 1149.1)
│                          │    Scan shift power reduction (OCC-based low-power)
│                          │    Tie-high/tie-low cell insertion
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  LEC-2: POST-DFT         │  ← Logical equivalence: pre-DFT vs. post-DFT netlist
│  (agent:formal)          │    BLOCKING — no proceed if FAIL
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  STA: MCMM + POCV/AOCV  │  ← Setup analysis: SS corner + POCV/AOCV derating
│  (agent:sta)             │    Hold analysis: FF corner + min-delay derating
│                          │    Scan shift timing at test frequency
│                          │    Max transition / max capacitance checks
│                          │    SI delta-delay derating enabled (pre-route estimate)
│                          │    Synthesis margin: WNS target ≥ +20% of clock period
│                          │      (tighter for ≤7nm due to PD degradation)
└────────────┬─────────────┘
             │  timing met across ALL MCMM scenarios?
             │  NO: slack < –(clock_period × 0.05) ──► RTL micro-arch fix
             │  NO: marginal ──► synthesis option / constraint tuning
             │  YES
             ▼
┌──────────────────────────┐
│  ATPG PATTERN GEN        │  ← Stuck-at fault patterns
│  (agent:dft)             │    Transition fault patterns (LOC + LOS)
│                          │    Path delay fault patterns
│                          │    Cell-aware ATPG (CAT) patterns
│                          │    IDDQ/static current test patterns
│                          │    Bridging fault patterns
│                          │    Patterns output in STIL format
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  GATE-LEVEL SIM (GLS)    │  ← Four modes required:
│                          │    1. Functional: max-delay SDF (setup check)
│                          │    2. Functional: min-delay SDF (hold check)
│                          │    3. X-prop optimistic (X=0 or X=1 — finds reset bugs)
│                          │    4. X-prop pessimistic (X blocks — finds X-state issues)
│                          │    PA-GLS with UPF if multi-domain design
│                          │    Run full regression (not just smoke)
└────────────┬─────────────┘
             │  all 4 GLS modes pass?
             │  NO ──► investigate (reset X-state, hold violation, UPF cell)
             │  YES
             ▼
┌──────────────────────────┐
│  *** HUMAN GATE ***      │  ← Synthesis Engineer + STA Engineer + DFT Lead
│  GATE-06: Synth Review   │    QoR report review; DFT coverage review
│                          │    LEC-2 results; GLS results
└────────────┬─────────────┘
             │ APPROVED
             ▼
       GATE-LEVEL NETLIST FREEZE
```

### 9.4 Artifacts

```
synth/
├── netlist/
│   ├── chip_top_synth.v        ← gate-level netlist
│   └── chip_top_synth.sdf      ← standard delay format
├── reports/
│   ├── timing_report.rpt       ← setup/hold slack per path
│   ├── area_report.rpt         ← cell count, area breakdown
│   ├── power_report.rpt        ← dynamic/leakage power
│   ├── dft_coverage.rpt        ← scan coverage, ATPG stats
│   └── qor_summary.md          ← QoR summary for human review
├── constraints/
│   ├── top_synth.sdc           ← final synthesis constraints
│   └── dft.sdc                 ← DFT-specific constraints
└── scripts/
    ├── run_synthesis.tcl
    └── run_dft.tcl
```

### 9.5 Tool Placeholders

```yaml
tools:
  # Logic Synthesis
  - id: synth_commercial
    options: ["Synopsys Design Compiler / Fusion Compiler",
              "Cadence Genus", "Mentor Precision RTL"]
    mcp_skill: "skill:logic_synthesizer"

  - id: synth_oss
    options: ["Yosys (OSS)", "Yosys + ABC (OSS)",
              "OpenLane flow (OSS, for supported PDKs)"]
    mcp_skill: "skill:logic_synthesizer_oss"

  # DFT
  - id: dft_tool
    options: ["Synopsys DFT Compiler + TetraMAX ATPG",
              "Cadence Encounter Test", "Mentor Tessent"]
    mcp_skill: "skill:dft_engine"

  # Static Timing Analysis
  - id: sta_tool
    options: ["Synopsys PrimeTime PX", "Cadence Tempus",
              "OpenSTA (OSS)", "ICTime (OSS)"]
    mcp_skill: "skill:sta_engine"

  # Gate-Level Simulation
  - id: gls_tool
    options: ["Same as RTL sim + SDF back-annotation"]
    mcp_skill: "skill:gls_runner"
```

### 9.6 Synthesis Tool Additions

```yaml
tools:
  - id: lec_tool
    options: ["Synopsys Formality", "Cadence Conformal LEC",
              "OneSpin 360 EC (formal LEC)"]
    mcp_skill: "skill:lec_runner"

  - id: rtl_power_analysis
    options: ["Ansys PowerArtist (RTL-level)", "Synopsys PrimePower RTL",
              "Cadence Joules"]
    mcp_skill: "skill:rtl_power_estimator"
    note: "Run at synthesis stage for early power feedback before PD"
```

### 9.7 Quality Gates

- [ ] SDC completeness: all ports constrained, all clocks (including generated) defined
- [ ] Each false path / MCP has documented rationale in constraints/waiver_log.md
- [ ] MCMM: WNS ≥ 0 on ALL setup corners, WNS ≥ 0 on ALL hold corners
- [ ] Post-synthesis timing margin: WNS ≥ +(clock_period × 0.20) for nodes ≤16nm; ≥ +(clock_period × 0.10) for ≥28nm
- [ ] TNS = 0 on all MCMM corners
- [ ] Max transition / max capacitance: zero violations
- [ ] Area within spec target ±10%
- [ ] Power estimate (SAIF-annotated) within spec target ±15%
- [ ] Clock gating coverage: all qualifying enables gated (verified by synthesis report)
- [ ] **DFT: stuck-at fault coverage ≥ 99%**
- [ ] **DFT: transition fault coverage ≥ 97%** (LOC and/or LOS)
- [ ] **DFT: path delay fault coverage ≥ 90%** (for high-speed designs)
- [ ] **DFT: cell-aware ATPG coverage ≥ 98%** (at advanced nodes ≤16nm)
- [ ] IDDQ test patterns generated
- [ ] Bridging fault coverage ≥ 95%
- [ ] Scan compression ratio achieved (target 50–100×)
- [ ] OCC inserted and timing-clean
- [ ] LEC-2 PASS (pre-DFT vs. post-DFT netlist)
- [ ] GLS: all four modes pass (max-SDF, min-SDF, X-opt, X-pess)
- [ ] PA-GLS with UPF: PASS (multi-domain designs only)
- [ ] No unmapped cells in final netlist
- [ ] Synthesis engineer + STA engineer + DFT Lead sign-off

---

## 10. Stage 7 — Physical Design (Backend)

### 10.1 Goal
Transform the gate-level netlist into a physical layout that meets all timing, power, signal integrity, and DRC/LVS requirements. Output is a final routed database ready for sign-off.

### 10.2 Agents Involved
- **Primary**: `agent:fp` (floorplan), `agent:pnr` (P&R), `agent:power` (power analysis)
- **Support**: `agent:sta` (timing closure), `agent:physical_verif` (DRC/LVS checks)
- **Human Roles**: PD Lead, Floorplan Engineer, P&R Engineer, Power Engineer

### 10.3 Process Flow

```
Gate-Level Netlist + SDC + UPF + PDK (LEF/LIB/GDS) + SRAM GDS
        │
        ▼
┌──────────────────────────┐
│  agent:pdk               │  ← PDK setup: LEF, TLU+, RC tables
│  PDK SETUP               │    SRAM/IP macro GDS import
│                          │    Layer map validation
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐    ┌──────────────────────┐
│  agent:fp                │    │  POWER PLANNING       │
│  FLOORPLANNING           │←──►│  (agent:power)        │
│  - Die/core area sizing  │    │  - VDD/VSS rings      │
│  - Macro placement       │    │  - Power stripes      │
│  - I/O pad placement     │    │  - IR drop analysis   │
│  - Voltage domain bounds │    │  - EM check           │
└────────────┬─────────────┘    └──────────────────────┘
             │
             ▼
┌──────────────────────────┐
│  PLACEMENT               │  ← Standard cell placement
│  (agent:pnr)             │    Timing-driven placement
│                          │    Congestion-aware placement
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  CLOCK TREE SYNTHESIS    │  ← CTS: clock skew minimization
│  (agent:pnr)             │    Clock buffer/inverter insertion
│                          │    Useful skew analysis
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  ROUTING                 │  ← Global routing → detailed routing
│  (agent:pnr)             │    SI-aware routing
│                          │    Via optimization
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  POST-ROUTE              │  ← RC extraction (SPEF) — StarRC/Quantus/OpenRCX
│  OPTIMIZATION            │    Post-route STA: MCMM + POCV/AOCV derating
│  (agent:sta + agent:pnr) │    SI-aware timing: crosstalk delta-delay (GBA)
│                          │    SI noise/glitch analysis (peak noise)
│                          │    Dynamic IR drop (all modes, incl. scan shift)
│                          │    Thermal hotspot analysis (if power density > threshold)
│                          │    ECO if timing violations: buffer/resize ECOs
│                          │    LEC-3 after every ECO that modifies netlist
└────────────┬─────────────┘
             │  timing + SI + IR met?
             │  NO ──► targeted ECO or re-route
             │  YES
             ▼
┌──────────────────────────┐
│  PHYSICAL COMPLETION     │  ← Mandatory before DRC sign-off:
│  (agent:pnr)             │    1. Tap cell insertion (latch-up prevention)
│                          │    2. End-of-row cell insertion
│                          │    3. Well tie-off + tie-high/tie-low cells
│                          │    4. Filler cell insertion (N-well continuity)
│                          │    5. Decap cell insertion (power integrity)
│                          │    6. Metal fill / dummy fill per foundry density
│                          │       spec (all metal + poly + diffusion layers)
│                          │    7. Via redundancy optimization (double-via)
│                          │    8. Post-fill incremental DRC (verify fill clean)
└────────────┬─────────────┘
             │  fill DRC clean?
             │  NO ──► adjust fill rules, re-fill
             │  YES
             ▼
        ROUTED DATABASE (COMPLETE)
```

### 10.4 Artifacts

```
pd/
├── floorplan/
│   ├── floorplan.def           ← DEF with macro/IO placement
│   └── floorplan_report.md     ← utilization, aspect ratio
├── placement/
│   └── placed.def
├── cts/
│   ├── cts.def
│   └── clock_tree_report.rpt   ← skew, insertion delay
├── route/
│   ├── routed.def
│   └── routed.gds              ← intermediate GDS
├── extraction/
│   └── top.spef                ← parasitic extraction
├── sta/
│   ├── setup_report.rpt        ← post-route setup timing
│   ├── hold_report.rpt         ← post-route hold timing
│   └── timing_summary.md
├── power/
│   ├── ir_drop.rpt             ← static/dynamic IR drop
│   ├── em_report.rpt           ← electromigration
│   └── power_summary.md
└── scripts/
    ├── run_floorplan.tcl
    ├── run_pnr.tcl
    └── run_sta.tcl
```

### 10.5 Tool Placeholders

```yaml
tools:
  # Place & Route
  - id: pnr_commercial
    options: ["Synopsys IC Compiler II (ICC2)", "Cadence Innovus",
              "Mentor Nitro-SoC"]
    mcp_skill: "skill:place_and_route"

  - id: pnr_oss
    options: ["OpenROAD / OpenLane2 (OSS)", "TritonRoute (OSS)"]
    mcp_skill: "skill:pnr_oss"

  # Static Timing Analysis (Post-Route)
  - id: sta_signoff
    options: ["Synopsys PrimeTime PX", "Cadence Tempus", "OpenSTA (OSS)"]
    mcp_skill: "skill:sta_signoff"

  # Parasitic Extraction
  - id: extraction
    options: ["Synopsys StarRC", "Cadence Quantus QRC",
              "Mentor Calibre xRC", "OpenRCX (OSS, OpenROAD)"]
    mcp_skill: "skill:parasitic_extractor"

  # Power Analysis
  - id: power_analysis
    options: ["Synopsys PrimePower", "Ansys RedHawk-SC",
              "Cadence Voltus", "OpenROAD PDN analysis (OSS)"]
    mcp_skill: "skill:power_analyzer"

  # Clock Tree Synthesis
  - id: cts_tool
    options: ["Built-in ICC2/Innovus CTS", "Synopsys CCOpt (in ICC2)",
              "TritonCTS (OSS, OpenROAD)"]
    mcp_skill: "skill:cts_engine"
```

### 10.6 Quality Gates

**Floorplan:**
- [ ] Utilization 60–75% (< 80% to avoid routing congestion)
- [ ] No macro overlap or I/O pad DRC errors
- [ ] Voltage domain boundaries do not cut through standard cell rows
- [ ] Per-block power budget allocated and tracked

**Placement:**
- [ ] Placement congestion < foundry threshold (no global hotspots)
- [ ] Max fanout and max transition DRVs: zero post-placement

**CTS:**
- [ ] Clock skew < 10% of clock period per domain (intra-domain)
- [ ] Cross-domain skew explicitly documented

**Routing:**
- [ ] Zero unrouted nets
- [ ] Zero DRC violations post-routing (pre-fill)
- [ ] SI noise/glitch violations: zero (peak noise analysis clean)
- [ ] Via redundancy applied (double-via report reviewed)

**Physical Completion (mandatory before proceeding to sign-off):**
- [ ] Tap cells inserted (latch-up check passes structurally)
- [ ] Tie-high/tie-low cells: all floating gate inputs tied
- [ ] Filler cells inserted on all rows
- [ ] Metal fill complete on all layers per foundry density rules
- [ ] Post-fill incremental DRC: zero violations

**Timing (post-route, MCMM + POCV/AOCV):**
- [ ] WNS ≥ 0 (all setup corners/modes including scan shift mode)
- [ ] Hold WHS ≥ 0 (all hold corners/modes, post-OCV derating)
- [ ] Max transition / max capacitance: zero violations

**Power:**
- [ ] Static IR drop ≤ 5% VDD
- [ ] Dynamic IR drop ≤ 10% VDD (all switching modes incl. scan shift)
- [ ] EM violations: zero (metal + via)
- [ ] Thermal hotspot: max temperature within process envelope

**LEC:**
- [ ] LEC-3: all post-route ECOs verified (pre-ECO vs. post-ECO)

**Sign-off:**
- [ ] PD Lead sign-off on routed + filled database

---

## 11. Stage 8 — Sign-Off & GDSII Tape-Out

### 11.1 Goal
Perform all final sign-off checks required by the foundry and confirm that the physical layout faithfully implements the design and meets all spec requirements. Produce the GDSII file for tape-out.

### 11.2 Agents Involved
- **Primary**: `agent:physical_verif`, `agent:sta`, `agent:power`
- **Support**: All prior agents for ECO support
- **Human Roles**: Sign-off Lead, DRC/LVS Engineer, STA Engineer, PD Lead, Program Manager

### 11.3 Sign-Off Checks

> All sign-off runs use the foundry-released, version-locked DRC/LVS rule deck. Deck version is recorded in `tapeout/foundry_submission/pdk_deck_versions.yaml`.

```
Routed + Filled Database (complete)
        │
        ├──────────────────────────────────────────────────────────┐
        ▼                                                          ▼
┌────────────────────┐  ┌───────────────────┐  ┌───────────────┐  ┌────────────────┐
│  PHYSICAL VERIF    │  │  ELECTRICAL VERIF │  │  TIMING       │  │  POWER SIGN-OFF│
│                    │  │                   │  │  SIGN-OFF     │  │                │
│  DRC (foundry deck)│  │  LVS (CDL vs GDS) │  │               │  │  Static IR drop│
│  Fill DRC (post-   │  │  Antenna rules    │  │  STA: MCMM    │  │  Dynamic IR     │
│    dummy-fill DRC) │  │  ERC              │  │  + POCV/AOCV  │  │  (incl. scan   │
│  ERC               │  │  Soft-check       │  │  all corners/ │  │  shift mode)   │
│  Metal density     │  │  Softchk          │  │  modes        │  │                │
│  (all layers in    │  │                   │  │               │  │  EM (metal +   │
│   density range)   │  │  Power/Ground     │  │  SI: noise +  │  │  via)          │
│  CMP analysis      │  │  net connectivity │  │  crosstalk GBA│  │                │
│  (hotspot model)   │  │  check            │  │               │  │  Thermal       │
│                    │  │                   │  │  Max tran/cap │  │  analysis      │
│  Voltage-dependent │  │                   │  │  zero viola.  │  │                │
│  DRC (per domain)  │  │                   │  │               │  │  ESD: CDM/HBM  │
│                    │  │                   │  │  Scan shift   │  │  (PathFinder / │
│  Hierarchical DRC  │  │                   │  │  hold timing  │  │  Totem)        │
│  (block then chip) │  │                   │  │               │  │                │
└────────┬───────────┘  └──────┬────────────┘  └──────┬────────┘  └───────┬────────┘
         │                     │                       │                   │
         └─────────────────────┴──────── ALL CLEAN? ───┴───────────────────┘
                                              │
                               NO ──► targeted ECO → re-run affected checks
                                              │
                                             YES
                                              │
                                              ▼
                             ┌─────────────────────────┐
                             │  LATCH-UP SIGN-OFF       │  ← Calibre LVS latch-up
                             │  (agent:physical_verif)  │    or Spectre latch-up
                             │                          │    simulation on critical
                             │                          │    I/O structures
                             └──────────┬──────────────┘
                                        │  CLEAN
                                        ▼
                             ┌─────────────────────────┐
                             │  LEC-4: FINAL NETLIST   │  ← Formality/Conformal
                             │  EQUIVALENCE CHECK       │    Final GDS netlist vs.
                             │  (agent:formal)          │    last known-good netlist
                             └──────────┬──────────────┘
                                        │  PASS
                                        ▼
                             ┌─────────────────────────┐
                             │  FINAL GLS SIGN-OFF      │  ← Full regression suite
                             │  (agent:verif_lead)      │    RC-annotated, MCMM SDF
                             │                          │    PA-GLS with UPF
                             │                          │    X-prop modes
                             └──────────┬──────────────┘
                                        │
                                        ▼
                             ┌─────────────────────────┐
                             │  *** HUMAN GATE ***      │  ← FULL TAPE-OUT REVIEW
                             │  GATE-08: TAPE-OUT       │    PM + All Lead Engineers
                             │                          │    Legal / IP clearance
                             │                          │    All waivers reviewed
                             └──────────┬──────────────┘
                                        │ APPROVED
                                        ▼
                             ┌─────────────────────────┐
                             │  GDSII GENERATION        │  ← Stream out GDSII
                             │  + OASIS (optional)      │    Merge all IP/macro GDS
                             │                          │    Final DRC on merged GDSII
                             │                          │    (foundry stream-in check)
                             └──────────┬──────────────┘
                                        │
                                        ▼
                                 TAPE-OUT DELIVERY
                              (Foundry submission package)
```

### 11.4 Tape-Out Package Checklist

```
tapeout/
├── gds/
│   ├── chip_final.gds              ← final GDSII (all layers merged)
│   ├── chip_final.oas              ← OASIS alternative (optional)
│   └── chip_final_drc_clean.log    ← zero violations or approved waivers
├── netlist/
│   ├── chip_final_netlist.v        ← post-layout Verilog netlist
│   ├── chip_final.cdl              ← CDL netlist (LVS source)
│   └── chip_final.spef             ← final SPEF (corner-specific)
├── timing/
│   ├── chip_final_tt.lib           ← characterized timing model (if hard IP)
│   ├── chip_final_ss.lib
│   └── chip_final_ff.lib
├── docs/
│   ├── tapeout_checklist.md        ← every gate-item signed off
│   ├── waiver_log.md               ← all DRC/LVS/coverage waivers + rationale
│   ├── spec_traceability_final.xlsx← REQ-ID → artifact final state
│   ├── change_log.md               ← all ECOs post-RTL-freeze
│   ├── test_interface_spec.md      ← scan chains, BIST, JTAG pin descriptions
│   └── ip_manifest.yaml            ← all IPs: name, version, license, source
├── test/
│   ├── atpg_stuck_at.stil          ← stuck-at patterns
│   ├── atpg_transition.stil        ← transition (at-speed) patterns
│   ├── atpg_cell_aware.stil        ← cell-aware ATPG patterns
│   ├── atpg_path_delay.stil        ← path delay patterns
│   ├── atpg_iddq.stil              ← IDDQ test patterns
│   └── mbist/                      ← MBIST controllers + patterns
├── foundry_submission/
│   ├── drc_report_clean.rpt        ← foundry deck version recorded
│   ├── lvs_report_clean.rpt
│   ├── latchup_report_clean.rpt
│   ├── antenna_report_clean.rpt
│   ├── esd_report_clean.rpt
│   ├── density_report_clean.rpt
│   ├── pdk_deck_versions.yaml      ← version-locked DRC/LVS deck IDs
│   └── README_foundry.md           ← submission instructions
└── lec/
    └── lec4_final_pass.log         ← LEC-4 clean
```

### 11.5 Tool Placeholders

```yaml
tools:
  # DRC / LVS
  - id: drc_lvs_commercial
    options: ["Mentor Calibre nmDRC / nmLVS", "Synopsys IC Validator (ICV)",
              "Cadence PVS / Pegasus", "Ansys PathFinder (ESD)"]
    mcp_skill: "skill:drc_lvs_runner"

  - id: drc_oss
    options: ["KLayout DRC (OSS)", "Magic VLSI DRC (OSS, for skywater130)"]
    mcp_skill: "skill:drc_oss"

  # STA Sign-Off
  - id: sta_final
    options: ["Synopsys PrimeTime (AOCV/POCV)", "Cadence Tempus",
              "Synopsys PrimeTime SI (GBA + graph-based analysis)"]
    mcp_skill: "skill:sta_final_signoff"

  # GDSII Streaming
  - id: gds_tools
    options: ["Synopsys ICC2 stream out", "Cadence Innovus stream out",
              "KLayout (OSS, viewer + stream conversion)",
              "Klayout DRC for final check (OSS)"]
    mcp_skill: "skill:gds_generator"

  # SPICE Verification (critical path)
  - id: spice_check
    options: ["Synopsys HSPICE", "Cadence Spectre", "ngspice (OSS)",
              "Synopsys FineSim"]
    mcp_skill: "skill:spice_simulator"
```

### 11.6 Quality Gates — Sign-Off Criteria

| Check | Criterion | Agent | Human |
|-------|-----------|-------|-------|
| DRC | Zero violations or foundry-approved waivers (waiver log attached) | agent:physical_verif | DRC Eng |
| Fill DRC | Zero violations after dummy metal fill | agent:physical_verif | PD Lead |
| LVS | CLEAN — CDL vs. GDS exact match, no shorts/opens | agent:physical_verif | LVS Eng |
| Antenna | Zero violations (all metal layers) | agent:physical_verif | PD Lead |
| ERC | Zero electrical rule violations | agent:physical_verif | PD Lead |
| Metal density | All layers in foundry min/max density range | agent:physical_verif | PD Lead |
| CMP | No CMP hotspots per foundry CMP model | agent:physical_verif | PD Lead |
| Latch-up | CLEAN (Calibre LVS latch-up or sim-based) | agent:physical_verif | DRC Eng |
| ESD | CDM/HBM targets met; all I/O ESD clamps verified | agent:physical_verif | DRC Eng |
| Voltage-dep. DRC | Domain-specific rules checked per voltage island | agent:physical_verif | PD Lead |
| Setup timing | WNS ≥ 0 all corners/modes (MCMM + POCV/AOCV) | agent:sta | STA Eng |
| Hold timing | WHS ≥ 0 all corners/modes (incl. scan shift) | agent:sta | STA Eng |
| Max tran/cap | Zero violations | agent:sta | STA Eng |
| SI noise/glitch | Zero peak-noise violations | agent:sta | STA Eng |
| Static IR drop | < 5% VDD all supply domains | agent:power | Power Eng |
| Dynamic IR drop | < 10% VDD all modes (incl. scan shift) | agent:power | Power Eng |
| EM | Zero metal + via EM violations | agent:power | Power Eng |
| Thermal | Max cell junction temp within process spec | agent:power | Power Eng |
| LEC-4 | Final netlist equivalence: PASS | agent:formal | Verif Lead |
| Final GLS | Full regression RC-annotated, PA-GLS, X-prop: PASS | agent:verif_lead | Verif Lead |
| DFT boundary scan | BSCAN EXTEST/BYPASS/SAMPLE functional | agent:dft | DFT Lead |
| IP clearance | All 3rd party IP version-locked and licensed | agent:orch | PM + Legal |
| PDK deck version | Deck version matches foundry approved revision | agent:physical_verif | PD Lead |

---

## 12. Cross-Cutting: Iteration & Feedback Loops

### 12.1 Feedback Loop Map

```
                    ┌──────────────────────────────────────────────────┐
                    │              ITERATION FEEDBACK LOOPS            │
                    └──────────────────────────────────────────────────┘

SPEC ──────────────────────────────────────────────────────────────────────┐
  ▲   Spec ambiguity discovered                                            │
  │   at any stage → re-negotiate spec                                     │
  │                                                                        │
ALGO ─────────────────────────────────────────────────────────────────┐   │
  ▲   Algorithm fails to meet accuracy                                 │   │
  │   after fixed-point conversion                                     │   │
  │                                                                    │   │
ARCH ──────────────────────────────────────────────────────────────┐  │   │
  ▲   PPA estimates blow budget →                                   │  │   │
  │   revise partitioning, pipeline depth                           │  │   │
  │                                                                 │  │   │
RTL ───────────────────────────────────────────────────────────┐   │  │   │
  ▲   Bugs found in verification                                │   │  │   │
  │   Critical path too slow for synthesis                      │   │  │   │
  │                                                             │   │  │   │
VERIF ──────────────────────────────────────────────────────┐  │   │  │   │
  ▲   Coverage hole → need new tests                         │  │   │  │   │
  │   Bug → RTL fix needed                                   │  │   │  │   │
  │                                                          │  │   │  │   │
SYNTH ───────────────────────────────────────────────────┐  │  │   │  │   │
  ▲   Timing not met → RTL micro-opt                      │  │  │   │  │   │
  │   Area overflow → arch revisit                        │  │  │   │  │   │
  │                                                       │  │  │   │  │   │
PD ──────────────────────────────────────────────────┐   │  │  │   │  │   │
  ▲   Routing congestion → floorplan revisit         │   │  │  │   │  │   │
  │   Hold violation → synthesis fix                 │   │  │  │   │  │   │
  │   Timing violation → ECO                         │   │  │  │   │  │   │
  │                                                  │   │  │  │   │  │   │
SIGNOFF ────────────────────────────────────────────►LOOPS CLOSE HERE
```

### 12.2 Escalation Policy

```yaml
iteration_policy:
  per_stage_max_auto_iterations: 3
  after_max_iterations:
    action: ESCALATE_TO_HUMAN
    notify: [stage_lead, project_manager]

  cross_stage_rework:
    timing_violation_in_pd:
      threshold_slack: -200ps  # worse than this → RTL change needed
      action: ESCALATE → RTL_STAGE (targeted micro-arch change)

    coverage_hole_persistent:
      after_iterations: 5
      action: ESCALATE → human verif engineer (manual test writing)

    drc_violation_no_fix:
      after_iterations: 3
      action: ESCALATE → human DRC engineer (waiver evaluation)
```

---

## 13. Tool Registry

### 13.1 Open Source Tools

| Category | Tool | Purpose | Stage |
|----------|------|---------|-------|
| **HDL Simulation** | Verilator | Fast cycle-accurate RTL sim | RTL, Verif |
| **HDL Simulation** | Icarus Verilog | Verilog simulator | RTL, Verif |
| **HDL Simulation** | GHDL | VHDL simulator | RTL, Verif |
| **Cocotb** | cocotb | Python-based testbench framework | Verif |
| **Formal** | SymbiYosys / yosys-smtbmc | Formal property checking | Verif, RTL |
| **Formal** | EBMC | Bounded model checker | Verif |
| **Synthesis** | Yosys | Logic synthesis (with ABC) | Synth |
| **Full Flow** | OpenLane / OpenLane2 | Complete RTL→GDS flow | All PD |
| **P&R** | OpenROAD | Place and route | PD |
| **P&R** | TritonRoute | Detailed router | PD |
| **STA** | OpenSTA | Static timing analysis | Synth, PD |
| **Extraction** | OpenRCX | Parasitic RC extraction | PD |
| **DRC** | KLayout | Layout viewer + DRC scripting | Sign-off |
| **DRC/Layout** | Magic VLSI | Layout editor + DRC (skywater) | Sign-off |
| **SPICE** | ngspice | SPICE circuit simulation | Sign-off |
| **Memory** | OpenRAM | SRAM compiler (skywater/GF180) | Arch, PD |
| **IP Mgmt** | FuseSoC | IP core management | RTL |
| **Reg Gen** | PeakRDL | Register file/UVM RAL generator | Arch, RTL |
| **Reg Gen** | SystemRDL compiler | SystemRDL processing | Arch |
| **Algo** | fxpmath | Fixed-point Python library | Algo |
| **Algo** | FloPoCo | Floating-point/fixed-point cores | Algo |
| **Coverage** | verilator --coverage | Code coverage | Verif |
| **CI** | GitHub Actions / Jenkins | Regression automation | Verif, Synth |
| **PDN** | OpenROAD PDN generator | Power distribution network | PD |

### 13.2 Commercial Tools

| Category | Tool | Vendor | Stage |
|----------|------|--------|-------|
| **Simulation** | VCS + Verdi | Synopsys | RTL, Verif |
| **Simulation** | Xcelium + SimVision | Cadence | RTL, Verif |
| **Simulation** | QuestaSim | Mentor/Siemens | RTL, Verif |
| **Lint** | SpyGlass | Synopsys | RTL |
| **Lint** | Ascent Lint | Real Intent | RTL |
| **CDC** | SpyGlass CDC | Synopsys | RTL |
| **CDC** | Meridian CDC | Cadence | RTL |
| **Formal** | VC Formal | Synopsys | Verif |
| **Formal** | JasperGold | Cadence | Verif |
| **Formal** | Questa Formal | Mentor/Siemens | Verif |
| **Formal** | OneSpin 360 | OneSpin | Verif |
| **Emulation** | Palladium Z2 | Cadence | Verif |
| **Emulation** | ZeBu | Synopsys | Verif |
| **Synthesis** | Fusion Compiler | Synopsys | Synth |
| **Synthesis** | Genus | Cadence | Synth |
| **DFT** | DFT Compiler + TetraMAX | Synopsys | Synth |
| **DFT** | Tessent | Mentor/Siemens | Synth |
| **P&R** | IC Compiler II (ICC2) | Synopsys | PD |
| **P&R** | Innovus | Cadence | PD |
| **STA** | PrimeTime PX + SI | Synopsys | Synth, PD, Sign-off |
| **STA** | Tempus | Cadence | Synth, PD, Sign-off |
| **Extraction** | StarRC | Synopsys | Sign-off |
| **Extraction** | Quantus QRC | Cadence | Sign-off |
| **Extraction** | Calibre xRC | Mentor/Siemens | Sign-off |
| **DRC/LVS** | Calibre nmDRC/nmLVS | Mentor/Siemens | Sign-off |
| **DRC/LVS** | IC Validator | Synopsys | Sign-off |
| **DRC/LVS** | Pegasus/PVS | Cadence | Sign-off |
| **Power** | PrimePower | Synopsys | Synth, PD, Sign-off |
| **Power** | Voltus | Cadence | PD, Sign-off |
| **Power** | RedHawk-SC | Ansys | Sign-off |
| **ESD** | PathFinder | Ansys | Sign-off |
| **SPICE** | HSPICE | Synopsys | Sign-off |
| **SPICE** | Spectre | Cadence | Sign-off |
| **Arch Model** | Platform Architect | Synopsys | Arch |
| **Memory** | ARM/Synopsys Compilers | Various | Arch, PD |

---

## 14. MCP Server & Skill Placeholders

### 14.1 MCP Server Architecture

```yaml
# Model Context Protocol servers to be implemented
mcp_servers:

  - id: mcp:eda_tool_runner
    description: "Unified interface to EDA tool execution"
    tools_exposed:
      - run_lint(rtl_files, tool, config) → LintReport
      - run_synthesis(rtl_files, sdc, library, config) → SynthResult
      - run_sim(tb_top, sim_args, seed) → SimResult
      - run_sta(netlist, sdc, spef, corners) → TimingReport
      - run_drc(gds, rules) → DRCReport
      - run_lvs(gds, netlist, rules) → LVSReport
    auth: "tool_license_server + local_cluster"

  - id: mcp:artifact_store
    description: "Version-controlled design artifact storage"
    tools_exposed:
      - store_artifact(stage, name, file, metadata) → ArtifactID
      - retrieve_artifact(artifact_id) → File
      - list_artifacts(stage, filter) → ArtifactList
      - get_traceability(req_id) → ArtifactList
    backend: "Git LFS + database"

  - id: mcp:requirement_tracker
    description: "Spec requirement management"
    tools_exposed:
      - get_requirement(req_id) → Requirement
      - list_requirements(filter) → RequirementList
      - update_status(req_id, status, evidence) → void
      - check_coverage() → CoverageReport
    backend: "YAML/JSON database"

  - id: mcp:job_scheduler
    description: "EDA job submission to compute cluster"
    tools_exposed:
      - submit_job(job_spec) → JobID
      - get_job_status(job_id) → JobStatus
      - cancel_job(job_id) → void
      - get_job_output(job_id) → JobOutput
    backend: "LSF / SLURM / Kubernetes"

  - id: mcp:human_review_gateway
    description: "Interface for human expert review requests"
    tools_exposed:
      - request_review(stage, artifacts, checklist) → ReviewID
      - get_review_status(review_id) → ReviewStatus
      - submit_review_decision(review_id, decision, comments) → void
    backend: "JIRA / Confluence / custom workflow"

  - id: mcp:pdk_vault
    description: "PDK and IP library management"
    tools_exposed:
      - get_library(pdk_name, corner, type) → LibraryPath
      - validate_ip(ip_name, version) → ValidationReport
      - get_design_rules(pdk_name) → DesignRules
    backend: "Secure PDK storage"
```

### 14.2 Skills / Tool-Use Plugins

```yaml
skills:
  - skill:spec_parser        # NLP → structured requirements
  - skill:rtl_generator      # LLM-based RTL generation per block
  - skill:tb_generator       # UVM testbench scaffolding
  - skill:svf_writer         # SVA property generation
  - skill:sdc_generator      # Timing constraint generation
  - skill:report_analyzer    # Parse EDA tool reports → structured data
  - skill:bug_classifier     # Classify simulation failures
  - skill:coverage_analyzer  # Coverage gap analysis → new test suggestions
  - skill:eco_advisor        # Timing ECO recommendation
  - skill:drc_fixer          # Suggest layout fixes for DRC violations
  - skill:documentation_gen  # Generate design documents from artifacts
  - skill:regression_runner  # Orchestrate parallel simulation jobs
  - skill:ppa_estimator      # Back-of-envelope PPA at architecture stage
```

---

## 15. Human Expert Checkpoints

### 15.1 Mandatory Human Review Gates

The following are **blocking** human review gates. No agent may proceed past these without recorded human approval.

| Gate ID | Stage | Reviewers | Documents Required | Criteria |
|---------|----|-----------|-------------|---------|
| **GATE-01** | Spec Baseline | PM, Arch Lead | PRD, requirements.yaml | All must-have REQs approved |
| **GATE-02** | Algo Baseline | Algo Lead, DSP Engineer | accuracy_report, golden ref | Fixed-point accuracy within spec |
| **GATE-03** | Architecture Review | Arch Lead, RTL Lead, DFT Lead, PD Lead | microarch_spec, block_diagram | ARB sign-off |
| **GATE-04** | RTL Code Review | RTL Lead | RTL files, lint reports | Zero lint errors, code review pass |
| **GATE-05** | Verification Closure | Verif Lead | Coverage reports, bug list | Coverage goals met, zero P1/P2 bugs |
| **GATE-06** | Synthesis Review | Synth Eng, STA Eng | QoR report, DFT report | Timing met, DFT coverage spec |
| **GATE-07** | PD Review | PD Lead | Routed DB, timing/power reports | All PD quality gates met |
| **GATE-08** | Tape-out Review | ALL leads + PM + Legal | Full sign-off package | ALL sign-off checks clean |

### 15.2 Human Expert Input Points (Non-Blocking)

Beyond mandatory gates, humans can inject feedback at any time:

- **Spec clarification queries**: Agent asks human for requirement disambiguation
- **Architecture trade-off discussion**: Agent presents options, human decides
- **Waiver approval**: Human approves DRC/LVS/coverage waivers with rationale
- **ECO approval**: Human approves physical ECOs before implementation
- **Schedule decisions**: Human makes tape-out go/no-go under schedule pressure
- **Risk acceptance**: Human accepts known risks and documents them

### 15.3 Human Override Protocol

```yaml
human_override:
  mechanism: "Orchestrator exposes override API"
  override_types:
    - SKIP_QUALITY_GATE: requires dual approval (lead + PM)
    - ACCEPT_WITH_WAIVER: requires lead approval + written rationale
    - ROLLBACK_TO_STAGE: requires PM approval
    - FORCE_PROCEED: emergency use, auto-creates risk ticket
  audit: "All overrides logged with timestamp, actor, rationale"
```

---

## 16. Quality Gates & Automated Checks

### 16.1 Automated Check Registry

```yaml
automated_checks:

  stage: RTL_DESIGN
  checks:
    - id: lint_error_count
      tool: spyglass_or_verilator
      threshold: "errors == 0"
      blocking: true
    - id: cdc_error_count
      tool: spyglass_cdc
      threshold: "errors == 0, warnings reviewed"
      blocking: true
    - id: rdc_error_count
      tool: meridian_rdc
      threshold: "errors == 0"
      blocking: true
    - id: rtl_compile_check
      tool: [vcs, xcelium, verilator]
      threshold: "compile success on all tools"
      blocking: true

  stage: VERIFICATION
  checks:
    - id: functional_coverage
      tool: simulator_coverage
      threshold: "≥ 100% VPlan items"
      blocking: true
    - id: code_coverage_stmt
      tool: simulator_coverage
      threshold: "≥ 95%"
      blocking: true
    - id: toggle_coverage
      tool: simulator_coverage
      threshold: "≥ 95%"
      blocking: false  # waivable
    - id: regression_pass_rate
      tool: regression_runner
      threshold: "100% pass"
      blocking: true
    - id: open_p1_bugs
      tool: bug_tracker
      threshold: "== 0"
      blocking: true
    - id: open_p2_bugs
      tool: bug_tracker
      threshold: "== 0"
      blocking: true

  stage: SYNTHESIS
  checks:
    - id: timing_wns
      tool: primetime_or_tempus
      threshold: "≥ 0 ps all corners"
      blocking: true
    - id: timing_tns
      tool: primetime_or_tempus
      threshold: "== 0 all corners"
      blocking: true
    - id: area_budget
      tool: dc_or_genus
      threshold: "≤ spec_area * 1.10"
      blocking: false
    - id: power_budget
      tool: primetime_px
      threshold: "≤ spec_power * 1.15"
      blocking: false
    - id: dft_coverage_stuck_at
      tool: tetramax_or_tessent
      threshold: "≥ 95%"
      blocking: true
    - id: unmapped_cells
      tool: synthesis_tool
      threshold: "== 0"
      blocking: true

  stage: SIGNOFF
  checks:
    - id: drc_violations
      tool: calibre_or_icv
      threshold: "== 0 (or approved waivers)"
      blocking: true
    - id: lvs_status
      tool: calibre_or_pvs
      threshold: "CLEAN"
      blocking: true
    - id: antenna_violations
      tool: calibre_antenna
      threshold: "== 0"
      blocking: true
    - id: setup_wns_signoff
      tool: primetime_si
      threshold: "≥ 0 all PVT corners"
      blocking: true
    - id: hold_whs_signoff
      tool: primetime_si
      threshold: "≥ 0 all PVT corners"
      blocking: true
    - id: static_ir_drop
      tool: redhawk_or_voltus
      threshold: "≤ 5% VDD"
      blocking: true
    - id: em_violations
      tool: redhawk_or_voltus
      threshold: "== 0"
      blocking: true
```

---

## 17. Data Model & Artifact Tracking

### 17.1 Core Data Structures

```python
# Requirement object
@dataclass
class Requirement:
    id: str                    # "REQ-001"
    category: str              # functional|performance|interface|power|area
    priority: str              # MUST|SHOULD|NICE
    description: str
    acceptance_criteria: str   # testable condition
    status: str                # OPEN|IN_PROGRESS|VERIFIED|WAIVED
    evidence: List[ArtifactRef]

# Artifact object
@dataclass
class Artifact:
    id: str                    # uuid
    stage: str                 # SPEC|ALGO|ARCH|RTL|VERIF|SYNTH|PD|SIGNOFF
    name: str
    path: str                  # git path or storage path
    format: str                # SV|GDS|YAML|PDF|...
    git_sha: str
    created_by: str            # agent_id or human_id
    req_ids: List[str]         # traceability
    quality_gate_results: Dict

# Stage handoff object
@dataclass
class StageHandoff:
    from_stage: str
    to_stage: str
    artifacts: List[ArtifactRef]
    quality_gate_results: Dict[str, QualityGateResult]
    human_approvals: List[HumanApproval]
    iteration: int
    timestamp: str
```

### 17.2 Traceability Matrix (Auto-Maintained)

Every artifact carries `req_ids[]`. The orchestrator maintains a live matrix:

```
REQ-001 (performance: 1GHz throughput)
  → algo/fixed_model.cpp (verified: throughput = 1.05GHz)
  → arch/microarch_spec.md §3.2 (pipeline depth=5 for 1GHz)
  → rtl/core/pipeline_stage*.sv (implementation)
  → verif/tests/throughput_test.sv (test)
  → synth/reports/timing_report.rpt (timing met at 1.1GHz)
  → pd/sta/setup_report.rpt (1.02GHz post-route)
  → STATUS: VERIFIED ✓
```

---

## 18. Risk Matrix & Mitigation

| Risk | Prob | Impact | Mitigation |
|------|------|--------|------------|
| LLM hallucination in RTL code | HIGH | HIGH | Mandatory lint + sim + human code review before any gate |
| LLM generating incorrect SDC constraints | HIGH | HIGH | SDC completeness check; false-path rationale required; STA human review |
| Timing closure miss in PD | MEDIUM | HIGH | 20% synthesis margin at ≤16nm; MCMM from synthesis; PD margin budget |
| POCV/AOCV not applied → false timing clean | MEDIUM | CRITICAL | POCV/AOCV mandatory from synthesis onward; blocking STA gate |
| CDC waiver incorrectly granted | MEDIUM | CRITICAL | Formal CDC proof for all waived warnings; waiver log requires dual approval |
| Coverage hole causing silicon bug | MEDIUM | CRITICAL | Formal verification + 500+ seeds + FSM/cross-coverage + assertion gates |
| UPF power state bug not caught | MEDIUM | HIGH | PA-GLS + formal low-power verification mandatory for multi-domain designs |
| DFT-induced hold violations | HIGH | HIGH | Scan stitch timing check immediately post-DFT; LEC-2 before proceeding |
| Incorrect P/G connection in hard IP macro | LOW | CRITICAL | agent:pdk validates all hard IP LIB/LEF/GDS against foundry release manifest |
| PDK/foundry rule change post-RTL | LOW | HIGH | PDK version lock in pdk_deck_versions.yaml; change-control process |
| IP integration defects | MEDIUM | HIGH | Standalone IP wrapper verification + protocol VIP compliance |
| Algorithm accuracy loss in fixed-point | MEDIUM | HIGH | SQNR analysis; golden ref C++ comparison; test vectors at corners |
| Schedule pressure → gate skip | HIGH | CRITICAL | Dual-approval required; auto-creates risk ticket; logged permanently |
| Tool version incompatibility | LOW | MEDIUM | Tool version locking in CI config; version pinned in artifact metadata |
| DRC miss before tape-out | LOW | CRITICAL | Hierarchical DRC throughout PD; final DRC on merged GDSII |
| Foundry shuttle slot missed | MEDIUM | HIGH | Schedule buffer at GATE-07 and GATE-08; early foundry engagement |
| Thermal failure at high power density | LOW | HIGH | Thermal analysis in post-route optimization; flagged if power density > 0.5 W/mm² |
| Power budget overflow | MEDIUM | HIGH | RTL-level power analysis (Ansys PowerArtist) at synthesis; SAIF-annotated PPA |

---

## 19. Known Gaps & Open Issues

> **Living record of framework deficiencies.** v2.0 addressed all 7 Critical and most Important issues from the expert gap review. Remaining items are listed below.

### 19.0 Resolved in v2.0 (formerly Critical/Important)

| ID | Resolution |
|----|-----------|
| CRIT-01 | DFT coverage targets corrected: stuck-at ≥99%, transition ≥97%, path-delay ≥90%, CAT ≥98%; scan compression, OCC, IDDQ, bridging faults added |
| CRIT-02 | POCV/AOCV + MCMM promoted to mandatory blocking gates at synthesis and sign-off; max-tran/cap checks added; SI at synthesis |
| CRIT-03 | GLS now 4 modes (max-SDF, min-SDF, X-opt, X-pess) + PA-GLS; full regression required |
| CRIT-04 | UPF simulation added to Stage 5 as blocking gate; formal LP verification added; AO net check referenced |
| CRIT-05 | Tap cells, filler, well ties, metal fill, via redundancy, post-fill DRC all added to PD flow |
| CRIT-06 | ESD, latch-up, CMP, hierarchical DRC, fill DRC, voltage-dependent DRC, PDK deck versioning all added to sign-off |
| CRIT-07 | LEC-1 through LEC-4 explicitly defined; LEC-2 (post-DFT) added as blocking gate; post-ECO LEC-3 per ECO |
| IMP-01 | DFT updated: OCC, scan compression, boundary scan verification, cell-aware ATPG, IDDQ, test time estimation all added |
| IMP-02 | PA-GLS, UPF sim, FSM coverage, cross-coverage, assertion gate, SVA pass gate, SAIF capture, 500-seed minimum all added |
| IMP-03 | SI/noise gate, dynamic IR drop for scan shift, thermal analysis, via redundancy all added to PD |
| IMP-04 | MCMM synthesis, retiming, clock gating coverage, scan stitch timing, LEC-2 post-DFT, synthesis margin revised |
| IMP-05 | SDC completeness check, false-path rationale requirement, generated clocks requirement all added |
| ENH-01 | Safety/security/reliability requirement categories added to Stage 1 |
| ENH-02 | RTL coding conventions expanded to 16 rules including initial-block ban, default-case, CE policy, naming |
| ENH-03 | Coverage model expanded: FSM state/transition/arc, assertion firing, cross-coverage, per-instance |
| ENH-08 | Risk matrix expanded: POCV, CDC waiver, DFT hold, P/G hard IP, thermal, shuttle miss |

### 19.1 Critical Gaps (Must Fix)

- [ ] **GAP-001**: No formal mechanism for multi-foundry PDK support — currently assumes single PDK; need PDK abstraction layer in `mcp:pdk_vault`
- [x] **GAP-002**: ~~`agent:upf` not fully specified~~ — **RESOLVED in v3.0.** Full specification in `GAP-002_UPF_Agent_Spec.md`: 4-stage verification (A: lint, B: PA-sim, C: formal LP 12 properties, D: post-synth/PD checks), 27 quality gates, 5 common-mistake detection classes, tool registry, retention sequence generation, PST construction automation.
- [ ] **GAP-003**: DFT agent lacks IJTAG (IEEE 1687) and embedded instrument support — critical for advanced multi-die and chiplet test architectures
- [x] **GAP-004**: ~~Mixed-signal / analog blocks not addressed~~ — **RESOLVED in v3.0.** Full `agent:ams` specification embedded in the document (Sections GAP-004.1–GAP-004.10): hard/soft/custom IP strategy, PVT corner matrix, SPICE sign-off, AMS co-simulation (5 tool options), RNM/wreal interface, Monte Carlo requirements, 2 new gates GATE-04A + GATE-07A, per-IP sign-off checklists, 12 new risk entries.
- [ ] **GAP-005**: Post-silicon validation covered at a high level in Stage 9 below but not deeply specified — ATE pattern conversion, fault diagnosis, frequency characterization (VF curve), and production test program are placeholder-level only
- [ ] **GAP-006**: EM/IR-driven ECO loop — when static/dynamic IR fails, the corrective agent behavior (add power straps, resize buffers, insert decap) needs explicit scripted procedures per power tool
- [ ] **GAP-007**: CDC formal proof coverage criteria not specified — what constitutes "formal CDC convergence" (full proof vs. k-step bounded) and under what conditions are structural-only checks acceptable needs a written policy
- [ ] **GAP-008**: LLM context window for large RTL blocks — hierarchical chunking strategy for multi-thousand-line modules not defined; `agent:rtl` chunking protocol and context handoff need design

### 19.2 Important Improvements

- [ ] **GAP-009**: Hardware emulation agent not fully defined — for designs >10M gates, emulation (Palladium Z2, ZeBu) is mandatory before tape-out; agent orchestration for compile → emulation → results needs design
- [ ] **GAP-010**: ~~Low-power verification~~ — **RESOLVED in v2.0** (PA-GLS + formal LP added to Stage 5)
- [ ] **GAP-011**: ~~MCMM synthesis~~ — **RESOLVED in v2.0** (MCMM added to Stage 6 synthesis flow)
- [ ] **GAP-012**: ~~POCV/AOCV~~ — **RESOLVED in v2.0** (promoted to Critical, added as mandatory blocking gate)
- [x] **GAP-013**: ~~Hierarchical design flow not addressed~~ — **RESOLVED in v3.0.** Full extension in `GAP-013_Hierarchical_SoC_Flow.md`: 5M/20M/100M gate thresholds, 7 block granularity criteria, ILM/ETM selection rules, HGATE-00 through HGATE-07, timing budget top-down/bottom-up allocation, block-level GDS sign-off, CDL merge strategy, change-control Type A/B/C classification, wave scheduling orchestrator, 8 new risk entries.
- [ ] **GAP-014**: IP re-characterization agent not defined — `agent:pdk` validates versions but does not run re-characterization flows for foundry hard IP at process splits; need `skill:ip_recharacterizer`
- [x] **GAP-015**: ~~Reliability / aging analysis not included~~ — **RESOLVED in v3.0.** Full specification in `GAP-015_Reliability_Aging_Analysis.md`: agent:reliability role (activates Stages 3+8), NBTI Reaction-Diffusion model + timing derating, HCI Takeda model, TDDB E/1/E/power-law models, EM Black's equation with thermal feedback, EOS, AEC-Q100 grades 0–3 table, JEDEC standard mapping, 27-item sign-off checklist, process-node × application guardband table, full tool registry with mcp_skill identifiers.
- [ ] **GAP-016**: DRC/LVS waiver formal workflow — waiver request → DRC engineer review → PD Lead approval → PM acknowledgment → documentation in waiver_log.md needs explicit `mcp:human_review_gateway` ticket type definition
- [ ] **GAP-017**: Agent conflict resolution protocol not defined — when `agent:fp` and `agent:pnr` have conflicting macro placement recommendations, the structured arbitration protocol via orchestrator is incomplete
- [ ] **GAP-018**: Agent state persistence not defined — if a synthesis job crashes mid-run, checkpoint-restart protocol for EDA tool invocations needs design in `mcp:job_scheduler`

### 19.3 Nice-to-Have Enhancements

- [ ] **GAP-N01**: Automated RTL micro-architecture optimization loop (ML-guided pipeline depth / area trade-offs)
- [ ] **GAP-N02**: AI-driven congestion prediction at floorplan stage before running P&R
- [ ] **GAP-N03**: Natural language query interface for human experts to interrogate live design state
- [ ] **GAP-N04**: Integration with PDM/PLM systems for BOM and IP licensing management
- [ ] **GAP-N05**: Package/substrate co-design agent for advanced packaging (chiplets, 2.5D/3D stacking)
- [ ] **GAP-N06**: Post-silicon characterization feedback loop — silicon VF curves feed back into architecture/RTL timing budgets
- [ ] **GAP-N07**: Mutation testing (e.g., Synopsys Certitude) to verify testbench quality — detects dead testbench code that cannot catch injected bugs
- [ ] **GAP-N08**: ATE format conversion agent — STIL → Advantest/Teradyne format conversion for production test (currently in Stage 9 as placeholder)

### 19.4 Framework Confidence Assessment (v3.0)

| Domain | v1.0 | v2.0 | v3.0 | Key v3.0 Changes |
|--------|------|------|------|-----------------|
| Specification | HIGH | HIGH | HIGH | + AEC-Q100/JEDEC req. category, reliability REQ traceability |
| Algorithm development | HIGH | HIGH | HIGH | Unchanged |
| Architecture design | MEDIUM-HIGH | MEDIUM-HIGH | HIGH | + Hierarchical block partitioning, ILM strategy, timing budget allocation |
| RTL design | MEDIUM | MEDIUM | MEDIUM | LLM quality still evolving; conventions improved |
| Functional verification | MEDIUM-HIGH | HIGH | HIGH | Unchanged from v2.0 |
| Logic synthesis | HIGH | HIGH | HIGH | Unchanged from v2.0 |
| Low-power / UPF | ABSENT | PARTIAL | HIGH | Full agent:upf spec: 4-stage verification, 27 QGs, formal LP proofs |
| Physical design (flat) | MEDIUM | MEDIUM-HIGH | HIGH | Unchanged from v2.0 |
| Physical design (hier.) | ABSENT | ABSENT | HIGH | Full hierarchical flow: 8 HGATEs, ILM/ETM, block sign-off strategy |
| Mixed-signal / AMS | ABSENT | ABSENT | MEDIUM-HIGH | agent:ams spec: 10 sections, 2 new gates (GATE-04A, GATE-07A) |
| Sign-off | MEDIUM-HIGH | HIGH | HIGH | + Reliability sign-off, AEC-Q100 checklist |
| Reliability / aging | ABSENT | ABSENT | HIGH | Full agent:reliability: NBTI/HCI/TDDB/EM/EOS, JEDEC/AEC-Q100 |
| Post-silicon | ABSENT | LOW | LOW-MEDIUM | Stage 9 placeholder; ATE conversion noted |
| **Overall** | **MEDIUM** | **MEDIUM-HIGH** | **HIGH** | **All 4 remaining blockers resolved; automotive-grade feasible** |

**v3.0 status:** The framework is now sufficiently specified for commercial-grade ASIC design across digital, hierarchical-SoC, low-power multi-domain, analog-integrated, and automotive-reliability targets. Remaining open items (GAP-N01 through GAP-N08 and GAP-017/018) are enhancements, not blockers for a first tape-out.

### 19.5 Companion Specification Documents

The following companion files provide full technical depth for the four major gap fills resolved in v3.0:

| Document | Gap Closed | Description |
|----------|-----------|-------------|
| `GAP-002_UPF_Agent_Spec.md` | GAP-002 | Full agent:upf specification: UPF generation, 4-stage LP verification (A–D), 27 quality gates, 5 common-mistake detection classes |
| `GAP-004_spec_in_main_doc` | GAP-004 | agent:ams specification embedded in Sections GAP-004.1 through GAP-004.10 above |
| `GAP-013_Hierarchical_SoC_Flow.md` | GAP-013 | Full hierarchical SoC extension: 8 HGATEs, ILM/ETM strategy, timing budget allocation, block sign-off, CDL merge, 8 hierarchical risk entries |
| `GAP-015_Reliability_Aging_Analysis.md` | GAP-015 | Full agent:reliability specification: NBTI/HCI/TDDB/EM/EOS analysis, JEDEC/AEC-Q100 mapping, 27-item sign-off checklist, process-node-specific guardbands |

---

## Appendix A: Quick-Start Agent Invocation Examples

```python
# Example: Dispatch RTL generation for a module
orchestrator.dispatch(
    agent="agent:rtl[0]",
    task="generate_rtl",
    inputs={
        "block_spec": "arch/microarch_spec.md#section-alu",
        "interface_spec": "arch/interface_spec.yaml#alu",
        "wordlengths": "algo/wordlengths.yaml#alu",
        "coding_style": "rtl/coding_conventions.md",
        "target_module": "rtl/core/alu.sv"
    },
    quality_gates=["lint", "cdc", "compile"],
    human_review_gate="GATE-04",
    max_iterations=3
)

# Example: Trigger synthesis
orchestrator.dispatch(
    agent="agent:synth",
    task="run_synthesis",
    inputs={
        "rtl_files": "git:sha/rtl/**/*.sv",
        "constraints": "rtl/constraints/top.sdc",
        "upf": "arch/power_intent.upf",
        "pdk_library": "mcp:pdk_vault/tsmc16ffc/tt_0p8v_25c.db",
        "target_freq_mhz": 1000,
        "target_area_um2": 500000
    },
    quality_gates=["timing_wns", "area_budget", "dft_coverage"],
    human_review_gate="GATE-06",
    max_iterations=5
)
```

---

## Appendix B: Recommended Process Node Progression

| Node | Foundry Options | Recommended Flow | Notes |
|------|----------------|-----------------|-------|
| 180nm – 130nm | TSMC, GlobalFoundries, SMIC | OpenLane (OSS) viable | Good for learning/research |
| 28nm – 22nm | TSMC, Samsung, GF | Commercial tools required | Standard cell + FinFET transition |
| 16nm – 12nm | TSMC (16FFC/12FFC) | Full commercial PD stack | FinFET, complex DRC |
| 7nm – 5nm | TSMC, Samsung | Full commercial, EUV-aware | Multi-patterning, complex SI |
| 3nm+ | TSMC N3, Samsung GAA | Nanosheet GAA, advanced | Leading edge, foundry engagement critical |

---

---

## 20. Post-Silicon Validation — Stage 9

> **Status:** Framework-level placeholder. Requires detailed design before commercial readiness for production designs.

### 20.1 Goal
Validate that fabricated silicon matches pre-silicon simulation predictions, characterize performance, and qualify the device for production.

### 20.2 Agents Involved
- **Primary**: `agent:silicon_validation` (placeholder — to be designed)
- **Support**: `agent:dft` (scan-based debug), `agent:sta` (correlation), `agent:verif_lead` (stimulus correlation)
- **Human Roles**: Silicon Validation Engineer, Lab Technician, ATE Engineer, Production Test Engineer

### 20.3 Sub-Stages

| Sub-Stage | Key Activities | Tools (Placeholder) |
|-----------|---------------|---------------------|
| **First Power-On** | Checklist: JTAG alive, supply rails correct, clock measurement | Lab: oscilloscope, power analyzer, JTAG probe |
| **JTAG Bring-Up** | Boundary scan EXTEST, BYPASS, IDCODE verification | Synopsys HAPS, Cadence Palladium board, JTAG debugger |
| **Functional Bring-Up** | Run directed tests from simulation on ATE | Teradyne UltraFlex, Advantest V93000 |
| **ATE Pattern Conversion** | STIL → ATE format conversion for each fault model | Synopsys TetraMAX ATE bridge, Siemens Tessent |
| **Frequency Characterization** | VF curve (voltage vs. max frequency) per die | ATE with parametric sweep |
| **Power Characterization** | Measure active/leakage vs. spec | ATE + power supply measurement |
| **Pre-silicon Correlation** | Compare ATE results vs. simulation predictions | Custom scripts; coverage gap analysis |
| **Fault Diagnosis** | Scan-based diagnosis on failing dies | Synopsys TetraMAX diagnosis, Siemens Tessent Diagnosis |
| **Wafer Acceptance Test (WAT)** | Foundry-provided WAT correlation | Foundry WAT data + internal analysis |
| **Qualification** | AEC-Q100 / JEDEC stress tests (if applicable) | External qualification lab |
| **Production Test Program** | Final ATE program, binning strategy, test time optimization | ATE vendor tools |

### 20.4 Key Artifacts

```
post_silicon/
├── bringup/
│   ├── first_power_on_checklist.md
│   └── jtag_bringup_log.md
├── characterization/
│   ├── vf_curve.csv
│   └── power_vs_mode.csv
├── ate/
│   ├── production_test_program/  ← ATE-format patterns
│   └── binning_spec.md
├── correlation/
│   └── sim_vs_silicon_report.md
└── qualification/
    └── aec_q100_report.md        ← if automotive-grade
```

### 20.5 Human Expert Checkpoints

| Gate | Trigger | Required Approvals |
|------|---------|--------------------|
| GATE-09a | First power-on | Silicon Validation Lead + HW Engineer |
| GATE-09b | Functional bring-up complete | Verif Lead + Silicon Validation Lead |
| GATE-09c | Characterization complete | PM + Architecture Lead (VF/power vs. spec) |
| GATE-09d | Production test program frozen | DFT Lead + ATE Engineer + PM |

---

## Appendix C: Tool Registry Corrections & Additions (v2.0)

The following supersede entries in Section 13 where vendor names or tool names changed:

| Old Name | Current Name | Note |
|---------|-------------|------|
| Mentor QuestaSim | Siemens EDA Questa One (QuestaSim) | Siemens acquired Mentor 2021 |
| Mentor ModelSim | Siemens EDA ModelSim | Same product, new branding |
| Mentor Calibre | Siemens EDA Calibre | Unchanged product, new parent |
| Mentor Tessent | Siemens EDA Tessent | Same |
| Mentor Nitro-SoC | Siemens EDA Nitro-SoC | Same |
| Cadence Encounter Test | Cadence Modus Test Solution | Encounter Test EOL'd |
| Synopsys DVE | Synopsys Verdi | DVE deprecated; Verdi is primary debug env |

**Additional tools to add to registry:**

| Category | Tool | Vendor | Stage |
|----------|------|--------|-------|
| Testbench Quality | Certitude | Synopsys | Verif |
| Coverage Mgmt | vManager | Cadence | Verif |
| RTL Power Analysis | PowerArtist | Ansys | Synth |
| RTL Power Analysis | Joules RTL Power Solution | Cadence | Synth |
| Formal LEC | Formality Ultra | Synopsys | All LEC |
| Formal LEC | Conformal LEC | Cadence | All LEC |
| Aging / Reliability | MOSRA | Synopsys | Sign-off |
| Aging / Reliability | Spectre APS | Cadence | Sign-off |
| ESD Device-level | Totem | Ansys | Sign-off |
| CMP Analysis | CMP Model (foundry-provided) | TSMC/GF | Sign-off |
| SPICE Fast | FineSim | Synopsys | Sign-off |
| Debug Platform | Verdi | Synopsys | RTL, Verif |
| ATE Interface | TetraMAX ATE Bridge | Synopsys | Post-Si |
| ATE | UltraFlex | Teradyne | Post-Si |
| ATE | V93000 | Advantest | Post-Si |

---

## GAP-004 Fix: agent:ams — Mixed-Signal and Analog Co-Design Agent Specification

> **Status:** Normative specification. Resolves GAP-004 from Section 19.1.
> **Scope:** Applies to any ASIC design that integrates one or more analog or mixed-signal (AMS) IP blocks including PLLs, ADC/DAC converters, SerDes PHYs, bandgap references, LDOs, and analog I/O pads.
> **Prerequisite reading:** Section 2 (Agent Team Organization), Section 6 (Architecture Design), Section 7 (RTL Design), Section 11 (Sign-Off), Section 13 (Tool Registry).

---

### GAP-004.1  agent:ams — Full Role Definition

#### GAP-004.1.1  Agent Identity

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ROLE                      │  AGENT ID   │  Primary Responsibility          │
├─────────────────────────────────────────────────────────────────────────────┤
│  AMS / Mixed-Signal Lead   │  agent:ams  │  Analog IP integration,          │
│                            │             │  AMS co-simulation, analog        │
│                            │             │  sign-off, digital wrapper RTL    │
│                            │             │  specification, vendor IP qual     │
└─────────────────────────────────────────────────────────────────────────────┘
```

`agent:ams` is a **specialist agent** inserted into the orchestrator's state machine immediately after architecture freeze (GATE-03) and runs a parallel AMS track alongside the digital RTL/Verification track. Its outputs (hard IP GDS, behavioral models, digital wrapper RTL, and analog sign-off reports) are mandatory inputs to physical design and tape-out.

**Human counterpart:** A dedicated human AMS engineer or mixed-signal design lead is mandatory. No analog sign-off check may be automated to the point of removing human review. See Section GAP-004.6 for human review requirements.

#### GAP-004.1.2  Responsibilities by IP Category

| IP Block | Responsibilities of agent:ams |
|---|---|
| **PLL / DLL** | Spec compliance (jitter, lock time, output frequency range, VCO gain), corner simulation, phase noise simulation, supply noise sensitivity (PSRR), behavioral model delivery, GDS integration coordination |
| **ADC** | ENOB / SNDR / SFDR / INL / DNL spec verification across PVT corners, Monte Carlo mismatch analysis, noise budget (thermal + flicker), reference chain validation (bandgap → reference buffer → ADC), CDL/LVS sign-off |
| **DAC** | INL/DNL, settling time, output impedance, SNR specification and simulation verification, glitch energy characterization |
| **SerDes PHY** | TX/RX equalization spec, BER estimation at target bit rate, eye diagram sign-off, PLL jitter budget (contribution to SerDes), pad ESD compliance, IBIS model generation or validation |
| **Bandgap Reference** | Curvature-corrected PTAT accuracy across –40 °C to +125 °C, PSRR, startup circuit verification, Monte Carlo reference voltage spread |
| **LDO / Linear Regulator** | Line/load regulation, PSRR at target frequencies, transient response (undershoot/overshoot), stability under all capacitive load corners, noise referred to output |
| **Analog I/O Pads** | ESD compliance (HBM/CDM), latch-up immunity, slew rate, drive strength, I/O voltage domain compatibility, on-pad ESD clamp simulation |
| **Crystal Oscillator Interface** | Loop gain margin, startup time, frequency stability (temperature coefficient, aging) |
| **Temperature Sensor** | Accuracy across process + temperature, calibration strategy, digital trim interface |

#### GAP-004.1.3  Inter-Agent Interfaces

```
agent:arch
    │  Receives: AMS IP requirements (jitter budget, noise budget, power budget per IP,
    │            analog supply domains, pad count allocation)
    │  Returns:  AMS architecture recommendation, IP selection (hard vs. custom),
    │            analog power domain boundaries, pad ring topology
    ▼
agent:ams
    │
    ├──► agent:pdk
    │        Receives: PDK name, process node, foundry
    │        Requests: Foundry-qualified SPICE models (spectre/BSIM/BSIM-CMG),
    │                  process corner files (TT/SS/FF/SF/FS),
    │                  device parameter files (mismatch sigma tables for Monte Carlo),
    │                  hard IP LIB / LEF / GDS / CDL (vendor-qualified),
    │                  IO pad library (ESD cell, pad frame rules)
    │
    ├──► agent:rtl
    │        Delivers: Digital wrapper RTL specification (port list, interface protocol,
    │                  register map for trim/config, test mode control signals)
    │        Requests: Lint-clean synthesizable wrapper SV file in return
    │
    ├──► agent:verif_lead
    │        Delivers: Behavioral models (VAMS / SystemC-AMS / Verilog-real),
    │                  AMS co-simulation testbench connect modules,
    │                  analog stimulus vectors, analog pass/fail criteria
    │        Requests: AMS regression results, functional coverage of digital
    │                  interface paths to analog blocks
    │
    ├──► agent:physical_verif
    │        Delivers: Analog block CDL netlist, LVS runset exceptions (ESD device
    │                  exemptions, floating-gate devices, intentional DRC waivers),
    │                  known antenna exceptions for long analog routing
    │        Requests: LVS CLEAN sign-off per analog block, DRC clean sign-off
    │
    └──► agent:fp (Physical Design — Floorplan)
             Delivers: Analog IP placement constraints (keep-out zones, orientation,
                       guard ring requirements, substrate noise isolation rules,
                       analog supply routing requirements, pad ring location)
             Requests: Confirmation that analog macros are placed per constraints
```

#### GAP-004.1.4  Hard IP Vendor Qualification Workflow

When an analog IP block is sourced from a third-party vendor (ARM, Synopsys DesignWare, Silicon Creations, IPDC, etc.) or from the foundry itself (foundry-provided PLL, IO pad library):

```
VENDOR IP INTAKE
      │
      ▼
┌─────────────────────────────┐
│  agent:ams + agent:pdk      │  Step 1: Manifest check
│  INTAKE CHECKLIST           │  Verify all deliverables received:
│                             │    □ Datasheet (performance spec per corner)
│                             │    □ SPICE / CDL netlist (schematic-level)
│                             │    □ Liberty (.lib) timing models (all corners)
│                             │    □ LEF abstract (obstruction, pin locations)
│                             │    □ GDSII (layer-mapped to target PDK)
│                             │    □ LVS runset and exceptions file
│                             │    □ DRC waiver log (vendor-approved waivers)
│                             │    □ Spectre simulation testbench + results
│                             │    □ IBIS model (if I/O pad or SerDes)
│                             │    □ UPF / power intent (if internally power-gated)
└─────────────┬───────────────┘
              │
              ▼
┌─────────────────────────────┐
│  FUNCTIONAL VERIFICATION    │  Step 2: Re-simulate key corners
│  (agent:ams re-runs sims)   │  Re-run vendor testbench at:
│                             │    - TT / 1.0V / 25 °C  (nominal)
│                             │    - SS / 0.9V / 125 °C (worst-case speed + temp)
│                             │    - FF / 1.1V / –40 °C (best-case, hold stress)
│                             │    - SS / 0.9V / –40 °C (worst-case cold)
│                             │  Confirm results match vendor datasheet ±5%
└─────────────┬───────────────┘
              │
              ▼
┌─────────────────────────────┐
│  GDS / LVS INTEGRITY CHECK  │  Step 3: Physical integrity
│  (agent:ams + agent:pdk)    │  - Run LVS: vendor CDL vs. vendor GDS
│                             │  - Run DRC with foundry deck (record waivers)
│                             │  - Layer map verification (PDK layer table)
│                             │  - P/G pin connectivity spot-check
│                             │  - LEF vs. GDS boundary match check
└─────────────┬───────────────┘
              │
              ▼
┌─────────────────────────────┐
│  IP QUALIFICATION REPORT    │  Step 4: Document and lock
│  (agent:ams authors,        │  - ip_qual_report_<ipname>_v<x>.md
│   human AMS Eng approves)   │  - Version-locked in mcp:pdk_vault
│                             │  - Added to ip_manifest.yaml
│                             │  - Any deviations escalated to human AMS Eng
└─────────────────────────────┘
```

---

### GAP-004.2  Analog/AMS Design Sub-Flow

#### GAP-004.2.1  IP Integration Strategy Decision

At architecture stage (GATE-03), `agent:ams` and `agent:arch` jointly classify each analog block:

| Integration Strategy | Definition | When Used | agent:ams Role |
|---|---|---|---|
| **Hard IP (foundry / vendor GDS)** | Pre-characterized, layout-complete IP delivered as locked GDS + CDL | PLL, IO pads, SerDes PHY for production schedules | Qualify, integrate, write digital wrapper spec |
| **Hard IP (custom, in-house)** | Full custom transistor-level design completed by human AMS team | Bandgap, LDO, precision ADC requiring custom tuning | Support simulation environment; coordinate GDS handoff |
| **Soft IP (synthesizable behavioral)** | RTL or VAMS behavioral model used for prototyping; no physical layout | Early verification / FPGA prototyping | Author and validate behavioral models |
| **Custom schematic + layout** | Transistor-level schematic in Virtuoso, custom layout | High-performance analog blocks not available as hard IP | Full SPICE validation, LVS, extraction, sign-off |

#### GAP-004.2.2  SPICE Netlist Validation Against Foundry Models

All analog blocks — whether custom-designed, vendor-supplied, or foundry-provided — must have their SPICE/CDL netlists validated against the target foundry SPICE models before any simulation results are considered authoritative.

```yaml
spice_model_validation:
  foundry_model_source: "mcp:pdk_vault/<foundry>/<node>/spice/models/"
  required_model_decks:
    - spectre_mos_tt.scs        # TT MOSFET model (Spectre format)
    - spectre_mos_ss.scs        # SS corner
    - spectre_mos_ff.scs        # FF corner
    - spectre_mos_sf.scs        # SF (slow NMOS, fast PMOS)
    - spectre_mos_fs.scs        # FS (fast NMOS, slow PMOS)
    - spectre_res_cap.scs       # Resistor and capacitor models
    - spectre_bjt.scs           # BJT / parasitic BJT (latch-up)
    - spectre_diode.scs         # ESD / protection diodes
    - mismatch_models.scs       # Statistical mismatch (for Monte Carlo)
  validation_steps:
    - Confirm model deck revision matches foundry-approved PDK version
    - Confirm model deck version recorded in ip_manifest.yaml
    - Verify MOSFET Ids/Vgs curves match foundry WAT data (within PDK tolerance)
    - Verify passive model Q-factor and parasitic RC at target frequency
  blocking: true   # No analog simulation accepted without model validation
```

#### GAP-004.2.3  Spectre / HSPICE Simulation Requirements

Every analog block must be simulated across the full PVT corner matrix before sign-off. The minimum required simulation set is:

```
CORNER MATRIX (mandatory)
                 PROCESS CORNER
               TT    SS    FF    SF    FS
           ┌─────┬─────┬─────┬─────┬─────┐
 TEMP  125°C│  ●  │  ●  │  ●  │  ●  │  ●  │  ← Worst hot (leakage, noise)
  (°C) 27°C │  ●  │  ●  │  ●  │     │     │  ← Nominal
      –40°C │  ●  │  ●  │  ●  │  ●  │  ●  │  ← Worst cold (startup, speed)
           └─────┴─────┴─────┴─────┴─────┘
VOLTAGE:  Nominal ±10% applied per power domain at each corner

MANDATORY SIMULATIONS PER BLOCK:
  □ DC operating point (all supply and bias conditions)
  □ AC small-signal (loop gain, phase margin for amplifiers/LDOs)
  □ Transient (startup, large-signal response, settling)
  □ Noise analysis (spot noise, integrated noise over bandwidth)
  □ Monte Carlo (see Section GAP-004.4.2)
  □ Periodic Steady State (PSS) for oscillators and PLLs
  □ Phase Noise (Pnoise) for PLL/VCO blocks
  □ S-parameter / harmonic balance for RF / SerDes blocks (if applicable)
```

Simulation tool configuration must be version-locked:

```yaml
simulation_config:
  preferred_tool: "Cadence Spectre (spectre / spectreS / APS mode)"
  alternate_tool:  "Synopsys HSPICE"
  oss_tool:        "ngspice (acceptable for pre-silicon feasibility only;
                    not acceptable for sign-off at advanced nodes)"
  convergence_settings:
    errpreset: liberal → moderate → conservative (escalate on non-convergence)
    homotopy: all     # Enable HSPICE/Spectre homotopy for difficult DC convergence
    gmin_stepping: enabled
  netlist_format: "CDL (preferred for LVS consistency) or SPICE subcircuit"
  results_format: "PSF binary (Spectre) or .sw/.tr/.ac (HSPICE)"
  results_stored_in: "mcp:artifact_store/ams/simulations/<block>/<corner>/"
```

#### GAP-004.2.4  CDL Extraction and LVS for Analog Blocks

Analog blocks require a separate LVS flow from the digital LVS flow because:
- Device parameters (W/L, multiplier) must be extracted and compared, not just topology
- Floating nodes (intentional in some analog topologies) need explicit exemption
- Diode-connected devices, guard rings, and substrate contacts need correct recognition
- ESD protection devices have non-standard configurations requiring runset exceptions

```
ANALOG LVS SUB-FLOW (per block)
        │
        ▼
┌───────────────────────────────┐
│  SCHEMATIC CDL EXPORT         │  Export CDL from Virtuoso schematic
│  (human AMS designer)         │  Include: device W/L, multiplier (m=),
│                               │  substrate/well connections, pin ordering
└─────────────┬─────────────────┘
              │
              ▼
┌───────────────────────────────┐
│  LAYOUT GDS STREAM-OUT        │  Stream out analog block GDS
│  (human AMS designer)         │  Layer map must match foundry layer table
└─────────────┬─────────────────┘
              │
              ▼
┌───────────────────────────────┐
│  LVS RUN (Calibre nmLVS)      │  agent:physical_verif executes
│  agent:physical_verif         │  Rules: foundry analog LVS deck
│                               │  Device recognition: MOSFET, BJT, diode,
│                               │  capacitor, resistor, varactor
│                               │  Exemptions file: floating_gates.svrf,
│                               │                   esd_exemptions.svrf
└─────────────┬─────────────────┘
              │
              ├── LVS CLEAN ──► proceed to parasitic extraction
              │
              └── LVS ERRORS ──► return to human AMS designer
                                  agent:ams logs error categories,
                                  suggests likely schematic/layout mismatch
                                  (device count, net short/open, parameter mismatch)

POST-LVS PARASITIC EXTRACTION:
  Tool options:
    Commercial: Calibre xRC (preferred), Synopsys StarRC, Cadence Quantus QRC
    OSS:        OpenRCX (not recommended for analog sign-off at advanced nodes)
  Extraction mode:
    - C-only extraction for noise-dominated paths
    - R+C extraction for settling-time-critical paths
    - R+C+CC (coupled capacitance) for differential pair matching
  Output: DSPF or SPECTRE format parasitic netlist
  Post-extraction re-simulation: mandatory — all corner sims re-run on extracted netlist
```

#### GAP-004.2.5  Analog Block GDS Integration into Top-Level

Analog block GDS files are integrated into the top-level chip GDS as hard macros. The integration flow is coordinated between `agent:ams`, `agent:fp`, and `agent:physical_verif`:

```
ANALOG GDS INTEGRATION FLOW

1. MACRO PLACEMENT (agent:fp)
   - Analog macros placed per agent:ams placement constraints:
       □ Distance from digital switching logic (substrate coupling)
       □ Orientation (sensitive analog inputs away from noisy digital I/O)
       □ Guard ring continuity at top-level (well ring, substrate ring)
       □ Analog supply strap entry points aligned with macro P/G pins
       □ Keep-out zone for digital routing over sensitive analog nets

2. ANALOG SUPPLY ROUTING (agent:fp + human AMS Eng)
   - Dedicated analog VDD (AVDD) and GND (AGND) supply domains
   - Separated from digital VDD at the package level (or on-chip LDO isolation)
   - Low-impedance supply routing to analog macros verified against IR drop budget
   - Decoupling capacitor placement adjacent to analog macro supply pins

3. SIGNAL ROUTING TO/FROM ANALOG MACROS (agent:pnr)
   - Analog signal nets routed on specified layers only (per agent:ams constraints)
   - Shield routing required for sensitive analog inputs (differential pairs, references)
   - Minimum crossing of digital routes over analog signal routes
   - Length matching for differential pairs (agent:ams specifies maximum delta length)

4. TOP-LEVEL GDS MERGE (agent:physical_verif + agent:ams)
   - Analog block GDS stream-in to top-level database (Virtuoso or ICC2/Innovus)
   - Layer mapping verification (analog PDK layers → top-level PDK layer IDs)
   - Overlap check: analog block boundary vs. digital placement area
   - Top-level DRC run including analog-digital boundary rules
   - Top-level LVS run: full chip CDL (digital + analog) vs. full chip GDS

5. PARASITIC VERIFICATION AT TOP-LEVEL
   - Analog supply nets extracted with top-level parasitics (R drop to macro)
   - Sensitive signal nets extracted for coupling noise budget verification
   - Re-simulation of critical analog blocks with top-level parasitics if supply
     resistance exceeds threshold defined in block datasheet
```

---

### GAP-004.3  AMS Co-Simulation Framework

Mixed-signal co-simulation is required to verify the interaction between analog IP (PLLs supplying clocks, ADC/DAC converting real-world signals, LDOs powering digital blocks) and the digital RTL that controls and interfaces them. Pure digital simulation of analog behavior is insufficient; behavioral analog models must be used in the digital simulation environment.

#### GAP-004.3.1  AMS Simulator Options

| Simulator | Vendor | Use Case | Integration with Digital |
|---|---|---|---|
| **Cadence AMS Designer / Xcelium AMS** | Cadence | Industry standard; Spectre kernel for analog, Xcelium for digital | Native; connect modules in Verilog-AMS |
| **Synopsys CustomSim AMS / VCS-AMS** | Synopsys | HSPICE or FineSim kernel for analog, VCS for digital | Connect modules; wreal support |
| **Mentor ADVance MS (ADMS)** | Siemens EDA | Eldo/ADiT analog kernel, Questa digital kernel | AMS connect modules, wreal |
| **SystemC-AMS (open standard)** | Accellera / Open Source | TLM-based AMS modeling; portable | SystemC TLM integration; IEEE 1666.1 |
| **ngspice + Verilator co-sim** | Open Source | Research / educational; limited commercial applicability | Custom socket bridge; not recommended for sign-off |
| **Xyce (SPICE-level)** | Sandia National Labs / OSS | High-performance SPICE; limited AMS co-sim support | Limited; not production-qualified |

**Recommended production configuration:** Cadence Xcelium + Spectre (AMS Designer) or Synopsys VCS + CustomSim.

#### GAP-004.3.2  Digital-Analog Boundary Definition

The boundary between digital and analog simulation domains is the most critical architectural decision in AMS co-simulation. `agent:ams` must produce a **connect module specification** for every digital/analog interface:

```
CONNECT MODULE SPECIFICATION (per interface)

  Interface: clk_out (PLL → Digital)
  ┌─────────────────────────────────────────────────────────┐
  │  ANALOG DOMAIN         │  CONNECT MODULE  │ DIGITAL DOMAIN│
  │  Spectre kernel        │  (Verilog-AMS)   │ Xcelium kernel│
  │                        │                  │               │
  │  PLL clk_out (voltage) │──[A2D converter]─►  wire clk_out │
  │  typ: 0..VDD swing     │  threshold: VDD/2│  logic 0/1    │
  │  transition time: trf  │  hysteresis: 50mV│               │
  └─────────────────────────────────────────────────────────┘

  Interface: adc_in (Digital input driver → ADC)
  ┌─────────────────────────────────────────────────────────┐
  │  DIGITAL DOMAIN        │  CONNECT MODULE  │ ANALOG DOMAIN │
  │  Xcelium kernel        │  (Verilog-AMS)   │ Spectre kernel│
  │                        │                  │               │
  │  wire driver_out [0/1] │──[D2A converter]─►  voltage net  │
  │                        │  0→0V, 1→VDD     │  (real-valued)│
  │                        │  Tr/Tf: 100ps    │               │
  └─────────────────────────────────────────────────────────┘
```

Connect module parameters (threshold, hysteresis, drive strength, transition time) must be set per the block datasheets and reviewed by the human AMS engineer before simulation sign-off.

#### GAP-004.3.3  Real Number Modeling (RNM) and `wreal` in SystemVerilog

For simulation environments that do not support full Verilog-AMS, `agent:ams` provides Real Number Models (RNM) using `wreal` net types in SystemVerilog (IEEE 1800, vendor extension):

```systemverilog
// Example: PLL RNM top-level interface
module pll_rnm #(
    parameter real FREF_HZ    = 25.0e6,   // Reference frequency
    parameter real FVCO_NOM   = 2.0e9,    // Nominal VCO frequency
    parameter real JITTER_RMS = 1.0e-12   // RMS jitter (seconds)
)(
    input  wire        ref_clk,      // Digital reference clock in
    input  wire        reset_n,      // Active-low reset
    input  wire [5:0]  div_ratio,    // Feedback divider (digital control)
    output wire        clk_out,      // Output clock (digital representation)
    output wire        lock_detect,  // Digital lock detect output
    // RNM ports for power supply monitoring
    input  wreal       vdd_analog,   // Analog supply (real-valued, volts)
    output wreal       idd_analog    // Supply current draw (real-valued, amps)
);
```

`wreal` nets are resolved by the simulator using real-arithmetic semantics rather than four-state logic. They enable:
- Supply voltage variation effects on PLL jitter and lock time
- ADC/DAC transfer function errors (gain error, offset, INL) modeled as real arithmetic
- Temperature-dependent bandgap voltage as a `wreal` parameter
- LDO output voltage droop under load modeled as a real function of load current

**Key constraint:** `wreal`-based models are for simulation speed; they are not synthesizable. The synthesis boundary is always the digital wrapper RTL (see Section GAP-004.5).

#### GAP-004.3.4  Behavioral Models for Fast Simulation

`agent:ams` must provide behavioral models at three levels of abstraction, with progressively higher simulation speed but lower accuracy:

```
ABSTRACTION LEVELS FOR ANALOG BEHAVIORAL MODELS

Level 3 (slowest, most accurate):
  TRANSISTOR-LEVEL SPICE
  Tool: Spectre / HSPICE
  Speed: 1× (reference)
  Use: Sign-off, Monte Carlo, post-layout corner

Level 2 (fast, analog-accurate):
  VERILOG-AMS BEHAVIORAL (wreal + continuous-time blocks)
  Tool: Xcelium AMS / VCS-AMS
  Speed: 10–100× vs. SPICE
  Use: Block-level AMS co-simulation, interface protocol verification
  Example (ADC):
    analog begin
      @(posedge clk) begin
        // Sample and quantize with thermal noise + INL model
        v_sample = V(vin_p, vin_n);
        v_noisy  = v_sample + thermal_noise_sample();
        adc_out  = real_to_binary(v_noisy, full_scale, resolution, inl_table);
      end
    end

Level 1 (fastest, functional-only):
  SYSTEMVERILOG wreal / INTEGER BEHAVIORAL
  Tool: Xcelium / VCS (standard digital sim with wreal extension)
  Speed: 1000× vs. SPICE
  Use: Chip-level regression, coverage closure, digital interface testing
  Example (ADC):
    always @(posedge clk) begin
      // Ideal quantizer — no noise, no INL, for digital IF testing only
      adc_out <= $rtoi(vin_real / full_scale * (2**BITS - 1));
    end
```

The choice of abstraction level per simulation campaign is documented in the AMS verification plan (see Section GAP-004.3.5).

#### GAP-004.3.5  Behavioral Model Validation Against Transistor-Level SPICE

Behavioral models must be correlated to SPICE before use in verification. `agent:ams` executes the following correlation flow:

```
BEHAVIORAL MODEL CORRELATION FLOW

For each analog IP block:

  STEP 1 — Define correlation test suite
    □ Nominal operating point (TT / 1.0V / 27°C)
    □ Key performance metrics (e.g., PLL: lock time, jitter; ADC: ENOB, SFDR)
    □ Stimulus: identical waveforms applied to both SPICE and behavioral model

  STEP 2 — Run SPICE (Level 3) simulation
    Tool: Spectre or HSPICE
    Output: Reference waveform + key metrics CSV

  STEP 3 — Run VAMS behavioral (Level 2) simulation
    Tool: Xcelium AMS
    Same stimulus as Step 2
    Output: Behavioral waveform + key metrics CSV

  STEP 4 — Run wreal (Level 1) simulation
    Tool: Xcelium / VCS
    Same stimulus
    Output: Functional output + key metrics CSV

  STEP 5 — Metrics comparison (agent:ams automated check)
    Acceptance thresholds (configurable per IP type):
      PLL lock time:    behavioral within 20% of SPICE
      PLL output jitter: behavioral within 30% of SPICE (noise is statistical)
      ADC ENOB:         behavioral within 0.5 bits of SPICE
      ADC SFDR:         behavioral within 6 dB of SPICE
      LDO output voltage: within 2% of SPICE at nominal load
      Bandgap voltage:  within 1% of SPICE at TT/27°C

  STEP 6 — Document and version-lock
    Artifact: ams/models/<block>/correlation_report_v<x>.md
    If thresholds not met: return to model developer (human AMS Eng)
    If thresholds met: model promoted to "VERIFIED" status in ip_manifest.yaml
```

---

### GAP-004.4  Analog Sign-Off Requirements

All analog blocks require the following sign-off checks to be completed and documented before GATE-08 (Tape-out Review). These checks are executed by `agent:ams` and reviewed by the human AMS engineer. No analog sign-off check is waivable without dual approval (human AMS engineer + project PM).

#### GAP-004.4.1  SPICE-Level Corner Simulation Pass Criteria

Each analog block has a block-specific pass/fail criteria document (`ams/<block>/signoff_criteria.yaml`). The universal minimum pass criteria are:

```yaml
# Universal minimum — all analog blocks
signoff_criteria_universal:
  dc_operating_point:
    all_corners: PASS      # No DC convergence failure; no node voltage out of
                           # safe operating range; no negative Vgs for PMOS/NMOS
  ac_stability:            # Applies to all feedback amplifiers (LDO, opamp, ADC ref)
    phase_margin_min: 45   # degrees, all corners
    gain_margin_min:  10   # dB, all corners
  supply_current:
    max_exceeds_budget: FAIL   # IDD must not exceed power budget from spec

# Per-IP additional criteria — examples
signoff_criteria_pll:
  lock_time_max_ns: 10000       # From reset release to lock detect assertion
  output_jitter_rms_ps: 2.0    # RMS period jitter, all corners
  output_jitter_pp_ps: 15.0    # Peak-to-peak period jitter, all corners
  output_frequency_accuracy: 0.1  # % error from target, all corners

signoff_criteria_adc_12bit:
  enob_min: 10.5               # Effective Number of Bits, worst corner
  sndr_min_db: 66.0            # Signal-to-Noise-and-Distortion Ratio
  sfdr_min_db: 72.0            # Spurious-Free Dynamic Range
  inl_max_lsb: 2.0             # Integral Non-Linearity, max abs value
  dnl_max_lsb: 0.8             # Differential Non-Linearity, max abs value
  no_missing_codes: true       # DNL must not reach –1 LSB

signoff_criteria_ldo:
  line_regulation_mv_per_v: 5  # Output variation per volt of input change
  load_regulation_mv_per_ma: 1 # Output variation per mA of load change
  psrr_db_at_1mhz_min: 40     # Power Supply Rejection Ratio
  output_noise_uv_rms: 50     # Integrated output noise 10 Hz – 100 kHz

signoff_criteria_bandgap:
  vref_accuracy_pct: 1.0       # Accuracy vs. nominal, all corners + Monte Carlo
  tc_ppm_per_c_max: 30         # Temperature coefficient ppm/°C
  psrr_db_at_dc_min: 60
```

#### GAP-004.4.2  Monte Carlo Analysis (Mismatch + Process)

Monte Carlo simulation is mandatory for all analog blocks and must be completed post-schematic (pre-layout) and post-layout (with extracted parasitics):

```yaml
monte_carlo_requirements:
  # Mismatch Monte Carlo (device-to-device variation within die)
  mismatch_mc:
    runs_minimum: 500          # Minimum number of runs for statistical significance
    variation_source: "Foundry mismatch model deck (pelgrom model or foundry tables)"
    temperature: 27            # Run at nominal temperature for mismatch focus
    corner: TT                 # Nominal process for mismatch isolation
    metrics_reported:
      - Mean (μ) of each key parameter
      - Standard deviation (σ) of each key parameter
      - 3σ yield estimate (% of runs meeting spec)
      - Worst-case sample (min/max of each metric)
    yield_target: 99.7         # percent (3σ) — adjust per product quality level

  # Process + Mismatch Monte Carlo (lot-to-lot variation)
  process_mc:
    runs_minimum: 200          # Process MC is slower; 200 typically sufficient
    variation_source: "Foundry process MC model deck (global lot-to-lot)"
    temperature_sweep: [-40, 27, 125]
    voltage_sweep: [vdd_min, vdd_nom, vdd_max]

  # Correlation check: worst MC run vs. worst corner sim
  # Worst MC run should not be more pessimistic than SS/–40°C corner by >20%
  # If it is, investigate model deck consistency with foundry

  artifacts:
    - ams/<block>/mc_mismatch_<runs>runs_results.csv
    - ams/<block>/mc_process_<runs>runs_results.csv
    - ams/<block>/mc_summary_report.md   # yield, histogram plots, 3σ values
```

#### GAP-004.4.3  Post-Layout Parasitic Extraction for Analog Blocks

Post-layout simulation with extracted parasitics is mandatory before sign-off. Pre-layout simulation results alone are not sufficient.

```yaml
post_layout_extraction:
  tools:
    preferred:  "Mentor Calibre xRC (PEX mode, R+C+CC)"
    alternate:  "Synopsys StarRC; Cadence Quantus QRC"
  extraction_modes:
    analog_precision: "R+C+CC (coupled capacitance for differential nets)"
    power_supply_nets: "R+C (DC + AC IR drop)"
  configuration:
    extraction_corners:
      - Cmax (maximum parasitic capacitance — worst settling time, noise)
      - Cmin (minimum parasitic capacitance — worst stability margin)
      - RCmax (maximum R×C — worst bandwidth, worst noise)
    antenna_check: not_applicable_per_block  # Analog blocks use floating gates
    output_format: "DSPF or Spectre include file"
  post_extraction_resimulation:
    required_corners: [SS_Cmax_m40, TT_RCmax_27, FF_Cmin_125]
    comparison_to_pre_layout:
      # Key metrics must not degrade by more than these thresholds post-layout
      pll_jitter_degradation_max_pct: 20
      adc_enob_degradation_max_bits: 0.3
      ldo_phase_margin_degradation_max_deg: 10
      bandgap_tc_degradation_max_ppm: 5
```

#### GAP-004.4.4  Noise Analysis

Noise is a first-class sign-off metric for precision analog blocks. `agent:ams` must produce a noise budget document that traces from device-level noise sources to system-level impact.

```
NOISE ANALYSIS REQUIREMENTS

1. ADC Noise Budget
   ─────────────────
   System SNR target (from spec): e.g., SNDR ≥ 66 dB (≡ ENOB 10.7 bits)
   Noise sources and contributions:
     □ Thermal noise (kT/C) of sampling capacitor
         → sets minimum sampling cap size: C_min = kT / (V_LSB²/12)
     □ Comparator noise (input-referred)
     □ Reference buffer noise (contribution to sampling noise)
     □ Substrate and supply noise coupling (digital aggressor estimation)
     □ Quantization noise (theoretical 6.02N + 1.76 dB SQNR limit)
   Tool: Spectre .noise analysis + Pnoise for switched-cap networks
   Simulation: Periodic noise (PNoise) at Nyquist frequency, TT/27°C
   Acceptance: Simulated noise floor ≤ specification noise floor (with 3 dB margin)

2. Amplifier / LDO Noise
   ──────────────────────
   Specification: Output noise spectral density (V/√Hz) and integrated noise (Vrms)
   Noise types:
     □ Flicker (1/f) noise: dominant at low frequency; characterized by corner freq
     □ Thermal (white) noise: dominant at high frequency
   Simulation: .noise analysis (Spectre) from 10 Hz to 100 MHz
   Acceptance: Integrated noise within specification budget
   Report:  noise_report_<block>.csv (noise density vs. frequency per corner)

3. PLL Phase Noise (see also Section GAP-004.4.5)
   □ VCO free-running phase noise (1/f³ + 1/f² regions)
   □ In-band noise (dominated by PFD/CP noise + reference noise)
   □ Out-of-band noise (dominated by VCO noise, shaped by loop filter)
   Simulation: Spectre Pnoise + HB (Harmonic Balance) or PSS+Pnoise
```

#### GAP-004.4.5  Phase Noise for PLL

Phase noise is characterized separately because it requires periodic steady-state analysis and is frequency-dependent:

```yaml
pll_phase_noise_signoff:
  simulation:
    type: "PSS (Periodic Steady State) + Pnoise (Periodic Noise)"
    tool: "Cadence Spectre (SpectreRF)"
    harmonics: 20          # Number of harmonics for PSS accuracy
    noise_sources:
      - VCO device noise (MOSFET flicker + thermal)
      - Charge pump current noise
      - Reference clock phase noise (input)
      - Feedback divider noise
      - Loop filter resistor thermal noise
  measurement_offsets_hz: [1e3, 10e3, 100e3, 1e6, 10e6]  # Hz from carrier
  acceptance_criteria:
    # Example for 2.4 GHz output
    phase_noise_at_100kHz_offset_dBc_Hz_max: -100
    phase_noise_at_1MHz_offset_dBc_Hz_max:   -120
    integrated_jitter_rms_ps_max: 2.0        # 12 kHz – 20 MHz integration band
  corners_required: [TT_27C, SS_125C, FF_m40C]
  artifacts:
    - ams/pll/phase_noise_<corner>.csv
    - ams/pll/phase_noise_summary.md
```

#### GAP-004.4.6  PSRR and CMRR for Amplifiers and LDOs

```yaml
psrr_cmrr_signoff:
  psrr:
    # Power Supply Rejection Ratio: ratio of supply disturbance to output disturbance
    simulation: "AC analysis with supply as input source; output as measurement node"
    frequency_sweep: "10 Hz to 100 MHz"
    acceptance_ldo:
      psrr_at_dc_min_db: 60
      psrr_at_1mhz_min_db: 40
      psrr_at_10mhz_min_db: 20
    acceptance_bandgap:
      psrr_at_dc_min_db: 60
    corners: [TT_27C, SS_125C, SS_m40C]

  cmrr:
    # Common-Mode Rejection Ratio: applies to differential amplifiers, opamps
    simulation: "AC analysis; common-mode source at input differential pair"
    frequency_sweep: "10 Hz to 10 MHz"
    acceptance_opamp_precision:
      cmrr_at_dc_min_db: 80
      cmrr_at_1mhz_min_db: 40
    corners: [TT_27C, SS_125C]
```

---

### GAP-004.5  Digital Wrapper RTL for Analog IP

Every analog IP block requires a synthesizable SystemVerilog wrapper. This wrapper is authored by `agent:rtl` based on a specification document produced by `agent:ams`. The wrapper is the sole point of contact between the digital synthesis flow and the analog IP.

#### GAP-004.5.1  Wrapper Architecture and Responsibilities

```
DIGITAL WRAPPER BLOCK DIAGRAM

  ┌───────────────────────────────────────────────────────────────┐
  │                  DIGITAL WRAPPER MODULE                        │
  │  (synthesizable SystemVerilog, written by agent:rtl)           │
  │                                                                │
  │  ┌────────────────┐         ┌─────────────────────────────┐   │
  │  │  APB/AXI-Lite  │         │  Signal Conditioning        │   │
  │  │  Register File │─cfg──►  │  (CDC, synchronizers,       │   │
  │  │  (trim/config) │         │   level shifters)           │   │
  │  └────────────────┘         └──────────────┬──────────────┘   │
  │                                            │                   │
  │  ┌────────────────┐                        ▼                   │
  │  │  Test Mux      │  testmode ◄──── ┌─────────────────────┐   │
  │  │  (DFT bypass)  │                 │  ANALOG IP INSTANCE  │   │
  │  └────────────────┘  bypass ──────► │  (black box in RTL)  │   │
  │                                     └─────────────────────┘   │
  │  ┌────────────────┐                        │                   │
  │  │  Lock/Ready    │  ◄─────────────────────┘                   │
  │  │  Status Logic  │  (digital status outputs from analog IP)    │
  │  └────────────────┘                                            │
  └───────────────────────────────────────────────────────────────┘
```

#### GAP-004.5.2  Interface Signal Conventions

```systemverilog
// Template: PLL digital wrapper interface
// agent:rtl generates this to agent:ams specification

module pll_wrapper #(
    parameter int FREF_MHZ = 25         // Reference frequency MHz
)(
    // Clock and Reset (digital domain)
    input  logic        ref_clk,         // Reference clock input
    input  logic        rst_n,           // Active-low synchronous reset

    // APB Configuration Interface (digital control)
    input  logic        apb_psel,
    input  logic        apb_penable,
    input  logic        apb_pwrite,
    input  logic [7:0]  apb_paddr,
    input  logic [31:0] apb_pwdata,
    output logic [31:0] apb_prdata,
    output logic        apb_pready,

    // PLL Status Outputs (to digital logic)
    output logic        pll_lock,        // Synchronous lock detect
    output logic        pll_clk_out,     // PLL output clock

    // Test Mode (DFT)
    input  logic        test_mode,       // DFT: bypass PLL, use ref_clk directly
    input  logic        scan_enable,

    // Analog ports — represented as inout in synthesizable wrapper
    // These ports connect to the hard IP analog supply pads
    // Synthesis tool treats them as black-box ports; no logic inferred
    inout  wire         avdd,            // Analog supply (hardwired to pad in netlist)
    inout  wire         agnd,            // Analog ground
    inout  wire         vctrl            // VCO control voltage (internal analog net)
    // NOTE: purely differential/analog signal ports use 'inout wire'
    //       or are omitted from the digital wrapper and handled in the
    //       analog block itself with direct pad connections
);

    // --- Internal signals ---
    logic        pll_lock_raw;           // Async lock detect from analog IP
    logic [5:0]  div_ratio;             // From register file to analog IP
    logic        pll_pd_n;              // Power-down control

    // --- Register file (configuration/trim) ---
    pll_reg_file u_reg (
        .apb_*    (apb_*),
        .div_ratio (div_ratio),
        .pd_n      (pll_pd_n)
    );

    // --- Analog IP instantiation (black box) ---
    // Synthesis treats this as a hard macro; no technology mapping
    (* keep_hierarchy = "true" *)
    pll_hardmacro u_pll (
        .ref_clk   (ref_clk),
        .pd_n      (pll_pd_n),
        .div       (div_ratio),
        .clk_out   (pll_clk_out),
        .lock      (pll_lock_raw),
        .avdd      (avdd),
        .agnd      (agnd),
        .vctrl     (vctrl)
    );

    // --- Lock detect synchronizer (async analog output → digital clock domain) ---
    // 2-flop synchronizer required; agent:rtl uses standard synchronizer cell
    cdc_sync2 u_lock_sync (
        .clk   (pll_clk_out),
        .rst_n (rst_n),
        .d     (pll_lock_raw),
        .q     (pll_lock)
    );

    // --- DFT test mode bypass ---
    // In test_mode: bypass PLL entirely; clock gating ensures no X-propagation
    // Synthesis: this mux is preserved; not optimized away
    (* keep = "true" *)
    assign pll_clk_out = test_mode ? ref_clk : pll_clk_out_raw;

endmodule
```

#### GAP-004.5.3  Synthesizability Rules for Analog Wrappers

`agent:rtl` enforces the following rules when generating analog IP wrappers:

```yaml
analog_wrapper_rtl_rules:
  - id: AW-01
    rule: "Analog IP hard macro instantiated as black box. Use (* black_box *) or
           equivalent synthesis pragma. Never infer logic from analog IP ports."
    check: lint tool reports zero cells inferred inside black-box boundary

  - id: AW-02
    rule: "All analog-domain supply ports (avdd, agnd, vbias) declared as
           'inout wire' in the wrapper. Not driven by any digital logic.
           Connected to pad ring net in top-level netlist."
    check: LVS connectivity check confirms P/G net continuity

  - id: AW-03
    rule: "All asynchronous outputs from analog IP (lock_detect, ready, data_valid)
           must pass through a 2-flop CDC synchronizer before use in digital logic.
           agent:ams specifies which outputs are asynchronous."
    check: SpyGlass CDC / Meridian CDC reports no violations at analog boundary

  - id: AW-04
    rule: "Test mode bypass path is always present. In test_mode=1, the analog IP
           is power-down (pd_n=0) and the functional clock is replaced by a
           known-good digital clock source. The bypass must be DRC-timing-clean
           at test frequency."
    check: DFT agent verifies bypass path timing in scan mode SDC

  - id: AW-05
    rule: "Configuration register file must be reset-accessible (values load from
           registers on reset release). No hard-coded analog bias values in RTL."
    check: Simulation verifies register reset values match analog IP datasheet defaults

  - id: AW-06
    rule: "Wrapper must have a complete SDC constraint entry in top.sdc:
           create_clock for PLL output; set_false_path or set_max_delay for
           analog status signals crossing from analog domain to digital domain."
    check: agent:sta confirms all wrapper ports are constrained

  - id: AW-07
    rule: "No combinational logic between clock source (PLL output) and any
           flip-flop clock pin. Clocks from PLLs are inserted only via clock
           tree synthesis. Use set_dont_touch on PLL clk_out net in synthesis."
    check: Zero combinational logic reported between PLL output and CTS sink
```

#### GAP-004.5.4  Test Mode Bypass Paths for DFT

The DFT strategy for analog blocks requires collaboration between `agent:ams` and `agent:dft`:

```
DFT CONSIDERATIONS FOR ANALOG IP

1. CLOCK BYPASS (PLL test mode)
   - In scan shift mode: replace PLL output clock with ATE-controlled test clock
   - OCC (On-Chip Clock Controller) is placed between PLL output and clock tree
   - OCC selects between: functional PLL output / test clock input
   - agent:dft inserts OCC; agent:ams specifies PLL output clock characteristics
     for correct OCC setup

2. ANALOG BLOCK POWER-DOWN DURING SCAN
   - During scan shift, analog blocks may be powered down (reduce noise, power)
   - Wrapper register file has a SCAN_PD_ENABLE bit
   - When scan_enable=1, analog supply power-down is asserted
   - agent:ams verifies startup time after scan power-up is within DFT timing

3. ADC/DAC BOUNDARY SCAN
   - For ADC: digital output bus is scannable via standard scan chain
   - For DAC: digital input bus is driven by scan chain in test mode
   - For analog pin testing: BSCAN (IEEE 1149.1) covers I/O pads
   - IJTAG (IEEE 1687) instruments may be embedded for ADC calibration access
   - agent:dft and agent:ams jointly define IJTAG instrument topology if required

4. ANALOG BIST (where applicable)
   - Some foundry PLLs include internal BIST (VCO frequency sweep + lock detect check)
   - agent:ams documents BIST enable sequence, expected pass criteria, test time
   - agent:dft integrates BIST enable into JTAG instruction register

5. SCAN CHAIN ISOLATION
   - Scan chains must not pass through analog block wrapper boundary
   - All scan flip-flops are in the digital wrapper only
   - Analog block outputs to digital registers are captured after analog block
     has reached steady state (scan capture clock timing must account for
     analog settling time)
```

---

### GAP-004.6  Quality Gates

#### GAP-004.6.1  AMS Track Quality Gate — GATE-04A

A new blocking gate `GATE-04A` is inserted in the orchestrator FSM parallel to GATE-04 (RTL Freeze). GATE-04A is the **AMS Architecture and IP Selection Freeze** gate.

```yaml
gate_04a:
  id: GATE-04A
  name: "AMS Architecture and IP Selection Freeze"
  stage: AMS_ARCHITECTURE
  parallel_to: GATE-04  # GATE-04A and GATE-04 may proceed in parallel
  required_reviewers:
    - human_ams_engineer       # MANDATORY — blocking without human AMS Eng
    - agent:arch               # Architecture consistency check
    - agent:pdk                # IP availability confirmation
  required_artifacts:
    - ams/ams_architecture_spec.md     # Block-by-block integration strategy
    - ams/ip_selection_rationale.yaml  # Hard IP vs. custom for each block
    - ams/vendor_ip_qual_reports/      # One per vendor-sourced IP
    - ams/spice_model_validation.log   # Foundry model deck validated
    - ams/behavioral_models/           # Level 2 + Level 1 models, correlation reports
    - ams/wrapper_spec/                # Digital wrapper specifications
    - ams/pad_ring_spec.md             # Analog pad ring topology
  pass_criteria:
    - All analog IPs have qualified SPICE models
    - All vendor IPs have completed intake qualification workflow
    - Behavioral models correlation reports show passing thresholds
    - AMS power budget approved by human arch lead
    - Digital wrapper specifications reviewed by human AMS engineer
```

#### GAP-004.6.2  AMS Sign-Off Gate — GATE-07A

A new blocking gate `GATE-07A` is inserted after GATE-07 (PD Review) and before GATE-08 (Tape-out Review).

```yaml
gate_07a:
  id: GATE-07A
  name: "AMS Sign-Off"
  stage: AMS_SIGNOFF
  must_complete_before: GATE-08
  required_reviewers:
    - human_ams_engineer       # MANDATORY — no waiver allowed
    - agent:physical_verif     # LVS/DRC sign-off per analog block
    - agent:sta                # Timing constraints at analog/digital boundary
  required_artifacts:
    - ams/<block>/corner_sim_results/   # All corners, all required simulations
    - ams/<block>/mc_mismatch_report.md # 500+ run Monte Carlo
    - ams/<block>/mc_process_report.md  # 200+ run process Monte Carlo
    - ams/<block>/post_layout_sim/      # Post-extraction re-simulation results
    - ams/<block>/noise_report.md       # Noise analysis
    - ams/<block>/lvs_clean.log         # Per-block LVS CLEAN
    - ams/<block>/drc_clean.log         # Per-block DRC CLEAN (or waiver log)
    - ams/top_level_gds_integration_check.log
    - ams/top_level_lvs_analog_digital.log
    - ams/behavioral_model_final_versions/
  per_ip_checklists: see Section GAP-004.6.3
```

#### GAP-004.6.3  Per-IP Sign-Off Checklists

**PLL Sign-Off Checklist:**
```
PLL SIGN-OFF CHECKLIST
□ Lock time verified at all corners (TT/SS/FF/SF/FS × –40/27/125°C)
□ Output frequency accuracy within spec at all corners
□ RMS period jitter ≤ specification, all corners
□ Peak-to-peak jitter ≤ specification, all corners
□ Phase noise verified at all required offset frequencies (PSS+Pnoise)
□ Integrated RMS jitter from phase noise ≤ specification
□ PSRR measured vs. spec (supply noise → output jitter)
□ VCO gain (Kvco) within expected range at all corners
□ Charge pump mismatch Monte Carlo: 500+ runs, yield ≥ 99.7%
□ Lock detect glitch test (supply ramp, reset, power cycle)
□ Post-layout re-simulation PASS (jitter degradation < 20% vs. schematic)
□ LVS CLEAN (block-level)
□ DRC CLEAN or approved waiver log
□ Behavioral model correlation: lock time within 20%, jitter within 30%
□ OCC / test clock bypass path verified in DFT simulation
□ Human AMS engineer sign-off
```

**ADC / DAC Sign-Off Checklist:**
```
ADC SIGN-OFF CHECKLIST
□ ENOB ≥ specification at worst-case corner (usually SS/125°C)
□ SNDR ≥ specification at Nyquist input frequency
□ SFDR ≥ specification at Nyquist input frequency
□ INL ≤ specification (max abs value, all codes), all corners
□ DNL ≤ specification (max abs value), no missing codes, all corners
□ Input common-mode range coverage verified
□ Reference voltage chain (bandgap → buffer → ADC ref) simulated
□ Thermal noise floor verified (kT/C noise budget satisfied)
□ Noise figure / total integrated noise vs. SNR budget: PASS
□ Monte Carlo (mismatch): ENOB, INL, DNL histograms, 500+ runs, yield ≥ 99%
□ Post-layout re-simulation: ENOB degradation < 0.3 bits vs. schematic
□ LVS CLEAN (block-level CDL vs. GDS)
□ DRC CLEAN (or waiver log with human approval)
□ Digital output scan path included in top-level scan chain
□ Test mode (all-ones, all-zeros, ramp digital code output) verified
□ Human AMS engineer sign-off

DAC SIGN-OFF CHECKLIST (additional to ADC):
□ Settling time to within 1 LSB, all corners
□ Glitch energy (code-crossing glitch) characterized and within spec
□ Output impedance vs. spec
□ Monotonicity verified (no DNL ≤ –1 LSB)
```

**Analog I/O Pad Sign-Off Checklist:**
```
ANALOG I/O PAD SIGN-OFF CHECKLIST
□ ESD HBM protection level ≥ specification (typically 2kV)
□ ESD CDM protection level ≥ specification (typically 250V or 500V)
□ Latch-up immunity: holding voltage > VDD, trigger current > 100 mA
□ Input voltage range covers specification at all corners
□ Slew rate within specification (not too fast — EMI; not too slow — timing)
□ Drive strength meets interface load specification
□ Pad ESD clamp does not load signal at target frequency (impedance check)
□ Pad ring design rule check: spacing, overlap, pin pitch
□ IBIS model generated and validated against SPICE transient (if required)
□ Foundry IO pad frame rules compliance
□ Human AMS engineer sign-off
```

**LDO / Bandgap Sign-Off Checklist:**
```
LDO SIGN-OFF CHECKLIST
□ Output voltage accuracy vs. spec (line + load regulation), all corners
□ Phase margin ≥ 45° with all specified load capacitor ranges, all corners
□ Gain margin ≥ 10 dB, all corners
□ PSRR ≥ spec at DC and all specified frequencies, all corners
□ Transient undershoot/overshoot ≤ spec under step load (min→max, max→min)
□ Startup behavior verified: no latch-up at power-on, correct sequencing
□ Output noise spectral density and integrated noise ≤ spec
□ Short-circuit current limiting verified (if specified)
□ Monte Carlo: output voltage spread, phase margin distribution, 500+ runs
□ Post-layout re-simulation: phase margin degradation < 10° vs. schematic
□ LVS CLEAN; DRC CLEAN
□ Human AMS engineer sign-off

BANDGAP SIGN-OFF CHECKLIST
□ Reference voltage accuracy ±1% (or per spec), all process corners
□ Temperature coefficient ≤ 30 ppm/°C (or per spec), –40 °C to +125 °C
□ PSRR ≥ 60 dB at DC, ≥ 40 dB at 1 MHz
□ Startup circuit: reference not latched at zero, cold-start at –40 °C verified
□ Monte Carlo: Vref spread, TC distribution, 500+ runs, yield ≥ 99.7%
□ Curvature correction trimming range verified (if applicable)
□ Post-layout re-simulation PASS
□ LVS CLEAN; DRC CLEAN
□ Human AMS engineer sign-off
```

#### GAP-004.6.4  Human Review Requirements

Analog design is a domain where AI agents have materially limited capability relative to digital design. The following human expert requirements are **non-negotiable** and cannot be overridden by any automated gate:

```yaml
human_review_requirements_ams:

  mandatory_human_roles:
    - id: human_ams_engineer
      description: "Licensed mixed-signal IC designer with SPICE simulation experience
                    at the target process node. Must have taped out analog blocks
                    (PLL, ADC, or LDO) at commercial foundry."
      responsibilities:
        - Review and approve all SPICE simulation results before GATE-04A
        - Review and approve all Monte Carlo results before GATE-07A
        - Review and approve all post-layout re-simulation results
        - Personally review every DRC/LVS waiver for analog blocks
        - Approve behavioral model correlation reports
        - Approve digital wrapper RTL specifications
        - Sign GATE-07A AMS sign-off package
      cannot_be_delegated_to_agent: true
      escalation_target_for: [simulation_non-convergence, unexpected_MC_yield_loss,
                               post_layout_degradation_exceeds_threshold,
                               LVS_shorts_in_sensitive_nodes, unexplained_silicon_failure]

  human_review_scope:
    pre_tape_out:
      - Full schematic review of all custom analog blocks (not hard IP)
      - SPICE netlist review for obvious modeling errors
      - Monte Carlo yield estimation review
      - Noise budget document review
      - Top-level analog supply routing review
      - ESD protection architecture review (I/O pad ring)
    at_gate_07a:
      - All corner simulation summary reports
      - Post-layout vs. schematic comparison delta report
      - IP qualification reports for all vendor IPs
      - DRC/LVS sign-off logs
      - Behavioral model correlation reports
      - AMS co-simulation regression summary
```

---

### GAP-004.7  Tool Registry Additions — AMS

#### GAP-004.7.1  Open-Source Tools

| Category | Tool | Version Guidance | Stage | Notes |
|---|---|---|---|---|
| **SPICE Simulation** | ngspice | ≥ 40 | Feasibility only | BSIM4 / BSIM-CMG support; not sign-off quality at ≤28nm |
| **SPICE Simulation** | Xyce | ≥ 7.6 | Feasibility / HPC | Trilinos-based; parallel SPICE; better than ngspice for large circuits |
| **SPICE Simulation** | QUCS-S | ≥ 24 | Feasibility | QUCS front-end with ngspice/Xyce backends; educational use |
| **AMS Modeling** | SystemC-AMS | IEEE 1666.1 | Behavioral modeling | Accellera standard; portable across tools |
| **Layout** | KLayout | ≥ 0.28 | GDS viewing / basic DRC | Not analog-grade LVS |
| **Layout** | Magic VLSI | ≥ 8.3 | Skywater130 / GF180 only | Full custom layout for open PDK nodes |
| **Schematic** | Xschem | ≥ 3.4 | Schematic capture | Open-source Virtuoso alternative; ngspice integration |
| **Schematic** | KiCad | ≥ 8 | PCB / system-level | Not IC layout grade |
| **Extraction** | OpenRCX | Latest | Digital PD only | Not suitable for analog precision extraction |

#### GAP-004.7.2  Commercial Tools

| Category | Tool | Vendor | Stage |
|---|---|---|---|
| **SPICE Simulation** | Spectre (spectre/spectreS/APS) | Cadence | AMS design + sign-off |
| **SPICE Simulation** | HSPICE | Synopsys | AMS design + sign-off |
| **SPICE Simulation** | FineSim SPICE | Synopsys | Large analog / fast SPICE |
| **SPICE Simulation** | Eldo / ADiT | Siemens EDA | AMS design |
| **AMS Co-Simulation** | AMS Designer (Xcelium + Spectre) | Cadence | AMS co-simulation |
| **AMS Co-Simulation** | CustomSim VCS-AMS (VCS + HSPICE/FineSim) | Synopsys | AMS co-simulation |
| **AMS Co-Simulation** | ADVance MS (ADMS) | Siemens EDA | AMS co-simulation |
| **Schematic / Layout** | Virtuoso ADE (ADE-L, ADE-XL, ADE-GXL) | Cadence | Full custom design |
| **Schematic / Layout** | Custom Compiler | Synopsys | Full custom design |
| **Parasitic Extraction** | Calibre xRC / PEX | Siemens EDA | Analog post-layout extraction |
| **Parasitic Extraction** | StarRC | Synopsys | Analog post-layout extraction |
| **Parasitic Extraction** | Quantus QRC | Cadence | Analog post-layout extraction |
| **LVS (Analog)** | Calibre nmLVS | Siemens EDA | Analog LVS sign-off |
| **LVS (Analog)** | PVS / Pegasus LVS | Cadence | Analog LVS |
| **DRC (Analog)** | Calibre nmDRC | Siemens EDA | Analog DRC sign-off |
| **AMS RF** | SpectreRF (PSS/Pnoise/HB) | Cadence | PLL / RF block characterization |
| **AMS RF** | HSPICE RF (HPSPICE + .hb) | Synopsys | PLL / mixer characterization |
| **IBIS Modeling** | Touchstone / IBIS-AMI | Industry standard | SerDes / IO IBIS generation |
| **AMS Reliability** | Spectre APS (aging) | Cadence | NBTI/HCI analog aging |
| **ESD** | Totem | Ansys | Device-level ESD simulation |

#### GAP-004.7.3  MCP Server and Skill Additions

```yaml
# Additions to mcp:eda_tool_runner for AMS support
mcp_eda_tool_runner_ams_additions:
  tools_added:
    - run_spice_sim(netlist, models, corners, analyses) → SpiceResult
        # Dispatches to Spectre or HSPICE; manages corner matrix sweep
    - run_monte_carlo(netlist, models, n_runs, params) → MonteCarloResult
        # Parallel dispatch of MC runs to compute cluster
    - run_pss_pnoise(netlist, models, harmonics, offsets) → PhaseNoiseResult
        # Spectre PSS+Pnoise flow for PLL characterization
    - run_analog_extraction(gds, lvs_netlist, rules, mode) → DSPFNetlist
        # Calibre xRC or StarRC dispatch
    - run_ams_cosim(digital_tb, analog_netlist, models, connect_modules) → AmsSimResult
        # Xcelium AMS or VCS-AMS co-simulation dispatch
    - run_ibis_gen(netlist, models, corner) → IBISModel
        # IBIS model generation from SPICE simulation

# New skills for agent:ams
skills_ams:
  - skill:spice_corner_runner      # Automated corner matrix execution + report
  - skill:mc_analyzer              # Monte Carlo results parsing → yield/sigma
  - skill:behavioral_model_gen     # Generate VAMS/wreal behavioral model from datasheet
  - skill:ams_cosim_setup          # Configure AMS connect modules + boundary definition
  - skill:analog_noise_budget      # Noise budget analysis from simulation results
  - skill:pll_jitter_analyzer      # Phase noise → integrated jitter conversion
  - skill:lvs_ams_setup            # Configure Calibre LVS for analog block (exemptions)
  - skill:vendor_ip_intake         # Automate vendor IP intake checklist steps 1–3
  - skill:wrapper_spec_generator   # Generate digital wrapper specification from IP datasheet
  - skill:correlation_reporter     # Compare SPICE vs. behavioral model metrics → report
```

---

### GAP-004.8  Orchestrator State Machine Extension for AMS Track

The following additions to the orchestrator FSM (Section 3.1) define the AMS parallel track:

```
ORCHESTRATOR FSM — AMS TRACK ADDITIONS

After GATE-03 (Architecture Approval), two parallel tracks proceed:

TRACK A: DIGITAL (existing)               TRACK B: AMS (new)
  RTL_CODING                                AMS_IP_INTAKE
  (parallel blocks)                           │
  │                                      ┌────┴─────────────────┐
  │                                      │  Vendor IP intake    │
  │                                      │  (Section GAP-004.1.4)│
  │                                      │  Model deck validate  │
  │                                      └────┬─────────────────┘
  │                                           │
  │                                      AMS_SCHEMATIC_SIM
  │                                           │
  │                                      ┌────┴─────────────────┐
  │                                      │  Pre-layout corner   │
  │                                      │  simulations         │
  │                                      │  Behavioral model    │
  │                                      │  generation          │
  │                                      │  Model correlation   │
  │                                      └────┬─────────────────┘
  │                                           │
  │                                      *** GATE-04A ***
  │                                      (AMS Architecture Freeze)
  │                                      Human AMS Eng required
  │                                           │
  GATE-04 (RTL Freeze) ◄─────────────────────┤
  │                                           │
  │                                      AMS_WRAPPER_RTL
  │                                           │
  │                         ┌──────────────────┴─────────────────┐
  │                         │  agent:rtl writes synthesizable     │
  │                         │  wrapper per agent:ams spec         │
  │                         └──────────────────┬─────────────────┘
  │                                            │
  VERIFICATION ◄──── AMS behavioral models ────┤
  (parallel: digital sim + AMS co-sim)         │
  │                                       AMS_LAYOUT_SIM
  │                                            │
  │                              ┌─────────────┴──────────────────┐
  │                              │  Post-layout extraction         │
  │                              │  Post-layout corner sims        │
  │                              │  Monte Carlo (mismatch)         │
  │                              │  Monte Carlo (process)          │
  │                              │  Noise analysis                 │
  │                              │  Phase noise (PLL)              │
  │                              │  PSRR/CMRR verification         │
  │                              └─────────────┬──────────────────┘
  │                                            │
  PD ◄──────── Analog GDS integration ─────────┤
  (analog macros placed + routed)              │
  │                                            │
  GATE-07 (PD Review) ◄────────────────────────┤
  │                                       *** GATE-07A ***
  │                                       (AMS Sign-Off)
  │                                       Human AMS Eng required
  │                                            │
  GATE-08 (Tape-out) ◄────────────────────────-┘
```

#### GAP-004.8.1  AMS Track Transition Conditions

| From → To | Transition Condition | Blocker if FAIL |
|---|---|---|
| GATE-03 → AMS_IP_INTAKE | Architecture approval includes AMS block list | Revise architecture |
| AMS_IP_INTAKE → AMS_SCHEMATIC_SIM | All vendor IP intake checklists complete; SPICE model decks validated | Re-engage vendor; escalate to human AMS Eng |
| AMS_SCHEMATIC_SIM → GATE-04A | All pre-layout corner sims pass criteria; behavioral model correlation PASS | Fix schematic (human AMS Eng); fix model |
| GATE-04A → AMS_WRAPPER_RTL | Human AMS engineer approves AMS architecture spec | Human AMS Eng must approve; no bypass |
| AMS_WRAPPER_RTL → AMS_LAYOUT_SIM | Digital wrapper lint-clean; wrapper spec reviewed by human AMS Eng | Fix wrapper RTL |
| AMS_LAYOUT_SIM → GATE-07A | Post-layout sims pass; MC yield ≥ target; LVS CLEAN; DRC CLEAN | Schematic or layout fix (human AMS Eng) |
| GATE-07A → GATE-08 | Human AMS engineer signs GATE-07A; all per-IP checklists complete | Human must sign; no automated bypass |

---

### GAP-004.9  Artifact Store Extensions for AMS

```
ams/
├── architecture/
│   ├── ams_architecture_spec.md          ← IP integration strategy, power domains
│   ├── ip_selection_rationale.yaml       ← hard/custom/soft decision per block
│   └── pad_ring_spec.md                  ← analog pad ring topology
├── models/
│   ├── <block>/
│   │   ├── behavioral_l2.vams            ← Level 2 VAMS behavioral model
│   │   ├── behavioral_l1.sv              ← Level 1 wreal SystemVerilog model
│   │   ├── correlation_report_v<x>.md    ← SPICE vs. model comparison
│   │   └── connect_modules/
│   │       └── <interface>_cm.vams       ← AMS connect module definitions
├── simulations/
│   ├── <block>/
│   │   ├── pre_layout/
│   │   │   ├── <corner>_<analysis>.log   ← Per-corner simulation results
│   │   │   └── signoff_summary.md        ← Pass/fail vs. criteria
│   │   ├── post_layout/
│   │   │   ├── <corner>_extracted.log
│   │   │   └── pre_vs_post_delta.md      ← Degradation analysis
│   │   ├── monte_carlo/
│   │   │   ├── mc_mismatch_<N>runs.csv
│   │   │   ├── mc_process_<N>runs.csv
│   │   │   └── mc_summary_report.md
│   │   └── noise/
│   │       ├── noise_<corner>.csv
│   │       └── noise_summary.md
├── ip_qual/
│   ├── <vendor_ip>/
│   │   ├── ip_qual_report_v<x>.md        ← Vendor IP qualification report
│   │   ├── lvs_clean.log
│   │   └── drc_waivers.md
├── wrapper_rtl/
│   ├── <block>_wrapper_spec.md           ← Specification from agent:ams to agent:rtl
│   └── <block>_wrapper.sv               ← Synthesizable wrapper (from agent:rtl)
├── layout/
│   ├── <block>.cdl                       ← Final CDL netlist (LVS source)
│   ├── <block>.gds                       ← Block-level GDS
│   ├── <block>_lvs_clean.log
│   ├── <block>_drc_clean.log
│   └── <block>.dspf                      ← Extracted parasitics
└── signoff/
    ├── gate_04a_approval.md              ← Human AMS Eng approval record
    ├── gate_07a_package.md               ← Full AMS sign-off package summary
    └── per_ip_checklists/
        └── <block>_signoff_checklist.md  ← Completed checklist per IP
```

---

### GAP-004.10  Risk Matrix Additions — AMS

| Risk | Prob | Impact | Mitigation |
|---|---|---|---|
| Analog IP behavioral model inaccuracy causes digital verification to miss AMS interface bugs | MEDIUM | HIGH | Mandatory behavioral model correlation (Section GAP-004.3.5); delta thresholds enforced; human AMS Eng review |
| Substrate noise coupling from digital switching degrades PLL jitter or ADC SNDR | MEDIUM | HIGH | Analog macro keep-out zones; guard ring continuity; shield routing; post-layout PSRR re-verification |
| Vendor hard IP GDS has DRC violations under current foundry deck (deck version mismatch) | MEDIUM | HIGH | IP intake step 3 re-runs DRC with current foundry deck; vendor notified; waiver log mandatory |
| Post-layout analog block degradation exceeds threshold (layout parasitics underestimated) | LOW | CRITICAL | Pre-layout extrapolation of estimated parasitics during schematic phase; aggressive post-layout simulation schedule |
| Monte Carlo yield < target due to process mismatch | LOW | HIGH | Early MC simulation (pre-layout); device sizing re-done if yield < 99%; conservative W/L for matching-critical devices |
| PLL phase noise too high post-silicon due to VCO model inaccuracy | LOW | CRITICAL | Use SpectreRF PSS+Pnoise (not behavioral jitter model) for sign-off; pre-silicon correlation to foundry ring oscillator data |
| Analog supply and digital supply coupling through shared bond wire / package | MEDIUM | MEDIUM | Separate AVDD / DVDD pad ring assignment; package substrate modeling in co-simulation |
| Digital wrapper CDC violation at analog-digital boundary | MEDIUM | HIGH | AW-03 rule enforced; SpyGlass CDC run includes all analog wrapper ports; 2-flop synchronizer mandatory |
| Analog IP startup failure at cold temperature (–40 °C) or at minimum supply | LOW | HIGH | Cold-temperature startup simulation mandatory (SS/–40°C corner); startup waveform human-reviewed |
| Missing or incorrect IBIS model causes signal integrity failure at board level | LOW | MEDIUM | IBIS model generation from SPICE mandatory; correlation to SPICE transient verified before delivery |
| AMS co-simulation convergence failure wastes schedule | HIGH | MEDIUM | errpreset escalation protocol; homotopy enabled; human AMS Eng reviews non-converging netlists |
| Analog IP license expiry blocks re-spin tape-out | LOW | HIGH | IP license terms version-locked in ip_manifest.yaml; re-spin rights confirmed at GATE-04A |

---

*GAP-004 Specification Version: 1.0*
*Status: Normative — resolves GAP-004 from Section 19.1*
*Author: agent:ams specification (human AMS engineer review required before adoption)*
*Compatible with Framework Version: 2.0*
*Next action: Human AMS engineer reviews this specification and approves or annotates before v3.0 framework incorporation.*

---

*Document Version: 3.0 | Status: Active Development*
*Maintained by: agent:orch + Human Architecture Lead*
*v3.0 changes: All 4 remaining critical gaps resolved via 4 parallel sub-agent research tasks; 3 new agents added to roster (agent:upf, agent:ams, agent:reliability); 8 hierarchical gates added (HGATE-00 through HGATE-07); confidence raised to HIGH overall.*
*Companion specs: GAP-002_UPF_Agent_Spec.md | GAP-013_Hierarchical_SoC_Flow.md | GAP-015_Reliability_Aging_Analysis.md*
*Next review: Human expert review of companion specs; GAP-017/GAP-018 (agent conflict resolution, state persistence) are next priority.*
