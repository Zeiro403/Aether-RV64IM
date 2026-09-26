module mem_wb_reg (
    input  logic clk,
    input  logic rst_n,

    // ============================================================
    // Pipeline Control
    // ============================================================

    input  logic stall_i,

    // ============================================================
    // MEM Stage Input
    // ============================================================

    input  logic        valid_i,

    `ifndef SYNTHESIS
        input  logic [63:0] pc_i,
        input  logic [31:0] instr_i,
    `endif

    // Final architectural result produced by MEM.
    input  logic [63:0] result_i,

    input  logic [4:0]  rd_addr_i,
    input  logic        reg_write_i,

    // ============================================================
    // WB Stage Output
    // ============================================================

    output logic        valid_o,

    `ifndef SYNTHESIS
        output logic [63:0] pc_o,
        output logic [31:0] instr_o,
    `endif

    output logic [63:0] result_o,

    output logic [4:0]  rd_addr_o,
    output logic        reg_write_o
);

    // ============================================================
    // MEM -> WB Pipeline Register
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

            result_o <= 64'b0;

            rd_addr_o   <= 5'b0;
            reg_write_o <= 1'b0;


        // --------------------------------------------------------
        // Normal Advance
        // --------------------------------------------------------

        end else if (!stall_i) begin

            valid_o <= valid_i;

            `ifndef SYNTHESIS
                pc_o    <= pc_i;
                instr_o <= instr_i;
            `endif

            result_o <= result_i;

            rd_addr_o   <= rd_addr_i;
            reg_write_o <= reg_write_i;
        end
    end

endmodule
