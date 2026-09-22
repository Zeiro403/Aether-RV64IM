module branch_comp 
    import riscv_pkg::*;
(
    input  branch_op_t  branch_op_i,
    input  logic [63:0] op_a_i,
    input  logic [63:0] op_b_i,
    output logic        branch_taken_o
);

    logic is_equal;
    logic is_less_signed;
    logic is_less_unsigned;

    // 1. Basic Comparisons
    assign is_equal = (op_a_i == op_b_i);
    assign is_less_signed = ($signed(op_a_i) < $signed(op_b_i));
    assign is_less_unsigned = (op_a_i < op_b_i);

    // 2. Selection Logic
    always_comb begin
        case (branch_op_i)
            BRANCH_BEQ:  branch_taken_o = is_equal;
            BRANCH_BNE:  branch_taken_o = !is_equal;
            BRANCH_BLT:  branch_taken_o = is_less_signed;
            BRANCH_BGE:  branch_taken_o = !is_less_signed;
            BRANCH_BLTU: branch_taken_o = is_less_unsigned;
            BRANCH_BGEU: branch_taken_o = !is_less_unsigned;
            default:     branch_taken_o = 1'b0;
        endcase
    end

endmodule
