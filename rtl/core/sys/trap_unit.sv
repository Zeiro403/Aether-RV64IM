module trap_unit (
    // ============================================================
    // Instruction Validity
    // ============================================================

    // Indicates that the EX stage currently contains a real
    // architectural instruction.
    input  logic        valid_i,

    // ============================================================
    // Exception / System Triggers
    // ============================================================

    input  logic        is_ecall_i,
    input  logic        is_ebreak_i,
    input  logic        is_mret_i,

    input  logic        illegal_instr_i,
    input  logic        load_misaligned_i,
    input  logic        store_misaligned_i,

    // Faulting address for address-related exceptions.
    input  logic [63:0] bad_addr_i,

    // ============================================================
    // Current Instruction Information
    // ============================================================

    input  logic [63:0] curr_pc_i,
    input  logic [31:0] curr_instr_i,

    // ============================================================
    // CSR State
    // ============================================================

    input  logic [63:0] mtvec_i,
    input  logic [63:0] mepc_i,

    // ============================================================
    // CSR Update Interface
    // ============================================================

    // A synchronous exception occurred.
    output logic        trap_en_o,

    // A valid MRET instruction is executing.
    output logic        mret_en_o,

    output logic [63:0] trap_cause_o,
    output logic [63:0] trap_pc_o,
    output logic [63:0] trap_val_o,

    // ============================================================
    // Frontend Redirect Interface
    // ============================================================

    output logic        redirect_valid_o,
    output logic [63:0] redirect_pc_o
);

    // ============================================================
    // Machine-Mode Exception Causes
    // ============================================================

    localparam logic [63:0] CAUSE_ILLEGAL_INSTR =
        64'd2;

    localparam logic [63:0] CAUSE_BREAKPOINT =
        64'd3;

    localparam logic [63:0] CAUSE_LOAD_MISALIGNED =
        64'd4;

    localparam logic [63:0] CAUSE_STORE_MISALIGNED =
        64'd6;

    localparam logic [63:0] CAUSE_ECALL_MMODE =
        64'd11;


    // ============================================================
    // Trap / Return Control
    // ============================================================

    always_comb begin

        // --------------------------------------------------------
        // Defaults
        // --------------------------------------------------------

        trap_en_o    = 1'b0;
        mret_en_o    = 1'b0;

        trap_cause_o = 64'b0;
        trap_pc_o    = curr_pc_i;
        trap_val_o   = 64'b0;

        redirect_valid_o = 1'b0;
        redirect_pc_o    = 64'b0;


        // --------------------------------------------------------
        // An invalid pipeline entry cannot generate any exception,
        // CSR trap update, MRET, or redirect.
        // --------------------------------------------------------

        if (valid_i) begin

            // ====================================================
            // 1. Illegal Instruction
            // ====================================================

            if (illegal_instr_i) begin

                trap_en_o = 1'b1;

                trap_cause_o = CAUSE_ILLEGAL_INSTR;
                trap_val_o   = {32'b0, curr_instr_i};

                redirect_valid_o = 1'b1;
                redirect_pc_o    = mtvec_i;


            // ====================================================
            // 2. ECALL from Machine Mode
            // ====================================================

            end else if (is_ecall_i) begin

                trap_en_o = 1'b1;

                trap_cause_o = CAUSE_ECALL_MMODE;
                trap_val_o   = 64'b0;

                redirect_valid_o = 1'b1;
                redirect_pc_o    = mtvec_i;


            // ====================================================
            // 3. EBREAK
            // ====================================================

            end else if (is_ebreak_i) begin

                trap_en_o = 1'b1;

                trap_cause_o = CAUSE_BREAKPOINT;
                trap_val_o   = {32'b0, curr_instr_i};

                redirect_valid_o = 1'b1;
                redirect_pc_o    = mtvec_i;


            // ====================================================
            // 4. Misaligned Load
            // ====================================================

            end else if (load_misaligned_i) begin

                trap_en_o = 1'b1;

                trap_cause_o = CAUSE_LOAD_MISALIGNED;
                trap_val_o   = bad_addr_i;

                redirect_valid_o = 1'b1;
                redirect_pc_o    = mtvec_i;


            // ====================================================
            // 5. Misaligned Store
            // ====================================================

            end else if (store_misaligned_i) begin

                trap_en_o = 1'b1;

                trap_cause_o = CAUSE_STORE_MISALIGNED;
                trap_val_o   = bad_addr_i;

                redirect_valid_o = 1'b1;
                redirect_pc_o    = mtvec_i;


            // ====================================================
            // 6. MRET
            // ====================================================
            //
            // MRET is not an exception.
            //
            // It updates mstatus through mret_en_o and redirects
            // execution to mepc.
            // ====================================================

            end else if (is_mret_i) begin

                mret_en_o = 1'b1;

                redirect_valid_o = 1'b1;
                redirect_pc_o    = mepc_i;
            end
        end
    end

endmodule
