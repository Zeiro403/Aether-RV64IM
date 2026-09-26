module regfile (
    input  logic        clk,
    input  logic        rst_n,

    // Read port 1
    input  logic [4:0]  rs1_addr_i,
    output logic [63:0] rs1_data_o,

    // Read port 2
    input  logic [4:0]  rs2_addr_i,
    output logic [63:0] rs2_data_o,

    // Write port
    input  logic [4:0]  rd_addr_i,
    input  logic [63:0] rd_data_i,
    input  logic        rd_wen_i
);

    logic [63:0] regs [0:31];

    // ============================================================
    // Write Port
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= 64'b0;
            end
        end else if (rd_wen_i && (rd_addr_i != 5'd0)) begin
            regs[rd_addr_i] <= rd_data_i;
        end
    end

    // ============================================================
    // Read Port 1
    // ============================================================
    //
    // WB -> ID bypass ensures that a register written in the
    // current cycle is immediately visible to Decode.
    // ============================================================

    always_comb begin
        if (rs1_addr_i == 5'd0) begin
            rs1_data_o = 64'b0;

        end else if (rd_wen_i && (rd_addr_i == rs1_addr_i)) begin
            rs1_data_o = rd_data_i;

        end else begin
            rs1_data_o = regs[rs1_addr_i];
        end
    end

    // ============================================================
    // Read Port 2
    // ============================================================

    always_comb begin
        if (rs2_addr_i == 5'd0) begin
            rs2_data_o = 64'b0;

        end else if (rd_wen_i && (rd_addr_i == rs2_addr_i)) begin
            rs2_data_o = rd_data_i;

        end else begin
            rs2_data_o = regs[rs2_addr_i];
        end
    end

endmodule
