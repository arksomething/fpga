`timescale 1ns/1ps

module cpu_fib_iterative_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;

    localparam [3:0] OP_ADD   = 4'b0000;
    localparam [3:0] OP_MOV   = 4'b0010;
    localparam [3:0] OP_BRA   = 4'b0011;
    localparam [3:0] OP_BZ    = 4'b0101;
    localparam [3:0] OP_CMPLT = 4'b1001;
    localparam [3:0] OP_ADDI  = 4'b1010;
    localparam [3:0] OP_LDI   = 4'b1100;

    cpu dut (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    function [15:0] enc_r;
        input [3:0] op;
        input [2:0] rd;
        input [2:0] rs1;
        input [2:0] rs2;
        begin
            enc_r = {op, rd, rs1, rs2, 3'b000};
        end
    endfunction

    function [15:0] enc_ldi;
        input [2:0] rd;
        input [7:0] imm8;
        begin
            enc_ldi = {OP_LDI, rd, imm8, 1'b0};
        end
    endfunction

    function [15:0] enc_i6;
        input [3:0] op;
        input [2:0] rd;
        input [2:0] rs1;
        input [5:0] imm6;
        begin
            enc_i6 = {op, rd, rs1, imm6};
        end
    endfunction

    function [15:0] enc_branch;
        input [3:0] op;
        input [2:0] rd;
        input integer off9;
        begin
            enc_branch = {op, rd, off9[8:0]};
        end
    endfunction

    function [15:0] enc_bra;
        input integer off12;
        begin
            enc_bra = {OP_BRA, off12[11:0]};
        end
    endfunction

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            dut.instruction_memory.mem[i] = 16'hF000;
            dut.data_memory.mem[i] = 16'h0000;
        end

        for (i = 0; i < 8; i = i + 1)
            dut.register_file.r[i] = 16'h0000;

        // Iterative fib(7) = 13
        // r1 = n, r2 = a, r3 = b, r4 = i, r5 = tmp, r6 = loop flag
        dut.instruction_memory.mem[0]  = enc_ldi(3'd1, 8'd7);        // n = 7
        dut.instruction_memory.mem[1]  = enc_ldi(3'd2, 8'd0);        // a = 0
        dut.instruction_memory.mem[2]  = enc_ldi(3'd3, 8'd1);        // b = 1
        dut.instruction_memory.mem[3]  = enc_ldi(3'd4, 8'd1);        // i = 1
        dut.instruction_memory.mem[4]  = enc_r(OP_CMPLT, 3'd6, 3'd4, 3'd1);
        dut.instruction_memory.mem[5]  = enc_branch(OP_BZ, 3'd6, 6); // -> 11
        dut.instruction_memory.mem[6]  = enc_r(OP_ADD, 3'd5, 3'd2, 3'd3);
        dut.instruction_memory.mem[7]  = enc_r(OP_MOV, 3'd2, 3'd3, 3'b000);
        dut.instruction_memory.mem[8]  = enc_r(OP_MOV, 3'd3, 3'd5, 3'b000);
        dut.instruction_memory.mem[9]  = enc_i6(OP_ADDI, 3'd4, 3'd4, 6'd1);
        dut.instruction_memory.mem[10] = enc_bra(-6);                // -> 4
        dut.instruction_memory.mem[11] = enc_r(OP_MOV, 3'd0, 3'd3, 3'b000);

        repeat (2) begin
            @(posedge clk);
            #1;
        end

        reset = 1'b0;

        repeat (80) begin
            @(posedge clk);
            #1;
        end

        $display("iter fib: r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d r6=%0d",
            dut.register_file.r[0], dut.register_file.r[1], dut.register_file.r[2],
            dut.register_file.r[3], dut.register_file.r[4], dut.register_file.r[5],
            dut.register_file.r[6]);

        if (dut.register_file.r[0] !== 16'd13 ||
            dut.register_file.r[1] !== 16'd7 ||
            dut.register_file.r[2] !== 16'd8 ||
            dut.register_file.r[3] !== 16'd13 ||
            dut.register_file.r[4] !== 16'd7) begin
            $display("FAIL: cpu_fib_iterative_tb mismatch");
            $fatal(1);
        end

        $display("PASS: cpu_fib_iterative_tb");
        $finish;
    end
endmodule
