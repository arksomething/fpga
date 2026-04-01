`timescale 1ns/1ps

module cpu_program_smoke_tb;
    reg clk = 0;
    reg reset = 1;

    cpu_top dut (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    initial begin
        integer i;

        // Initialize all instructions to NOP.
        for (i = 0; i < 256; i = i + 1)
            dut.instr_mem.mem[i] = 16'h0000;

        // Program:
        //   r1 = 5
        //   r2 = 3
        //   r3 = r1 + r2      => 8
        //   r4 = r3 - r2      => 5
        //   r5 = r3 & r4      => 0
        //   r6 = r3           => 8
        //   r7 = 10
        //   jmp r7            => skip addresses 8 and 9
        //   r0 = 99           (skipped)
        //   r0 = 77           (skipped)
        //   r0 = 42           (executed after jump)
        dut.instr_mem.mem[0]  = 16'hC20A; // LDI r1, 5
        dut.instr_mem.mem[1]  = 16'hC406; // LDI r2, 3
        dut.instr_mem.mem[2]  = 16'h0650; // ADD r3, r1, r2
        dut.instr_mem.mem[3]  = 16'h18D0; // SUB r4, r3, r2
        dut.instr_mem.mem[4]  = 16'h3AE0; // AND r5, r3, r4
        dut.instr_mem.mem[5]  = 16'h2CC0; // MOV r6, r3
        dut.instr_mem.mem[6]  = 16'hCE14; // LDI r7, 10
        dut.instr_mem.mem[7]  = 16'h4E00; // JMP r7
        dut.instr_mem.mem[8]  = 16'hC0C6; // LDI r0, 99 (skip)
        dut.instr_mem.mem[9]  = 16'hC09A; // LDI r0, 77 (skip)
        dut.instr_mem.mem[10] = 16'hC054; // LDI r0, 42

        $dumpfile("build/cpu_program_smoke_tb.vcd");
        $dumpvars(0, cpu_program_smoke_tb);

        #20 reset = 0;
        #800;

        $display("r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d r6=%0d r7=%0d",
            dut.regs.r[0], dut.regs.r[1], dut.regs.r[2], dut.regs.r[3],
            dut.regs.r[4], dut.regs.r[5], dut.regs.r[6], dut.regs.r[7]);
        $display("pc=%0d ir=0x%04h", dut.pc, dut.ir);

        if (dut.regs.r[1] == 16'd5 &&
            dut.regs.r[2] == 16'd3 &&
            dut.regs.r[3] == 16'd8 &&
            dut.regs.r[4] == 16'd5 &&
            dut.regs.r[5] == 16'd0 &&
            dut.regs.r[6] == 16'd8 &&
            dut.regs.r[0] == 16'd42) begin
            $display("PASS: CPU executed smoke program correctly.");
        end else begin
            $display("FAIL: CPU smoke program result mismatch.");
        end

        $finish;
    end
endmodule
