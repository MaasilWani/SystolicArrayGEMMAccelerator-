# Systolic Array GEMM Accelerator on Arty A7

This repository contains a hardware/software co-design project implementing a small matrix-multiplication accelerator on the Digilent Arty A7-100T FPGA.

The system integrates a 4x4 INT8 systolic array accelerator with a MicroBlaze V soft processor using Vivado block design and Vitis bare-metal software. The MicroBlaze writes input matrices to shared BRAM, programs memory-mapped control registers, launches the accelerator, polls for completion, and verifies the output through UART.

## Software Version
Vivado/Vitis 2025.2

## Project Summary

Matrix multiplication is a core operation in neural networks, scientific computing, DSP, and many embedded workloads. General-purpose processors often spend significant time moving data between memory and arithmetic units. This project explores a systolic-array accelerator where operands are reused inside a grid of processing elements, reducing repeated memory accesses and improving throughput for small matrix operations.

The implemented design supports:

- 4x4 INT8 matrix multiplication
- INT32 accumulation/output
- MicroBlaze-controlled accelerator execution
- Shared dual-port BRAM communication
- AXI-Lite control/status registers
- UART-based debug output
- 16x16 tiled GEMM using repeated 4x4 accelerator calls

## Hardware Platform

- Board: Digilent Arty A7-100T
- FPGA: Xilinx Artix-7
- Processor: MicroBlaze V soft processor
- System clock: 100 MHz
- Design tools: Vivado and Vitis

## System Architecture

The Vivado block design contains:

- MicroBlaze V processor
- Local instruction/data memory
- AXI SmartConnect
- AXI BRAM Controller
- Dual-port Block RAM
- AXI UartLite
- MicroBlaze Debug Module, MDM
- Custom AXI-Lite Control Registers IP
- Custom systolic-array accelerator wrapper

The processor accesses shared BRAM through the AXI BRAM Controller. The accelerator accesses the second port of the same BRAM directly. This allows the processor to prepare input data and later read output data while the accelerator performs computation using the shared memory.

## Repository Structure

```text
.
├── vivado/
│   ├── scripts/
│   │   ├── recreate_project.tcl
│   │   └── block_design.tcl
│   ├── constraints/
│   │   └── <board_constraints>.xdc
│   └── ip_repo/
│       └── <custom_ip_folders>
├── vitis/
│   └── app_src/
│       └── main.c
├── docs/
├── .gitignore
└── README.md
```

## Memory Map

The integrated MicroBlaze system uses the following memory map:

| Peripheral | Base Address | Size |
|---|---:|---:|
| Local Memory, DLMB/ILMB | `0x00000000` | 16 KB |
| Control Registers | `0x80000000` | 4 KB |
| AXI BRAM Controller | `0xC0000000` | 16 KB |
| AXI UartLite | `0x40600000` | 64 KB |

In the Vitis application, these addresses are accessed through `xparameters.h`, for example:

```c
#define DMEM_EXT   XPAR_AXI_BRAM_0_BASEADDRESS
#define CTRL_BASE  XPAR_CTRL_REGS_FSM_0_BASEADDR
```

## Shared BRAM Layout

The tested software uses the following offsets inside the shared BRAM:

| Region | Offset | Purpose |
|---|---:|---|
| Matrix A | `0x00000000` | Input matrix A |
| Matrix B | `0x00000040` | Input matrix B |
| Matrix C | `0x00000100` | Output/result matrix C |

For the 4x4 accelerator, each row or column is packed into one 32-bit word containing four INT8 values.

Matrix A is packed row-wise. Matrix B is packed column-wise/pre-transposed so that the systolic array can consume the data in the expected order.

Example:

```c
Xil_Out32(DMEM_EXT + A_BASE + 0x00, 0x01020304);
Xil_Out32(DMEM_EXT + A_BASE + 0x04, 0x05060708);
Xil_Out32(DMEM_EXT + A_BASE + 0x08, 0x090A0B0C);
Xil_Out32(DMEM_EXT + A_BASE + 0x0C, 0x0D0E0F10);
```

## Control Register Map

The custom AXI-Lite control-register IP exposes the following register interface:

| Offset | Access | Name | Description |
|---:|---|---|---|
| `0x00` | Write | `src_a_addr` | BRAM offset for Matrix A |
| `0x04` | Write | `src_b_addr` | BRAM offset for Matrix B |
| `0x08` | Write | `dst_addr` | BRAM offset for Matrix C/result |
| `0x10` | Write | `go` | Start accelerator |
| `0x14` | Read | `ack` | Accelerator acknowledged start |
| `0x18` | Read | `busy` | Accelerator currently running |
| `0x1C` | Read | `done` | Sticky completion flag |

Typical accelerator launch sequence:

```c
Xil_Out32(CTRL_BASE + 0x00, A_BASE);
Xil_Out32(CTRL_BASE + 0x04, B_BASE);
Xil_Out32(CTRL_BASE + 0x08, C_BASE);

Xil_Out32(CTRL_BASE + 0x10, 0x00000001);

while (!Xil_In32(CTRL_BASE + 0x1C));
```

## Vitis Software Tests

The Vitis `main.c` file contains multiple test programs. Only one `main()` should be active at a time.

Implemented tests include:

1. Basic 4x4 accelerator correctness test  
   Writes known 4x4 matrices to BRAM, starts the accelerator, polls `done`, and prints the result over UART.

2. Empty-loop cycle counter test  
   Uses the RISC-V `rdcycle` CSR to verify cycle-count measurement.

3. 4x4 software matrix multiply  
   Runs a reference C implementation on the MicroBlaze for comparison.

4. 4x4 hardware benchmark  
   Measures accelerator execution time for one 4x4 matrix multiply.

5. 16x16 software matrix multiply  
   Computes a full 16x16 matrix multiplication on the processor.

6. 16x16 tiled hardware GEMM  
   Decomposes a 16x16 multiply into 64 repeated 4x4 accelerator calls and accumulates partial results in software.

## Output Ordering Note

The hardware returns the 4x4 result matrix in a reversed/transposed order. The software compensates for this while reading results from BRAM.

For each output index:

```c
local_row = 3 - (idx % 4);
local_col = 3 - (idx / 4);
```

In the 16x16 tiled GEMM test, the tile placement is also adjusted in software based on the observed hardware output order.

## Evaluation Results

The final integrated system was tested at 100 MHz on the Arty A7-100T.

| Test | Cycles | Speedup |
|---|---:|---:|
| Software 4x4 matrix multiply | 7,720 | 1x |
| Hardware 4x4 matrix multiply | 164 | 47x |
| Software 16x16 matrix multiply | 496,312 | 1x |
| Hardware 16x16 tiled GEMM | 235,021 | 2.1x |

The 4x4 accelerator achieves a large speedup because the systolic array computes the output through a parallel pipeline. The 16x16 tiled version still improves performance, but the speedup is limited by software-managed tiling overhead, repeated AXI transactions, polling, and BRAM reads/writes.

## Resource Utilization

Approximate utilization for the complete design:

| Module | LUTs | Registers | F7 Muxes |
|---|---:|---:|---:|
| Systolic Array | 2157 | 766 | 48 |
| FSM Controller | 117 | 264 | 0 |
| Accelerator Wrapper | 2447 | 1872 | 48 |
| Control Registers | 48 | 136 | 0 |
| MicroBlaze V | 1606 | 1317 | 88 |
| MDM | 143 | 199 | 5 |
| AXI SmartConnect | 397 | 463 | 1 |
| AXI BRAM Controller | 150 | 169 | 0 |
| AXI UartLite | 92 | 111 | 10 |
| Total | 4917 | 4329 | 157 |

## Recreate Vivado Project

The recommended way to recreate the Vivado design from this repository is to create a fresh Vivado project and source the saved block design Tcl script.

Do **not** rely only on `recreate_project.tcl` unless the source paths have been cleaned, because the exported project Tcl may contain machine-specific paths from the original Vivado project.

### 1. Create a fresh Vivado project

Open Vivado and create a new RTL project:

```text
Project name: systolic_array_T3_recreated
Project location: <repo_root>
Board/Part: Arty A7-100T / xc7a100tcsg324-1
```

Choose:

```text
Do not specify sources at this time
```

### 2. Add the custom IP repository

In the Vivado Tcl Console, run:

```tcl
set_property ip_repo_paths <repo_root>/vivado/ip_repo [current_project]
update_ip_catalog
```

Example on Windows:

```tcl
set_property ip_repo_paths C:/Users/maasi/Desktop/SystolicArrayGEMMAccelerator-/vivado/ip_repo [current_project]
update_ip_catalog
```

### 3. Recreate the block design

Run:

```tcl
source <repo_root>/vivado/scripts/block_design.tcl
```

Example:

```tcl
source C:/Users/maasi/Desktop/SystolicArrayGEMMAccelerator-/vivado/scripts/block_design.tcl
```

Then run:

```tcl
validate_bd_design
save_bd_design
```

### 4. Add constraints

Add the board constraint file from:

```text
vivado/constraints/
```

In Vivado:

```text
Add Sources → Add or Create Constraints
```

### 5. Generate the design

After the block design validates:

```text
Generate Output Products
Create HDL Wrapper
Run Synthesis
Run Implementation
Generate Bitstream
Export Hardware
```

When exporting hardware for Vitis, select:

```text
Include bitstream
```

## Running the Vitis Application

1. Export the Vivado hardware platform.
2. Open Vitis.
3. Create a bare-metal application for the exported MicroBlaze platform.
4. Copy/import the files from:

```text
vitis/app_src/
```

5. Build the application.
6. Program the FPGA.
7. Run the application on the MicroBlaze.
8. Open a UART terminal to observe printed results.

## Current Limitations

- Accelerator supports fixed 4x4 INT8 input tiles.
- Outputs are INT32 values.
- Larger matrices require software tiling.
- The 16x16 tiled implementation uses 64 accelerator calls.
- Processor-managed data movement creates significant overhead.
- Current software uses polling instead of interrupts.
- No DMA engine is currently used.

## Possible Future Improvements

- Add DMA support to reduce processor-managed BRAM transfers.
- Use interrupts instead of polling the `done` register.
- Increase systolic array size beyond 4x4.
- Add support for larger matrix dimensions directly in hardware.
- Improve output ordering to reduce software-side reshuffling.
- Add automated test scripts and UART output logs.
- Add support for signed INT8 test cases and saturation/overflow analysis.

## Authors

Project team: The Dot Product

- Maasil Wani
- Linda Mendez
- Wayne Hsieh
- Tyler Lee
- Niels van Ritbergen
- Daniel Arnold

## Notes

Generated Vivado and Vitis build files are intentionally not tracked in Git. This repository is intended to store the source files, custom IP, constraints, Tcl recreation scripts, and tested Vitis application code.
