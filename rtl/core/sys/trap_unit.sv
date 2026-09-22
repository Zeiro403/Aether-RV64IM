module trap_unit (
    // -----------------------------------------
    // Triggers (From Decode / Execute stage)
    // -----------------------------------------
    input  logic        is_ecall_i,
    input  logic        is_ebreak_i,
    input  logic        is_mret_i,
    input  logic        illegal_instr_i,
    input  logic        load_misaligned_i,
    input  logic        store_misaligned_i,
    input  logic [63:0] bad_addr_i,
    
    // -----------------------------------------
    // State Info (From Pipeline)
    // -----------------------------------------
    input  logic [63:0] curr_pc_i,       // PC of the instruction causing the trap
    input  logic [31:0] curr_instr_i,    // The instruction itself (for mtval)
    
    // -----------------------------------------
    // CSR Inputs (From csr_regfile)
    // -----------------------------------------
    input  logic [63:0] mtvec_i,         // Where to go on Trap
    input  logic [63:0] mepc_i,          // Where to go on MRET
    
    // -----------------------------------------
    // CSR Outputs (To csr_regfile)
    // -----------------------------------------
    output logic        trap_en_o,
    output logic        mret_en_o,
    output logic [63:0] trap_cause_o,
    output logic [63:0] trap_pc_o,
    output logic [63:0] trap_val_o,
    
    // -----------------------------------------
    // Fetch / Pipeline Outputs (To Hazard/Fetch)
    // -----------------------------------------
    output logic        trap_flush_o,    // Tell pipeline registers to clear
    output logic [63:0] pc_trap_val_o    // The override address
);

    // RISC-V Machine Mode Exception Codes
    localparam logic [63:0] CAUSE_ILLEGAL_INSTR    = 64'd2;
    localparam logic [63:0] CAUSE_BREAKPOINT       = 64'd3;
    localparam logic [63:0] CAUSE_LOAD_MISALIGNED  = 64'd4;  
    localparam logic [63:0] CAUSE_STORE_MISALIGNED = 64'd6;  
    localparam logic [63:0] CAUSE_ECALL_MMODE      = 64'd11;

    always_comb begin
        // Default Outputs (No Trap)
        trap_en_o     = 1'b0;
        mret_en_o     = 1'b0;
        trap_cause_o  = 64'b0;
        trap_pc_o     = curr_pc_i;
        trap_val_o    = 64'b0;
        
        trap_flush_o  = 1'b0;
        pc_trap_val_o = 64'b0;

        // 1. Check for Traps (Highest Priority)
        if (illegal_instr_i) begin
            trap_en_o     = 1'b1;
            trap_cause_o  = CAUSE_ILLEGAL_INSTR;
            trap_val_o    = {32'b0, curr_instr_i}; // Save the bad instruction
            
            trap_flush_o  = 1'b1;
            pc_trap_val_o = mtvec_i;               // Jump to handler
            
        end else if (is_ecall_i) begin
            trap_en_o     = 1'b1;
            trap_cause_o  = CAUSE_ECALL_MMODE;
            trap_val_o    = 64'b0;                 // ECALL leaves mtval 0
            
            trap_flush_o  = 1'b1;
            pc_trap_val_o = mtvec_i;               // Jump to handler
            
        end else if (is_ebreak_i) begin
            trap_en_o     = 1'b1;
            trap_cause_o  = CAUSE_BREAKPOINT;
            trap_val_o    = {32'b0, curr_instr_i};
            
            trap_flush_o  = 1'b1;
            pc_trap_val_o = mtvec_i;               // Jump to handler
            
        end else if (load_misaligned_i) begin
            trap_en_o     = 1'b1;
            trap_cause_o  = CAUSE_LOAD_MISALIGNED;
            trap_val_o    = bad_addr_i;            // Save the bad address to mtval

            
            trap_flush_o  = 1'b1;
            pc_trap_val_o = mtvec_i;
            
        end else if (store_misaligned_i) begin
            trap_en_o     = 1'b1;
            trap_cause_o  = CAUSE_STORE_MISALIGNED;
            trap_val_o    = bad_addr_i;            // Save the bad address to mtval
            
            trap_flush_o  = 1'b1;
            pc_trap_val_o = mtvec_i;
        end

        // 2. Check for Returns (MRET)
        else if (is_mret_i) begin
            mret_en_o     = 1'b1;
            
            trap_flush_o  = 1'b1;                  // Flush pipeline
            pc_trap_val_o = mepc_i;                // Jump back to saved PC
        end
    end

endmodule
