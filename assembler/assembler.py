import sys
from pathlib import Path

# assembler/assembler.py -> repo root (fpga/)
_REPO_ROOT = Path(__file__).resolve().parent.parent
_DEFAULT_ASM = _REPO_ROOT / "assembly.txt"
# memory.v loads program.hex from the simulation cwd; run_cpu_tests.sh uses cpu/build/
_DEFAULT_HEX = _REPO_ROOT / "cpu" / "build" / "program.hex"

asm_path = Path(sys.argv[1]) if len(sys.argv) > 1 else _DEFAULT_ASM
hex_path = Path(sys.argv[2]) if len(sys.argv) > 2 else _DEFAULT_HEX

hex_path.parent.mkdir(parents=True, exist_ok=True)

with open(asm_path, "r", encoding="utf-8") as f:

    label_to_line = {}
    ir = []
    for line in f:
        if len(line) > 0 and line[0] != ";": 
            # print(line)
            if line[0] != '.':
                ir.append(line.strip())
            else:
                label_to_line[line[1:].strip()] = len(ir)

    print(ir)
    print(label_to_line)

    instruction_to_op = {
        # --- rd(3) rs1(3) rs2(3) pad(3)=0 — three registers ---
        "ADD": 0b0000_0000_0000_0000,
        "SUB": 0b0001_0000_0000_0000,
        "MOV": 0b0010_0000_0000_0000,
        "CMPEQ": 0b1000_0000_0000_0000,
        "CMPLT": 0b1001_0000_0000_0000,

        # --- rd(3) rs1(3) imm6(6) — two registers + 6-bit imm ---
        "LOAD": 0b0110_0000_0000_0000,
        "ADDI": 0b1010_0000_0000_0000,

        # --- rd(3) off9(9) signed — compare/branch uses reg + 9-bit offset ---
        "BZ": 0b0101_0000_0000_0000,
        "BNZ": 0b1011_0000_0000_0000,

        # --- off12(12) signed — PC-relative offset only (whole low 12) ---
        "BRA": 0b0011_0000_0000_0000,
        "CALL": 0b1101_0000_0000_0000,

        # --- other layouts (not the four buckets above) ---
        "JMP": 0b0100_0000_0000_0000,   # pad(3) rs1(3) zero(6)
        "STORE": 0b0111_0000_0000_0000,  # pad(3) rs(3) base(3) pad(3)
        "LDI": 0b1100_0000_0000_0000,  # rd(3) imm8(8) LSB=0
        "RET": 0b1110_0000_0000_0000,  # low 12 = 0; uses SP in hardware
        "NOP": 0b1111_0000_0000_0000,  # low 12 = 0
    }

    rrr = set(["ADD", "SUB", "MOV", "CMPEQ", "CMPLT"])
    rri = set(["LOAD", "ADDI"])
    ro9 = set(["BZ", "BNZ"])
    o12 = set(["BRA"])
    nan = set(["RET", "NOP"])
    output = []
    breaks = set(["BZ", "BRA", "BNZ"])
    def reg_ok(tok: str, idx: int) -> bool:
        # r7 is SP (CALL/RET); using it as a normal operand breaks the stack model.
        return tok.startswith("r") and 0 <= idx <= 6

    for i, line in enumerate(ir):  # compute br, bz, bra offsets
        line_fields = line.strip().split(" ")
        cur_instruction = instruction_to_op[line_fields[0]]
        opcode = line_fields[0]
        if opcode in breaks:
            label = line_fields[1] if opcode == "BRA" else line_fields[2]
            offset = label_to_line[label] - i
            if opcode == "BRA" and abs(offset) >= 2**12 or opcode != "BRA" and abs(offset) >= 2**9:
                print("OFFSET TOO MUCH")
                break
            if opcode == "BRA":
                cur_instruction |= offset & 0xFFF
            else:
                reg_tok = line_fields[1]
                register_index = int(reg_tok[1:])
                if not reg_ok(reg_tok, register_index):
                    print("invalid register (r0-r6 only; r7 is SP)")
                    break
                cur_instruction |= (register_index << 9) | (offset & 0x1FF)
        elif opcode == "CALL":
            if len(line_fields) < 2:
                print("CALL needs a label or offset")
                break
            target = line_fields[1]
            if target in label_to_line:
                offset = label_to_line[target] - i
            else:
                offset = int(target)
            if abs(offset) >= 2**12:
                print("OFFSET TOO MUCH")
                break
            cur_instruction |= offset & 0xFFF
        elif opcode in rrr:
            rd = int(line_fields[1][1:])
            rs1 = int(line_fields[2][1:])
            if opcode == "MOV":
                rs2 = 0
                rs2_tok = "r0"
            else:
                rs2 = int(line_fields[3][1:])
                rs2_tok = line_fields[3]
            if (
                not reg_ok(line_fields[1], rd)
                or not reg_ok(line_fields[2], rs1)
                or not reg_ok(rs2_tok, rs2)
            ):
                print("invalid register (r0-r6 only; r7 is SP)")
                break
            cur_instruction |= (rd << 9) | (rs1 << 6) | (rs2 << 3)
        elif opcode in rri:
            rd = int(line_fields[1][1:])
            rs1 = int(line_fields[2][1:])
            imm6 = int(line_fields[3])
            if not reg_ok(line_fields[1], rd) or not reg_ok(line_fields[2], rs1):
                print("invalid register (r0-r6 only; r7 is SP)")
                break
            if imm6 > 63:
                print("imm6 too big")
                break
            cur_instruction |= imm6 | (rs1 << 6) | (rd << 9)
        elif opcode in ro9:
            rd = int(line_fields[1][1:])
            off9 = int(line_fields[2])
            if not reg_ok(line_fields[1], rd):
                print("invalid register (r0-r6 only; r7 is SP)")
                break
            if off9 > 511:
                print("off9 too big")
                break
            cur_instruction |= off9 | (rd << 9)
        elif opcode in o12:
            off12 = int(line_fields[1])
            if off12 > 4095:
                print("off12 too big")
                break
            cur_instruction |= off12 & 0xFFF
        elif opcode == "JMP":
            rs1 = int(line_fields[1][1:])
            if not reg_ok(line_fields[1], rs1):
                print("invalid register (r0-r6 only; r7 is SP)")
                break
            cur_instruction |= rs1 << 6
        elif opcode == "STORE":
            rs = int(line_fields[1][1:])
            base = int(line_fields[2][1:])
            if not reg_ok(line_fields[1], rs) or not reg_ok(line_fields[2], base):
                print("invalid register (r0-r6 only; r7 is SP)")
                break
            cur_instruction |= (rs << 6) | (base << 3)
        elif opcode == "LDI":
            rd = int(line_fields[1][1:])
            imm8 = int(line_fields[2])
            if not reg_ok(line_fields[1], rd):
                print("invalid register (r0-r6 only; r7 is SP)")
                break
            if imm8 > 255:
                print("imm8 too big")
                break
            cur_instruction |= (rd << 9) | (imm8 << 1)
        elif opcode in nan:
            pass  # low 12 bits stay 0
        output.append(cur_instruction)

with open(hex_path, "w", encoding="utf-8") as f:
    for w in output:
        f.write(f"{w:04X}\n")
    for i in range(256 - len(output)):
        f.write(f"F000\n")

print(f"Assembled {asm_path} -> {hex_path} ({len(output)} instructions)")