`timescale 1ns/1ps

module cpu_edge_cases_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;
    integer pass_count = 0;
    integer fail_count = 0;
    integer saw_stall;

    localparam [3:0] OP_BRA   = 4'b0011;
    localparam [3:0] OP_JMP   = 4'b0100;
    localparam [3:0] OP_BNZ   = 4'b1011;
    localparam [3:0] OP_LOAD  = 4'b0110;
    localparam [3:0] OP_CMPEQ = 4'b1000;
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

    function [15:0] enc_bra;
        input [11:0] off12;
        begin
            enc_bra = {OP_BRA, off12};
        end
    endfunction

    function [15:0] enc_jmp;
        input [2:0] rs1;
        begin
            enc_jmp = {OP_JMP, 3'b000, rs1, 6'b000000};
        end
    endfunction

    task prepare_case;
        integer idx;
        begin
            reset = 1'b1;
            saw_stall = 0;

            for (idx = 0; idx < 256; idx = idx + 1) begin
                dut.instruction_memory.mem[idx] = 16'hF000;
                dut.data_memory.mem[idx] = 16'h0000;
            end

            for (idx = 0; idx < 8; idx = idx + 1)
                dut.register_file.r[idx] = 16'h0000;
        end
    endtask

    task run_case;
        input integer cycles;
        integer idx;
        begin
            repeat (2) begin
                @(posedge clk);
                #1;
            end

            reset = 1'b0;

            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
                #1;
                if (dut.stall)
                    saw_stall = 1;
            end
        end
    endtask

    task report_case;
        input [127:0] case_name;
        input integer passed;
        begin
            if (passed) begin
                pass_count = pass_count + 1;
                $display("PASS: %0s", case_name);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s", case_name);
            end
        end
    endtask

    initial begin
        // CMPEQ -> BNZ should forward the boolean result and branch.
        prepare_case();
        dut.register_file.r[1] = 16'd5;
        dut.register_file.r[2] = 16'd5;
        dut.instruction_memory.mem[0] = enc_r(OP_CMPEQ, 3'd3, 3'd1, 3'd2);
        dut.instruction_memory.mem[1] = enc_branch(OP_BNZ, 3'd3, 9'd3);
        dut.instruction_memory.mem[2] = enc_ldi(3'd0, 8'd99);
        dut.instruction_memory.mem[3] = enc_bra(12'd2);
        dut.instruction_memory.mem[4] = enc_ldi(3'd0, 8'd42);
        run_case(12);
        report_case(
            "CMPEQ true forwards into BNZ",
            (dut.register_file.r[3] == 16'd1) && (dut.register_file.r[0] == 16'd42)
        );

        // CMPEQ false should not branch.
        prepare_case();
        dut.register_file.r[1] = 16'd5;
        dut.register_file.r[2] = 16'd7;
        dut.instruction_memory.mem[0] = enc_r(OP_CMPEQ, 3'd3, 3'd1, 3'd2);
        dut.instruction_memory.mem[1] = enc_branch(OP_BNZ, 3'd3, 9'd3);
        dut.instruction_memory.mem[2] = enc_ldi(3'd0, 8'd99);
        dut.instruction_memory.mem[3] = enc_bra(12'd2);
        dut.instruction_memory.mem[4] = enc_ldi(3'd0, 8'd42);
        run_case(10);
        report_case(
            "CMPEQ false falls through",
            (dut.register_file.r[3] == 16'd0) && (dut.register_file.r[0] == 16'd99)
        );

        // LOAD -> BNZ should stall once and then branch on the loaded value.
        prepare_case();
        dut.register_file.r[2] = 16'h0020;
        dut.data_memory.mem[8'h20] = 16'd1;
        dut.instruction_memory.mem[0] = enc_i6(OP_LOAD, 3'd1, 3'd2, 6'd0);
        dut.instruction_memory.mem[1] = enc_branch(OP_BNZ, 3'd1, 9'd3);
        dut.instruction_memory.mem[2] = enc_ldi(3'd0, 8'd99);
        dut.instruction_memory.mem[3] = enc_bra(12'd2);
        dut.instruction_memory.mem[4] = enc_ldi(3'd0, 8'd42);
        run_case(10);
        report_case(
            "LOAD nonzero stalls then branches",
            saw_stall && (dut.register_file.r[1] == 16'd1) && (dut.register_file.r[0] == 16'd42)
        );

        // LOAD zero should still stall, but branch should not be taken.
        prepare_case();
        dut.register_file.r[2] = 16'h0020;
        dut.data_memory.mem[8'h20] = 16'd0;
        dut.instruction_memory.mem[0] = enc_i6(OP_LOAD, 3'd1, 3'd2, 6'd0);
        dut.instruction_memory.mem[1] = enc_branch(OP_BNZ, 3'd1, 9'd3);
        dut.instruction_memory.mem[2] = enc_ldi(3'd0, 8'd99);
        dut.instruction_memory.mem[3] = enc_bra(12'd2);
        dut.instruction_memory.mem[4] = enc_ldi(3'd0, 8'd42);
        run_case(10);
        report_case(
            "LOAD zero stalls then falls through",
            saw_stall && (dut.register_file.r[1] == 16'd0) && (dut.register_file.r[0] == 16'd99)
        );

        // LDI -> JMP should use the freshly produced register value.
        prepare_case();
        dut.instruction_memory.mem[0] = enc_ldi(3'd1, 8'd4);
        dut.instruction_memory.mem[1] = enc_jmp(3'd1);
        dut.instruction_memory.mem[2] = enc_ldi(3'd0, 8'd99);
        dut.instruction_memory.mem[4] = enc_ldi(3'd0, 8'd42);
        run_case(10);
        report_case(
            "LDI forwards into JMP",
            (dut.register_file.r[1] == 16'd4) && (dut.register_file.r[0] == 16'd42)
        );

        // ADDI should sign-extend imm6 and forward the updated value.
        prepare_case();
        dut.instruction_memory.mem[0] = enc_ldi(3'd1, 8'd5);
        dut.instruction_memory.mem[1] = enc_i6(OP_ADDI, 3'd1, 3'd1, 6'h3f); // -1 => 4
        dut.instruction_memory.mem[2] = enc_i6(OP_ADDI, 3'd2, 3'd1, 6'h3e); // -2 => 2
        run_case(10);
        report_case(
            "ADDI sign-extends negative imm6",
            (dut.register_file.r[1] == 16'd4) && (dut.register_file.r[2] == 16'd2)
        );

        $display("cpu_edge_cases_tb: passed=%0d failed=%0d", pass_count, fail_count);
        if (fail_count != 0)
            $fatal(1);
        $finish;
    end
endmodule
