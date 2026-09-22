module tracer (
    input logic        clk,
    input logic        valid_wb_i,    // "Did an instruction finish this cycle?"
    input logic [63:0] pc_i,          // The PC of that instruction
    input logic [31:0] instr_i,       // The raw 32-bit machine code
    input logic        reg_write_i,   // Did we write to a register?
    input logic [4:0]  rd_addr_i,     // Which register?
    input logic [63:0] rd_data_i      // What value?
);

    // Spike Log Format:
    // core   0: 0x0000000080000000 (0x00000297) x5  0x0000000080000297
    
    logic [63:0] prev_pc;
    always @(posedge clk) begin
        // Only print if valid AND it's not the same PC we just printed unless it's a branch to self
        if (valid_wb_i && reg_write_i && (rd_addr_i != 0) && (pc_i != prev_pc)) begin
            $display("core   0: 0x%016x (0x%08x) x%0d  0x%016x", 
                     pc_i, instr_i, rd_addr_i, rd_data_i);
            prev_pc <= pc_i;
        end
    end

endmodule
