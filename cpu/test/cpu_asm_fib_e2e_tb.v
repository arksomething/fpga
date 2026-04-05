`timescale 1ns/1ps

// E2E: assemble assembly.txt -> cpu/build/program.hex, then simulate without
// overwriting instruction memory (same checks as cpu_fib_iterative_tb).

module cpu_asm_fib_e2e_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;

    cpu dut (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            dut.data_memory.mem[i] = 16'h0000;

        for (i = 0; i < 8; i = i + 1)
            dut.register_file.r[i] = 16'h0000;

        repeat (2) begin
            @(posedge clk);
            #1;
        end

        reset = 1'b0;

        repeat (80) begin
            @(posedge clk);
            #1;
        end

        $display("e2e asm fib: r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d r6=%0d",
            dut.register_file.r[0], dut.register_file.r[1], dut.register_file.r[2],
            dut.register_file.r[3], dut.register_file.r[4], dut.register_file.r[5],
            dut.register_file.r[6]);

        if (dut.register_file.r[0] !== 16'd13 ||
            dut.register_file.r[1] !== 16'd7 ||
            dut.register_file.r[2] !== 16'd8 ||
            dut.register_file.r[3] !== 16'd13 ||
            dut.register_file.r[4] !== 16'd7) begin
            $display("FAIL: cpu_asm_fib_e2e_tb mismatch");
            $fatal(1);
        end

        $display("PASS: cpu_asm_fib_e2e_tb");
        $finish;
    end
endmodule
