module core_top
    import riscv_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // ============================================================
    // Instruction Bus
    // ============================================================

    output logic        ibus_req_o,
    output logic [63:0] ibus_addr_o,
    input  logic        ibus_gnt_i,
    input  logic        ibus_rvalid_i,
    input  logic [31:0] ibus_rdata_i,

    // ============================================================
    // Data Bus
    // ============================================================

    output logic        dbus_req_o,
    output logic        dbus_we_o,
    output logic [7:0]  dbus_be_o,
    output logic [63:0] dbus_addr_o,
    output logic [63:0] dbus_wdata_o,
    input  logic        dbus_gnt_i,
    input  logic        dbus_rvalid_i,
    input  logic [63:0] dbus_rdata_i,

    // ============================================================
    // Performance Monitoring
    // ============================================================

    output logic [63:0] perf_cycles_o,
    output logic [63:0] perf_instructions_o,

    output logic [63:0] perf_branches_o,
    output logic [63:0] perf_branches_taken_o,
    output logic [63:0] perf_redirects_o,

    output logic [63:0] perf_loads_o,
    output logic [63:0] perf_stores_o,
    output logic [63:0] perf_muldiv_o,

    output logic [63:0] perf_ex_stall_cycles_o,
    output logic [63:0] perf_mem_stall_cycles_o
);
    // =========================================================================
    // PIPELINE CONTROL
    // =========================================================================

    logic stall_if_id;
    logic stall_id_ex;
    logic stall_ex_mem;

    logic flush_if_id;
    logic flush_id_ex;
    logic flush_ex_mem;

    logic hazard_stall_if;
    logic hazard_stall_id;
    logic hazard_stall_ex;
    logic hazard_stall_mem;

    logic hazard_flush_if_id;
    logic hazard_flush_id_ex;
    logic hazard_flush_ex_mem;

    forward_sel_t forward_a_sel;
    forward_sel_t forward_b_sel;


    // =========================================================================
    // FETCH STAGE
    // =========================================================================

    logic        fetch_valid;
    logic        fetch_ready;
    logic [63:0] fetch_pc;
    logic [31:0] fetch_instr;


    // =========================================================================
    // IF / ID
    // =========================================================================

    logic        id_valid;
    logic [63:0] id_pc;
    logic [31:0] id_instr;


    // =========================================================================
    // DECODE STAGE
    // =========================================================================

    logic [4:0] dec_rs1;
    logic [4:0] dec_rs2;
    logic [4:0] dec_rd;

    logic       dec_uses_rs1;
    logic       dec_uses_rs2;

    logic [63:0] dec_imm;

    fu_t         dec_fu;
    alu_op_t     dec_alu_op;
    lsu_op_t     dec_lsu_op;
    branch_op_t  dec_branch_op;
    mul_op_t     dec_mul_op;
    csr_op_t     dec_csr_op;
    ctrl_flow_t  dec_ctrl_flow;

    op_a_sel_t   dec_op_a_sel;
    op_b_sel_t   dec_op_b_sel;

    logic        dec_reg_write;
    logic        dec_csr_write;

    logic        dec_is_ecall;
    logic        dec_is_ebreak;
    logic        dec_is_mret;
    logic        dec_illegal;

    logic [63:0] reg_rs1_data;
    logic [63:0] reg_rs2_data;


    // =========================================================================
    // ID / EX
    // =========================================================================

    logic        ex_valid;

    logic [63:0] ex_pc;
    logic [31:0] ex_instr;

    logic [4:0]  ex_rs1;
    logic [4:0]  ex_rs2;
    logic [4:0]  ex_rd;

    logic        ex_uses_rs1;
    logic        ex_uses_rs2;

    logic [63:0] ex_rs1_data;
    logic [63:0] ex_rs2_data;
    logic [63:0] ex_imm;

    fu_t         ex_fu;
    alu_op_t     ex_alu_op;
    lsu_op_t     ex_lsu_op;
    branch_op_t  ex_branch_op;
    mul_op_t     ex_mul_op;
    csr_op_t     ex_csr_op;
    ctrl_flow_t  ex_ctrl_flow;

    op_a_sel_t   ex_op_a_sel;
    op_b_sel_t   ex_op_b_sel;

    logic        ex_reg_write;
    logic        ex_csr_write;

    logic [11:0] ex_csr_addr;

    logic        ex_is_ecall;
    logic        ex_is_ebreak;
    logic        ex_is_mret;
    logic        ex_illegal;


    // =========================================================================
    // EXECUTE STAGE OUTPUTS
    // =========================================================================

    logic        execute_ready;
    logic        execute_valid;

    logic [63:0] execute_result;
    logic [63:0] execute_store_data;

    logic [4:0]  execute_rd;
    logic        execute_reg_write;

    fu_t         execute_fu;
    lsu_op_t     execute_lsu_op;


    // -------------------------------------------------------------------------
    // Execute -> CSR interface
    // -------------------------------------------------------------------------

    logic [11:0] execute_csr_addr;
    logic [63:0] execute_csr_wdata;
    csr_op_t     execute_csr_op;
    logic        execute_csr_write;

    logic [63:0] csr_rdata;
    logic        csr_valid;
    logic        csr_write_valid;

    logic [63:0] mtvec;
    logic [63:0] mepc;

    logic csr_write_commit;
    logic trap_commit;
    logic mret_commit;

    // -------------------------------------------------------------------------
    // Execute -> Trap CSR update interface
    // -------------------------------------------------------------------------

    logic        execute_trap_en;
    logic        execute_mret_en;

    logic [63:0] execute_trap_pc;
    logic [63:0] execute_trap_cause;
    logic [63:0] execute_trap_val;


    // -------------------------------------------------------------------------
    // Execute redirect
    // -------------------------------------------------------------------------

    logic        execute_redirect_valid;
    logic [63:0] execute_redirect_pc;

    logic        redirect_commit_valid;


    // =========================================================================
    // EX / MEM
    // =========================================================================

    logic        mem_valid;

    `ifndef SYNTHESIS
    logic [63:0] mem_pc;
    logic [31:0] mem_instr;
    `endif

    logic [63:0] mem_result;
    logic [63:0] mem_store_data;

    logic [4:0]  mem_rd;
    logic        mem_reg_write;

    fu_t         mem_fu;
    lsu_op_t     mem_lsu_op;


    // =========================================================================
    // MEMORY / LSU
    // =========================================================================

    logic        lsu_start;
    logic        lsu_done;
    logic [63:0] lsu_result;

    logic        mem_ready;
    logic        mem_result_ready;

    logic [63:0] mem_final_result;
    logic [63:0] mem_forward_data;

    logic        mem_to_wb_valid;


    // =========================================================================
    // MEM / WB
    // =========================================================================

    logic        wb_valid;

    logic [63:0] wb_result;

    logic [4:0]  wb_rd;
    logic        wb_reg_write;

    logic        wb_write_enable;

    `ifndef SYNTHESIS
    logic [63:0] wb_pc;
    logic [31:0] wb_instr;
    `endif

    `ifndef SYNTHESIS
    logic        retire_valid;
    logic [63:0] retire_pc;
    logic [31:0] retire_instr;

    logic        retire_rd_wen;
    logic [4:0]  retire_rd_addr;
    logic [63:0] retire_rd_data;
    `endif


    // =========================================================================
    // PIPELINE DATAPATH
    // =========================================================================

    // =========================================================================
    // STAGE 1: FETCH
    // =========================================================================

    assign fetch_ready =
        !hazard_stall_if &&
        !stall_if_id;


    fetch u_fetch (
        .clk              (clk),
        .rst_n            (rst_n),

        .valid_o          (fetch_valid),
        .pc_o             (fetch_pc),
        .instr_o          (fetch_instr),
        .ready_i          (fetch_ready),

        .redirect_valid_i (redirect_commit_valid),
        .redirect_pc_i    (execute_redirect_pc),

        .ibus_req_o       (ibus_req_o),
        .ibus_addr_o      (ibus_addr_o),
        .ibus_gnt_i       (ibus_gnt_i),
        .ibus_rvalid_i    (ibus_rvalid_i),
        .ibus_rdata_i     (ibus_rdata_i)
    );


    // =========================================================================
    // IF -> ID
    // =========================================================================

    if_id_reg u_if_id (
        .clk      (clk),
        .rst_n    (rst_n),

        .valid_i  (fetch_valid),
        .pc_i     (fetch_pc),
        .instr_i  (fetch_instr),

        .stall_i  (stall_if_id),
        .flush_i  (flush_if_id),

        .valid_o  (id_valid),
        .pc_o     (id_pc),
        .instr_o  (id_instr)
    );


    // =========================================================================
    // STAGE 2: DECODE
    // =========================================================================

    decoder u_decoder (
        .instr_i          (id_instr),

        .rs1_addr_o       (dec_rs1),
        .rs2_addr_o       (dec_rs2),
        .rd_addr_o        (dec_rd),

        .uses_rs1_o       (dec_uses_rs1),
        .uses_rs2_o       (dec_uses_rs2),

        .fu_o             (dec_fu),

        .alu_op_o         (dec_alu_op),
        .lsu_op_o         (dec_lsu_op),
        .branch_op_o      (dec_branch_op),
        .mul_op_o         (dec_mul_op),
        .csr_op_o         (dec_csr_op),
        .ctrl_flow_o      (dec_ctrl_flow),

        .op_a_sel_o       (dec_op_a_sel),
        .op_b_sel_o       (dec_op_b_sel),

        .reg_write_o      (dec_reg_write),
        .csr_write_o      (dec_csr_write),

        .is_ecall_o       (dec_is_ecall),
        .is_ebreak_o      (dec_is_ebreak),
        .is_mret_o        (dec_is_mret),

        .illegal_instr_o  (dec_illegal)
    );


    imm_gen u_imm_gen (
        .instr_i (id_instr),
        .imm_o   (dec_imm)
    );


    // =========================================================================
    // INTEGER REGISTER FILE
    // =========================================================================

    assign wb_write_enable =
        wb_valid &&
        wb_reg_write;


    regfile u_regfile (
        .clk        (clk),
        .rst_n      (rst_n),

        .rs1_addr_i (dec_rs1),
        .rs1_data_o (reg_rs1_data),

        .rs2_addr_i (dec_rs2),
        .rs2_data_o (reg_rs2_data),

        .rd_addr_i  (wb_rd),
        .rd_data_i  (wb_result),
        .rd_wen_i   (wb_write_enable)
    );


    // =========================================================================
    // ID -> EX
    // =========================================================================

    id_ex_reg u_id_ex (
        .clk             (clk),
        .rst_n           (rst_n),

        .stall_i         (stall_id_ex),
        .flush_i         (flush_id_ex),

        // Instruction
        .valid_i         (id_valid),
        .pc_i            (id_pc),
        .instr_i         (id_instr),

        // Registers
        .rs1_addr_i      (dec_rs1),
        .rs2_addr_i      (dec_rs2),
        .rd_addr_i       (dec_rd),

        .uses_rs1_i      (dec_uses_rs1),
        .uses_rs2_i      (dec_uses_rs2),

        .rs1_data_i      (reg_rs1_data),
        .rs2_data_i      (reg_rs2_data),

        .imm_i           (dec_imm),

        // Execution description
        .fu_i            (dec_fu),

        .alu_op_i        (dec_alu_op),
        .lsu_op_i        (dec_lsu_op),
        .branch_op_i     (dec_branch_op),
        .mul_op_i        (dec_mul_op),
        .csr_op_i        (dec_csr_op),
        .ctrl_flow_i     (dec_ctrl_flow),

        .op_a_sel_i      (dec_op_a_sel),
        .op_b_sel_i      (dec_op_b_sel),

        // Architectural effects
        .reg_write_i     (dec_reg_write),
        .csr_write_i     (dec_csr_write),

        // CSR / system
        .csr_addr_i      (id_instr[31:20]),

        .is_ecall_i      (dec_is_ecall),
        .is_ebreak_i     (dec_is_ebreak),
        .is_mret_i       (dec_is_mret),

        .illegal_instr_i (dec_illegal),

        // EX outputs
        .valid_o         (ex_valid),
        .pc_o            (ex_pc),
        .instr_o         (ex_instr),

        .rs1_addr_o      (ex_rs1),
        .rs2_addr_o      (ex_rs2),
        .rd_addr_o       (ex_rd),

        .uses_rs1_o      (ex_uses_rs1),
        .uses_rs2_o      (ex_uses_rs2),

        .rs1_data_o      (ex_rs1_data),
        .rs2_data_o      (ex_rs2_data),

        .imm_o           (ex_imm),

        .fu_o            (ex_fu),

        .alu_op_o        (ex_alu_op),
        .lsu_op_o        (ex_lsu_op),
        .branch_op_o     (ex_branch_op),
        .mul_op_o        (ex_mul_op),
        .csr_op_o        (ex_csr_op),
        .ctrl_flow_o     (ex_ctrl_flow),

        .op_a_sel_o      (ex_op_a_sel),
        .op_b_sel_o      (ex_op_b_sel),

        .reg_write_o     (ex_reg_write),
        .csr_write_o     (ex_csr_write),

        .csr_addr_o      (ex_csr_addr),

        .is_ecall_o      (ex_is_ecall),
        .is_ebreak_o     (ex_is_ebreak),
        .is_mret_o       (ex_is_mret),

        .illegal_instr_o (ex_illegal)
    );


    // =========================================================================
    // CSR ARCHITECTURAL STATE
    // =========================================================================

    logic instret_event;

    assign instret_event = wb_valid;

    csr_regfile u_csr (
        .clk          (clk),
        .rst_n        (rst_n),

        .addr_i       (execute_csr_addr),
        .wdata_i      (execute_csr_wdata),
        .op_i         (execute_csr_op),
        .we_i         (csr_write_commit),

        .rdata_o      (csr_rdata),
        .csr_valid_o  (csr_valid),
        .csr_write_valid_o (csr_write_valid),

        .trap_en_i    (trap_commit),
        .trap_pc_i    (execute_trap_pc),
        .trap_cause_i (execute_trap_cause),
        .trap_val_i   (execute_trap_val),

        .mret_i       (mret_commit),

        // A valid WB entry represents a successfully retired
        // architectural instruction.
        .instret_i    (instret_event),

        .mtvec_o      (mtvec),
        .mepc_o       (mepc)
    );


    // =========================================================================
    // STAGE 3: EXECUTE
    // =========================================================================

    execute_stage u_execute (
        .clk                  (clk),
        .rst_n                (rst_n),

        // ID/EX instruction
        .valid_i              (ex_valid),
        .pc_i                 (ex_pc),
        .instr_i              (ex_instr),

        .rs1_addr_i           (ex_rs1),
        .rd_addr_i            (ex_rd),

        .rs1_data_i           (ex_rs1_data),
        .rs2_data_i           (ex_rs2_data),
        .imm_i                (ex_imm),

        .fu_i                 (ex_fu),

        .alu_op_i             (ex_alu_op),
        .lsu_op_i             (ex_lsu_op),
        .branch_op_i          (ex_branch_op),
        .mul_op_i             (ex_mul_op),
        .csr_op_i             (ex_csr_op),
        .ctrl_flow_i          (ex_ctrl_flow),

        .op_a_sel_i           (ex_op_a_sel),
        .op_b_sel_i           (ex_op_b_sel),

        .reg_write_i          (ex_reg_write),
        .csr_write_i          (ex_csr_write),

        .csr_addr_i           (ex_csr_addr),

        .is_ecall_i           (ex_is_ecall),
        .is_ebreak_i          (ex_is_ebreak),
        .is_mret_i            (ex_is_mret),
        .illegal_instr_i      (ex_illegal),

        // Forwarding
        .forward_a_sel_i      (forward_a_sel),
        .forward_b_sel_i      (forward_b_sel),

        .mem_forward_data_i   (mem_forward_data),
        .wb_forward_data_i    (wb_result),

        // CSR state
        .csr_rdata_i          (csr_rdata),
        .csr_valid_i          (csr_valid),
        .csr_write_valid_i     (csr_write_valid),

        .mtvec_i              (mtvec),
        .mepc_i               (mepc),

        // EX readiness
        .ready_o              (execute_ready),

        // EX/MEM payload
        .valid_o              (execute_valid),

        .result_o             (execute_result),
        .store_data_o         (execute_store_data),

        .rd_addr_o            (execute_rd),
        .reg_write_o          (execute_reg_write),

        .fu_o                 (execute_fu),
        .lsu_op_o             (execute_lsu_op),

        // CSR instruction interface
        .csr_addr_o           (execute_csr_addr),
        .csr_wdata_o          (execute_csr_wdata),
        .csr_op_o             (execute_csr_op),
        .csr_write_o          (execute_csr_write),

        // Trap CSR update
        .trap_en_o            (execute_trap_en),
        .mret_en_o            (execute_mret_en),

        .trap_pc_o            (execute_trap_pc),
        .trap_cause_o         (execute_trap_cause),
        .trap_val_o           (execute_trap_val),

        // Redirect
        .redirect_valid_o     (execute_redirect_valid),
        .redirect_pc_o        (execute_redirect_pc)
    );


    // =========================================================================
    // COMMIT QUALIFICATION
    // =========================================================================
    //
    // EX is younger than MEM.
    //
    // If MEM is blocked, an EX-stage CSR/trap/MRET/redirect must wait
    // until the older MEM instruction can advance. This preserves the
    // in-order architectural ordering of side effects.
    // =========================================================================

    assign csr_write_commit =
        execute_csr_write &&
        mem_ready;

    assign trap_commit =
        execute_trap_en &&
        mem_ready;

    assign mret_commit =
        execute_mret_en &&
        mem_ready;

    assign redirect_commit_valid =
        execute_redirect_valid &&
        mem_ready;

    // =========================================================================
    // EX -> MEM
    // =========================================================================

    ex_mem_reg u_ex_mem (
        .clk          (clk),
        .rst_n        (rst_n),

        .stall_i      (stall_ex_mem),
        .flush_i      (flush_ex_mem),

        .valid_i      (execute_valid),

        `ifndef SYNTHESIS
            .pc_i         (ex_pc),
            .instr_i      (ex_instr),
        `endif

        .result_i     (execute_result),
        .store_data_i (execute_store_data),

        .rd_addr_i    (execute_rd),
        .reg_write_i  (execute_reg_write),

        .fu_i         (execute_fu),
        .lsu_op_i     (execute_lsu_op),

        .valid_o      (mem_valid),

        `ifndef SYNTHESIS
            .pc_o         (mem_pc),
            .instr_o      (mem_instr),
        `endif

        .result_o     (mem_result),
        .store_data_o (mem_store_data),

        .rd_addr_o    (mem_rd),
        .reg_write_o  (mem_reg_write),

        .fu_o         (mem_fu),
        .lsu_op_o     (mem_lsu_op)
    );


    // =========================================================================
    // MEMORY STAGE FLOW
    // =========================================================================

    assign lsu_start =
        mem_valid &&
        (mem_fu == FU_LSU);


    // A non-memory instruction passes through MEM immediately.
    //
    // An LSU instruction remains in MEM until its transaction completes.
    always_comb begin
        if (!mem_valid) begin
            mem_ready = 1'b1;

        end else if (mem_fu == FU_LSU) begin
            mem_ready = lsu_done;

        end else begin
            mem_ready = 1'b1;
        end
    end


    // MEM forwarding is available immediately for ordinary execution
    // results. A load result is not forwardable until the LSU completes.
    always_comb begin
        if (!mem_valid) begin
            mem_result_ready = 1'b1;

        end else if (
            (mem_fu == FU_LSU) &&
            lsu_is_load(mem_lsu_op)
        ) begin
            mem_result_ready = lsu_done;

        end else begin
            mem_result_ready = 1'b1;
        end
    end


    // Select the architectural result leaving MEM.
    always_comb begin
        if (
            (mem_fu == FU_LSU) &&
            lsu_is_load(mem_lsu_op)
        ) begin
            mem_final_result = lsu_result;

        end else begin
            mem_final_result = mem_result;
        end
    end

    assign mem_forward_data = mem_final_result;


    // Only transfer a MEM instruction into WB when MEM has actually
    // completed. MEM/WB itself therefore does not need to be stalled.
    assign mem_to_wb_valid =
        mem_valid &&
        mem_ready;

    // =========================================================================
    // STAGE 4: MEMORY / LSU
    // =========================================================================

    lsu u_lsu (
        .clk           (clk),
        .rst_n         (rst_n),

        .start_i       (lsu_start),

        .op_i          (mem_lsu_op),
        .addr_i        (mem_result),
        .store_data_i  (mem_store_data),

        .done_o        (lsu_done),
        .result_o      (lsu_result),

        .dbus_req_o    (dbus_req_o),
        .dbus_we_o     (dbus_we_o),
        .dbus_be_o     (dbus_be_o),
        .dbus_addr_o   (dbus_addr_o),
        .dbus_wdata_o  (dbus_wdata_o),

        .dbus_gnt_i    (dbus_gnt_i),
        .dbus_rvalid_i (dbus_rvalid_i),
        .dbus_rdata_i  (dbus_rdata_i)
    );


    // =========================================================================
    // MEM -> WB
    // =========================================================================

    mem_wb_reg u_mem_wb (
        .clk         (clk),
        .rst_n       (rst_n),

        // MEM/WB is not independently stalled. A MEM instruction
        // transfers only when mem_ready is true.
        .stall_i     (1'b0),

        .valid_i     (mem_to_wb_valid),

        `ifndef SYNTHESIS
            .pc_i        (mem_pc),
            .instr_i     (mem_instr),
        `endif

        .result_i    (mem_final_result),

        .rd_addr_i   (mem_rd),
        .reg_write_i (mem_reg_write),

        .valid_o     (wb_valid),

        `ifndef SYNTHESIS
            .pc_o        (wb_pc),
            .instr_o     (wb_instr),
        `endif

        .result_o    (wb_result),

        .rd_addr_o   (wb_rd),
        .reg_write_o (wb_reg_write)
    );


    // =========================================================================
    // CROSS-PIPELINE CONTROL
    // =========================================================================

    // =========================================================================
    // HAZARD / FORWARDING CONTROL
    // =========================================================================

    hazard_unit u_hazard (
        // ID stage
        .id_valid_i            (id_valid),
        .id_uses_rs1_i         (dec_uses_rs1),
        .id_uses_rs2_i         (dec_uses_rs2),
        .id_rs1_i              (dec_rs1),
        .id_rs2_i              (dec_rs2),

        // EX stage
        .ex_valid_i            (ex_valid),
        .ex_uses_rs1_i         (ex_uses_rs1),
        .ex_uses_rs2_i         (ex_uses_rs2),
        .ex_rs1_i              (ex_rs1),
        .ex_rs2_i              (ex_rs2),

        .ex_rd_i               (ex_rd),
        .ex_reg_write_i        (ex_reg_write),
        .ex_is_load_i          (
            ex_valid &&
            (ex_fu == FU_LSU) &&
            lsu_is_load(ex_lsu_op)
        ),

        .ex_ready_i            (execute_ready),

        // MEM stage
        .mem_valid_i           (mem_valid),
        .mem_rd_i              (mem_rd),
        .mem_reg_write_i       (mem_reg_write),

        .mem_result_ready_i    (mem_result_ready),
        .mem_ready_i           (mem_ready),

        // WB stage
        .wb_valid_i            (wb_valid),
        .wb_rd_i               (wb_rd),
        .wb_reg_write_i        (wb_reg_write),

        // Control-flow recovery
        .redirect_i            (redirect_commit_valid),

        // Forwarding
        .forward_a_o           (forward_a_sel),
        .forward_b_o           (forward_b_sel),

        // Pipeline control
        .stall_if_o            (hazard_stall_if),
        .stall_id_o            (hazard_stall_id),
        .stall_ex_o            (hazard_stall_ex),
        .stall_mem_o           (hazard_stall_mem),

        .flush_if_id_o         (hazard_flush_if_id),
        .flush_id_ex_o         (hazard_flush_id_ex),
        .flush_ex_mem_o        (hazard_flush_ex_mem)
    );


    assign stall_if_id  = hazard_stall_id;
    assign stall_id_ex  = hazard_stall_ex;
    assign stall_ex_mem = hazard_stall_mem;

    assign flush_if_id  = hazard_flush_if_id;
    assign flush_id_ex  = hazard_flush_id_ex;
    assign flush_ex_mem = hazard_flush_ex_mem;

    `ifndef SYNTHESIS

    assign retire_valid   = wb_valid;

    assign retire_pc      = wb_pc;
    assign retire_instr   = wb_instr;

    assign retire_rd_wen  =
        wb_valid &&
        wb_reg_write &&
        (wb_rd != 5'd0);

    assign retire_rd_addr = wb_rd;
    assign retire_rd_data = wb_result;

    `endif


    // =========================================================================
    // RETIREMENT / TRACE
    // =========================================================================

`ifndef SYNTHESIS

tracer u_tracer (
    .clk               (clk),

    .retire_valid_i    (retire_valid),
    .retire_pc_i       (retire_pc),
    .retire_instr_i    (retire_instr),

    .retire_rd_wen_i   (retire_rd_wen),
    .retire_rd_addr_i  (retire_rd_addr),
    .retire_rd_data_i  (retire_rd_data)
);

`endif


// =========================================================================
// PERFORMANCE MONITORING
// =========================================================================

logic ex_advance;

logic perf_branch;
logic perf_branch_taken;
logic perf_load;
logic perf_store;
logic perf_muldiv;
logic perf_redirect;

logic perf_ex_stall;
logic perf_mem_stall;


// -------------------------------------------------------------------------
// Instruction event qualification
//
// ex_advance is asserted exactly once when an EX instruction successfully
// advances into EX/MEM.
// -------------------------------------------------------------------------

assign ex_advance =
    execute_valid &&
    !stall_ex_mem;


// Conditional branch completed in EX.
assign perf_branch =
    ex_advance &&
    (ex_ctrl_flow == CTRL_BRANCH);


// With the current no-prediction frontend, a conditional branch redirects
// only when it is taken.
assign perf_branch_taken =
    perf_branch &&
    execute_redirect_valid;


// Memory instruction classes.
assign perf_load =
    ex_advance &&
    (ex_fu == FU_LSU) &&
    lsu_is_load(ex_lsu_op);

assign perf_store =
    ex_advance &&
    (ex_fu == FU_LSU) &&
    lsu_is_store(ex_lsu_op);


// M-extension instruction completed EX.
assign perf_muldiv =
    ex_advance &&
    (ex_fu == FU_MULDIV);


// Committed control-flow redirect.
assign perf_redirect =
    redirect_commit_valid;


// Unit-local stall cycles.
//
// These intentionally measure the execution/memory unit being busy,
// rather than generic downstream pipeline backpressure.
assign perf_ex_stall =
    ex_valid &&
    !execute_ready;

assign perf_mem_stall =
    mem_valid &&
    !mem_ready;


// -------------------------------------------------------------------------
// Performance counters
// -------------------------------------------------------------------------

perf_counters u_perf (
    .clk                   (clk),
    .rst_n                 (rst_n),

    .retire_i              (wb_valid),

    .branch_i              (perf_branch),
    .branch_taken_i        (perf_branch_taken),

    .load_i                (perf_load),
    .store_i               (perf_store),
    .muldiv_i              (perf_muldiv),

    .redirect_i            (perf_redirect),

    .ex_stall_i            (perf_ex_stall),
    .mem_stall_i           (perf_mem_stall),

    .cycles_o              (perf_cycles_o),
    .instructions_o        (perf_instructions_o),

    .branches_o            (perf_branches_o),
    .branches_taken_o      (perf_branches_taken_o),
    .redirects_o           (perf_redirects_o),

    .loads_o               (perf_loads_o),
    .stores_o              (perf_stores_o),
    .muldiv_instructions_o (perf_muldiv_o),

    .ex_stall_cycles_o     (perf_ex_stall_cycles_o),
    .mem_stall_cycles_o    (perf_mem_stall_cycles_o)
);


endmodule
