module hazard_unit (
    // Inputs from Decode Stage (Current Instruction)
    input  logic [4:0]  id_rs1_addr_i,
    input  logic [4:0]  id_rs2_addr_i,

    // Inputs from Execute Stage (Previous Instruction)
    input  logic [4:0]  ex_rd_addr_i,
    input  logic        ex_mem_read_i, // Is EX doing a Load?

    // Output Controls
    output logic        stall_hazard_o,   // Freeze PC
    output logic        flush_hazard_o    // Insert NOP into ID/EX
);

    always_comb begin
        stall_hazard_o = 1'b0;
        flush_hazard_o = 1'b0;

        // LOAD-USE HAZARD DETECTION
        // If EX is a Load, and EX.rd matches ID.rs1 or ID.rs2:
        if (ex_mem_read_i && (ex_rd_addr_i != 5'd0) &&
           ((ex_rd_addr_i == id_rs1_addr_i) || (ex_rd_addr_i == id_rs2_addr_i))) begin
            
            // Stall the pipeline for 1 cycle
            stall_hazard_o = 1'b1; // Do not fetch next
            flush_hazard_o = 1'b1; // Send NOP to EX (Bubble)
        end
    end

endmodule
