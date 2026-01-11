`timescale 1ns/1ps

module alu_tb;
    // Testbench signals
    reg  [15:0] a, b;
    reg  [1:0]  alu_sel;
    wire [15:0] result;
    wire        zero, negative, carry;

    // Test tracking
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate the ALU
    alu uut (
        .a(a),
        .b(b),
        .alu_sel(alu_sel),
        .result(result),
        .zero(zero),
        .negative(negative),
        .carry(carry)
    );

    // Task to check result and flags
    task check;
        input [15:0] exp_result;
        input        exp_zero;
        input        exp_negative;
        input        exp_carry;
        input [63:0] test_name; // 8-char test name
        begin
            #1; // Allow combinational logic to settle
            if (result === exp_result && zero === exp_zero && 
                negative === exp_negative && carry === exp_carry) begin
                $display("PASS: %s | a=%h b=%h sel=%b => result=%h z=%b n=%b c=%b",
                         test_name, a, b, alu_sel, result, zero, negative, carry);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %s | a=%h b=%h sel=%b", test_name, a, b, alu_sel);
                $display("      Expected: result=%h z=%b n=%b c=%b", 
                         exp_result, exp_zero, exp_negative, exp_carry);
                $display("      Got:      result=%h z=%b n=%b c=%b", 
                         result, zero, negative, carry);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // Setup waveform dump
        $dumpfile("test/alu_tb.vcd");
        $dumpvars(0, alu_tb);

        $display("========================================");
        $display("         ALU Testbench Start");
        $display("========================================");

        // ----------------------------------------
        // ADD Tests (alu_sel = 2'b00)
        // ----------------------------------------
        $display("\n--- ADD Tests ---");
        alu_sel = 2'b00;

        // Basic addition: 5 + 3 = 8
        a = 16'h0005; b = 16'h0003;
        check(16'h0008, 1'b0, 1'b0, 1'b0, "ADD_BASIC");

        // Zero result: 0 + 0 = 0
        a = 16'h0000; b = 16'h0000;
        check(16'h0000, 1'b1, 1'b0, 1'b0, "ADD_ZERO");

        // Carry/overflow: FFFF + 1 = 0 (with carry)
        a = 16'hFFFF; b = 16'h0001;
        check(16'h0000, 1'b1, 1'b0, 1'b1, "ADD_CARRY");

        // Carry with non-zero result: FFFF + 2 = 1 (with carry)
        a = 16'hFFFF; b = 16'h0002;
        check(16'h0001, 1'b0, 1'b0, 1'b1, "ADD_CAR2");

        // Negative result: 0x7FFF + 1 = 0x8000 (MSB set)
        a = 16'h7FFF; b = 16'h0001;
        check(16'h8000, 1'b0, 1'b1, 1'b0, "ADD_NEG");

        // Large addition no carry: 0x8000 + 0x7FFF = 0xFFFF
        a = 16'h8000; b = 16'h7FFF;
        check(16'hFFFF, 1'b0, 1'b1, 1'b0, "ADD_LARG");

        // ----------------------------------------
        // SUB Tests (alu_sel = 2'b01)
        // ----------------------------------------
        $display("\n--- SUB Tests ---");
        alu_sel = 2'b01;

        // Basic subtraction: 8 - 3 = 5
        a = 16'h0008; b = 16'h0003;
        check(16'h0005, 1'b0, 1'b0, 1'b0, "SUB_BASIC");

        // Zero result: 5 - 5 = 0
        a = 16'h0005; b = 16'h0005;
        check(16'h0000, 1'b1, 1'b0, 1'b0, "SUB_ZERO");

        // Borrow/underflow: 0 - 1 = FFFF (with borrow)
        a = 16'h0000; b = 16'h0001;
        check(16'hFFFF, 1'b0, 1'b1, 1'b1, "SUB_BORW");

        // Borrow: 5 - 10 = FFFB (with borrow)
        a = 16'h0005; b = 16'h000A;
        check(16'hFFFB, 1'b0, 1'b1, 1'b1, "SUB_BOR2");

        // No borrow, negative result: 0x8000 - 1 = 0x7FFF
        a = 16'h8000; b = 16'h0001;
        check(16'h7FFF, 1'b0, 1'b0, 1'b0, "SUB_NOBO");

        // Large subtraction: 0xFFFF - 0xFFFF = 0
        a = 16'hFFFF; b = 16'hFFFF;
        check(16'h0000, 1'b1, 1'b0, 1'b0, "SUB_LARG");

        // ----------------------------------------
        // AND Tests (alu_sel = 2'b10)
        // ----------------------------------------
        $display("\n--- AND Tests ---");
        alu_sel = 2'b10;

        // Basic AND: 0xFF00 & 0x0FF0 = 0x0F00
        a = 16'hFF00; b = 16'h0FF0;
        check(16'h0F00, 1'b0, 1'b0, 1'b0, "AND_BASIC");

        // Zero result: 0xAAAA & 0x5555 = 0x0000
        a = 16'hAAAA; b = 16'h5555;
        check(16'h0000, 1'b1, 1'b0, 1'b0, "AND_ZERO");

        // All ones: 0xFFFF & 0xFFFF = 0xFFFF
        a = 16'hFFFF; b = 16'hFFFF;
        check(16'hFFFF, 1'b0, 1'b1, 1'b0, "AND_ONES");

        // Negative result: 0x8000 & 0xFFFF = 0x8000
        a = 16'h8000; b = 16'hFFFF;
        check(16'h8000, 1'b0, 1'b1, 1'b0, "AND_NEG");

        // Partial mask: 0x1234 & 0x00FF = 0x0034
        a = 16'h1234; b = 16'h00FF;
        check(16'h0034, 1'b0, 1'b0, 1'b0, "AND_MASK");

        // ----------------------------------------
        // NOP Tests (alu_sel = 2'b11)
        // ----------------------------------------
        $display("\n--- NOP Tests ---");
        alu_sel = 2'b11;

        // NOP with random inputs: should output 0
        a = 16'h1234; b = 16'h5678;
        check(16'h0000, 1'b1, 1'b0, 1'b0, "NOP_RND");

        // NOP with all ones: should still output 0
        a = 16'hFFFF; b = 16'hFFFF;
        check(16'h0000, 1'b1, 1'b0, 1'b0, "NOP_ONES");

        // NOP with zeros
        a = 16'h0000; b = 16'h0000;
        check(16'h0000, 1'b1, 1'b0, 1'b0, "NOP_ZERO");

        // ----------------------------------------
        // Summary
        // ----------------------------------------
        $display("\n========================================");
        $display("         ALU Testbench Complete");
        $display("========================================");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        $display("========================================\n");

        $finish;
    end

endmodule

