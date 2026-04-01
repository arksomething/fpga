# FPGA Workspace (CPU-focused)

This repository is mainly a small custom CPU project for a Gowin FPGA target.
If your current goal is CPU work, treat `blink/` as optional scaffolding.

## Repository layout

- `cpu/` - main project (RTL + testbenches)
- `blink/` - optional standalone LED blinker reference project

## CPU project overview

The CPU is centered around `cpu/src/cpu_top.v` and currently includes:

- `alu.v` - 16-bit ALU (`ADD`, `SUB`, `AND`, `NOP`)
- `cu.v` - control unit/FSM for instruction decode and execute
- `register_file.v` - 8 x 16-bit register file
- `memory.v` - 256 x 16-bit synchronous memory with `$readmemh("program.hex", mem)`
- `cpu_top.v` - ties PC, IR, CU, register file, ALU, and instruction memory together

Vendor-generated Gowin pROM files exist in `cpu/src/gowin_prom/`, but `cpu_top.v` is currently wired to `memory.v` for instruction fetch.

## ISA (current)

Instruction width: 16 bits

- `0000` `ADD rd, rs1, rs2`
- `0001` `SUB rd, rs1, rs2`
- `0010` `MOV rd, rs1`
- `0011` `AND rd, rs1, rs2`
- `0100` `JMP rs1`
- `0101` `JZ rs1`
- `1100` `LDI rd, imm8`

Reference decode is documented in `cpu/src/cu.v`.

## Simulation quick start

Run from `cpu/`:

```bash
cd cpu
mkdir -p build
iverilog -g2012 -o build/alu_tb src/alu.v test/alu_tb.v
vvp build/alu_tb
```

For full CPU simulation:

```bash
iverilog -g2012 -o build/cpu_tb \
  src/alu.v src/cu.v src/cpu_top.v src/memory.v src/register_file.v \
  test/cpu_tb.v
vvp build/cpu_tb
```

`cpu/program.hex` is included with a default `0000` word so simulation starts without a missing-file error. Replace it with your own instruction stream (one 16-bit hex word per line). If the file has fewer than 256 words, Icarus may print a "Not enough words" warning from `$readmemh`; this is expected.

## Gowin project files

- `cpu/cpu.gprj` (main project)
- `blink/blink.gprj` (optional blink project)

The `cpu/cpu.gprj` testbench path is set to `test/cpu_tb.v` to match the repository layout.
