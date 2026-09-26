module if_id_reg (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        valid_i,
    input  logic [63:0] pc_i,
    input  logic [31:0] instr_i,

    input  logic        stall_i,
    input  logic        flush_i,

    output logic        valid_o,
    output logic [63:0] pc_o,
    output logic [31:0] instr_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_o <= 1'b0;
            pc_o    <= 64'b0;
            instr_o <= 32'h0000_0013;

        end else if (flush_i) begin
            valid_o <= 1'b0;
            pc_o    <= 64'b0;
            instr_o <= 32'h0000_0013;

        end else if (!stall_i) begin
            valid_o <= valid_i;

            if (valid_i) begin
                pc_o    <= pc_i;
                instr_o <= instr_i;
            end else begin
                pc_o    <= 64'b0;
                instr_o <= 32'h0000_0013; // NOP
            end
        end
    end

endmodule
