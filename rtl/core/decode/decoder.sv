module decoder
import riscv_pkg::*;
(
    input logic [31:0] instr_i,

    // Register fields
    output logic [4:0] rs1_addr_o,
    output logic [4:0] rs2_addr_o,
    output logic [4:0] rd_addr_o,

    // Source register usage
    output logic uses_rs1_o,
    output logic uses_rs2_o,

    // Execution routing
    output fu_t fu_o,

    // Operation selection
    output alu_op_t     alu_op_o,
    output lsu_op_t     lsu_op_o,
    output branch_op_t  branch_op_o,
    output mul_op_t     mul_op_o,
    output csr_op_t     csr_op_o,
    output ctrl_flow_t  ctrl_flow_o,

    // Operand selection
    output op_a_sel_t op_a_sel_o,
    output op_b_sel_t op_b_sel_o,

    // Architectural effects
    output logic reg_write_o,
    output logic csr_write_o,

    // System instructions
    output logic is_ecall_o,
    output logic is_ebreak_o,
    output logic is_mret_o,

    // Decode exception
    output logic illegal_instr_o
);

    opcode_t    opcode;

    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [11:0] funct12;

    // RV64 shift-immediate upper encoding fields.
    logic [5:0] shamt6;
    logic [5:0] shift_funct6;

    // RV64 *W shift-immediate encoding.
    logic [4:0] shamt5;


    // ============================================================
    // Instruction Fields
    // ============================================================

    assign opcode     = opcode_t'(instr_i[6:0]);

    assign rd_addr_o  = instr_i[11:7];
    assign funct3     = instr_i[14:12];
    assign rs1_addr_o = instr_i[19:15];
    assign rs2_addr_o = instr_i[24:20];

    assign funct7     = instr_i[31:25];
    assign funct12    = instr_i[31:20];

    assign shamt6       = instr_i[25:20];
    assign shift_funct6 = instr_i[31:26];

    assign shamt5 = instr_i[24:20];


    // ============================================================
    // Decode
    // ============================================================

    always_comb begin

        // --------------------------------------------------------
        // Safe defaults
        // --------------------------------------------------------

        fu_o        = FU_NONE;

        alu_op_o    = ALU_ADD;
        lsu_op_o    = LSU_NONE;
        branch_op_o = BRANCH_NONE;
        mul_op_o    = M_NONE;
        csr_op_o    = CSR_NONE;
        ctrl_flow_o = CTRL_NONE;

        op_a_sel_o  = OP_A_RS1;
        op_b_sel_o  = OP_B_RS2;

        uses_rs1_o  = 1'b0;
        uses_rs2_o  = 1'b0;

        reg_write_o = 1'b0;
        csr_write_o = 1'b0;

        is_ecall_o  = 1'b0;
        is_ebreak_o = 1'b0;
        is_mret_o   = 1'b0;

        illegal_instr_o = 1'b0;


        case (opcode)

            // ====================================================
            // OP-IMM
            // ====================================================

            OP_IMM: begin

                fu_o        = FU_ALU;

                uses_rs1_o  = 1'b1;
                uses_rs2_o  = 1'b0;

                reg_write_o = 1'b1;

                op_a_sel_o  = OP_A_RS1;
                op_b_sel_o  = OP_B_IMM;

                case (funct3)

                    // ADDI
                    3'b000: begin
                        alu_op_o = ALU_ADD;
                    end

                    // SLTI
                    3'b010: begin
                        alu_op_o = ALU_SLT;
                    end

                    // SLTIU
                    3'b011: begin
                        alu_op_o = ALU_SLTU;
                    end

                    // XORI
                    3'b100: begin
                        alu_op_o = ALU_XOR;
                    end

                    // ORI
                    3'b110: begin
                        alu_op_o = ALU_OR;
                    end

                    // ANDI
                    3'b111: begin
                        alu_op_o = ALU_AND;
                    end


                    // ------------------------------------------------
                    // SLLI
                    //
                    // RV64:
                    //
                    // funct6 = 000000
                    // shamt  = 6 bits
                    // ------------------------------------------------

                    3'b001: begin

                        if (shift_funct6 == 6'b000000) begin
                            alu_op_o = ALU_SLL;

                        end else begin
                            illegal_instr_o = 1'b1;
                        end
                    end


                    // ------------------------------------------------
                    // SRLI / SRAI
                    //
                    // SRLI funct6 = 000000
                    // SRAI funct6 = 010000
                    // ------------------------------------------------

                    3'b101: begin

                        case (shift_funct6)

                            6'b000000: begin
                                alu_op_o = ALU_SRL;
                            end

                            6'b010000: begin
                                alu_op_o = ALU_SRA;
                            end

                            default: begin
                                illegal_instr_o = 1'b1;
                            end

                        endcase
                    end


                    default: begin
                        illegal_instr_o = 1'b1;
                    end

                endcase
            end


            // ====================================================
            // OP
            // ====================================================

            OP_REG: begin

                uses_rs1_o  = 1'b1;
                uses_rs2_o  = 1'b1;

                reg_write_o = 1'b1;

                op_a_sel_o  = OP_A_RS1;
                op_b_sel_o  = OP_B_RS2;


                // ------------------------------------------------
                // RV64M
                // ------------------------------------------------

                if (funct7 == 7'b0000001) begin

                    fu_o = FU_MULDIV;

                    case (funct3)

                        3'b000: mul_op_o = M_MUL;
                        3'b001: mul_op_o = M_MULH;
                        3'b010: mul_op_o = M_MULHSU;
                        3'b011: mul_op_o = M_MULHU;

                        3'b100: mul_op_o = M_DIV;
                        3'b101: mul_op_o = M_DIVU;
                        3'b110: mul_op_o = M_REM;
                        3'b111: mul_op_o = M_REMU;

                        default: begin
                            illegal_instr_o = 1'b1;
                        end

                    endcase


                // ------------------------------------------------
                // RV64I
                // ------------------------------------------------

                end else begin

                    fu_o = FU_ALU;

                    case (funct3)

                        // ADD / SUB
                        3'b000: begin

                            case (funct7)

                                7'b0000000:
                                    alu_op_o = ALU_ADD;

                                7'b0100000:
                                    alu_op_o = ALU_SUB;

                                default:
                                    illegal_instr_o = 1'b1;

                            endcase
                        end


                        // SLL
                        3'b001: begin

                            if (funct7 == 7'b0000000)
                                alu_op_o = ALU_SLL;
                            else
                                illegal_instr_o = 1'b1;
                        end


                        // SLT
                        3'b010: begin

                            if (funct7 == 7'b0000000)
                                alu_op_o = ALU_SLT;
                            else
                                illegal_instr_o = 1'b1;
                        end


                        // SLTU
                        3'b011: begin

                            if (funct7 == 7'b0000000)
                                alu_op_o = ALU_SLTU;
                            else
                                illegal_instr_o = 1'b1;
                        end


                        // XOR
                        3'b100: begin

                            if (funct7 == 7'b0000000)
                                alu_op_o = ALU_XOR;
                            else
                                illegal_instr_o = 1'b1;
                        end


                        // SRL / SRA
                        3'b101: begin

                            case (funct7)

                                7'b0000000:
                                    alu_op_o = ALU_SRL;

                                7'b0100000:
                                    alu_op_o = ALU_SRA;

                                default:
                                    illegal_instr_o = 1'b1;

                            endcase
                        end


                        // OR
                        3'b110: begin

                            if (funct7 == 7'b0000000)
                                alu_op_o = ALU_OR;
                            else
                                illegal_instr_o = 1'b1;
                        end


                        // AND
                        3'b111: begin

                            if (funct7 == 7'b0000000)
                                alu_op_o = ALU_AND;
                            else
                                illegal_instr_o = 1'b1;
                        end


                        default: begin
                            illegal_instr_o = 1'b1;
                        end

                    endcase
                end
            end


            // ====================================================
            // OP-IMM-32
            // ====================================================

            OP_IMM_32: begin

                fu_o        = FU_ALU;

                uses_rs1_o  = 1'b1;
                uses_rs2_o  = 1'b0;

                reg_write_o = 1'b1;

                op_a_sel_o  = OP_A_RS1;
                op_b_sel_o  = OP_B_IMM;

                case (funct3)

                    // ADDIW
                    3'b000: begin
                        alu_op_o = ALU_ADDW;
                    end


                    // ------------------------------------------------
                    // SLLIW
                    //
                    // funct7 must be exactly 0000000.
                    // shamt is 5 bits in RV64 *W operations.
                    // ------------------------------------------------

                    3'b001: begin

                        if (funct7 == 7'b0000000)
                            alu_op_o = ALU_SLLW;
                        else
                            illegal_instr_o = 1'b1;
                    end


                    // SRLIW / SRAIW
                    3'b101: begin

                        case (funct7)

                            7'b0000000:
                                alu_op_o = ALU_SRLW;

                            7'b0100000:
                                alu_op_o = ALU_SRAW;

                            default:
                                illegal_instr_o = 1'b1;

                        endcase
                    end


                    default: begin
                        illegal_instr_o = 1'b1;
                    end

                endcase
            end


            // ====================================================
            // OP-32
            // ====================================================

            OP_REG_32: begin

                uses_rs1_o  = 1'b1;
                uses_rs2_o  = 1'b1;

                reg_write_o = 1'b1;

                op_a_sel_o  = OP_A_RS1;
                op_b_sel_o  = OP_B_RS2;


                // ------------------------------------------------
                // RV64M *W
                // ------------------------------------------------

                if (funct7 == 7'b0000001) begin

                    fu_o = FU_MULDIV;

                    case (funct3)

                        3'b000:
                            mul_op_o = M_MULW;

                        3'b100:
                            mul_op_o = M_DIVW;

                        3'b101:
                            mul_op_o = M_DIVUW;

                        3'b110:
                            mul_op_o = M_REMW;

                        3'b111:
                            mul_op_o = M_REMUW;

                        // funct3 001/010/011 are not RV64M OP-32
                        // instructions.
                        default: begin
                            illegal_instr_o = 1'b1;
                        end

                    endcase


                // ------------------------------------------------
                // RV64I *W
                // ------------------------------------------------

                end else begin

                    fu_o = FU_ALU;

                    case (funct3)

                        // ADDW / SUBW
                        3'b000: begin

                            case (funct7)

                                7'b0000000:
                                    alu_op_o = ALU_ADDW;

                                7'b0100000:
                                    alu_op_o = ALU_SUBW;

                                default:
                                    illegal_instr_o = 1'b1;

                            endcase
                        end


                        // SLLW
                        3'b001: begin

                            if (funct7 == 7'b0000000)
                                alu_op_o = ALU_SLLW;
                            else
                                illegal_instr_o = 1'b1;
                        end


                        // SRLW / SRAW
                        3'b101: begin

                            case (funct7)

                                7'b0000000:
                                    alu_op_o = ALU_SRLW;

                                7'b0100000:
                                    alu_op_o = ALU_SRAW;

                                default:
                                    illegal_instr_o = 1'b1;

                            endcase
                        end


                        default: begin
                            illegal_instr_o = 1'b1;
                        end

                    endcase
                end
            end


            // ====================================================
            // LOAD
            // ====================================================

            OP_LOAD: begin

                fu_o        = FU_LSU;

                uses_rs1_o  = 1'b1;
                uses_rs2_o  = 1'b0;

                reg_write_o = 1'b1;

                op_a_sel_o  = OP_A_RS1;
                op_b_sel_o  = OP_B_IMM;

                case (funct3)

                    3'b000: lsu_op_o = LSU_LB;
                    3'b001: lsu_op_o = LSU_LH;
                    3'b010: lsu_op_o = LSU_LW;
                    3'b011: lsu_op_o = LSU_LD;

                    3'b100: lsu_op_o = LSU_LBU;
                    3'b101: lsu_op_o = LSU_LHU;
                    3'b110: lsu_op_o = LSU_LWU;

                    default: begin
                        illegal_instr_o = 1'b1;
                    end

                endcase
            end


            // ====================================================
            // STORE
            // ====================================================

            OP_STORE: begin

                fu_o        = FU_LSU;

                uses_rs1_o  = 1'b1;
                uses_rs2_o  = 1'b1;

                reg_write_o = 1'b0;

                op_a_sel_o  = OP_A_RS1;
                op_b_sel_o  = OP_B_IMM;

                case (funct3)

                    3'b000: lsu_op_o = LSU_SB;
                    3'b001: lsu_op_o = LSU_SH;
                    3'b010: lsu_op_o = LSU_SW;
                    3'b011: lsu_op_o = LSU_SD;

                    default: begin
                        illegal_instr_o = 1'b1;
                    end

                endcase
            end


            // ====================================================
            // CONDITIONAL BRANCH
            // ====================================================

            OP_BRANCH: begin

                fu_o          = FU_BRANCH;
                ctrl_flow_o   = CTRL_BRANCH;

                uses_rs1_o    = 1'b1;
                uses_rs2_o    = 1'b1;

                reg_write_o   = 1'b0;

                op_a_sel_o    = OP_A_RS1;
                op_b_sel_o    = OP_B_RS2;

                case (funct3)

                    3'b000: branch_op_o = BRANCH_BEQ;
                    3'b001: branch_op_o = BRANCH_BNE;

                    3'b100: branch_op_o = BRANCH_BLT;
                    3'b101: branch_op_o = BRANCH_BGE;

                    3'b110: branch_op_o = BRANCH_BLTU;
                    3'b111: branch_op_o = BRANCH_BGEU;

                    // 010 and 011 are reserved.
                    default: begin
                        illegal_instr_o = 1'b1;
                    end

                endcase
            end


            // ====================================================
            // JAL
            // ====================================================

            OP_JAL: begin

                fu_o          = FU_BRANCH;
                ctrl_flow_o   = CTRL_JAL;

                uses_rs1_o    = 1'b0;
                uses_rs2_o    = 1'b0;

                reg_write_o   = 1'b1;

                // Link value = PC + 4
                op_a_sel_o    = OP_A_PC;
                op_b_sel_o    = OP_B_FOUR;
            end


            // ====================================================
            // JALR
            // ====================================================

            OP_JALR: begin

                fu_o          = FU_BRANCH;
                ctrl_flow_o   = CTRL_JALR;

                uses_rs1_o    = 1'b1;
                uses_rs2_o    = 1'b0;

                reg_write_o   = 1'b1;

                // Link value = PC + 4
                op_a_sel_o    = OP_A_PC;
                op_b_sel_o    = OP_B_FOUR;

                // JALR requires funct3 == 000.
                if (funct3 != 3'b000) begin
                    illegal_instr_o = 1'b1;
                end
            end


            // ====================================================
            // LUI
            // ====================================================

            OP_LUI: begin

                fu_o        = FU_ALU;

                uses_rs1_o  = 1'b0;
                uses_rs2_o  = 1'b0;

                reg_write_o = 1'b1;

                op_a_sel_o  = OP_A_ZERO;
                op_b_sel_o  = OP_B_IMM;

                alu_op_o    = ALU_ADD;
            end


            // ====================================================
            // AUIPC
            // ====================================================

            OP_AUIPC: begin

                fu_o        = FU_ALU;

                uses_rs1_o  = 1'b0;
                uses_rs2_o  = 1'b0;

                reg_write_o = 1'b1;

                op_a_sel_o  = OP_A_PC;
                op_b_sel_o  = OP_B_IMM;

                alu_op_o    = ALU_ADD;
            end


            // ====================================================
            // SYSTEM
            // ====================================================

            OP_SYSTEM: begin

                fu_o = FU_CSR;

                // ------------------------------------------------
                // Privileged/system instructions
                // ------------------------------------------------

                if (funct3 == 3'b000) begin

                    case (funct12)

                        // ECALL
                        12'h000: begin
                            is_ecall_o = 1'b1;
                        end

                        // EBREAK
                        12'h001: begin
                            is_ebreak_o = 1'b1;
                        end

                        // MRET
                        12'h302: begin
                            is_mret_o = 1'b1;
                        end

                        default: begin
                            illegal_instr_o = 1'b1;
                        end

                    endcase


                // ------------------------------------------------
                // CSR instructions
                // ------------------------------------------------

                end else begin

                    case (funct3)

                        // CSRRW
                        3'b001: begin

                            csr_write_o = 1'b1;
                            reg_write_o = 1'b1;

                            uses_rs1_o  = 1'b1;

                            csr_op_o = CSR_RW;
                        end


                        // CSRRS
                        3'b010: begin

                            csr_write_o = 1'b1;
                            reg_write_o = 1'b1;

                            uses_rs1_o  = 1'b1;

                            csr_op_o = CSR_RS;
                        end


                        // CSRRC
                        3'b011: begin

                            csr_write_o = 1'b1;
                            reg_write_o = 1'b1;

                            uses_rs1_o  = 1'b1;

                            csr_op_o = CSR_RC;
                        end


                        // CSRRWI
                        3'b101: begin

                            csr_write_o = 1'b1;
                            reg_write_o = 1'b1;

                            uses_rs1_o  = 1'b0;

                            csr_op_o = CSR_RWI;
                        end


                        // CSRRSI
                        3'b110: begin

                            csr_write_o = 1'b1;
                            reg_write_o = 1'b1;

                            uses_rs1_o  = 1'b0;

                            csr_op_o = CSR_RSI;
                        end


                        // CSRRCI
                        3'b111: begin

                            csr_write_o = 1'b1;
                            reg_write_o = 1'b1;

                            uses_rs1_o  = 1'b0;

                            csr_op_o = CSR_RCI;
                        end


                        default: begin
                            illegal_instr_o = 1'b1;
                        end

                    endcase
                end
            end


            // ====================================================
            // MISC-MEM
            //
            // Current Aether core has:
            //   - no cache
            //   - no speculative memory subsystem
            //   - no separate instruction/data coherence mechanism
            //
            // Therefore FENCE and FENCE.I have no hardware work to do
            // and are implemented architecturally as NOPs.
            //
            // Other funct3 encodings under this opcode are illegal.
            // ====================================================

            OP_FENCE: begin

                fu_o = FU_NONE;

                case (funct3)

                    // FENCE
                    3'b000: begin
                        // NOP in current uncached implementation.
                    end

                    // FENCE.I
                    3'b001: begin
                        // NOP in current uncached implementation.
                    end

                    default: begin
                        illegal_instr_o = 1'b1;
                    end

                endcase
            end


            // ====================================================
            // Unsupported Major Opcode
            // ====================================================

            default: begin
                illegal_instr_o = 1'b1;
            end

        endcase


        // ========================================================
        // Side-effect suppression for illegal instructions
        // ========================================================
        //
        // The trap path already prevents illegal instructions from
        // completing architecturally. Clearing these controls here as
        // well makes Decode itself safe and deterministic.
        // ========================================================

        if (illegal_instr_o) begin

            fu_o        = FU_NONE;

            reg_write_o = 1'b0;
            csr_write_o = 1'b0;

            uses_rs1_o  = 1'b0;
            uses_rs2_o  = 1'b0;

            lsu_op_o    = LSU_NONE;
            mul_op_o    = M_NONE;
            csr_op_o    = CSR_NONE;

            branch_op_o = BRANCH_NONE;
            ctrl_flow_o = CTRL_NONE;

            is_ecall_o  = 1'b0;
            is_ebreak_o = 1'b0;
            is_mret_o   = 1'b0;
        end

    end


    // shamt fields are deliberately decoded above. Keep the named
    // shamt signals available for readability of the instruction format.
    /* verilator lint_off UNUSEDSIGNAL */
    logic unused_shamt;
    assign unused_shamt = ^{shamt6, shamt5};
    /* verilator lint_on UNUSEDSIGNAL */

endmodule
