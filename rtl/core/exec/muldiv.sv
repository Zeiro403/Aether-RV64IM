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

    localparam logic [5:0] LATENCY_MUL = 6'd4;
    localparam logic [5:0] LATENCY_DIV = 6'd32;

    typedef enum logic [1:0] {
        IDLE,
        BUSY,
        DONE
    } state_t;

    state_t state_q;

    logic [63:0] op_a_q;
    logic [63:0] op_b_q;
    mul_op_t     op_q;

    logic [5:0] counter_q;

    logic [63:0] calculated_result;

/* verilator lint_off UNUSEDSIGNAL */
logic        [127:0] mul_uu;
logic signed [127:0] mul_ss;
logic signed [128:0] mul_su;
/* verilator lint_on UNUSEDSIGNAL */

    logic signed [31:0] a32_s;
    logic signed [31:0] b32_s;
    logic        [31:0] a32_u;
    logic        [31:0] b32_u;

    logic signed [31:0] mulw_result;
logic signed [31:0] divw_result;
logic        [31:0] divuw_result;
logic signed [31:0] remw_result;
logic        [31:0] remuw_result;

    // ============================================================
    // Operation classification
    // ============================================================

    function automatic logic is_div_op(mul_op_t op);
        case (op)
            M_DIV,
            M_DIVU,
            M_REM,
            M_REMU,
            M_DIVW,
            M_DIVUW,
            M_REMW,
            M_REMUW: is_div_op = 1'b1;

            default: is_div_op = 1'b0;
        endcase
    endfunction


    // ============================================================
    // Interface outputs
    // ============================================================

    assign result_valid_o = (state_q == DONE);


    // ============================================================
    // Arithmetic
    //
    // This is currently behavioral arithmetic. The handshake around
    // it is architectural; the arithmetic implementation can later
    // be replaced by iterative/pipelined hardware without changing
    // the surrounding pipeline interface.
    // ============================================================

    always_comb begin
        calculated_result = 64'b0;

        mul_uu = 128'b0;
        mul_ss = '0;
        mul_su = '0;

        a32_s = $signed(op_a_q[31:0]);
        b32_s = $signed(op_b_q[31:0]);

        a32_u = op_a_q[31:0];
        b32_u = op_b_q[31:0];

        mulw_result  = 32'b0;
divw_result  = 32'b0;
divuw_result = 32'b0;
remw_result  = 32'b0;
remuw_result = 32'b0;

        case (op_q)

            // ----------------------------------------------------
            // RV64 multiply
            // ----------------------------------------------------

            M_MUL: begin
                calculated_result = op_a_q * op_b_q;
            end

            M_MULH: begin
                mul_ss = $signed(op_a_q) * $signed(op_b_q);
                calculated_result = mul_ss[127:64];
            end

            M_MULHSU: begin
                // 65-bit signed representations avoid treating an
                // unsigned operand with bit 63 set as negative.
                mul_su =
                    $signed({op_a_q[63], op_a_q}) *
                    $signed({1'b0, op_b_q});

                calculated_result = mul_su[127:64];
            end

            M_MULHU: begin
                mul_uu = op_a_q * op_b_q;
                calculated_result = mul_uu[127:64];
            end


            // ----------------------------------------------------
            // RV64 divide / remainder
            // ----------------------------------------------------

            M_DIV: begin
                if (op_b_q == 64'b0) begin
                    calculated_result = 64'hFFFF_FFFF_FFFF_FFFF;

                end else if (
                    (op_a_q == 64'h8000_0000_0000_0000) &&
                    (op_b_q == 64'hFFFF_FFFF_FFFF_FFFF)
                ) begin
                    calculated_result = 64'h8000_0000_0000_0000;

                end else begin
                    calculated_result =
                        $signed(op_a_q) / $signed(op_b_q);
                end
            end

            M_DIVU: begin
                if (op_b_q == 64'b0)
                    calculated_result = 64'hFFFF_FFFF_FFFF_FFFF;
                else
                    calculated_result = op_a_q / op_b_q;
            end

            M_REM: begin
                if (op_b_q == 64'b0) begin
                    calculated_result = op_a_q;

                end else if (
                    (op_a_q == 64'h8000_0000_0000_0000) &&
                    (op_b_q == 64'hFFFF_FFFF_FFFF_FFFF)
                ) begin
                    calculated_result = 64'b0;

                end else begin
                    calculated_result =
                        $signed(op_a_q) % $signed(op_b_q);
                end
            end

            M_REMU: begin
                if (op_b_q == 64'b0)
                    calculated_result = op_a_q;
                else
                    calculated_result = op_a_q % op_b_q;
            end


// ----------------------------------------------------
// RV64 word operations
// ----------------------------------------------------

M_MULW: begin
    mulw_result = a32_s * b32_s;

    calculated_result = {
        {32{mulw_result[31]}},
        mulw_result
    };
end


M_DIVW: begin

    if (b32_s == 32'sd0) begin

        // Division by zero => -1
        divw_result = -32'sd1;

    end else if (
        (a32_s == 32'sh8000_0000) &&
        (b32_s == -32'sd1)
    ) begin

        // Signed overflow
        divw_result = 32'sh8000_0000;

    end else begin

        divw_result = a32_s / b32_s;
    end

    calculated_result = {
        {32{divw_result[31]}},
        divw_result
    };
end


M_DIVUW: begin

    if (b32_u == 32'b0) begin

        // Division by zero => all ones
        divuw_result = 32'hFFFF_FFFF;

    end else begin

        divuw_result = a32_u / b32_u;
    end

    // RV64 *W operations always sign-extend their 32-bit result.
    calculated_result = {
        {32{divuw_result[31]}},
        divuw_result
    };
end


M_REMW: begin

    if (b32_s == 32'sd0) begin

        // Remainder by zero => dividend
        remw_result = a32_s;

    end else if (
        (a32_s == 32'sh8000_0000) &&
        (b32_s == -32'sd1)
    ) begin

        remw_result = 32'sd0;

    end else begin

        remw_result = a32_s % b32_s;
    end

    calculated_result = {
        {32{remw_result[31]}},
        remw_result
    };
end


M_REMUW: begin

    if (b32_u == 32'b0) begin

        // Remainder by zero => dividend
        remuw_result = a32_u;

    end else begin

        remuw_result = a32_u % b32_u;
    end

    calculated_result = {
        {32{remuw_result[31]}},
        remuw_result
    };
end

            default: begin
                calculated_result = 64'b0;
            end

        endcase
    end


    // ============================================================
    // Request / completion state
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state_q   <= IDLE;
            counter_q <= 6'b0;

            op_a_q <= 64'b0;
            op_b_q <= 64'b0;
            op_q   <= M_NONE;

            result_o <= 64'b0;

        end else begin

            case (state_q)

                // ------------------------------------------------
                // Accept exactly one request.
                // ------------------------------------------------

                IDLE: begin
                    if (start_i &&
                        (op_i != M_NONE)) begin

                        op_a_q <= op_a_i;
                        op_b_q <= op_b_i;
                        op_q   <= op_i;

                        if (is_div_op(op_i))
                            counter_q <= LATENCY_DIV - 6'd1;
                        else
                            counter_q <= LATENCY_MUL - 6'd1;

                        state_q <= BUSY;
                    end
                end


                // ------------------------------------------------
                // Behavioral latency.
                // ------------------------------------------------

                BUSY: begin
                    if (counter_q != 6'b0) begin
                        counter_q <= counter_q - 6'd1;

                    end else begin
                        result_o <= calculated_result;
                        state_q  <= DONE;
                    end
                end


                // ------------------------------------------------
                // Result is valid for one complete cycle.
                //
                // The surrounding in-order EX stage is expected to
                // advance the instruction during this cycle.
                // ------------------------------------------------

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
