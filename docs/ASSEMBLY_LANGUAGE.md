# Assembly language reference

This document describes the **textual assembly language** accepted by `assembler/assembler.py` and how it maps to the **16-bit machine encoding** consumed by the CPU in `cpu/`. It is meant to stay aligned with the control unit decode in `cpu/cu.v` and the overview in the repository `README.md`.

---

## 1. Machine model (target architecture)

| Property | Value |
|----------|--------|
| Word size | **16 bits** (instructions and general data) |
| Registers | **`r0`–`r7`**, each 16 bits wide |
| Stack pointer | **`r7`**. Hardware uses **`r7`** implicitly for **`CALL`** / **`RET`** (operand fetch forced to SP in decode) |
| Program counter | **8 bits**, **byte-addressed in units of 16-bit words** (instruction address  `0..255`) |
| Instruction memory | **256 words**, separate from data |
| Data memory | **256 words**, separate from instruction memory |
| Endianness / alignment | One instruction per word; hex files are one **4-digit hex** value per line |

The CPU is pipelined (fetch/decode/execute/memory paths with forwarding, load-use stalls, and branch flush). Those details do not change the **static** encoding described here, but they explain why **load→branch** or **load→ALU** ordering can require an extra cycle.

---

## 2. Source file format (assembler)

- **Encoding:** UTF-8 text.
- **Comments:** A line whose **first non-empty character** would be parsed as comment: lines starting with **`;`** are skipped entirely only if the **first character** of the line is `;` (see assembler: it checks `line[0] != ";"` for blank handling—in practice **put `;` in column 0** for full-line comments).
- **Whitespace:** Instruction lines are split on **single spaces** (`split(" ")`). Operands are **space-separated**; **no commas**.
- **Labels:** A line starting with **`.`** followed by a name defines a label at the **next instruction index** (address of the following non-label line in the emitted stream).

  Example:

  ```asm
  LDI r1 0
  .LOOP
  ADDI r1 r1 1
  BRA LOOP
  ```

  Here **`LOOP`** is bound to the **instruction index** of **`ADDI`** (not the **`LDI`**).

- **Identifiers:** Label names are whatever text follows **`./`** on a label line (trimmed). Use letters; avoid spaces. Matching is **case-sensitive**.

---

## 3. Registers in source vs hardware

| Token | Role in **assembler** | Role in **hardware** |
|-------|----------------------|----------------------|
| **`r0`–`r6`** | Allowed as explicit operands | General-purpose |
| **`r7`** | **Rejected** in `assembler.py` for normal operands (`reg_ok`) | **Stack pointer** for **`CALL`** / **`RET`** |

**Rationale:** Hand-written assembly should not treat **`r7`** as a general register; doing so corrupts the call/return convention.

**RTL note:** **`CALL`** and **`RET`** always read **`r7`** for stack access regardless of register fields in the instruction word; the assembler still encodes a normal **`CALL`** / **`RET`** bit pattern.

---

## 4. Instruction encoding overview

All instructions are **16 bits**:

| Bits | Field (conceptual) |
|------|---------------------|
| `[15:12]` | **Opcode** (4 bit) |
| `[11:0]` | Opcode-specific payload (registers, immediates, offsets) |

The assembler builds a word as **`opcode_base | payload`**, where **`opcode_base`** has only the top nibble set (see `instruction_to_op` in `assembler/assembler.py`).

---

## 5. Operand classes

### 5.1 Three-register (R-style)

**Layout:** `rd(3) | rs1(3) | rs2(3) | 000`

| Bits | Meaning |
|------|--------|
| `[11:9]` | **rd** |
| `[8:6]` | **rs1** |
| `[5:3]` | **rs2** |
| `[2:0]` | **0** (must be zero in RTL encoders) |

**Assembler syntax:**  
`OP rd rs1 rs2`

**Exception — `MOV`:** only two registers are written in source; **`rs2`** is encoded as **`r0`** / index **0**:

```asm
MOV rd rs1
```

This matches the testbench pattern `enc_r(OP_MOV, rd, rs1, 0)`.

### 5.2 Two registers + 6-bit immediate

**Layout:** `rd(3) | rs1(3) | imm6(6)`

| Bits | Meaning |
|------|--------|
| `[11:9]` | **rd** |
| `[8:6]` | **rs1** (or **base** for `LOAD`) |
| `[5:0]` | **imm6** raw 6-bit field |

**Assembler syntax:**  
`LOAD rd base imm6` or `ADDI rd rs1 imm6`

**`LOAD imm6`:** unsigned decimal **`0..63`** and **zero-extended** in hardware.

**`ADDI imm6`:** signed decimal **`-32..31`** and **sign-extended** in hardware.

### 5.3 Branch on register + 9-bit PC-relative offset

**Layout:** `rd(3) | off9(9)`

| Bits | Meaning |
|------|--------|
| `[11:9]` | **rd** (condition register) |
| `[8:0]` | **off9**, **signed**, 9-bit two’s complement in the word |

**Semantics:** Let **`PC_BR`** be the **instruction address** of the branch instruction (the CPU’s pipeline uses the fetch address of that instruction, not `PC+1`, when forming the target). Then:

- **Taken:** **`next_PC = PC_BR + sign_extend(off9)`**
- **`BZ`:** take if **`R[rd] == 0`**
- **`BNZ`:** take if **`R[rd] != 0`**

**Assembler — label form (preferred):**

```asm
BZ rd LABEL
BNZ rd LABEL
```

The assembler computes **`off9 = address(LABEL) - current_instruction_index`** and masks to 9 bits.

**Range:** **`off9`** must fit in **signed 9 bits** (assembler checks `|offset| < 512`, i.e. strictly less than `2^9`; exact usable range from any PC is limited by wrapping—stay within **`±255`** words for sanity on an 8-bit PC).

**Assembler — numeric form** (secondary path, `ro9` in code):  
`BZ rd N` / `BNZ rd N` with decimal **`N`** in **`0..511`** does **not** resolve labels; it emits **`N`** directly into **`off9`** (use only when **`N`** is already the correct encoded offset).

### 5.4 12-bit PC-relative (`BRA`, `CALL`)

**Layout:** `off12(12)` in bits **`[11:0]`**; opcode in **`[15:12]`**.

**Semantics:** Same base as branches: **`next_PC = PC_insn + sign_extend(off12)`** where **`PC_insn`** is the address of the **`BRA`** / **`CALL`** instruction.

**Assembler — label form:**

```asm
BRA LABEL
CALL LABEL
```

**Assembler — numeric form:**  
`CALL -3` or **`BRA`** via the **`o12`** path with a decimal (advanced; **positive** checks in the **`BRA`**-only path may reject large values—prefer **labels**).

**Range:** `|offset| < 4096` (must fit in **12-bit signed** field after masking, i.e. magnitude constraint per assembler).

### 5.5 `JMP`

**Layout:** `000(3) | rs1(3) | 000000(6)`

**Assembler syntax:**  
`JMP rs1`  
**Effect:** **`PC = R[rs1][7:0]`** (low byte of register; 8-bit PC in top).

### 5.6 `STORE`

**Layout:** `000(3) | rs(3) | base(3) | 000(3)`

**Assembler syntax:**  
`STORE rs base`  
**Effect:** **`MEM[R[base]] = R[rs]`** (implemented form in README / RTL).

### 5.7 `LDI`

**Layout:** `rd(3) | imm8(8) | 0` — immediate occupies **`[8:1]`**, **`[0]=0`**.

**Assembler syntax:**  
`LDI rd imm8`  
**`imm8`:** **`0..255`**, zero-extended into **`rd`**.

### 5.8 `RET`, `NOP`

**Layout:** low **12 bits** treated as **0** for **`RET`** in encoders; **`NOP`** is opcode nibble **`0xF`** with don’t-care low bits (assembler leaves low 12 zero).

**Assembler syntax:**  
`RET`  
`NOP`  
(no operands)

**Hardware:** **`RET`** uses **`r7`** for stack; **`RET`** updates **`r7`** as part of the operation.

---

## 6. Instruction set (alphabetic by mnemonic)

Opcode nibble shown as **hex** in the first column (bits **[15:12]**).

| Opc | Mnemonic | Assembly syntax | Operation (semantics) |
|-----|----------|-----------------|------------------------|
| 0 | `ADD` | `ADD rd rs1 rs2` | `R[rd] = R[rs1] + R[rs2]` (unsigned wrap in 16 bits) |
| 1 | `SUB` | `SUB rd rs1 rs2` | `R[rd] = R[rs1] - R[rs2]` |
| 2 | `MOV` | `MOV rd rs1` | `R[rd] = R[rs1]`; encodes `rs2 = 0` |
| 3 | `BRA` | `BRA LABEL` | Unconditional branch: `PC = PC_BRA + off12` |
| 4 | `JMP` | `JMP rs1` | `PC = R[rs1][7:0]` |
| 5 | `BZ` | `BZ rd LABEL` | If `R[rd]==0`, `PC = PC_BZ + off9` |
| 6 | `LOAD` | `LOAD rd base imm6` | `R[rd] = MEM[R[base] + zext(imm6)]` |
| 7 | `STORE` | `STORE rs base` | `MEM[R[base]] = R[rs]` |
| 8 | `CMPEQ` | `CMPEQ rd rs1 rs2` | `R[rd] = (R[rs1]==R[rs2]) ? 1 : 0` |
| 9 | `CMPLT` | `CMPLT rd rs1 rs2` | `R[rd] = ($signed(rs1) < $signed(rs2)) ? 1 : 0` |
| A | `ADDI` | `ADDI rd rs1 imm6` | `R[rd] = R[rs1] + sext(imm6)` |
| B | `BNZ` | `BNZ rd LABEL` | If `R[rd]!=0`, `PC = PC_BNZ + off9` |
| C | `LDI` | `LDI rd imm8` | `R[rd] = zext(imm8)` |
| D | `CALL` | `CALL LABEL` or `CALL offset` | Push **return `PC+1`**, `SP--`, `PC = PC_CALL + off12` |
| E | `RET` | `RET` | Pop return address, `SP++`, jump |
| F | `NOP` | `NOP` | No operation |

**Note:** The physical ALU includes an **`AND`** mode, but there is **no `AND` opcode** in this ISA; **`CMPEQ`** uses **`SUB`** internally for comparison.

---

## 7. Calls, stack, and data memory

- **Stack grows downward** (decrement on **`CALL`**, increment on **`RET`**).
- **`CALL`** stores the **return address** (**next sequential PC**, i.e. **`PC + 1`** of the **`CALL`**) through the memory stage at **`MEM[SP - 1]`**, then updates **`SP ← SP - 1`**.
- **`RET`** loads PC from **`MEM[SP]`**, then **`SP ← SP + 1`** (exact RTL ordering is in `cu.v` / README).

Programmers must initialize **`r7`** to a valid region of **data** memory before **`CALL`** if using software stacks (see recursive Fibonacci test for an example of setting SP via **`LDI`** into **`r7`** in hand-written benches—your **text assembler forbids naming `r7`**, so bootstrap code for SP may need **macro support** or **raw hex** unless the rule is relaxed).

---

## 8. Output: `program.hex`

- **Format:** one **4-character hex** line per word, uppercase, no **`0x`** prefix (e.g. `C20E`).
- **Length:** assembler emits **256** lines for simulation convenience: real instructions first, then **`F000`** (**`NOP`**) padding.
- **Load path:** `cpu/memory.v` uses **`$readmemh("program.hex", mem)`** relative to the **simulator’s current working directory**. The test script runs **`vvp` from `cpu/build/`** after assembling into **`cpu/build/program.hex`**.

**Default assembler paths** (see `assembler.py`):

- **Input:** `<repo>/assembly.txt`
- **Output:** `<repo>/cpu/build/program.hex`

Optional CLI:

```bash
python3 assembler/assembler.py [path/to.asm] [path/to.hex]
```

---

## 9. Limitations and sharp edges

1. **`r7` in source:** Disallowed by policy in the assembler; RTL still uses **`r7`** for **`CALL`/`RET`**.
2. **Tokenizer:** **Spaces only** between operands; multiple spaces can create **empty tokens** and break parsing (keep one space between fields).
3. **No include / macro / expression** in the assembler.
4. **Label-forward references** are OK; **undefined labels** fail at resolve time.
5. **`STORE`** in README historically mentions an offset form; the **implemented** encoding is **`MEM[R[base]]`** only—match **`STORE rs base`**.
6. **Signed immediates** on **`BRA`/`CALL`/`BZ`/`BNZ`**: use **labels** so the assembler computes two’s-complement offsets; **numeric `BZ`/`BNZ`** path is **unsigned 0..511** in the `ro9` handler—prefer **label form** for clarity.

---

## 10. Complete small example (iterative Fibonacci)

This matches the spirit of `assembly.txt` / `cpu_fib_iterative_tb`:

```asm
; Iterative fibonacci: n in r1, result in r0 (fib(7) == 13)
LDI r1 7
LDI r2 0
LDI r3 1
LDI r4 1
.LOOP
CMPLT r6 r4 r1
BZ r6 EXIT
ADD r5 r2 r3
MOV r2 r3
MOV r3 r5
ADDI r4 r4 1
BRA LOOP
.EXIT
MOV r0 r3
```

After assembly, **`R[0]`** should hold **13** for **`n = 7`** when run on the CPU simulation with enough cycles.

---

## 11. See also

- `README.md` — repository overview and short ISA summary  
- `cpu/cu.v` — decode, pipeline control, and branch/CALL semantics  
- `assembler/assembler.py` — authoritative for **text syntax** and **label resolution**  
- `cpu/test/cpu_asm_fib_e2e_tb.v` — assembler → hex → CPU smoke test  
