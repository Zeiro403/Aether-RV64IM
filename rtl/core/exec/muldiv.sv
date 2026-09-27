module muldiv
import riscv_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // Request interface
    input  logic        start_i,
    input  mul_op_t     op_i,
    input  logic [63:0] op_a_i,
    input  logic [63:0] op_b_i,

    // Completion interface
    output logic        result_valid_o,
    output logic [63:0] result_o
);

    // =========================================================================
    // Aether iterative RV64IM multiply/divide unit
    // =========================================================================
    //
    // Multiplication:
    //   Radix-2 shift-and-add.
    //   One multiplier bit is consumed per cycle.
    //
    // Division:
    //   Radix-2 restoring division.
    //   One quotient bit is produced per cycle.
    //
    // Signed operations are converted to unsigned magnitudes before iteration.
    // The appropriate sign is restored when the operation completes.
    //
    // IMPORTANT:
    //   There are intentionally no synthesizable *, /, or % operators here.
    //
    // Latency:
    //   MUL/MULH/MULHSU/MULHU : 64 iterations
    //   MULW                   : 32 iterations
    //   DIV/DIVU/REM/REMU     : 64 iterations
    //   DIVW/DIVUW/REMW/REMUW : 32 iterations
    //
    // Divide-by-zero and signed-overflow cases complete immediately through
    // the DONE state because RISC-V defines their results explicitly.
    // =========================================================================


    // =========================================================================
    // State
    // =========================================================================

    typedef enum logic [1:0] {
        IDLE,
        MUL_RUN,
        DIV_RUN,
        DONE
    } state_t;

    state_t state_q;

    mul_op_t op_q;

    // Iterations remaining.
    logic [6:0] count_q;


    // =========================================================================
    // Multiply datapath
    // =========================================================================

    // Accumulated product.
    logic [127:0] mul_product_q;

    // Multiplicand is shifted left every iteration.
    logic [127:0] mul_multiplicand_q;

    // Multiplier is shifted right every iteration.
    logic [63:0] mul_multiplier_q;

    // Product after the current iteration.
    logic [127:0] mul_product_next;

    // Sign of the complete mathematical product for MULH/MULHSU.
    logic mul_negative_q;


    // =========================================================================
    // Divide datapath
    // =========================================================================

    // During restoring division, quotient_q initially carries the dividend.
    // As iterations proceed, consumed dividend bits shift out and quotient
    // bits shift in from the right.
    logic [63:0] div_quotient_q;

    logic [63:0] div_divisor_q;

    // Stored remainder is always 64 bits.
    logic [63:0] div_remainder_q;

    // Shifting the remainder and inserting the next dividend bit requires
    // one additional temporary bit.
    logic [64:0] div_shifted_remainder;

    logic [63:0] div_remainder_next;
    logic [63:0] div_quotient_next;

    logic div_quotient_negative_q;
    logic div_remainder_negative_q;


    // =========================================================================
    // Operation helpers
    // =========================================================================

    function automatic logic is_mul_op(input mul_op_t op);
        case (op)
            M_MUL,
            M_MULH,
            M_MULHSU,
            M_MULHU,
            M_MULW:
                is_mul_op = 1'b1;

            default:
                is_mul_op = 1'b0;
        endcase
    endfunction


    function automatic logic is_div_op(input mul_op_t op);
        case (op)
            M_DIV,
            M_DIVU,
            M_REM,
            M_REMU,
            M_DIVW,
            M_DIVUW,
            M_REMW,
            M_REMUW:
                is_div_op = 1'b1;

            default:
                is_div_op = 1'b0;
        endcase
    endfunction


    // =========================================================================
    // Two's-complement helpers
    // =========================================================================

    function automatic logic [63:0] negate64(
        input logic [63:0] value
    );
        negate64 = (~value) + 64'd1;
    endfunction


    function automatic logic [31:0] negate32(
        input logic [31:0] value
    );
        negate32 = (~value) + 32'd1;
    endfunction


    // Return the high 64 bits of a 128-bit product after optional
    // two's-complement sign correction.
    function automatic logic [63:0] signed_product_high64(
        input logic [127:0] product,
        input logic         negative
    );
        logic [63:0] product_hi;
        logic        low_nonzero;

        begin
            product_hi  = product[127:64];
            low_nonzero = |product[63:0];

            if (negative) begin
                // High half of the 128-bit two's-complement negation.
                //
                // -product = ~product + 1
                //
                // The +1 propagates into the upper 64 bits only when the
                // original lower 64 bits are zero.
                signed_product_high64 =
                    (~product_hi) + {63'd0, ~low_nonzero};
            end else begin
                signed_product_high64 = product_hi;
            end
        end
    endfunction

    // Sign-extend a 32-bit result to RV64 XLEN.
    function automatic logic [63:0] sext32(
        input logic [31:0] value
    );
        sext32 = {
            {32{value[31]}},
            value
        };
    endfunction


    // =========================================================================
    // Interface
    // =========================================================================

    assign result_valid_o = (state_q == DONE);


    // =========================================================================
    // Multiply iteration
    // =========================================================================
    //
    // Classic binary long multiplication:
    //
    // if multiplier[0] == 1:
    //     product += multiplicand
    //
    // multiplicand <<= 1
    // multiplier   >>= 1
    //
    // Only one 128-bit conditional addition is performed in a cycle.
    // =========================================================================

    always_comb begin
        mul_product_next = mul_product_q;

        if (mul_multiplier_q[0]) begin
            mul_product_next =
                mul_product_q + mul_multiplicand_q;
        end
    end


    // =========================================================================
    // Division iteration
    // =========================================================================
    //
    // Restoring division:
    //
    // shifted_remainder = {remainder, next_dividend_bit}
    // quotient          = quotient << 1
    //
    // if shifted_remainder >= divisor:
    //     remainder = shifted_remainder - divisor
    //     quotient[0] = 1
    // else:
    //     remainder = shifted_remainder
    //     quotient[0] = 0
    //
    // Only one compare/subtract datapath is required.
    // =========================================================================

    always_comb begin

        div_shifted_remainder = {
            div_remainder_q,
            div_quotient_q[63]
        };

        div_quotient_next = {
            div_quotient_q[62:0],
            1'b0
        };

        div_remainder_next =
            div_shifted_remainder[63:0];

        if (div_shifted_remainder >= {1'b0, div_divisor_q}) begin

            div_remainder_next =
                div_shifted_remainder[63:0] - div_divisor_q;

            div_quotient_next[0] = 1'b1;
        end
    end


    // =========================================================================
    // Sequential controller and datapath
    // =========================================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state_q <= IDLE;
            op_q    <= M_NONE;
            count_q <= 7'd0;

            result_o <= 64'd0;

            // Multiply state
            mul_product_q      <= 128'd0;
            mul_multiplicand_q <= 128'd0;
            mul_multiplier_q   <= 64'd0;
            mul_negative_q     <= 1'b0;

            // Divide state
            div_quotient_q  <= 64'd0;
            div_divisor_q   <= 64'd0;
            div_remainder_q <= 64'd0;

            div_quotient_negative_q  <= 1'b0;
            div_remainder_negative_q <= 1'b0;

        end else begin

            case (state_q)

                // =============================================================
                // IDLE
                // =============================================================

                IDLE: begin

                    count_q <= 7'd0;

                    if (start_i && (op_i != M_NONE)) begin

                        op_q <= op_i;

                        // =====================================================
                        // Multiplication setup
                        // =====================================================

                        if (is_mul_op(op_i)) begin

                            mul_product_q <= 128'd0;

                            case (op_i)

                                // ---------------------------------------------
                                // MUL
                                //
                                // The low 64 product bits are identical for
                                // signed and unsigned multiplication.
                                // ---------------------------------------------

                                M_MUL: begin

                                    mul_multiplicand_q <= {
                                        64'd0,
                                        op_a_i
                                    };

                                    mul_multiplier_q <= op_b_i;

                                    mul_negative_q <= 1'b0;

                                    count_q <= 7'd64;
                                end


                                // ---------------------------------------------
                                // MULH
                                //
                                // signed x signed
                                // ---------------------------------------------

                                M_MULH: begin

                                    mul_multiplicand_q <= {
                                        64'd0,
                                        op_a_i[63]
                                            ? negate64(op_a_i)
                                            : op_a_i
                                    };

                                    mul_multiplier_q <=
                                        op_b_i[63]
                                            ? negate64(op_b_i)
                                            : op_b_i;

                                    mul_negative_q <=
                                        op_a_i[63] ^ op_b_i[63];

                                    count_q <= 7'd64;
                                end


                                // ---------------------------------------------
                                // MULHSU
                                //
                                // signed x unsigned
                                // ---------------------------------------------

                                M_MULHSU: begin

                                    mul_multiplicand_q <= {
                                        64'd0,
                                        op_a_i[63]
                                            ? negate64(op_a_i)
                                            : op_a_i
                                    };

                                    mul_multiplier_q <= op_b_i;

                                    mul_negative_q <= op_a_i[63];

                                    count_q <= 7'd64;
                                end


                                // ---------------------------------------------
                                // MULHU
                                //
                                // unsigned x unsigned
                                // ---------------------------------------------

                                M_MULHU: begin

                                    mul_multiplicand_q <= {
                                        64'd0,
                                        op_a_i
                                    };

                                    mul_multiplier_q <= op_b_i;

                                    mul_negative_q <= 1'b0;

                                    count_q <= 7'd64;
                                end


                                // ---------------------------------------------
                                // MULW
                                //
                                // Only the low 32 product bits are required.
                                // Therefore only 32 multiplier bits need to be
                                // consumed.
                                // ---------------------------------------------

                                M_MULW: begin

                                    mul_multiplicand_q <= {
                                        96'd0,
                                        op_a_i[31:0]
                                    };

                                    mul_multiplier_q <= {
                                        32'd0,
                                        op_b_i[31:0]
                                    };

                                    mul_negative_q <= 1'b0;

                                    count_q <= 7'd32;
                                end


                                default: begin

                                    mul_multiplicand_q <= 128'd0;
                                    mul_multiplier_q   <= 64'd0;
                                    mul_negative_q     <= 1'b0;

                                    count_q <= 7'd0;
                                end

                            endcase

                            state_q <= MUL_RUN;


                        // =====================================================
                        // Division / remainder setup
                        // =====================================================

                        end else if (is_div_op(op_i)) begin

                            div_remainder_q <= 64'd0;

                            // -------------------------------------------------
                            // Architecturally defined exceptional cases
                            // -------------------------------------------------

                            // 64-bit divide by zero
                            if (
                                ((op_i == M_DIV)  ||
                                 (op_i == M_DIVU) ||
                                 (op_i == M_REM)  ||
                                 (op_i == M_REMU))
                                &&
                                (op_b_i == 64'd0)
                            ) begin

                                case (op_i)

                                    M_DIV,
                                    M_DIVU:
                                        result_o <=
                                            64'hFFFF_FFFF_FFFF_FFFF;

                                    M_REM,
                                    M_REMU:
                                        result_o <= op_a_i;

                                    default:
                                        result_o <= 64'd0;

                                endcase

                                state_q <= DONE;


                            // -------------------------------------------------
                            // 32-bit divide by zero
                            // -------------------------------------------------

                            end else if (
                                ((op_i == M_DIVW)  ||
                                 (op_i == M_DIVUW) ||
                                 (op_i == M_REMW)  ||
                                 (op_i == M_REMUW))
                                &&
                                (op_b_i[31:0] == 32'd0)
                            ) begin

                                case (op_i)

                                    M_DIVW,
                                    M_DIVUW:
                                        result_o <=
                                            64'hFFFF_FFFF_FFFF_FFFF;

                                    M_REMW,
                                    M_REMUW:
                                        result_o <=
                                            sext32(op_a_i[31:0]);

                                    default:
                                        result_o <= 64'd0;

                                endcase

                                state_q <= DONE;


                            // -------------------------------------------------
                            // DIV signed overflow
                            //
                            // INT64_MIN / -1 = INT64_MIN
                            // -------------------------------------------------

                            end else if (
                                (op_i == M_DIV) &&
                                (op_a_i ==
                                    64'h8000_0000_0000_0000) &&
                                (op_b_i ==
                                    64'hFFFF_FFFF_FFFF_FFFF)
                            ) begin

                                result_o <=
                                    64'h8000_0000_0000_0000;

                                state_q <= DONE;


                            // -------------------------------------------------
                            // REM signed overflow
                            //
                            // INT64_MIN % -1 = 0
                            // -------------------------------------------------

                            end else if (
                                (op_i == M_REM) &&
                                (op_a_i ==
                                    64'h8000_0000_0000_0000) &&
                                (op_b_i ==
                                    64'hFFFF_FFFF_FFFF_FFFF)
                            ) begin

                                result_o <= 64'd0;

                                state_q <= DONE;


                            // -------------------------------------------------
                            // DIVW signed overflow
                            //
                            // INT32_MIN / -1 = INT32_MIN, sign extended
                            // -------------------------------------------------

                            end else if (
                                (op_i == M_DIVW) &&
                                (op_a_i[31:0] ==
                                    32'h8000_0000) &&
                                (op_b_i[31:0] ==
                                    32'hFFFF_FFFF)
                            ) begin

                                result_o <=
                                    64'hFFFF_FFFF_8000_0000;

                                state_q <= DONE;


                            // -------------------------------------------------
                            // REMW signed overflow
                            //
                            // INT32_MIN % -1 = 0
                            // -------------------------------------------------

                            end else if (
                                (op_i == M_REMW) &&
                                (op_a_i[31:0] ==
                                    32'h8000_0000) &&
                                (op_b_i[31:0] ==
                                    32'hFFFF_FFFF)
                            ) begin

                                result_o <= 64'd0;

                                state_q <= DONE;


                            // =================================================
                            // Normal iterative division
                            // =================================================

                            end else begin

                                case (op_i)

                                    // -----------------------------------------
                                    // Signed 64-bit DIV / REM
                                    // -----------------------------------------

                                    M_DIV,
                                    M_REM: begin

                                        div_quotient_q <=
                                            op_a_i[63]
                                                ? negate64(op_a_i)
                                                : op_a_i;

                                        div_divisor_q <=
                                            op_b_i[63]
                                                ? negate64(op_b_i)
                                                : op_b_i;

                                        div_quotient_negative_q <=
                                            op_a_i[63] ^
                                            op_b_i[63];

                                        div_remainder_negative_q <=
                                            op_a_i[63];

                                        count_q <= 7'd64;
                                    end


                                    // -----------------------------------------
                                    // Unsigned 64-bit DIVU / REMU
                                    // -----------------------------------------

                                    M_DIVU,
                                    M_REMU: begin

                                        div_quotient_q <= op_a_i;
                                        div_divisor_q  <= op_b_i;

                                        div_quotient_negative_q <=
                                            1'b0;

                                        div_remainder_negative_q <=
                                            1'b0;

                                        count_q <= 7'd64;
                                    end


                                    // -----------------------------------------
                                    // Signed 32-bit DIVW / REMW
                                    //
                                    // The 32-bit dividend magnitude is placed
                                    // in bits [63:32]. The MSB-first divider
                                    // therefore consumes exactly 32 bits over
                                    // 32 iterations.
                                    // -----------------------------------------

                                    M_DIVW,
                                    M_REMW: begin

                                        div_quotient_q <= {
                                            op_a_i[31]
                                                ? negate32(
                                                    op_a_i[31:0]
                                                  )
                                                : op_a_i[31:0],
                                            32'd0
                                        };

                                        div_divisor_q <= {
                                            32'd0,
                                            op_b_i[31]
                                                ? negate32(
                                                    op_b_i[31:0]
                                                  )
                                                : op_b_i[31:0]
                                        };

                                        div_quotient_negative_q <=
                                            op_a_i[31] ^
                                            op_b_i[31];

                                        div_remainder_negative_q <=
                                            op_a_i[31];

                                        count_q <= 7'd32;
                                    end


                                    // -----------------------------------------
                                    // Unsigned 32-bit DIVUW / REMUW
                                    // -----------------------------------------

                                    M_DIVUW,
                                    M_REMUW: begin

                                        div_quotient_q <= {
                                            op_a_i[31:0],
                                            32'd0
                                        };

                                        div_divisor_q <= {
                                            32'd0,
                                            op_b_i[31:0]
                                        };

                                        div_quotient_negative_q <=
                                            1'b0;

                                        div_remainder_negative_q <=
                                            1'b0;

                                        count_q <= 7'd32;
                                    end


                                    default: begin

                                        div_quotient_q <= 64'd0;
                                        div_divisor_q  <= 64'd0;

                                        div_quotient_negative_q <=
                                            1'b0;

                                        div_remainder_negative_q <=
                                            1'b0;

                                        count_q <= 7'd0;
                                    end

                                endcase

                                state_q <= DIV_RUN;
                            end
                        end
                    end
                end


                // =============================================================
                // Iterative multiplication
                // =============================================================

                MUL_RUN: begin

                    // Perform current iteration.
                    mul_product_q <= mul_product_next;

                    mul_multiplicand_q <=
                        mul_multiplicand_q << 1;

                    mul_multiplier_q <=
                        mul_multiplier_q >> 1;

                    count_q <= count_q - 7'd1;

                    // mul_product_next already contains the arithmetic result
                    // of the final iteration, so use it rather than the old
                    // registered mul_product_q value.
                    if (count_q == 7'd1) begin

                        case (op_q)

                            M_MUL: begin

                                result_o <=
                                    mul_product_next[63:0];

                            end


                            M_MULH,
                            M_MULHSU: begin

                                result_o <=
                                    signed_product_high64(
                                        mul_product_next,
                                        mul_negative_q
                                    );

                            end


                            M_MULHU: begin

                                result_o <=
                                    mul_product_next[127:64];

                            end


                            M_MULW: begin

                                result_o <=
                                    sext32(
                                        mul_product_next[31:0]
                                    );

                            end


                            default: begin

                                result_o <= 64'd0;

                            end

                        endcase

                        state_q <= DONE;
                    end
                end


                // =============================================================
                // Iterative division
                // =============================================================

                DIV_RUN: begin

                    // Perform current restoring-division iteration.
                    div_remainder_q <= div_remainder_next;
                    div_quotient_q  <= div_quotient_next;

                    count_q <= count_q - 7'd1;

                    // div_*_next contains the result including the final
                    // iteration, so completion uses those values directly.
                    if (count_q == 7'd1) begin

                        case (op_q)

                            // -------------------------------------------------
                            // 64-bit signed quotient
                            // -------------------------------------------------

                            M_DIV: begin

                                if (div_quotient_negative_q)
                                    result_o <=
                                        negate64(div_quotient_next);
                                else
                                    result_o <=
                                        div_quotient_next;

                            end


                            // -------------------------------------------------
                            // 64-bit unsigned quotient
                            // -------------------------------------------------

                            M_DIVU: begin

                                result_o <=
                                    div_quotient_next;

                            end


                            // -------------------------------------------------
                            // 64-bit signed remainder
                            // -------------------------------------------------

                            M_REM: begin

                                if (div_remainder_negative_q)
                                    result_o <=
                                        negate64(div_remainder_next);
                                else
                                    result_o <=
                                        div_remainder_next;

                            end


                            // -------------------------------------------------
                            // 64-bit unsigned remainder
                            // -------------------------------------------------

                            M_REMU: begin

                                result_o <=
                                    div_remainder_next;

                            end


                            // -------------------------------------------------
                            // 32-bit signed quotient
                            // -------------------------------------------------

                            M_DIVW: begin

                                if (div_quotient_negative_q)
                                    result_o <=
                                        sext32(
                                            negate32(
                                                div_quotient_next[31:0]
                                            )
                                        );
                                else
                                    result_o <=
                                        sext32(
                                            div_quotient_next[31:0]
                                        );

                            end


                            // -------------------------------------------------
                            // 32-bit unsigned quotient
                            //
                            // RV64 W operations sign-extend their 32-bit result,
                            // including DIVUW.
                            // -------------------------------------------------

                            M_DIVUW: begin

                                result_o <=
                                    sext32(
                                        div_quotient_next[31:0]
                                    );

                            end


                            // -------------------------------------------------
                            // 32-bit signed remainder
                            // -------------------------------------------------

                            M_REMW: begin

                                if (div_remainder_negative_q)
                                    result_o <=
                                        sext32(
                                            negate32(
                                                div_remainder_next[31:0]
                                            )
                                        );
                                else
                                    result_o <=
                                        sext32(
                                            div_remainder_next[31:0]
                                        );

                            end


                            // -------------------------------------------------
                            // 32-bit unsigned remainder
                            //
                            // REMUW also sign-extends its 32-bit result.
                            // -------------------------------------------------

                            M_REMUW: begin

                                result_o <=
                                    sext32(
                                        div_remainder_next[31:0]
                                    );

                            end


                            default: begin

                                result_o <= 64'd0;

                            end

                        endcase

                        state_q <= DONE;
                    end
                end


                // =============================================================
                // Completion
                // =============================================================
                //
                // result_valid_o is combinationally asserted whenever state_q
                // is DONE. Therefore the completed result remains valid for
                // this entire cycle.
                // =============================================================

                DONE: begin

                    state_q <= IDLE;

                end


                default: begin

                    state_q <= IDLE;

                end

            endcase
        end
    end

endmodule
