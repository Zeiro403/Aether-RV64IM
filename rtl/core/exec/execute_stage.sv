module execute_stage
import riscv_pkg::*;
(
    input  logic clk,
    input  logic rst_n,

    // ============================================================
    // ID/EX Instruction
    // ============================================================

    input  logic        valid_i,
    input  logic [63:0] pc_i,
    input  logic [31:0] instr_i,

    input  logic [4:0]  rs1_addr_i,
    input  logic [4:0]  rd_addr_i,

    input  logic [63:0] rs1_data_i,
    input  logic [63:0] rs2_data_i,
    input  logic [63:0] imm_i,

    input  fu_t          fu_i,

    input  alu_op_t      alu_op_i,
    input  lsu_op_t      lsu_op_i,
    input  branch_op_t   branch_op_i,
    input  mul_op_t      mul_op_i,
    input  csr_op_t      csr_op_i,
    input  ctrl_flow_t   ctrl_flow_i,

    input  op_a_sel_t    op_a_sel_i,
    input  op_b_sel_t    op_b_sel_i,

    input  logic         reg_write_i,
    input  logic         csr_write_i,

    input  logic [11:0]  csr_addr_i,

    input  logic         is_ecall_i,
    input  logic         is_ebreak_i,
    input  logic         is_mret_i,
    input  logic         illegal_instr_i,

    // ============================================================
    // Forwarding
    // ============================================================

    input  forward_sel_t forward_a_sel_i,
    input  forward_sel_t forward_b_sel_i,

    input  logic [63:0] mem_forward_data_i,
    input  logic [63:0] wb_forward_data_i,

    // ============================================================
    // CSR Architectural State
    // ============================================================

    input  logic [63:0] csr_rdata_i,

    // CSR exists and may be read.
    input  logic        csr_valid_i,

    // CSR accepts software writes.
    input  logic        csr_write_valid_i,

    input  logic [63:0] mtvec_i,
    input  logic [63:0] mepc_i,

    // ============================================================
    // EX Stage Readiness
    // ============================================================

    output logic        ready_o,

    // ============================================================
    // EX/MEM Payload
    // ============================================================

    output logic        valid_o,

    output logic [63:0] result_o,
    output logic [63:0] store_data_o,

    output logic [4:0]  rd_addr_o,
    output logic        reg_write_o,

    output fu_t          fu_o,
    output lsu_op_t      lsu_op_o,

    // ============================================================
    // CSR Commit Payload
    // ============================================================

    output logic [11:0] csr_addr_o,
    output logic [63:0] csr_wdata_o,
    output csr_op_t     csr_op_o,
    output logic        csr_write_o,

    // ============================================================
    // Trap / MRET Commit Payload
    // ============================================================

    output logic        trap_en_o,
    output logic        mret_en_o,

    output logic [63:0] trap_pc_o,
    output logic [63:0] trap_cause_o,
    output logic [63:0] trap_val_o,

    // ============================================================
    // Frontend Redirect
    // ============================================================

    output logic        redirect_valid_o,
    output logic [63:0] redirect_pc_o
);


    // ============================================================
    // 1. FORWARDED REGISTER OPERANDS
    // ============================================================

    logic [63:0] forwarded_rs1;
    logic [63:0] forwarded_rs2;


    always_comb begin
        case (forward_a_sel_i)

            FWD_MEM:
                forwarded_rs1 = mem_forward_data_i;

            FWD_WB:
                forwarded_rs1 = wb_forward_data_i;

            default:
                forwarded_rs1 = rs1_data_i;

        endcase
    end


    always_comb begin
        case (forward_b_sel_i)

            FWD_MEM:
                forwarded_rs2 = mem_forward_data_i;

            FWD_WB:
                forwarded_rs2 = wb_forward_data_i;

            default:
                forwarded_rs2 = rs2_data_i;

        endcase
    end


    // ============================================================
    // 2. ALU OPERAND SELECTION
    // ============================================================

    logic [63:0] alu_operand_a;
    logic [63:0] alu_operand_b;


    always_comb begin
        case (op_a_sel_i)

            OP_A_PC:
                alu_operand_a = pc_i;

            OP_A_ZERO:
                alu_operand_a = 64'b0;

            default:
                alu_operand_a = forwarded_rs1;

        endcase
    end


    always_comb begin
        case (op_b_sel_i)

            OP_B_IMM:
                alu_operand_b = imm_i;

            OP_B_FOUR:
                alu_operand_b = 64'd4;

            default:
                alu_operand_b = forwarded_rs2;

        endcase
    end


    // ============================================================
    // 3. ALU
    // ============================================================

    logic [63:0] alu_result;


    alu u_alu (
        .alu_op_i (alu_op_i),
        .op_a_i   (alu_operand_a),
        .op_b_i   (alu_operand_b),
        .result_o (alu_result)
    );


    // ============================================================
    // 4. BRANCH / JUMP RESOLUTION
    // ============================================================

    logic        branch_taken;

    logic [63:0] branch_target;

    logic        control_redirect_valid;
    logic [63:0] control_redirect_pc;


    branch_comp u_branch_comp (
        .branch_op_i    (branch_op_i),
        .op_a_i         (forwarded_rs1),
        .op_b_i         (forwarded_rs2),
        .branch_taken_o (branch_taken)
    );


    // ------------------------------------------------------------
    // Target calculation
    // ------------------------------------------------------------

    always_comb begin

        // Conditional branch and JAL:
        //
        // target = PC + immediate
        branch_target = pc_i + imm_i;


        // JALR:
        //
        // target = (rs1 + immediate) & ~1
        if (ctrl_flow_i == CTRL_JALR) begin
            branch_target =
                (forwarded_rs1 + imm_i) &
                ~64'd1;
        end
    end


    // ------------------------------------------------------------
    // Control-flow redirect
    // ------------------------------------------------------------

    always_comb begin

        control_redirect_valid = 1'b0;
        control_redirect_pc    = branch_target;


        if (valid_i) begin

            case (ctrl_flow_i)

                CTRL_BRANCH: begin

                    if (branch_taken) begin
                        control_redirect_valid = 1'b1;
                        control_redirect_pc    = branch_target;
                    end
                end


                CTRL_JAL: begin

                    control_redirect_valid = 1'b1;
                    control_redirect_pc    = branch_target;
                end


                CTRL_JALR: begin

                    control_redirect_valid = 1'b1;
                    control_redirect_pc    = branch_target;
                end


                default: begin

                    control_redirect_valid = 1'b0;
                end

            endcase
        end
    end


    // ============================================================
    // 5. MULTIPLY / DIVIDE
    // ============================================================

    logic        muldiv_req_valid;
    logic        muldiv_result_valid;
    logic [63:0] muldiv_result;


    assign muldiv_req_valid =
        valid_i &&
        (fu_i == FU_MULDIV);


    muldiv u_muldiv (
        .clk            (clk),
        .rst_n          (rst_n),

        .start_i        (muldiv_req_valid),

        .op_i           (mul_op_i),
        .op_a_i         (forwarded_rs1),
        .op_b_i         (forwarded_rs2),

        .result_valid_o (muldiv_result_valid),
        .result_o       (muldiv_result)
    );


    // ============================================================
    // 6. CSR OPERAND
    // ============================================================
    //
    // Register CSR instructions:
    //
    //     operand = forwarded rs1
    //
    // Immediate CSR instructions:
    //
    //     operand = zero-extended zimm[4:0]
    //
    // The zimm field occupies the same instruction bits as rs1.
    // ============================================================

    logic [63:0] csr_operand;


    always_comb begin

        if (csr_is_imm(csr_op_i)) begin

            csr_operand = {
                59'b0,
                rs1_addr_i
            };

        end else begin

            csr_operand = forwarded_rs1;

        end
    end


    // ============================================================
    // 7. CSR WRITE INTENT
    // ============================================================
    //
    // CSRRW / CSRRWI
    //     always attempt a CSR write.
    //
    // CSRRS / CSRRC
    //     rs1=x0 means read only.
    //
    // CSRRSI / CSRRCI
    //     zimm=0 means read only.
    //
    // Since rs1_addr_i is also the zimm field for immediate CSR
    // instructions, the zero test is identical for both cases.
    // ============================================================

    logic csr_write_requested;


    always_comb begin

        case (csr_op_i)

            CSR_RW,
            CSR_RWI: begin

                csr_write_requested = 1'b1;
            end


            CSR_RS,
            CSR_RC,
            CSR_RSI,
            CSR_RCI: begin

                csr_write_requested =
                    (rs1_addr_i != 5'd0);
            end


            default: begin

                csr_write_requested = 1'b0;
            end

        endcase
    end


    // CSR payload has exactly one driver.
    assign csr_addr_o  = csr_addr_i;
    assign csr_wdata_o = csr_operand;
    assign csr_op_o    = csr_op_i;


    // ============================================================
    // 8. EFFECTIVE ADDRESS ALIGNMENT
    // ============================================================

    logic is_misaligned;

    logic load_misaligned;
    logic store_misaligned;


    always_comb begin

        is_misaligned = 1'b0;


        case (lsu_op_i)

            // Halfword requires 2-byte alignment.
            LSU_LH,
            LSU_LHU,
            LSU_SH: begin

                is_misaligned =
                    alu_result[0];
            end


            // Word requires 4-byte alignment.
            LSU_LW,
            LSU_LWU,
            LSU_SW: begin

                is_misaligned =
                    |alu_result[1:0];
            end


            // Doubleword requires 8-byte alignment.
            LSU_LD,
            LSU_SD: begin

                is_misaligned =
                    |alu_result[2:0];
            end


            // Byte accesses are always naturally aligned.
            default: begin

                is_misaligned = 1'b0;
            end

        endcase
    end


    assign load_misaligned =
        valid_i &&
        (fu_i == FU_LSU) &&
        lsu_is_load(lsu_op_i) &&
        is_misaligned;


    assign store_misaligned =
        valid_i &&
        (fu_i == FU_LSU) &&
        lsu_is_store(lsu_op_i) &&
        is_misaligned;


    // ============================================================
    // 9. CSR ACCESS LEGALITY
    // ============================================================
    //
    // A CSR access is illegal if:
    //
    //   1. the requested CSR does not exist, or
    //
    //   2. the instruction attempts to modify a read-only CSR.
    //
    // Reading a read-only CSR using CSRRS/CSRRC with rs1=x0 or
    // CSRRSI/CSRRCI with zimm=0 remains legal.
    // ============================================================

    logic illegal_csr_access;
    logic combined_illegal_instr;


    always_comb begin

        illegal_csr_access = 1'b0;


        if (
            valid_i &&
            (fu_i == FU_CSR) &&
            (csr_op_i != CSR_NONE)
        ) begin

            // CSR address is not implemented.
            if (!csr_valid_i) begin

                illegal_csr_access = 1'b1;


            // Existing CSR, but this instruction attempts to write
            // a read-only CSR.
            end else if (
                csr_write_requested &&
                !csr_write_valid_i
            ) begin

                illegal_csr_access = 1'b1;

            end
        end
    end


    assign combined_illegal_instr =
        illegal_instr_i ||
        illegal_csr_access;


    // ============================================================
    // 10. TRAP / MRET RESOLUTION
    // ============================================================

    logic        system_redirect_valid;
    logic [63:0] system_redirect_pc;


    trap_unit u_trap (
        .valid_i              (valid_i),

        .is_ecall_i           (is_ecall_i),
        .is_ebreak_i          (is_ebreak_i),
        .is_mret_i            (is_mret_i),

        .illegal_instr_i      (combined_illegal_instr),

        .load_misaligned_i    (load_misaligned),
        .store_misaligned_i   (store_misaligned),

        .bad_addr_i           (alu_result),

        .curr_pc_i            (pc_i),
        .curr_instr_i         (instr_i),

        .mtvec_i              (mtvec_i),
        .mepc_i               (mepc_i),

        .trap_en_o            (trap_en_o),
        .mret_en_o            (mret_en_o),

        .trap_cause_o         (trap_cause_o),
        .trap_pc_o            (trap_pc_o),
        .trap_val_o           (trap_val_o),

        .redirect_valid_o     (system_redirect_valid),
        .redirect_pc_o        (system_redirect_pc)
    );


    // ============================================================
    // 11. REDIRECT ARBITRATION
    // ============================================================
    //
    // Trap/MRET always overrides ordinary branch/jump resolution.
    // ============================================================

    always_comb begin

        if (system_redirect_valid) begin

            redirect_valid_o = 1'b1;
            redirect_pc_o    = system_redirect_pc;

        end else begin

            redirect_valid_o = control_redirect_valid;
            redirect_pc_o    = control_redirect_pc;

        end
    end


    // ============================================================
    // 12. EX STAGE READINESS
    // ============================================================
    //
    // Ordinary instructions complete in one EX cycle.
    //
    // MULDIV remains resident in EX until its result is valid.
    // ============================================================

    always_comb begin

        ready_o = 1'b1;


        if (
            valid_i &&
            (fu_i == FU_MULDIV)
        ) begin

            ready_o = muldiv_result_valid;
        end
    end


    // ============================================================
    // 13. RESULT SELECTION
    // ============================================================

    always_comb begin

        result_o = alu_result;


        case (fu_i)

            FU_MULDIV: begin

                result_o = muldiv_result;
            end


            FU_CSR: begin

                // CSR instructions return the CSR's pre-write value
                // to rd.
                result_o = csr_rdata_i;
            end


            default: begin

                result_o = alu_result;
            end

        endcase
    end


    // ============================================================
    // 14. NORMAL PIPELINE COMPLETION
    // ============================================================
    //
    // A trapping instruction must not enter EX/MEM.
    //
    // MRET is not an exception. It redirects execution but is still
    // considered an executed instruction and may retire normally.
    // ============================================================

    always_comb begin

        valid_o = 1'b0;


        if (
            valid_i &&
            ready_o &&
            !trap_en_o
        ) begin

            valid_o = 1'b1;
        end
    end


    // ============================================================
    // 15. EX/MEM PAYLOAD
    // ============================================================

    assign store_data_o = forwarded_rs2;

    assign rd_addr_o = rd_addr_i;

    assign fu_o     = fu_i;
    assign lsu_op_o = lsu_op_i;


    // ============================================================
    // 16. GPR WRITE QUALIFICATION
    // ============================================================

    assign reg_write_o =
        valid_o &&
        reg_write_i;


    // ============================================================
    // 17. CSR WRITE QUALIFICATION
    // ============================================================
    //
    // This is the only driver of csr_write_o.
    //
    // The actual architectural CSR update is committed later by
    // core_top after the EX instruction is allowed to advance.
    // ============================================================

    assign csr_write_o =
        valid_i &&
        ready_o &&
        (fu_i == FU_CSR) &&
        csr_write_i &&
        csr_write_requested &&
        csr_valid_i &&
        csr_write_valid_i &&
        !combined_illegal_instr;

endmodule
