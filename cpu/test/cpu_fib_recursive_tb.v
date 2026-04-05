`timescale 1ns/1ps

module cpu_fib_recursive_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;

    localparam [3:0] OP_ADD   = 4'b0000;
    localparam [3:0] OP_SUB   = 4'b0001;
    localparam [3:0] OP_MOV   = 4'b0010;
    localparam [3:0] OP_BRA   = 4'b0011;
    localparam [3:0] OP_LOAD  = 4'b0110;
    localparam [3:0] OP_STORE = 4'b0111;
    localparam [3:0] OP_CMPLT = 4'b1001;
    localparam [3:0] OP_LDI   = 4'b1100;
    localparam [3:0] OP_CALL  = 4'b1101;
    localparam [3:0] OP_RET   = 4'b1110;

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

    function [15:0] enc_store;
        input [2:0] rs;
        input [2:0] base;
        begin
            enc_store = {OP_STORE, 3'b000, rs, base, 3'b000};
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

    function [15:0] enc_call;
        input integer off12;
        begin
            enc_call = {OP_CALL, off12[11:0]};
        end
    endfunction

    function [15:0] enc_ret;
        begin
            enc_ret = {OP_RET, 12'b0};
        end
    endfunction

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            dut.instruction_memory.mem[i] = 16'hF000;
            dut.data_memory.mem[i] = 16'h0000;
        end

        for (i = 0; i < 8; i = i + 1)
            dut.register_file.r[i] = 16'h0000;

        // Recursive fib(6) = 8
        // r0 = return value
        // r1 = n
        // r2 = compare flag
        // r3 = const 1
        // r4 = const 2
        // r5 = temp fib(n-1)
        // r7 = SP
        dut.instruction_memory.mem[0]  = enc_ldi(3'd3, 8'd1);     // const 1
        dut.instruction_memory.mem[1]  = enc_ldi(3'd4, 8'd2);     // const 2
        dut.instruction_memory.mem[2]  = enc_ldi(3'd7, 8'h40);    // SP = 64
        dut.instruction_memory.mem[3]  = enc_ldi(3'd1, 8'd6);     // n = 6
        dut.instruction_memory.mem[4]  = enc_call(4);             // -> 8
        dut.instruction_memory.mem[5]  = enc_r(OP_MOV, 3'd2, 3'd0, 3'b000);
        dut.instruction_memory.mem[6]  = enc_bra(20);             // -> 26

        // fib function at 8
        dut.instruction_memory.mem[8]  = enc_r(OP_CMPLT, 3'd2, 3'd1, 3'd4);
        dut.instruction_memory.mem[9]  = enc_branch(4'b1011, 3'd2, 15); // BNZ -> 24
        dut.instruction_memory.mem[10] = enc_r(OP_SUB, 3'd7, 3'd7, 3'd3);
        dut.instruction_memory.mem[11] = enc_store(3'd1, 3'd7);
        dut.instruction_memory.mem[12] = enc_r(OP_SUB, 3'd1, 3'd1, 3'd3);
        dut.instruction_memory.mem[13] = enc_call(-5);            // -> 8
        dut.instruction_memory.mem[14] = enc_r(OP_SUB, 3'd7, 3'd7, 3'd3);
        dut.instruction_memory.mem[15] = enc_store(3'd0, 3'd7);
        dut.instruction_memory.mem[16] = enc_i6(OP_LOAD, 3'd1, 3'd7, 6'd1);
        dut.instruction_memory.mem[17] = enc_r(OP_SUB, 3'd1, 3'd1, 3'd4);
        dut.instruction_memory.mem[18] = enc_call(-10);           // -> 8
        dut.instruction_memory.mem[19] = enc_i6(OP_LOAD, 3'd5, 3'd7, 6'd0);
        dut.instruction_memory.mem[20] = enc_r(OP_ADD, 3'd0, 3'd5, 3'd0);
        dut.instruction_memory.mem[21] = enc_r(OP_ADD, 3'd7, 3'd7, 3'd3);
        dut.instruction_memory.mem[22] = enc_r(OP_ADD, 3'd7, 3'd7, 3'd3);
        dut.instruction_memory.mem[23] = enc_ret();
        dut.instruction_memory.mem[24] = enc_r(OP_MOV, 3'd0, 3'd1, 3'b000);
        dut.instruction_memory.mem[25] = enc_ret();

        repeat (2) begin
            @(posedge clk);
            #1;
        end

        reset = 1'b0;

        repeat (1200) begin
            @(posedge clk);
            #1;
        end

        $display("rec fib: r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d sp=%0d",
            dut.register_file.r[0], dut.register_file.r[1], dut.register_file.r[2],
            dut.register_file.r[3], dut.register_file.r[4], dut.register_file.r[5],
            dut.register_file.r[7]);
        $display("stack[63]=%0d stack[62]=%0d stack[61]=%0d stack[60]=%0d",
            dut.data_memory.mem[8'h3f], dut.data_memory.mem[8'h3e],
            dut.data_memory.mem[8'h3d], dut.data_memory.mem[8'h3c]);

        if (dut.register_file.r[0] !== 16'd8 ||
            dut.register_file.r[2] !== 16'd8 ||
            dut.register_file.r[3] !== 16'd1 ||
            dut.register_file.r[4] !== 16'd2 ||
            dut.register_file.r[7] !== 16'h0040) begin
            $display("FAIL: cpu_fib_recursive_tb mismatch");
            $fatal(1);
        end

        $display("PASS: cpu_fib_recursive_tb");
        $finish;
    end
endmodule
