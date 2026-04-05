`timescale 1ns/1ps

module cpu_call_stack_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;

    localparam [3:0] OP_BRA  = 4'b0011;
    localparam [3:0] OP_LDI  = 4'b1100;
    localparam [3:0] OP_CALL = 4'b1101;
    localparam [3:0] OP_RET  = 4'b1110;

    cpu dut (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    function [15:0] enc_ldi;
        input [2:0] rd;
        input [7:0] imm8;
        begin
            enc_ldi = {OP_LDI, rd, imm8, 1'b0};
        end
    endfunction

    function [15:0] enc_call;
        input [11:0] off12;
        begin
            enc_call = {OP_CALL, off12};
        end
    endfunction

    function [15:0] enc_ret;
        begin
            enc_ret = {OP_RET, 12'b0};
        end
    endfunction

    function [15:0] enc_bra;
        input [11:0] off12;
        begin
            enc_bra = {OP_BRA, off12};
        end
    endfunction

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            dut.instruction_memory.mem[i] = 16'hF000;
            dut.data_memory.mem[i] = 16'h0000;
        end

        for (i = 0; i < 8; i = i + 1)
            dut.register_file.r[i] = 16'h0000;

        dut.register_file.r[7] = 16'h0010;

        // Program:
        //   0: CALL outer_fn
        //   1: r0 = 42               (after both returns)
        //   2: BRA end
        //   4: CALL inner_fn
        //   5: r1 = 7                (after inner return)
        //   6: RET
        //   8: r2 = 9
        //   9: RET
        dut.instruction_memory.mem[0]  = enc_call(12'd4);   // -> 4, return to 1
        dut.instruction_memory.mem[1]  = enc_ldi(3'd0, 8'd42);
        dut.instruction_memory.mem[2]  = enc_bra(12'd9);    // -> 11
        dut.instruction_memory.mem[4]  = enc_call(12'd4);   // -> 8, return to 5
        dut.instruction_memory.mem[5]  = enc_ldi(3'd1, 8'd7);
        dut.instruction_memory.mem[6]  = enc_ret();
        dut.instruction_memory.mem[8]  = enc_ldi(3'd2, 8'd9);
        dut.instruction_memory.mem[9]  = enc_ret();

        repeat (2) begin
            @(posedge clk);
            #1;
        end

        reset = 1'b0;

        repeat (24) begin
            @(posedge clk);
            #1;
        end

        $display("r0=%0d r1=%0d r2=%0d sp=%0d stk[15]=%0d stk[14]=%0d",
            dut.register_file.r[0],
            dut.register_file.r[1],
            dut.register_file.r[2],
            dut.register_file.r[7],
            dut.data_memory.mem[8'h0f],
            dut.data_memory.mem[8'h0e]);

        if (dut.register_file.r[0] !== 16'd42 ||
            dut.register_file.r[1] !== 16'd7 ||
            dut.register_file.r[2] !== 16'd9 ||
            dut.register_file.r[7] !== 16'h0010 ||
            dut.data_memory.mem[8'h0f] !== 16'd1 ||
            dut.data_memory.mem[8'h0e] !== 16'd5) begin
            $display("FAIL: cpu_call_stack_tb mismatch");
            $fatal(1);
        end

        $display("PASS: cpu_call_stack_tb");
        $finish;
    end
endmodule
