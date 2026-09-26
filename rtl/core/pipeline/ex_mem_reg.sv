module ex_mem_reg 
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
    // EX Stage Input
    // ============================================================

    input  logic        valid_i,

    `ifndef SYNTHESIS
        input  logic [63:0] pc_i,
        input  logic [31:0] instr_i,
    `endif

    input  logic [63:0] result_i,
    input  logic [63:0] store_data_i,

    input  logic [4:0]  rd_addr_i,
    input  logic        reg_write_i,

    input  fu_t          fu_i,
    input  lsu_op_t      lsu_op_i,

    // ============================================================
    // MEM Stage Output
    // ============================================================

    output logic        valid_o,

    `ifndef SYNTHESIS
        output logic [63:0] pc_o,
        output logic [31:0] instr_o,
    `endif

    output logic [63:0] result_o,
    output logic [63:0] store_data_o,

    output logic [4:0]  rd_addr_o,
    output logic        reg_write_o,

    output fu_t          fu_o,
    output lsu_op_t      lsu_op_o
);

    // ============================================================
    // EX -> MEM Pipeline Register
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        if (!rst_n) begin

            valid_o <= 1'b0;

            `ifndef SYNTHESIS
                pc_o    <= 64'b0;
                instr_o <= 32'b0;
            `endif

            result_o     <= 64'b0;
            store_data_o <= 64'b0;

            rd_addr_o   <= 5'b0;
            reg_write_o <= 1'b0;

            fu_o     <= FU_NONE;
            lsu_op_o <= LSU_NONE;


        // --------------------------------------------------------
        // Flush
        // --------------------------------------------------------
        //
        // valid=0 is the architectural bubble.
        //
        // Side-effect controls are also cleared for deterministic
        // behavior and additional safety.
        // --------------------------------------------------------

        end else if (flush_i) begin

            valid_o <= 1'b0;

            reg_write_o <= 1'b0;

            fu_o     <= FU_NONE;
            lsu_op_o <= LSU_NONE;


        // --------------------------------------------------------
        // Normal Advance
        // --------------------------------------------------------
        //
        // If stall_i=1 there are no assignments, therefore the
        // complete MEM-stage instruction remains unchanged.
        // --------------------------------------------------------

        end else if (!stall_i) begin

            valid_o <= valid_i;

            `ifndef SYNTHESIS
                pc_o    <= pc_i;
                instr_o <= instr_i;
            `endif

            result_o     <= result_i;
            store_data_o <= store_data_i;

            rd_addr_o   <= rd_addr_i;
            reg_write_o <= reg_write_i;

            fu_o     <= fu_i;
            lsu_op_o <= lsu_op_i;
        end
    end

endmodule
