module csr_regfile 
    import riscv_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // -----------------------------------------
    // Pipeline Interface
    // -----------------------------------------
    input  logic [11:0] addr_i,
    input  logic [63:0] wdata_i,
    input  csr_op_t     op_i,
    input  logic        we_i,
    
    output logic [63:0] rdata_o,
    output logic        csr_valid_o,  

    // -----------------------------------------
    // Hardware Trap Interface
    // -----------------------------------------
    input  logic        trap_en_i,    // Trap occurred

    /* verilator lint_off UNUSED */
    input  logic [63:0] trap_pc_i,    // PC of trap
    /* verilator lint_on UNUSED */

    input  logic [63:0] trap_cause_i, // Cause code
    input  logic [63:0] trap_val_i,   // mtval (faulting address/instruction)

    input  logic        mret_i,    
    input  logic        instret_i,  
    
    output logic [63:0] mtvec_o,      
    output logic [63:0] mepc_o        
);

    // -----------------------------------------
    // Registers
    // -----------------------------------------
    logic [63:0] mstatus; 
    logic [63:0] mtvec;
    logic [63:0] mscratch;
    logic [63:0] mepc;
    logic [63:0] mcause;
    logic [63:0] mtval;
    logic [63:0] mcycle;
    logic [63:0] minstret;

    // -----------------------------------------
    // 1. Read Logic & Validity Check
    // -----------------------------------------
    logic [63:0] csr_read_val;
    
    always_comb begin
        csr_valid_o = 1'b1;
        case (addr_i)
            CSR_MSTATUS:  csr_read_val = mstatus;
            CSR_MIE:      csr_read_val = 64'b0; 
            CSR_MIP:      csr_read_val = 64'b0;
            CSR_MTVEC:    csr_read_val = mtvec;
            CSR_MSCRATCH: csr_read_val = mscratch;
            CSR_MEPC:     csr_read_val = mepc;
            CSR_MCAUSE:   csr_read_val = mcause;
            CSR_MTVAL:    csr_read_val = mtval;
            CSR_MCYCLE:   csr_read_val = mcycle;
            CSR_MINSTRET: csr_read_val = minstret;
            CSR_MISA:     csr_read_val = 64'h8000_0000_0010_0100; // RV64IM
            default: begin
                csr_read_val = 64'b0;
                csr_valid_o  = 1'b0; // Flag illegal CSR access
            end
        endcase
    end

    assign rdata_o = csr_read_val;

    // -----------------------------------------
    // 2. Atomic Write Calculation
    // -----------------------------------------
    logic [63:0] final_wdata;
    always_comb begin
        case (op_i)
            CSR_RW, CSR_RWI: final_wdata = wdata_i;
            CSR_RS, CSR_RSI: final_wdata = csr_read_val | wdata_i;
            CSR_RC, CSR_RCI: final_wdata = csr_read_val & ~wdata_i;
            default:         final_wdata = wdata_i;
        endcase
    end

    // -----------------------------------------
    // 3. Synchronous Updates (With Strict Masking)
    // -----------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus  <= 64'b0;
            // MPP (bits 12:11) must be 2'b11 for Machine mode
            mstatus[12:11] <= 2'b11; 
            
            mtvec    <= 64'b0;
            mscratch <= 64'b0;
            mepc     <= 64'b0;
            mcause   <= 64'b0;
            mtval    <= 64'b0;
            mcycle   <= 64'b0;
            minstret <= 64'b0;
        end else begin
            // Hardware Counters
            mcycle <= mcycle + 64'd1;
            if (instret_i) minstret <= minstret + 64'd1;

            // ----------------------------------
            // Priority 1: Hardware Traps
            // ----------------------------------
            if (trap_en_i) begin
                mepc     <= {trap_pc_i[63:2], 2'b00}; 
                mcause   <= trap_cause_i;
                mtval    <= trap_val_i;
                
                // MSTATUS updates on trap
                mstatus[7] <= mstatus[3]; // MPIE = MIE
                mstatus[3] <= 1'b0;       // MIE = 0
                mstatus[12:11] <= 2'b11;  // MPP = 11 (Machine Mode)
            end 
            // ----------------------------------
            // Priority 2: Return from Trap (MRET)
            // ----------------------------------
            else if (mret_i) begin
                mstatus[3] <= mstatus[7]; // MIE = MPIE
                mstatus[7] <= 1'b1;       // MPIE = 1
                mstatus[12:11] <= 2'b11;  // MPP = 11
            end
            // ----------------------------------
            // Priority 3: Software Writes
            // ----------------------------------
            else if (we_i && csr_valid_o) begin
                case (addr_i)
                    CSR_MSTATUS: begin
                        mstatus[3] <= final_wdata[3];
                        mstatus[7] <= final_wdata[7];
                    end
                    CSR_MTVEC: begin
                        // Direct mode, force lower 2 bits to 00
                        mtvec <= {final_wdata[63:2], 2'b00};
                    end
                    CSR_MSCRATCH: mscratch <= final_wdata;
                    CSR_MEPC: begin
                        // Alignment masking
                        mepc <= {final_wdata[63:2], 2'b00};
                    end
                    CSR_MCAUSE:   mcause <= final_wdata;
                    CSR_MTVAL:    mtval  <= final_wdata;
                    default: ;
                endcase
            end
        end
    end

    always_ff @(posedge clk) begin
        if (we_i && csr_valid_o && addr_i == CSR_MTVEC)
            $display("[DEBUG] mtvec updated to: 0x%h", final_wdata);
    end

    // Outputs
    assign mtvec_o = mtvec;
    assign mepc_o  = mepc;

endmodule
