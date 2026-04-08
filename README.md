# FPGA Workspace (CPU-focused)

This repository is mainly a small custom CPU project for FPGA experiments.
If your current goal is CPU work, treat `blink/` as optional scaffolding.

## Repository layout

- `cpu/` - current RTL, simulation benches, and test runner
- `cpu/test/` - self-checking CPU testbenches
- `cpu_original/` - older reference implementation kept for comparison
- `blink/` - optional standalone LED blinker reference project

## Current CPU

- 16-bit instructions and 16-bit register/data path
- 8 general-purpose 16-bit registers, `r0` through `r7`
- `r7` is used as the stack pointer for `CALL` and `RET`
- 8-bit instruction pointer and 256-word address space
- separate instruction and data memories, both backed by `cpu/memory.v`
- pipelined control with forwarding, load-use stalls, branch handling, and stack-based call/return

Current RTL files:

- `cpu/cpu.v` - top-level CPU wiring
- `cpu/cu.v` - control unit and pipeline control
- `cpu/register.v` - 8 x 16-bit register file with same-cycle read-after-write bypass
- `cpu/memory.v` - 256 x 16-bit memory with combinational read
- `cpu/alu.v` - 16-bit ALU core (`ADD`, `SUB`, `AND`, `NOP`)

`cpu/memory.v` loads `program.hex` from the current working directory at simulation time. When running `vvp`, make sure a `program.hex` exists in that working directory, or use the provided test runner which generates a default image in `cpu/build/`.

## ISA

Full **assembly syntax** (labels, encodings, `program.hex`): [`docs/ASSEMBLY_LANGUAGE.md`](docs/ASSEMBLY_LANGUAGE.md).

Instruction width: 16 bits

Arithmetic and data movement:

- `0000` `ADD rd, rs1, rs2`
  `R[rd] = R[rs1] + R[rs2]`
- `0001` `SUB rd, rs1, rs2`
  `R[rd] = R[rs1] - R[rs2]`
- `0010` `MOV rd, rs1`
  `R[rd] = R[rs1]`
- `0110` `LOAD rd, [base + imm6]`
  `R[rd] = MEM[R[base] + zero_extend(imm6)]`
- `0111` `STORE rs, [base]`
  Current implemented form: `MEM[R[base]] = R[rs]`
- `1010` `ADDI rd, rs1, imm6`
  `R[rd] = R[rs1] + sign_extend(imm6)` where `imm6` is `-32..31`
- `1100` `LDI rd, imm8`
  `R[rd] = zero_extend(imm8)`
  Current encoding uses bits `[8:1]` for `imm8`

Compare and branch:

- `1000` `CMPEQ rd, rs1, rs2`
  `R[rd] = 1` when `R[rs1] == R[rs2]`, else `0`
- `1001` `CMPLT rd, rs1, rs2`
  `R[rd] = 1` when `$signed(R[rs1]) < $signed(R[rs2])`, else `0`
- `0011` `BRA off12`
  `PC = PC + off12`
- `0100` `JMP rs1`
  `PC = R[rs1]`
- `0101` `BZ rd, off9`
  branch when `R[rd] == 0`
- `1011` `BNZ rd, off9`
  branch when `R[rd] != 0`

Calls and returns:

- `1101` `CALL off12`
  push return address (`PC + 1`) onto the stack, decrement `r7`, then jump to `PC + off12`
- `1110` `RET`
  pop the return address from the stack, increment `r7`, then jump to the popped address
- `1111` `NOP`
  no operation

The stack grows downward. `CALL` stores the return address to `MEM[SP - 1]` and then writes back `SP - 1`. `RET` reads the return address from `MEM[SP]`, redirects the PC to that value, and then writes back `SP + 1`.

## Simulation and tests

Run the full CPU regression suite from the repository root:

```bash
bash cpu/test/run_cpu_tests.sh
```

This runner builds and executes the current self-checking benches:

- `cpu_edge_cases_tb` - forwarding, stalls, and branch/jump edge cases
- `cpu_program_smoke_tb` - mixed instruction smoke program
- `cpu_call_stack_tb` - nested `CALL` and `RET`
- `cpu_fib_iterative_tb` - iterative Fibonacci program
- `cpu_fib_recursive_tb` - recursive Fibonacci program

The runner creates `cpu/build/program.hex` automatically so `memory.v` has a default image to load before each testbench overrides memory contents.

If you want to compile the current CPU manually, use:

```bash
iverilog -g2012 -o /tmp/fpga_cpu.out \
  cpu/cpu.v cpu/cu.v cpu/register.v cpu/memory.v cpu/alu.v
```

## Gowin project files

- `cpu/cpu.gprj` - main CPU project
- `blink/blink.gprj` - optional blink project
