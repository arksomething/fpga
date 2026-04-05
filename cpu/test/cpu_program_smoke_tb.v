`timescale 1ns/1ps

module cpu_program_smoke_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;

    localparam [3:0] OP_ADD   = 4'b0000;
    localparam [3:0] OP_SUB   = 4'b0001;
    localparam [3:0] OP_MOV   = 4'b0010;
    localparam [3:0] OP_BZ    = 4'b0101;
    localparam [3:0] OP_LOAD  = 4'b0110;
    localparam [3:0] OP_STORE = 4'b0111;
    localparam [3:0] OP_CMPEQ = 4'b1000;
    localparam [3:0] OP_CMPLT = 4'b1001;
    localparam [3:0] OP_ADDI  = 4'b1010;
    localparam [3:0] OP_BNZ   = 4'b1011;
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

    function [15:0] enc_i6;
        input [3:0] op;
        input [2:0] rd;
        input [2:0] rs1;
        input [5:0] imm6;
        begin
            enc_i6 = {op, rd, rs1, imm6};
        end
    endfunction

    function [15:0] enc_ldi;
        input [2:0] rd;
        input [7:0] imm8;
        begin
            enc_ldi = {OP_LDI, rd, imm8, 1'b0};
        end
    endfunction

    function [15:0] enc_branch;
        input [3:0] op;
        input [2:0] rd;
        input [8:0] off9;
        begin
            enc_branch = {op, rd, off9};
        end
    endfunction

    function [15:0] enc_store;
        input [2:0] rs;
        input [2:0] base;
        begin
            enc_store = {OP_STORE, 3'b000, rs, base, 3'b000};
        end
    endfunction

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            dut.instruction_memory.mem[i] = 16'hF000;
            dut.data_memory.mem[i] = 16'h0000;
        end

        for (i = 0; i < 8; i = i + 1)
            dut.register_file.r[i] = 16'h0000;

        // Program:
        //   r1 = 5
        //   r2 = r1 + 3        => 8
        //   r3 = r1 + r2       => 13
        //   r4 = r3 - r1       => 8
        //   r5 = r4            => 8
        //   r6 = (r5 == r2)    => 1, skip bad write to r0
        //   r6 = (r1 < r2)     => 1, BZ should not branch
        //   r0 = 42
        //   MEM[r2] = r3       => MEM[8] = 13
        //   r4 = MEM[r2]       => 13
        //   r6 = (r4 == r3)    => 1, skip second bad write to r0
        dut.instruction_memory.mem[0]  = enc_ldi(3'd1, 8'd5);
        dut.instruction_memory.mem[1]  = enc_i6(OP_ADDI, 3'd2, 3'd1, 6'd3);
        dut.instruction_memory.mem[2]  = enc_r(OP_ADD, 3'd3, 3'd1, 3'd2);
        dut.instruction_memory.mem[3]  = enc_r(OP_SUB, 3'd4, 3'd3, 3'd1);
        dut.instruction_memory.mem[4]  = enc_r(OP_MOV, 3'd5, 3'd4, 3'b000);
        dut.instruction_memory.mem[5]  = enc_r(OP_CMPEQ, 3'd6, 3'd5, 3'd2);
        dut.instruction_memory.mem[6]  = enc_branch(OP_BNZ, 3'd6, 9'd2);
        dut.instruction_memory.mem[7]  = enc_ldi(3'd0, 8'd99);
        dut.instruction_memory.mem[8]  = enc_r(OP_CMPLT, 3'd6, 3'd1, 3'd2);
        dut.instruction_memory.mem[9]  = enc_branch(OP_BZ, 3'd6, 9'd2);
        dut.instruction_memory.mem[10] = enc_ldi(3'd0, 8'd42);
        dut.instruction_memory.mem[11] = enc_store(3'd3, 3'd2);
        dut.instruction_memory.mem[12] = enc_i6(OP_LOAD, 3'd4, 3'd2, 6'd0);
        dut.instruction_memory.mem[13] = enc_r(OP_CMPEQ, 3'd6, 3'd4, 3'd3);
        dut.instruction_memory.mem[14] = enc_branch(OP_BNZ, 3'd6, 9'd2);
        dut.instruction_memory.mem[15] = enc_ldi(3'd0, 8'd77);

        repeat (2) begin
            @(posedge clk);
            #1;
        end

        reset = 1'b0;

        repeat (20) begin
            @(posedge clk);
            #1;
        end

        $display("r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d r6=%0d sp=%0d mem[8]=%0d",
            dut.register_file.r[0], dut.register_file.r[1], dut.register_file.r[2],
            dut.register_file.r[3], dut.register_file.r[4], dut.register_file.r[5],
            dut.register_file.r[6], dut.register_file.r[7], dut.data_memory.mem[8]);

        if (dut.register_file.r[0] !== 16'd42 ||
            dut.register_file.r[1] !== 16'd5 ||
            dut.register_file.r[2] !== 16'd8 ||
            dut.register_file.r[3] !== 16'd13 ||
            dut.register_file.r[4] !== 16'd13 ||
            dut.register_file.r[5] !== 16'd8 ||
            dut.register_file.r[6] !== 16'd1 ||
            dut.data_memory.mem[8] !== 16'd13) begin
            $display("FAIL: cpu_program_smoke_tb mismatch");
            $fatal(1);
        end

        $display("PASS: cpu_program_smoke_tb");
        $finish;
    end
endmodule
