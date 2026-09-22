module decode 
    import riscv_pkg::*;
(
    input  logic [31:0] instr_i,

    output logic [4:0]  rs1_addr_o,
    output logic [4:0]  rs2_addr_o,
    output logic [4:0]  rd_addr_o,
    output logic        alu_src_o,
    
    output alu_op_t     alu_op_o,
    output lsu_op_t     lsu_op_o,
    output branch_op_t  branch_op_o,
    output mul_op_t     mul_op_o,
    
    output logic        reg_write_o,
    output logic        mem_write_o,
    output logic        mem_to_reg_o,
    output logic        mem_read_o,

    output logic        is_jump_o,
    output logic        is_jalr_o,
    output logic        is_lui_o,  
    output logic        is_auipc_o, 

    output logic        csr_we_o,
    output csr_op_t     csr_op_o,
    output logic        is_ecall_o,
    output logic        is_ebreak_o,
    output logic        is_mret_o,
    output logic        illegal_instr_o,

    output logic [63:0] imm_o
);

    opcode_t    opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode     = opcode_t'(instr_i[6:0]);
    assign rd_addr_o  = instr_i[11:7];
    assign funct3     = instr_i[14:12];
    assign rs1_addr_o = instr_i[19:15];
    assign rs2_addr_o = instr_i[24:20];
    assign funct7     = instr_i[31:25];

    /* verilator lint_off UNUSED */
    logic [6:0] unused_funct7;
    assign unused_funct7 = funct7;
    /* verilator lint_on UNUSED */

    // ------------------------------------
    // IMMEDIATE GENERATION
    // ------------------------------------
    always_comb begin : imm_gen
        imm_o = 64'b0; // default

        case (opcode)
            // I-Type immediates
            OP_IMM, OP_LOAD, OP_JALR, OP_IMM_32: begin
                imm_o = {{52{instr_i[31]}}, 
                        instr_i[31:20]};
            end

            //System immediates
            OP_SYSTEM: begin
                imm_o = {59'b0, instr_i[19:15]};
            end

            // S-Type immediates
            OP_STORE: begin
                imm_o = {{52{instr_i[31]}}, 
                        instr_i[31:25], 
                        instr_i[11:7]};
            end

            // B-Type immediates
            OP_BRANCH: begin
                imm_o = {{51{instr_i[31]}},
                        instr_i[31], instr_i[7],
                        instr_i[30:25], instr_i[11:8],
                        1'b0};
            end

            // J-Type immediates
            OP_JAL: begin
                imm_o = {{43{instr_i[31]}},
                        instr_i[31],
                        instr_i[19:12],
                        instr_i[20],
                        instr_i[30:21],
                        1'b0};
            end

            // U-Type immediates
            OP_LUI, OP_AUIPC: begin
                imm_o = {{32{instr_i[31]}}, 
                        instr_i[31:12], 12'b0};
            end

            // No immediate field instructions
            OP_REG, OP_REG_32, OP_FENCE: begin
                imm_o = 64'b0;
            end

            default: imm_o = 64'b0;
        endcase
    end


    // ------------------------------------
    // CONTROL LOGIC
    // ------------------------------------
    always_comb begin : control_logic
        // Defaults
        alu_op_o        = ALU_ADD;
        lsu_op_o        = LSU_NONE;
        branch_op_o     = BRANCH_NONE;
        mul_op_o        = M_NONE;
        reg_write_o     = 1'b0;
        alu_src_o       = 1'b0;
        mem_write_o     = 1'b0;
        mem_read_o      = 1'b0; 
        mem_to_reg_o    = 1'b0;
        is_jump_o       = 1'b0;
        is_jalr_o       = 1'b0;
        is_lui_o        = 1'b0;
        is_auipc_o      = 1'b0;
        csr_we_o        = 1'b0;
        csr_op_o        = CSR_NONE;
        is_ecall_o      = 1'b0;
        is_ebreak_o     = 1'b0;
        is_mret_o       = 1'b0;
        illegal_instr_o = 1'b0;

        case (opcode)
            OP_IMM: begin
                reg_write_o = 1'b1;
                alu_src_o   = 1'b1;
                case (funct3)
                    3'b000: alu_op_o = ALU_ADD;     //ADDI
                    3'b010: alu_op_o = ALU_SLT;     //SLTI
                    3'b011: alu_op_o = ALU_SLTU;    //SLTIU
                    3'b100: alu_op_o = ALU_XOR;     //XORI
                    3'b110: alu_op_o = ALU_OR;      //ORI
                    3'b111: alu_op_o = ALU_AND;     //ANDI
                    3'b001: alu_op_o = ALU_SLL;     //SLLI
                    3'b101: alu_op_o = (funct7[5]) ? ALU_SRA : ALU_SRL; //SRAI & SRLI

                    default: alu_op_o = ALU_ADD;
                endcase
            end
            OP_IMM_32: begin
                reg_write_o = 1'b1;
                alu_src_o   = 1'b1;
                case(funct3)
                    3'b000: alu_op_o = ALU_ADDW; // ADDIW
                    3'b001: alu_op_o = ALU_SLLW; // SLLIW
                    3'b101: alu_op_o = (funct7[5]) ? ALU_SRAW : ALU_SRLW; // SRAIW / SRLIW

                    default: alu_op_o = ALU_ADDW;
                endcase
            end
            OP_REG: begin
                reg_write_o = 1'b1;
                alu_src_o   = 1'b0;
                // Multiplier (Funct7 == 0x01)
                if (funct7 == 7'b0000001) begin
                    case (funct3)
                        3'b000: mul_op_o = M_MUL;
                        3'b001: mul_op_o = M_MULH;
                        3'b010: mul_op_o = M_MULHSU;
                        3'b011: mul_op_o = M_MULHU;
                        3'b100: mul_op_o = M_DIV;
                        3'b101: mul_op_o = M_DIVU;
                        3'b110: mul_op_o = M_REM;
                        3'b111: mul_op_o = M_REMU;

                        default: mul_op_o = M_NONE;
                    endcase
                end else begin
                    // Standard ALU Ops
                    case (funct3)
                        3'b000: alu_op_o = (funct7[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: alu_op_o = ALU_SLL;
                        3'b010: alu_op_o = ALU_SLT;
                        3'b011: alu_op_o = ALU_SLTU;
                        3'b100: alu_op_o = ALU_XOR;
                        3'b101: alu_op_o = (funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: alu_op_o = ALU_OR;
                        3'b111: alu_op_o = ALU_AND;

                        default: alu_op_o = ALU_ADD;
                    endcase
                end
            end
            OP_REG_32: begin
                reg_write_o = 1'b1;
                alu_src_o   = 1'b0;
                // Multiplier (Funct7 == 0x01)
                if (funct7 == 7'b0000001) begin
                    case (funct3)
                        3'b000: mul_op_o = M_MULW;
                        3'b100: mul_op_o = M_DIVW;
                        3'b101: mul_op_o = M_DIVUW;
                        3'b110: mul_op_o = M_REMW;
                        3'b111: mul_op_o = M_REMUW;

                        default: mul_op_o = M_NONE;
                    endcase
                end else begin
                    // Standard ALU Ops
                    case (funct3)
                        3'b000: alu_op_o = (funct7[5]) ? ALU_SUBW : ALU_ADDW;
                        3'b001: alu_op_o = ALU_SLLW;
                        3'b101: alu_op_o = (funct7[5]) ? ALU_SRAW : ALU_SRLW;
                        
                        default: alu_op_o = ALU_ADDW;
                    endcase
                end
            end
            OP_LOAD: begin
                reg_write_o  = 1'b1;
                alu_src_o    = 1'b1;
                mem_to_reg_o = 1'b1;
                mem_read_o   = 1'b1;
                alu_op_o     = ALU_ADD;
                case (funct3)
                    3'b000: lsu_op_o = LSU_LB;
                    3'b001: lsu_op_o = LSU_LH;
                    3'b010: lsu_op_o = LSU_LW;
                    3'b011: lsu_op_o = LSU_LD;
                    3'b100: lsu_op_o = LSU_LBU;
                    3'b101: lsu_op_o = LSU_LHU;
                    3'b110: lsu_op_o = LSU_LWU;

                    default: lsu_op_o = LSU_LD;
                endcase
            end
            OP_STORE: begin
                alu_src_o   = 1'b1;
                mem_write_o = 1'b1;
                alu_op_o    = ALU_ADD;
                case (funct3)
                    3'b000: lsu_op_o = LSU_SB;
                    3'b001: lsu_op_o = LSU_SH;
                    3'b010: lsu_op_o = LSU_SW;
                    3'b011: lsu_op_o = LSU_SD;
                    
                    default: lsu_op_o = LSU_SD;
                endcase
            end
            OP_BRANCH: begin
                branch_op_o = branch_op_t'(funct3);
            end
            OP_JAL: begin
                reg_write_o = 1'b1;
                is_jump_o   = 1'b1;
            end
            OP_JALR: begin
                reg_write_o = 1'b1;
                is_jump_o   = 1'b1;
                is_jalr_o   = 1'b1;
                alu_src_o   = 1'b1;
                alu_op_o    = ALU_ADD;
            end
            OP_LUI: begin
                reg_write_o = 1'b1;
                alu_src_o   = 1'b1; // Use Imm
                is_lui_o    = 1'b1; // Op A = 0
                alu_op_o    = ALU_ADD; // 0 + Imm = Imm
            end
            OP_AUIPC: begin
                reg_write_o = 1'b1;
                alu_src_o   = 1'b1; // Use Imm
                is_auipc_o  = 1'b1; // Op A = PC
                alu_op_o    = ALU_ADD; // PC + Imm
            end

            OP_SYSTEM: begin
                if (funct3 == 3'b000) begin
                    // ------------------------------------
                    // Exceptions / Environment Calls
                    // ------------------------------------
                    case (instr_i[31:20]) // funct12
                        12'h000: is_ecall_o  = 1'b1;
                        12'h001: is_ebreak_o = 1'b1;
                        12'h302: is_mret_o   = 1'b1;
                        default: illegal_instr_o = 1'b1; // Unknown system action
                    endcase
                end else begin
                    // ------------------------------------
                    // CSR Read/Write Instructions
                    // ------------------------------------
                    // funct3 determines the CSR operation
                    case (funct3)
                        3'b001, 3'b010, 3'b011, // CSRRW, CSRRS, CSRRC
                        3'b101, 3'b110, 3'b111: // CSRRWI, CSRRSI, CSRRCI
                        begin
                            csr_we_o    = 1'b1;
                            reg_write_o = 1'b1; // CSR instructions write old value to 'rd'
                            csr_op_o    = csr_op_t'(funct3);
                        end
                        default: illegal_instr_o = 1'b1; // Invalid CSR operation
                    endcase
                end
            end

            OP_FENCE: begin
                //Treat as NOP
            end
            
            default: begin
                reg_write_o = 1'b0;
                illegal_instr_o = 1'b1;
            end
        endcase
    end
endmodule
