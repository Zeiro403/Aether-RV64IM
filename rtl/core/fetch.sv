module fetch (
    // Inputs from Prefetch Buffer
    input  logic        pf_valid_i,
    input  logic [31:0] pf_instr_i,
    input  logic [63:0] pf_pc_i,

    // Outputs to IF/ID Register
    output logic        stall_fetch_o,
    output logic [31:0] instr_o,
    output logic [63:0] pc_out_o
);

    // Stall Logic
    // If the buffer is empty stall the pipeline
    assign stall_fetch_o = ~pf_valid_i;
    // If the buffer is empty pass NOP (0x00000013) to the bus
    assign instr_o  = pf_valid_i ? pf_instr_i : 32'h00000013;
    assign pc_out_o = pf_pc_i;

endmodule
