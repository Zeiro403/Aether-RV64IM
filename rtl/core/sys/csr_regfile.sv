module csr_regfile
import riscv_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // ------------------------------------------------------------
    // Pipeline CSR interface
    // ------------------------------------------------------------

    input  logic [11:0] addr_i,
    input  logic [63:0] wdata_i,
    input  csr_op_t     op_i,
    input  logic        we_i,

    output logic [63:0] rdata_o,
    output logic        csr_valid_o,
    output logic csr_write_valid_o,

    // ------------------------------------------------------------
    // Trap interface
    // ------------------------------------------------------------

    input  logic        trap_en_i,
    input  logic [63:0] trap_pc_i,
    input  logic [63:0] trap_cause_i,
    input  logic [63:0] trap_val_i,

    input  logic        mret_i,
    input  logic        instret_i,

    output logic [63:0] mtvec_o,
    output logic [63:0] mepc_o
);

    // ============================================================
    // Architectural CSR state
    // ============================================================

    logic [63:0] mstatus;
    logic [63:0] mtvec;
    logic [63:0] mscratch;
    logic [63:0] mepc;
    logic [63:0] mcause;
    logic [63:0] mtval;

    logic [63:0] mcycle;
    logic [63:0] minstret;


    // ============================================================
    // Implemented CSR properties
    // ============================================================

    logic csr_readable;
    logic csr_writable;

    assign csr_write_valid_o = csr_writable;


    always_comb begin

        csr_readable = 1'b0;
        csr_writable = 1'b0;

        case (addr_i)

            // ----------------------------------------------------
            // Read/write machine CSRs
            // ----------------------------------------------------

            CSR_MSTATUS,
            CSR_MTVEC,
            CSR_MSCRATCH,
            CSR_MEPC,
            CSR_MCAUSE,
            CSR_MTVAL: begin
                csr_readable = 1'b1;
                csr_writable = 1'b1;
            end


            // ----------------------------------------------------
            // Implemented read-only CSRs
            // ----------------------------------------------------

            CSR_MISA,
            CSR_MCYCLE,
            CSR_MINSTRET: begin
                csr_readable = 1'b1;
                csr_writable = 1'b0;
            end


            // ----------------------------------------------------
            // Not implemented by Aether
            // ----------------------------------------------------

            default: begin
                csr_readable = 1'b0;
                csr_writable = 1'b0;
            end

        endcase
    end


    // A CSR address is valid if the CSR exists.
    assign csr_valid_o = csr_readable;


    // ============================================================
    // CSR read
    // ============================================================

    always_comb begin

        rdata_o = 64'b0;

        case (addr_i)

            CSR_MSTATUS:
                rdata_o = mstatus;

            CSR_MTVEC:
                rdata_o = mtvec;

            CSR_MSCRATCH:
                rdata_o = mscratch;

            CSR_MEPC:
                rdata_o = mepc;

            CSR_MCAUSE:
                rdata_o = mcause;

            CSR_MTVAL:
                rdata_o = mtval;

            CSR_MCYCLE:
                rdata_o = mcycle;

            CSR_MINSTRET:
                rdata_o = minstret;


            // RV64IM:
            //
            // MXL[63:62] = 2 for RV64
            //
            // Extension bits:
            // I = bit 8
            // M = bit 12
            //
            // This CSR is implemented as a fixed read-only value.
            CSR_MISA:
                rdata_o =
                    (64'h2 << 62) |
                    (64'h1 << 12) |
                    (64'h1 << 8);

            default:
                rdata_o = 64'b0;

        endcase
    end


    // ============================================================
    // CSR atomic operation
    // ============================================================

    logic [63:0] final_wdata;

    always_comb begin

        case (op_i)

            CSR_RW,
            CSR_RWI:
                final_wdata = wdata_i;

            CSR_RS,
            CSR_RSI:
                final_wdata = rdata_o | wdata_i;

            CSR_RC,
            CSR_RCI:
                final_wdata = rdata_o & ~wdata_i;

            default:
                final_wdata = wdata_i;

        endcase
    end


    // ============================================================
    // Architectural updates
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            mstatus  <= 64'b0;
            mtvec    <= 64'b0;
            mscratch <= 64'b0;
            mepc     <= 64'b0;
            mcause   <= 64'b0;
            mtval    <= 64'b0;

            mcycle   <= 64'b0;
            minstret <= 64'b0;


            // Machine Previous Privilege = M.
            //
            // Aether currently implements only machine mode.
            mstatus[12:11] <= 2'b11;


        end else begin

            // ----------------------------------------------------
            // Hardware counters
            // ----------------------------------------------------

            mcycle <= mcycle + 64'd1;

            if (instret_i)
                minstret <= minstret + 64'd1;


            // ====================================================
            // Priority 1: Trap entry
            // ====================================================

            if (trap_en_i) begin

                // IALIGN = 32 in the current core.
                mepc <= {
                    trap_pc_i[63:2],
                    2'b00
                };

                mcause <= trap_cause_i;
                mtval  <= trap_val_i;


                // ------------------------------------------------
                // mstatus trap transition
                //
                // MPIE <- MIE
                // MIE  <- 0
                // MPP  <- M
                // ------------------------------------------------

                mstatus[7] <= mstatus[3];
                mstatus[3] <= 1'b0;

                mstatus[12:11] <= 2'b11;


            // ====================================================
            // Priority 2: MRET
            // ====================================================

            end else if (mret_i) begin

                // ------------------------------------------------
                // Machine return
                //
                // MIE  <- MPIE
                // MPIE <- 1
                //
                // Aether remains machine-only, so MPP is retained
                // as M rather than implementing privilege descent.
                // ------------------------------------------------

                mstatus[3] <= mstatus[7];
                mstatus[7] <= 1'b1;

                mstatus[12:11] <= 2'b11;


            // ====================================================
            // Priority 3: CSR software write
            // ====================================================

            end else if (
                we_i &&
                csr_readable &&
                csr_writable
            ) begin

                case (addr_i)

                    // --------------------------------------------
                    // mstatus
                    //
                    // Current implementation exposes only the bits
                    // which have meaning in this machine-only core.
                    // --------------------------------------------

                    CSR_MSTATUS: begin

                        mstatus[3] <= final_wdata[3];
                        mstatus[7] <= final_wdata[7];

                        // Machine-only implementation.
                        mstatus[12:11] <= 2'b11;
                    end


                    // --------------------------------------------
                    // mtvec
                    //
                    // Current implementation supports Direct mode.
                    // MODE is therefore forced to 00.
                    // --------------------------------------------

                    CSR_MTVEC: begin
                        mtvec <= {
                            final_wdata[63:2],
                            2'b00
                        };
                    end


                    CSR_MSCRATCH: begin
                        mscratch <= final_wdata;
                    end


                    // IALIGN = 32.
                    CSR_MEPC: begin
                        mepc <= {
                            final_wdata[63:2],
                            2'b00
                        };
                    end


                    CSR_MCAUSE: begin
                        mcause <= final_wdata;
                    end


                    CSR_MTVAL: begin
                        mtval <= final_wdata;
                    end


                    default: begin
                        // Read-only and unsupported CSRs cannot reach
                        // this branch because csr_writable is false.
                    end

                endcase
            end
        end
    end


    // ============================================================
    // Trap-visible outputs
    // ============================================================

    assign mtvec_o = mtvec;
    assign mepc_o  = mepc;

    // trap_pc_i[1:0] are intentionally discarded because the
    // current core has IALIGN=32 and mepc is 4-byte aligned.
    /* verilator lint_off UNUSEDSIGNAL */
    logic unused_trap_pc_low;
    assign unused_trap_pc_low = ^trap_pc_i[1:0];
    /* verilator lint_on UNUSEDSIGNAL */

endmodule
