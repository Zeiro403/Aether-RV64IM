module id_ex_reg 
import riscv_pkg::*;
(
    input  logic clk,
    input  logic rst_n,

    // ============================================================
    // Pipeline Control
    // ============================================================

    input  logic stall_i,
    input  logic flush_i,

    // ============================================================
    // Instruction Identity
    // ============================================================

    input  logic        valid_i,
    input  logic [63:0] pc_i,
    input  logic [31:0] instr_i,

    // ============================================================
    // Register Information
    // ============================================================

    input  logic [4:0] rs1_addr_i,
    input  logic [4:0] rs2_addr_i,
    input  logic [4:0] rd_addr_i,

    input  logic       uses_rs1_i,
    input  logic       uses_rs2_i,

    input  logic [63:0] rs1_data_i,
    input  logic [63:0] rs2_data_i,

    // ============================================================
    // Immediate
    // ============================================================

    input  logic [63:0] imm_i,

    // ============================================================
    // Execution Description
    // ============================================================

    input  fu_t         fu_i,

    input  alu_op_t     alu_op_i,
    input  lsu_op_t     lsu_op_i,
    input  branch_op_t  branch_op_i,
    input  mul_op_t     mul_op_i,
    input  csr_op_t     csr_op_i,
    input  ctrl_flow_t  ctrl_flow_i,

    input  op_a_sel_t   op_a_sel_i,
    input  op_b_sel_t   op_b_sel_i,

    // ============================================================
    // Architectural Effects
    // ============================================================

    input  logic reg_write_i,
    input  logic csr_write_i,

    // ============================================================
    // CSR / System Information
    // ============================================================

    input  logic [11:0] csr_addr_i,

    input  logic is_ecall_i,
    input  logic is_ebreak_i,
    input  logic is_mret_i,

    input  logic illegal_instr_i,

    // ============================================================
    // Outputs: EX Stage
    // ============================================================

    output logic        valid_o,
    output logic [63:0] pc_o,
    output logic [31:0] instr_o,

    // Register information
    output logic [4:0] rs1_addr_o,
    output logic [4:0] rs2_addr_o,
    output logic [4:0] rd_addr_o,

    output logic       uses_rs1_o,
    output logic       uses_rs2_o,

    output logic [63:0] rs1_data_o,
    output logic [63:0] rs2_data_o,

    // Immediate
    output logic [63:0] imm_o,

    // Execution description
    output fu_t         fu_o,

    output alu_op_t     alu_op_o,
    output lsu_op_t     lsu_op_o,
    output branch_op_t  branch_op_o,
    output mul_op_t     mul_op_o,
    output csr_op_t     csr_op_o,
    output ctrl_flow_t  ctrl_flow_o,

    output op_a_sel_t   op_a_sel_o,
    output op_b_sel_t   op_b_sel_o,

    // Architectural effects
    output logic reg_write_o,
    output logic csr_write_o,

    // CSR / system information
    output logic [11:0] csr_addr_o,

    output logic is_ecall_o,
    output logic is_ebreak_o,
    output logic is_mret_o,

    output logic illegal_instr_o
);

    // ============================================================
    // ID -> EX Pipeline Register
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        // --------------------------------------------------------
        // Asynchronous Reset
        // --------------------------------------------------------
        if (!rst_n) begin

            valid_o <= 1'b0;

            pc_o    <= 64'b0;
            instr_o <= 32'b0;

            rs1_addr_o <= 5'b0;
            rs2_addr_o <= 5'b0;
            rd_addr_o  <= 5'b0;

            uses_rs1_o <= 1'b0;
            uses_rs2_o <= 1'b0;

            rs1_data_o <= 64'b0;
            rs2_data_o <= 64'b0;

            imm_o <= 64'b0;

            fu_o <= FU_NONE;

            alu_op_o     <= ALU_ADD;
            lsu_op_o     <= LSU_NONE;
            branch_op_o  <= BRANCH_NONE;
            mul_op_o     <= M_NONE;
            csr_op_o     <= CSR_NONE;
            ctrl_flow_o  <= CTRL_NONE;

            op_a_sel_o <= OP_A_RS1;
            op_b_sel_o <= OP_B_RS2;

            reg_write_o <= 1'b0;
            csr_write_o <= 1'b0;

            csr_addr_o <= 12'b0;

            is_ecall_o  <= 1'b0;
            is_ebreak_o <= 1'b0;
            is_mret_o   <= 1'b0;

            illegal_instr_o <= 1'b0;

        // --------------------------------------------------------
        // Flush
        // --------------------------------------------------------
        //
        // Architecturally, valid_o = 0 is sufficient to represent
        // a bubble.
        //
        // During the current pipeline refactor we additionally clear
        // side-effect controls so the existing Execute stage cannot
        // accidentally act on stale control information.
        // --------------------------------------------------------
        end else if (flush_i) begin

            valid_o <= 1'b0;

            fu_o         <= FU_NONE;
            lsu_op_o     <= LSU_NONE;
            branch_op_o  <= BRANCH_NONE;
            mul_op_o     <= M_NONE;
            csr_op_o     <= CSR_NONE;
            ctrl_flow_o  <= CTRL_NONE;

            reg_write_o <= 1'b0;
            csr_write_o <= 1'b0;

            uses_rs1_o <= 1'b0;
            uses_rs2_o <= 1'b0;

            is_ecall_o  <= 1'b0;
            is_ebreak_o <= 1'b0;
            is_mret_o   <= 1'b0;

            illegal_instr_o <= 1'b0;

        // --------------------------------------------------------
        // Normal Pipeline Advance
        // --------------------------------------------------------
        //
        // If stall_i is asserted, this branch is not entered and
        // every register naturally retains its previous value.
        // --------------------------------------------------------
        end else if (!stall_i) begin

            valid_o <= valid_i;

            pc_o    <= pc_i;
            instr_o <= instr_i;

            rs1_addr_o <= rs1_addr_i;
            rs2_addr_o <= rs2_addr_i;
            rd_addr_o  <= rd_addr_i;

            uses_rs1_o <= uses_rs1_i;
            uses_rs2_o <= uses_rs2_i;

            rs1_data_o <= rs1_data_i;
            rs2_data_o <= rs2_data_i;

            imm_o <= imm_i;

            fu_o <= fu_i;

            alu_op_o     <= alu_op_i;
            lsu_op_o     <= lsu_op_i;
            branch_op_o  <= branch_op_i;
            mul_op_o     <= mul_op_i;
            csr_op_o     <= csr_op_i;
            ctrl_flow_o  <= ctrl_flow_i;

            op_a_sel_o <= op_a_sel_i;
            op_b_sel_o <= op_b_sel_i;

            reg_write_o <= reg_write_i;
            csr_write_o <= csr_write_i;

            csr_addr_o <= csr_addr_i;

            is_ecall_o  <= is_ecall_i;
            is_ebreak_o <= is_ebreak_i;
            is_mret_o   <= is_mret_i;

            illegal_instr_o <= illegal_instr_i;
        end
    end

endmodule
