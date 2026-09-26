package riscv_pkg;

    // ------------------------------------
    // 1. Basic Parameters
    // ------------------------------------
    /* verilator lint_off UNUSEDPARAM */
    localparam int XLEN = 64;
    localparam int ILEN = 32;
    /* verilator lint_on UNUSEDPARAM */

    // ------------------------------------
    // 2. Opcodes (RV64I Base)
    // ------------------------------------
    typedef enum logic [6:0] {
        OP_LUI    = 7'b0110111,
        OP_AUIPC  = 7'b0010111,
        OP_JAL    = 7'b1101111,
        OP_JALR   = 7'b1100111,
        OP_BRANCH = 7'b1100011,
        OP_LOAD   = 7'b0000011,
        OP_STORE  = 7'b0100011,
        OP_IMM    = 7'b0010011, 
        OP_IMM_32 = 7'b0011011,
        OP_REG    = 7'b0110011,
        OP_REG_32 = 7'b0111011,
        OP_FENCE =  7'b0001111,
        OP_SYSTEM = 7'b1110011
    } opcode_t;

    // ------------------------------------
    // 3. ALU Operations
    // ------------------------------------
    typedef enum logic [4:0] {
        //Arithmetic
        ALU_ADD,  ALU_ADDW,  
        ALU_SUB,  ALU_SUBW,
        //Logical
        ALU_OR,   ALU_AND, ALU_XOR,
        //Comparison
        ALU_SLT,  ALU_SLTU, 
        //Shift
        ALU_SLL,  ALU_SLLW, 
        ALU_SRL,  ALU_SRLW, 
        ALU_SRA,  ALU_SRAW  
    } alu_op_t;

    typedef enum logic [3:0] {
        LSU_NONE,   // Not a memory op
        LSU_LB,     // Load Byte (Signed)
        LSU_LH,     // Load Halfword (Signed)
        LSU_LW,     // Load Word (Signed)
        LSU_LD,     // Load Doubleword
        LSU_LBU,    // Load Byte (Unsigned)
        LSU_LHU,    // Load Halfword (Unsigned)
        LSU_LWU,    // Load Word (Unsigned)
        LSU_SB,     // Store Byte
        LSU_SH,     // Store Halfword
        LSU_SW,     // Store Word
        LSU_SD      // Store Doubleword
    } lsu_op_t;

    typedef enum logic [3:0] {
        BRANCH_NONE ,
        BRANCH_BEQ  ,
        BRANCH_BNE  ,
        BRANCH_BLT  ,
        BRANCH_BGE  ,
        BRANCH_BLTU ,
        BRANCH_BGEU
    } branch_op_t;

    typedef enum logic [3:0] { // 4 bits to be safe
        M_NONE,
        M_MUL,      // Low 64 bits of Signed*Signed
        M_MULH,     // High 64 bits of Signed*Signed
        M_MULHSU,   // High 64 bits of Signed*Unsigned
        M_MULHU,    // High 64 bits of Unsigned*Unsigned
        M_MULW,
        
        M_DIV,      // Signed Divide
        M_DIVU,     // Unsigned Divide
        M_REM,      // Signed Remainder
        M_REMU,      // Unsigned Remainder
        M_DIVW,
        M_DIVUW,
        M_REMW,
        M_REMUW
    } mul_op_t;

    // ------------------------------------
    // 4. CSR Addresses (Machine Mode)
    // ------------------------------------
    typedef enum logic [11:0] {
        CSR_MSTATUS  = 12'h300, // Machine status register
        CSR_MISA     = 12'h301, // ISA and extensions
        CSR_MIE      = 12'h304, // Machine interrupt-enable register
        CSR_MTVEC    = 12'h305, // Machine trap-handler base address
        CSR_MSCRATCH = 12'h340, // Scratch register for machine trap handlers
        CSR_MEPC     = 12'h341, // Machine exception program counter
        CSR_MCAUSE   = 12'h342, // Machine trap cause
        CSR_MTVAL    = 12'h343,
        CSR_MIP      = 12'h344, // Machine interrupt pending
        CSR_MCYCLE   = 12'hB00, // Machine cycle counter
        CSR_MINSTRET = 12'hB02  // Machine instructions-retired counter
    } csr_addr_t;

    // ------------------------------------
    // 5. CSR Operations (funct3)
    // ------------------------------------
    typedef enum logic [2:0] {
        CSR_NONE = 3'b000,
        CSR_RW   = 3'b001, // Atomic Read/Write
        CSR_RS   = 3'b010, // Atomic Read/Set Bit
        CSR_RC   = 3'b011, // Atomic Read/Clear Bit
        CSR_RWI  = 3'b101, // Immediate Read/Write
        CSR_RSI  = 3'b110, // Immediate Read/Set
        CSR_RCI  = 3'b111  // Immediate Read/Clear
    } csr_op_t;

    typedef enum logic [2:0] {
        FU_NONE,
        FU_ALU,
        FU_LSU,
        FU_BRANCH,
        FU_MULDIV,
        FU_CSR
    } fu_t;

    typedef enum logic [1:0] {
        OP_A_RS1,
        OP_A_PC,
        OP_A_ZERO
    } op_a_sel_t;

    typedef enum logic [1:0] {
        OP_B_RS2,
        OP_B_IMM,
        OP_B_FOUR
    } op_b_sel_t;

    typedef enum logic [1:0] {
        CTRL_NONE,
        CTRL_BRANCH,
        CTRL_JAL,
        CTRL_JALR
    } ctrl_flow_t;

    typedef enum logic [1:0] {
    FWD_REG,
    FWD_MEM,
    FWD_WB
} forward_sel_t;

function automatic logic lsu_is_load(lsu_op_t op);
    case (op)
        LSU_LB,
        LSU_LH,
        LSU_LW,
        LSU_LD,
        LSU_LBU,
        LSU_LHU,
        LSU_LWU: lsu_is_load = 1'b1;

        default: lsu_is_load = 1'b0;
    endcase
endfunction


function automatic logic lsu_is_store(lsu_op_t op);
    case (op)
        LSU_SB,
        LSU_SH,
        LSU_SW,
        LSU_SD: lsu_is_store = 1'b1;

        default: lsu_is_store = 1'b0;
    endcase
endfunction


function automatic logic csr_is_imm(csr_op_t op);
    case (op)
        CSR_RWI,
        CSR_RSI,
        CSR_RCI: csr_is_imm = 1'b1;

        default: csr_is_imm = 1'b0;
    endcase
endfunction

endpackage
