module tracer (
    input logic clk,

    input logic        retire_valid_i,
    input logic [63:0] retire_pc_i,
    input logic [31:0] retire_instr_i,

    input logic        retire_rd_wen_i,
    input logic [4:0]  retire_rd_addr_i,
    input logic [63:0] retire_rd_data_i
);

    always_ff @(posedge clk) begin
        if (retire_valid_i) begin

            if (retire_rd_wen_i) begin
                $display(
                    "core   0: 0x%016h (0x%08h) x%-2d 0x%016h",
                    retire_pc_i,
                    retire_instr_i,
                    retire_rd_addr_i,
                    retire_rd_data_i
                );

            end else begin
                $display(
                    "core   0: 0x%016h (0x%08h)",
                    retire_pc_i,
                    retire_instr_i
                );
            end
        end
    end


endmodule
