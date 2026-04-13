# Neural Network ASIC — RGB Color Classifier

A full custom ASIC implementation of a feedforward neural network designed to classify RGB pixel data as either **white** or **black**. The design originates from an FPGA reference implementation (VHDL) and is being re-implemented in Verilog for RTL simulation, logic synthesis, transistor-level schematic design, and physical layout — targeting tapeout readiness.

---

## Project Overview

The neural network consists of:
- **3 hidden neurons**, each receiving 8-bit R, G, B pixel inputs
- **1 output neuron**, receiving the 3 hidden layer outputs
- **Sigmoid activation** implemented as a 16,384-entry ROM lookup table (14-bit address → 8-bit output)
- **Color mapper** that thresholds the output neuron (>127 → white pixel, ≤127 → black pixel)

Each neuron computes a weighted sum of its inputs (multiply-accumulate with bias), passes the result through a saturating clamp, and looks up the sigmoid activation in a ROM. The pipeline has a **15-cycle end-to-end latency**.

The design follows a standard ASIC flow:
1. High-level behavioral modeling
2. RTL design in Verilog + simulation in Cadence Xcelium
3. Transistor-level schematic in Cadence Virtuoso
4. Physical layout with DRC/LVS verification

---

## Repository Structure

```
.
├── README.md
│
├── docs/
│   ├── block_diagram.png          # System-level block diagram of the neural network
│   ├── neuron_diagram.png         # Implementation diagram of a single neuron
│   ├── Project2Goals.png          # Project milestone 2 goals
│   ├── Project3Goals.png          # Project milestone 3 goals
│   ├── Project4Goals.png          # Project milestone 4 goals
│   └── xceliumSCUG.pdf            # Cadence Xcelium Simulator User Guide (reference)
│
├── verilog/
│   ├── neuron.v                   # Top-level neuron module (pipelined, 7-cycle latency)
│   ├── nn_top.v                   # Full neural network top-level (hidden + output layers + color mapper)
│   ├── color_mapper.v             # Output color decision block (>127 → white, else black)
│   ├── r_multiplier_r.v           # Registered multiplier (input reg → multiply → output reg)
│   ├── adder_r.v                  # Registered adder
│   ├── clamp_shift_r.v            # Saturating clamp + right-shift + register (produces ROM address)
│   ├── sat_clamp.v                # Combinational saturating clamp (maps signed sum to 14-bit ROM addr)
│   ├── sigmoid_lut.v              # Synthesizable sigmoid ROM (pure case statement, no $exp)
│   ├── sigmoid_rom.v              # Behavioral sigmoid ROM (uses $exp for simulation accuracy)
│   └── register.v                 # Generic D flip-flop register (parameterized width)
│
├── testbench/
│   ├── tb_neuron.v                # Testbench for the individual neuron module
│   ├── tb_nn_top.v                # Testbench for the full neural network top-level
│   ├── tb_color_mapper.v          # Testbench for the color mapper block
│   ├── tb_sigmoid_rom.v           # Testbench for the sigmoid ROM lookup table
│   └── tb_sat_clamp.v             # Testbench for the saturating clamp block
│
├── sim/
│   ├── hdl.var                    # Xcelium environment configuration (LIB_MAP, VIEW_MAP, XRUNOPTS)
│   ├── cds.lib                    # Cadence library definitions file
│   ├── run_sim.sh                 # Shell script to compile and simulate with xrun
│   └── waves/                     # Simulation waveform output files (.shm / .vcd)
│
├── synthesis/
│   ├── constraints.sdc            # Synthesis timing constraints (clock period, I/O delays)
│   ├── genus_script.tcl           # Cadence Genus synthesis script
│   ├── netlist/
│   │   └── nn_top_netlist.v       # Gate-level netlist output from synthesis
│   └── reports/
│       ├── timing_report.txt      # Post-synthesis timing report
│       ├── area_report.txt        # Post-synthesis area report
│       └── power_report.txt       # Post-synthesis power report
│
├── schematic/
│   ├── virtuoso_lib/              # Cadence Virtuoso library directory (sub-block schematics)
│   │   ├── neuron/                # Transistor-level neuron schematic cell
│   │   ├── multiplier/            # Transistor-level multiplier schematic cell
│   │   ├── adder/                 # Transistor-level adder schematic cell
│   │   ├── clamp/                 # Transistor-level clamp schematic cell
│   │   └── sigmoid_rom/           # Transistor-level ROM schematic cell
│   └── sim_results/               # Virtuoso ADE simulation results and plots
│
└── layout/
    ├── floorplan/                 # Floor-planning files and area estimates
    ├── sub_blocks/                # Individual sub-block layouts (DRC/LVS clean)
    ├── system/                    # Full system-level integrated layout
    ├── drc/                       # DRC run decks and error reports
    ├── lvs/                       # LVS run decks and comparison reports
    └── extracted_netlist/         # Post-layout extracted netlist for final simulation
```

---

## Design Hierarchy

```
nn_top
├── HIDDEN0  : neuron           ← R_IN, G_IN, B_IN → h0_out
│   ├── MUL1 : r_multiplier_r
│   ├── MUL2 : r_multiplier_r
│   ├── MUL3 : r_multiplier_r
│   ├── ADD1 : adder_r
│   ├── ADD2 : adder_r
│   ├── ADD3 : adder_r
│   ├── CL   : clamp_shift_r
│   └── ROM  : ROM_r  (sigmoid LUT)
├── HIDDEN1  : neuron           ← R_IN, G_IN, B_IN → h1_out
├── HIDDEN2  : neuron           ← R_IN, G_IN, B_IN → h2_out
├── OUTPUT0  : neuron           ← h0_out, h1_out, h2_out → nn_out
└── MAPPER   : color_mapper     ← nn_out → R_OUT, G_OUT, B_OUT
```

**Pipeline latency:** 15 clock cycles (7 hidden + 7 output + 1 color mapper)

---

## Tools & Flow

| Phase | Tool | Description |
|---|---|---|
| RTL Simulation | Cadence Xcelium (`xrun`) | Compile and simulate Verilog RTL and testbenches |
| Logic Synthesis | Cadence Genus | Synthesize RTL to gate-level netlist |
| Schematic Design | Cadence Virtuoso | Transistor-level schematic entry and ADE simulation |
| Physical Layout | Cadence Virtuoso Layout | Full-custom layout, DRC, LVS, parasitic extraction |

---

## Neuron Pipeline Stages

| Stage | Block | Latency |
|---|---|---|
| 1 | Input register + 3× multiply + output register | 2 cycles |
| 2 | 3× registered adder (pairwise then final sum) | 3 cycles |
| 3 | Saturating clamp + shift + register | 1 cycle |
| 4 | Sigmoid ROM read + registered output | 1 cycle |
| **Total** | | **7 cycles** |

---

## Weights & Biases

Weights are hardcoded as signed 32-bit integer parameters (fixed-point, scale factor implicit). Values are taken directly from the trained FPGA reference model (`FPGA_plain/nn_rgb.vhd`).

| Neuron | W1 | W2 | W3 | BIAS |
|---|---|---|---|---|
| Hidden 0 | +29 | -45 | -87 | -18227 |
| Hidden 1 | -361 | +126 | +371 | +2845 |
| Hidden 2 | -313 | +96 | +337 | +4513 |
| Output 0 | +51 | -158 | -129 | +41760 |

---

## Milestone Goals

**Project 2** — Architecture definition, Cadence symbol creation, high-level Verilog/AMS modeling, Virtuoso/Xcelium validation, block ownership assignment.

**Project 3** — Transistor-level schematic implementation in Virtuoso, sub-block and system-level schematic simulation, layout floor-planning, IO location and routing strategy definition.

**Project 4** — Sub-block and system-level layout, DRC/LVS verification at both levels, final simulation from extracted netlist, performance comparison against schematic, tapeout readiness summary.

---

## Running Simulations

```bash
# Compile and simulate the full neural network testbench
cd sim/
xrun -f run_sim.sh

# Or manually:
xrun ../verilog/*.v ../testbench/tb_nn_top.v -top tb_nn_top -access +rwc -gui
```

See `sim/hdl.var` for library and view configuration details. Refer to `docs/xceliumSCUG.pdf` for full Xcelium simulator documentation.

---

## Authors

ECE Senior Design Team — UC San Diego
