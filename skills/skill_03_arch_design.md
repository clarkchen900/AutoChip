# skill_03_arch_design — Architecture Design
## Stage 3 | Gate: GATE-03

**Version:** 1.0
**Agent:** agent:arch (primary), agent:rtl + agent:upf + agent:ams (review)
**Trigger:** GATE-02 approval from skill_02_algo_dev

---

## Cross-References

| Direction | Skill | Artifact / Purpose |
|-----------|-------|--------------------|
| Upstream | skill_02_algo_dev | `algo/algo_spec.md`, `algo/hls_qor.rpt` |
| Upstream | skill_01_spec_intake | `spec/product_spec.yaml`, `spec/rtm.csv` |
| Downstream | skill_04_rtl_design | `arch/block_diagram.yaml`, `arch/clock_domains.yaml`, `arch/power_intent.yaml`, `arch/memory_map.yaml` |
| Downstream | skill_05_verification | `arch/perf_model.yaml` (throughput/latency budget) |
| Downstream | skill_06_synthesis | `arch/clock_domains.yaml` (clock constraints seed) |
| Downstream | skill_07_pnr | `arch/block_diagram.yaml` (hierarchy for floorplan) |
| On GATE-03 REJECT | skill_03_arch_design | Iterate architecture |
| If synthesis fails timing >20% | skill_03_arch_design | Revisit timing budget |
| If P&R congestion unresolvable | skill_03_arch_design | Revisit floorplan strategy |
| Library | skill_lib_memory | Recall PDK, power domain count, clock count |

---

## Inputs

| Artifact | Source | Required |
|----------|--------|---------|
| `spec/product_spec.yaml` | skill_01 | Yes |
| `algo/algo_spec.md` | skill_02 | Yes |
| `algo/hls_qor.rpt` | skill_02 | If HLS was used |
| PDK capability matrix | skill_lib_pdk_select | Yes (memory compiler, IO lib) |

---

## Requirements Gathering

```
STAGE 3: ARCHITECTURE REQUIREMENTS
  (Recalled: freq=<MHz>, area=<mm²>, power=<mW>, pdk=<pdk>)

── BLOCK PARTITIONING ─────────────────────────────────────────────────
  Generate block template from spec:    [yes / provide manually]
  Hierarchical design:
    Gate count <5M:   flat or light hierarchy    [auto-select]
    Gate count 5-20M: recommended hierarchy      [auto-select]
    Gate count >20M:  mandatory hierarchy (ILM)  [auto-select]
  SoC integration (multiple hard IP):   [yes / no]

── CLOCK ARCHITECTURE ─────────────────────────────────────────────────
  Clock domains (recalled):             [<count>]
  Clock sources:
    [1] On-chip PLL   [2] Crystal oscillator   [3] External clock
  CDC synchronization strategy:
    [1] 2FF synchronizer (default)
    [2] Async FIFO (for data buses)
    [3] Handshake protocol (for control)
    [4] Grey-code counter (for pointers)
  ICG policy:                           [cell-based ICG only — no logic gating]
  Useful skew optimization in P&R:      [yes / no]

── MEMORY SUBSYSTEM ───────────────────────────────────────────────────
  On-chip SRAM (KB):                    [256]
  Memory compiler:
    From PDK:    [<detected SRAM compiler or "none found">]
    OpenRAM:     [available for sky130 / not for commercial nodes]
  Cache or scratchpad:                  [scratchpad (default for ASIC)]
  ROM:                                  [none / specify size KB]

── BUS / INTERCONNECT ─────────────────────────────────────────────────
  Primary bus:     [AXI4 / APB / AHB / custom NoC]
  Bus width (bits): [64]
  Masters / slaves:  [specify counts or auto from block list]

── POWER ARCHITECTURE ─────────────────────────────────────────────────
  Power domains (recalled):             [<count>]
  Domain boundaries:                    [specify blocks per domain]
  Retention registers needed:           [yes / no]
  Level shifters needed:                [yes (if voltage domains differ)]
  Always-on logic:                      [specify blocks]
  UPF strategy:   [IEEE 1801-2015 — auto-generate from answers above]

── ANALOG / MIXED-SIGNAL ──────────────────────────────────────────────
  AMS blocks (PLL, ADC, DAC, LDO):     [list or none]
  AMS co-simulation required:           [yes / no]
  wreal / RNM models available:         [yes / no]

── TIMING BUDGET ──────────────────────────────────────────────────────
  Top-level timing budget allocation:
    Routing overhead estimate:          [12% of clock period]
    CTS skew estimate:                  [6% of clock period]
    Synthesis margin:                   [20% of clock period]
    Block timing budget = period − routing − CTS − margin
    (auto-calculated and shown for approval)

── PERFORMANCE MODEL ──────────────────────────────────────────────────
  Generate architecture performance model: [yes]
    Estimated throughput (Gbps):         [calculated from algo_spec]
    Estimated latency (cycles):          [calculated from pipeline depth]
    Bus utilization:                     [estimated from bandwidth req]
```

---

## Auto-Generated Architecture Artifacts

```
GENERATING ARCHITECTURE ARTIFACTS:
  ✓ arch/block_diagram.yaml      top-level block list + connectivity
  ✓ arch/clock_domains.yaml      all clocks, frequencies, CDC pairs, ICG policy
  ✓ arch/power_intent.yaml       domain boundaries, AO/retention map → UPF seed
  ✓ arch/memory_map.yaml         address map (→ SystemRDL / IP-XACT)
  ✓ arch/bus_matrix.yaml         master/slave connectivity matrix
  ✓ arch/interface_spec.yaml     IO protocol list with signal widths
  ✓ arch/perf_model.yaml         throughput/latency/bus-util budget
  ✓ arch/timing_budget.yaml      block budgets, synthesis margin targets
  ✓ spec/arch_spec.md            human-readable architecture document

  If AMS blocks present:
  ✓ arch/ams_requirements.yaml   SPICE model list, RNM interface spec
```

---

## Output Artifacts

| Artifact | Path | Consumed By |
|----------|------|-------------|
| Block diagram | `arch/block_diagram.yaml` | skill_04, skill_07 (floorplan) |
| Clock domain spec | `arch/clock_domains.yaml` | skill_04, skill_06, skill_07 |
| Power intent | `arch/power_intent.yaml` | skill_04 (UPF gen), skill_06, skill_07 |
| Memory map | `arch/memory_map.yaml` | skill_04 (RTL regs), skill_05 |
| Timing budget | `arch/timing_budget.yaml` | skill_06_synthesis |
| Performance model | `arch/perf_model.yaml` | skill_05_verification |
| Architecture spec | `spec/arch_spec.md` | Human review |

---

## Output Metrics

```
ARCHITECTURE REVIEW METRICS
────────────────────────────────────────────────────────────────
Metric                       Result        Target      Status
────────────────────────────────────────────────────────────────
CDC pairs identified         <N>           documented  INFO
Power domains                <N>           matches spec ?
SRAM compiler availability   <yes/no>      YES         ?
Address map conflicts        <N>           0           ?
Estimated die area (mm²)     <value>       ≤<spec>     ?
Estimated active power (mW)  <value>       ≤<spec>     ?
Bus utilization (model)      <pct>%        <80%        ?
Arch CDC lint (SpyGlass)     <N> violations 0          ?
Timing budget feasible       <yes/no>      YES         ?
────────────────────────────────────────────────────────────────
Overall: <PASS/FAIL> → GATE-03 request
```

---

## Quality Gate: GATE-03

```
GATE-03 CRITERIA (human approval required):
  □ All blocks identified and owned by RTL engineers
  □ Clock domain diagram complete; all CDC pairs named
  □ Power domain boundaries agreed and documented
  □ Memory map complete (no overlaps)
  □ Timing budget allocated to all blocks (feasibility checked)
  □ Architecture performance model passes spec targets
  □ Arch CDC lint clean (SpyGlass CDC or equivalent)
  □ AMS requirements documented (if applicable)
  □ arch_spec.md reviewed by RTL Lead + Verif Lead

Approvers: Architecture Lead + RTL Lead
```

---

## Iteration Protocol

| Trigger | Action |
|---------|--------|
| Timing budget infeasible (can't close at target) | Reduce clock target; change PDK; or restructure pipeline |
| Area estimate over budget | Split large blocks; reduce memory size; check algo gate count |
| CDC count too high | Reduce async domains; revisit clocking strategy |
| skill_06_synthesis: WNS fail >20% | Return here; revise timing budget allocation per block |
| skill_07_pnr: congestion unresolvable | Return here; revise block floorplan; reduce utilization target |

---

## Memory Write

```yaml
design_requirements:
  clock_domains: [<list>]
  power_domains: [<list>]
execution_history:
  arch_design:
    - timestamp: <ISO8601>
      result: <PASS/FAIL>
      metrics:
        cdc_pairs: <N>
        power_domains: <N>
        est_area_mm2: <value>
        est_power_mw: <value>
      artifacts: [arch/block_diagram.yaml, arch/clock_domains.yaml,
                  arch/power_intent.yaml, arch/timing_budget.yaml]
      gate: GATE-03
```

---

*Previous: [`skill_02_algo_dev.md`](skill_02_algo_dev.md)*
*Next (parallel): [`skill_04_rtl_design.md`](skill_04_rtl_design.md) + [`skill_05_verification.md`](skill_05_verification.md)*
*Index: [`SKILLS_INDEX.md`](SKILLS_INDEX.md)*
