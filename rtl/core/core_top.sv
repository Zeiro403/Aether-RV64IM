module core_top 
    import riscv_pkg::*; 
(
    input  logic        clk,
    input  logic        rst_n,

    // ---------------------------------------------------------
    // Instruction Bus (I-Bus)
    // ---------------------------------------------------------
    output logic        ibus_req_o,
    output logic [63:0] ibus_addr_o,
    input  logic        ibus_gnt_i,   
    input  logic        ibus_rvalid_i, 
    input  logic [31:0] ibus_rdata_i,

    // ---------------------------------------------------------
    // Data Bus (D-Bus)
    // ---------------------------------------------------------
    output logic        dbus_req_o,
    output logic        dbus_we_o,
    output logic [7:0]  dbus_be_o,
    output logic [63:0] dbus_addr_o,
    output logic [63:0] dbus_wdata_o,
    input  logic        dbus_gnt_i,     
    input  logic        dbus_rvalid_i,  
    input  logic [63:0] dbus_rdata_i
);

    // =========================================================================
    // WIRE & SIGNAL DECLARATIONS
    // =========================================================================

    // Global Control Signals
    logic stall_hazard; 
    logic stall_mul;    
    logic stall_fetch;  
    logic stall_lsu;    
    logic stall_if_id;
    logic stall_id_ex;
    logic stall_ex_mem;
    logic stall_mem_wb;

    logic flush_hazard; 
    logic flush_if_id;  
    logic flush_id_ex;  
    logic flush_ex_mem; 

    // -----------------------------------------
    // STAGE 1: FETCH SIGNALS
    // -----------------------------------------
    // Prefetch Buffer signals
    logic        pf_valid;     
    logic [31:0] pf_instr;     
    logic [63:0] pf_pc;
    logic        fetch_ready;
    logic        do_flush;
    logic [63:0] flush_target;

    // Fetch Unit signals
    logic [63:0] current_pc;
    logic [31:0] raw_instr;

    // -----------------------------------------
    // Pipeline: IF to ID signals
    // -----------------------------------------
    logic [63:0] id_pc;
    logic [31:0] id_instr;

    // -----------------------------------------
    // STAGE 2: DECODE SIGNALS
    // -----------------------------------------
    // Decode signals
    logic [4:0]  dec_rs1;
    logic [4:0]  dec_rs2;
    logic [4:0]  dec_rd;
    logic [63:0] dec_imm;
    alu_op_t     dec_alu_op;
    lsu_op_t     dec_lsu_op;
    branch_op_t  dec_branch_op;
    mul_op_t     dec_mul_op;  
    logic        dec_reg_write;
    logic        dec_alu_src;
    logic        dec_mem_write;
    logic        dec_mem_read;   
    logic        dec_mem_to_reg;
    logic        dec_is_jump;
    logic        dec_is_jalr;
    logic        dec_is_lui;     
    logic        dec_is_auipc;   

    // Trap Decode signals
    logic        id_csr_we;
    csr_op_t     id_csr_op;
    logic        id_is_ecall;
    logic        id_is_ebreak;
    logic        id_is_mret;
    logic        id_illegal_instr;
    logic [11:0] id_csr_addr;

    // Regfile signals
    logic [63:0] reg_rs1_data;
    logic [63:0] reg_rs2_data;

    // -----------------------------------------
    // Pipeline: ID to EX signals
    // -----------------------------------------
    logic [63:0] ex_pc;
    logic [31:0] ex_instr;
    logic [63:0] ex_rs1_data;
    logic [63:0] ex_rs2_data;
    logic [63:0] ex_imm;
    logic [4:0]  ex_rd_addr;
    alu_op_t     ex_alu_op;
    lsu_op_t     ex_lsu_op;
    branch_op_t  ex_branch_op;
    mul_op_t     ex_mul_op;     
    logic        ex_reg_write;
    logic        ex_alu_src;
    logic        ex_mem_write;
    logic        ex_mem_read;    
    logic        ex_mem_to_reg;
    logic        ex_is_jump;
    logic        ex_is_jalr;
    logic        ex_is_lui;      
    logic        ex_is_auipc;    
    logic [4:0]  ex_rs1_addr;
    logic [4:0]  ex_rs2_addr;

    // Trap EX signals
    logic        ex_csr_we;
    csr_op_t     ex_csr_op;
    logic        ex_is_ecall;
    logic        ex_is_ebreak;
    logic        ex_is_mret;
    logic        ex_illegal_instr;
    logic [11:0] ex_csr_addr;

    // -----------------------------------------
    // STAGE 3: EXECUTE SIGNALS
    // -----------------------------------------
    // Forwarding signals
    logic [63:0] alu_operand_a;
    logic [63:0] alu_operand_b;

    // ALU signals
    logic [63:0] alu_final_a;
    logic [63:0] alu_final_b;
    logic [63:0] alu_result;

    // Branch signals
    logic [63:0] branch_target;
    logic        branch_taken;
    logic        pc_redirect;

    // Multiplier signals
    logic [63:0] mul_result;  

    // CSR Regfile signals
    logic [63:0] csr_wdata;
    logic [63:0] csr_rdata;
    logic        csr_valid;
    logic [63:0] mtvec_val;
    logic [63:0] mepc_val;

    // Alignment and Trap Unit signals
    logic        is_misaligned;
    logic        load_misaligned;
    logic        store_misaligned;
    logic        combined_illegal_instr;
    logic        trap_en;
    logic        mret_en;
    logic [63:0] trap_cause;
    logic [63:0] trap_pc;
    logic [63:0] trap_val;
    logic        trap_flush;
    logic [63:0] pc_trap_val;

    // Final EX Result MUX signal
    logic [63:0] final_ex_result;

    // -----------------------------------------
    // Pipeline: EX to MEM signals
    // -----------------------------------------
    logic [63:0] mem_pc;    
    logic [31:0] mem_instr; 
    logic [63:0] mem_alu_result;
    logic [63:0] mem_store_data;
    logic [4:0]  mem_rd_addr;
    logic        mem_reg_write;
    lsu_op_t     mem_lsu_op;
    logic        mem_mem_write;
    logic        mem_mem_read;
    logic        mem_mem_to_reg;
    
    // -----------------------------------------
    // STAGE 4: MEMORY SIGNALS
    // -----------------------------------------
    // LSU signals
    logic [63:0] lsu_final_data;

    // -----------------------------------------
    // Pipeline: MEM to WB signals
    // -----------------------------------------
    logic [63:0] wb_pc;
    logic [31:0] wb_instr;     
    logic [63:0] wb_alu_result;
    logic [63:0] wb_mem_data;
    logic [4:0]  wb_rd_addr;
    logic        wb_reg_write;
    logic        wb_mem_to_reg;

    // -----------------------------------------
    // STAGE 5: WRITEBACK SIGNALS
    // -----------------------------------------
    logic [63:0] wb_final_data;


    // =========================================================================
    // PIPELINE LOGIC & INSTANTIATIONS
    // =========================================================================

    // ---------------------------------------------------------
    // STALL & FLUSH CONTROL
    // ---------------------------------------------------------
    assign stall_if_id  = stall_hazard | stall_mul | stall_fetch | stall_lsu;
    assign stall_id_ex  = stall_mul | stall_lsu;
    assign stall_ex_mem = stall_lsu;
    assign stall_mem_wb = stall_lsu;

    assign flush_if_id  = pc_redirect || trap_flush;
    assign flush_id_ex  = pc_redirect || trap_flush || (flush_hazard && !stall_id_ex);
    assign flush_ex_mem = (stall_mul && !stall_lsu) || trap_flush;


    // ---------------------------------------------------------
    // STAGE 1: FETCH
    // ---------------------------------------------------------
    assign fetch_ready  = ~(stall_hazard | stall_mul | stall_fetch | stall_lsu); 
    assign do_flush     = pc_redirect || trap_flush;
    assign flush_target = trap_flush ? pc_trap_val : branch_target;

    prefetch_buffer u_prefetch (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush_i         (do_flush),
        .flush_addr_i    (flush_target),
        .ready_i         (fetch_ready),
        .valid_o         (pf_valid),
        .instr_o         (pf_instr),
        .pc_o            (pf_pc),
        .ibus_req_o      (ibus_req_o),
        .ibus_addr_o     (ibus_addr_o),
        .ibus_gnt_i      (ibus_gnt_i),
        .ibus_rvalid_i   (ibus_rvalid_i),
        .ibus_rdata_i    (ibus_rdata_i)
    );

    fetch u_fetch (
        .pf_valid_i      (pf_valid),
        .pf_instr_i      (pf_instr),
        .pf_pc_i         (pf_pc),
        .stall_fetch_o   (stall_fetch),
        .instr_o         (raw_instr),
        .pc_out_o        (current_pc)
    );


    // ---------------------------------------------------------
    // PIPELINE REGISTER: IF -> ID
    // ---------------------------------------------------------
    if_id_reg u_if_id (
        .clk      (clk),
        .rst_n    (rst_n),
        .stall_i  (stall_if_id),
        .flush_i  (flush_if_id),   
        .pc_i     (current_pc),
        .instr_i  (raw_instr),
        .pc_o     (id_pc),
        .instr_o  (id_instr)
    );


    // ---------------------------------------------------------
    // STAGE 2: DECODE
    // ---------------------------------------------------------
    decode u_decode (
        .instr_i         (id_instr),
        .rs1_addr_o      (dec_rs1),
        .rs2_addr_o      (dec_rs2),
        .rd_addr_o       (dec_rd),
        .alu_op_o        (dec_alu_op),
        .lsu_op_o        (dec_lsu_op),
        .branch_op_o     (dec_branch_op),
        .mul_op_o        (dec_mul_op),
        .reg_write_o     (dec_reg_write),
        .alu_src_o       (dec_alu_src),
        .mem_write_o     (dec_mem_write),
        .mem_read_o      (dec_mem_read),   
        .mem_to_reg_o    (dec_mem_to_reg),
        .is_jump_o       (dec_is_jump),
        .is_jalr_o       (dec_is_jalr),
        .is_lui_o        (dec_is_lui),     
        .is_auipc_o      (dec_is_auipc),
        .csr_we_o        (id_csr_we),
        .csr_op_o        (id_csr_op),
        .is_ecall_o      (id_is_ecall),
        .is_ebreak_o     (id_is_ebreak),
        .is_mret_o       (id_is_mret),
        .illegal_instr_o (id_illegal_instr),   
        .imm_o           (dec_imm)
    );

    hazard_unit u_hazard (
        .id_rs1_addr_i   (dec_rs1),
        .id_rs2_addr_i   (dec_rs2),
        .ex_rd_addr_i    (ex_rd_addr),
        .ex_mem_read_i   (ex_mem_read),
        .stall_hazard_o  (stall_hazard),
        .flush_hazard_o  (flush_hazard)
    );


    // ---------------------------------------------------------
    // PIPELINE REGISTER: ID -> EX
    // ---------------------------------------------------------
    assign id_csr_addr = id_instr[31:20];

    id_ex_reg u_id_ex (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush_i         (flush_id_ex),
        .stall_i         (stall_id_ex), 
        .pc_i            (id_pc),
        .instr_i         (id_instr),
        .rs1_data_i      (reg_rs1_data),
        .rs2_data_i      (reg_rs2_data),
        .imm_i           (dec_imm),
        .csr_we_i        (id_csr_we),
        .csr_op_i        (id_csr_op),
        .is_ecall_i      (id_is_ecall),
        .is_ebreak_i     (id_is_ebreak),
        .is_mret_i       (id_is_mret),
        .illegal_instr_i (id_illegal_instr),
        .csr_addr_i      (id_csr_addr),
        .rs1_addr_i      (dec_rs1),
        .rs2_addr_i      (dec_rs2),
        .rd_addr_i       (dec_rd),
        .alu_op_i        (dec_alu_op),
        .lsu_op_i        (dec_lsu_op),
        .branch_op_i     (dec_branch_op),
        .mul_op_i        (dec_mul_op),
        .reg_write_i     (dec_reg_write),
        .alu_src_i       (dec_alu_src),
        .mem_write_i     (dec_mem_write),
        .mem_read_i      (dec_mem_read),
        .mem_to_reg_i    (dec_mem_to_reg),
        .is_jump_i       (dec_is_jump),
        .is_jalr_i       (dec_is_jalr),
        .is_lui_i        (dec_is_lui),
        .is_auipc_i      (dec_is_auipc),
        
        .pc_o            (ex_pc),
        .instr_o         (ex_instr),
        .rs1_data_o      (ex_rs1_data),
        .rs2_data_o      (ex_rs2_data),
        .imm_o           (ex_imm),
        .csr_we_o        (ex_csr_we),
        .csr_op_o        (ex_csr_op),
        .is_ecall_o      (ex_is_ecall),
        .is_ebreak_o     (ex_is_ebreak),
        .is_mret_o       (ex_is_mret),
        .illegal_instr_o (ex_illegal_instr),
        .csr_addr_o      (ex_csr_addr),
        .rs1_addr_o      (ex_rs1_addr),
        .rs2_addr_o      (ex_rs2_addr),
        .rd_addr_o       (ex_rd_addr),
        .alu_op_o        (ex_alu_op),
        .lsu_op_o        (ex_lsu_op),
        .branch_op_o     (ex_branch_op),
        .mul_op_o        (ex_mul_op),
        .reg_write_o     (ex_reg_write),
        .alu_src_o       (ex_alu_src),
        .mem_write_o     (ex_mem_write),
        .mem_read_o      (ex_mem_read),
        .mem_to_reg_o    (ex_mem_to_reg),
        .is_jump_o       (ex_is_jump),
        .is_jalr_o       (ex_is_jalr),
        .is_lui_o        (ex_is_lui),
        .is_auipc_o      (ex_is_auipc)
    );


    // ---------------------------------------------------------
    // STAGE 3: EXECUTE
    // ---------------------------------------------------------
    
    // -- Data Forwarding Logic --
    always_comb begin
        if (mem_reg_write && (mem_rd_addr != 0) && (mem_rd_addr == ex_rs1_addr)) begin
             if (mem_mem_to_reg) alu_operand_a = lsu_final_data;
             else                alu_operand_a = mem_alu_result;
        end else if (wb_reg_write && (wb_rd_addr != 0) && (wb_rd_addr == ex_rs1_addr)) begin
             alu_operand_a = wb_final_data;
        end else begin
             alu_operand_a = ex_rs1_data;
        end
    end

    always_comb begin
        if (mem_reg_write && (mem_rd_addr != 0) && (mem_rd_addr == ex_rs2_addr)) begin
             if (mem_mem_to_reg) alu_operand_b = lsu_final_data;
             else                alu_operand_b = mem_alu_result;
        end else if (wb_reg_write && (wb_rd_addr != 0) && (wb_rd_addr == ex_rs2_addr)) begin
             alu_operand_b = wb_final_data;
        end else begin
             alu_operand_b = ex_rs2_data;
        end
    end

    // -- Branch Control --
    branch_comp u_branch (
        .branch_op_i     (ex_branch_op),
        .op_a_i          (alu_operand_a),
        .op_b_i          (alu_operand_b),
        .branch_taken_o  (branch_taken)
    );
    
    assign branch_target = ex_is_jalr ? ((alu_operand_a + ex_imm) & ~64'd1) : (ex_pc + ex_imm);
    assign pc_redirect   = branch_taken || ex_is_jump || ex_is_jalr;

    // -- ALU Input Multiplexing --
    always_comb begin
        if (ex_is_jump) begin
            alu_final_a = ex_pc;
            alu_final_b = 64'd4;
        end else if (ex_is_lui) begin
            alu_final_a = 64'b0; 
            alu_final_b = ex_imm;
        end else if (ex_is_auipc) begin
            alu_final_a = ex_pc; 
            alu_final_b = ex_imm;
        end else begin
            alu_final_a = alu_operand_a;
            alu_final_b = (ex_alu_src) ? ex_imm : alu_operand_b;
        end
    end

    // -- ALU Unit --
    alu u_alu (
        .alu_op_i  (ex_alu_op),
        .op_a_i    (alu_final_a),
        .op_b_i    (alu_final_b),
        .result_o  (alu_result)
    );

    // -- Multiplier Unit --
    multiplier u_multiplier (
        .clk         (clk),
        .rst_n       (rst_n),
        .mul_op_i    (ex_mul_op),
        .op_a_i      (alu_operand_a),
        .op_b_i      (alu_operand_b),
        .result_o    (mul_result),
        .stall_mul_o (stall_mul)
    );

    // -- CSR and System Control --
    assign csr_wdata = (ex_csr_op[2] == 1'b1) ? ex_imm : alu_final_a;

    csr_regfile u_csr (
        .clk          (clk),
        .rst_n        (rst_n),
        .addr_i       (ex_csr_addr),
        .wdata_i      (csr_wdata),
        .op_i         (ex_csr_op),
        .we_i         (ex_csr_we),
        .rdata_o      (csr_rdata),
        .csr_valid_o  (csr_valid),
        .trap_en_i    (trap_en),
        .trap_pc_i    (trap_pc),
        .trap_cause_i (trap_cause),
        .trap_val_i   (trap_val),
        .mret_i       (mret_en),
        .instret_i    (1'b0),  //Instruction Timer to be implemented
        .mtvec_o      (mtvec_val),
        .mepc_o       (mepc_val)
    );

    // -- Trap Alignment Logic --
    always_comb begin
        is_misaligned = 1'b0;
        case (ex_lsu_op)
            LSU_LH, LSU_LHU, LSU_SH: if (alu_result[0] != 1'b0)   is_misaligned = 1'b1; 
            LSU_LW, LSU_LWU, LSU_SW: if (alu_result[1:0] != 2'b00)  is_misaligned = 1'b1; 
            LSU_LD, LSU_SD:          if (alu_result[2:0] != 3'b000) is_misaligned = 1'b1; 
            default: is_misaligned = 1'b0; 
        endcase
    end

    assign load_misaligned  = is_misaligned && ex_mem_read;
    assign store_misaligned = is_misaligned && ex_mem_write;
    assign combined_illegal_instr = ex_illegal_instr || (ex_csr_we && !csr_valid);

    // -- Trap Unit --
    trap_unit u_trap (
        .is_ecall_i         (ex_is_ecall),
        .is_ebreak_i        (ex_is_ebreak),
        .is_mret_i          (ex_is_mret),
        .illegal_instr_i    (combined_illegal_instr),
        .load_misaligned_i  (load_misaligned),
        .store_misaligned_i (store_misaligned),
        .bad_addr_i         (alu_result),
        .curr_pc_i          (ex_pc),    
        .curr_instr_i       (ex_instr), 
        .mtvec_i            (mtvec_val),
        .mepc_i             (mepc_val),
        .trap_en_o          (trap_en),
        .mret_en_o          (mret_en),
        .trap_cause_o       (trap_cause),
        .trap_pc_o          (trap_pc),
        .trap_val_o         (trap_val),
        .trap_flush_o       (trap_flush),
        .pc_trap_val_o      (pc_trap_val)
    );

    // -- Final Execute Result Mux --
    // Priority: CSR > Multiplier > Standard ALU
    assign final_ex_result = (ex_csr_we && csr_valid) ? csr_rdata :
                             (ex_mul_op != M_NONE)    ? mul_result : 
                                                        alu_result;


    // ---------------------------------------------------------
    // PIPELINE REGISTER: EX -> MEM
    // ---------------------------------------------------------
    ex_mem_reg u_ex_mem (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall_i      (stall_ex_mem),
        .flush_i      (flush_ex_mem),
        .pc_i         (ex_pc),        
        .instr_i      (ex_instr),     
        .alu_result_i (final_ex_result),
        .store_data_i (alu_operand_b),
        .rd_addr_i    (ex_rd_addr),
        .reg_write_i  (ex_reg_write),
        .lsu_op_i     (ex_lsu_op),
        .mem_write_i  (ex_mem_write),
        .mem_read_i   (ex_mem_read),
        .mem_to_reg_i (ex_mem_to_reg),
        
        .pc_o         (mem_pc),    
        .instr_o      (mem_instr),  
        .alu_result_o (mem_alu_result),
        .store_data_o (mem_store_data),
        .rd_addr_o    (mem_rd_addr),
        .reg_write_o  (mem_reg_write),
        .lsu_op_o     (mem_lsu_op),
        .mem_write_o  (mem_mem_write),
        .mem_read_o   (mem_mem_read),
        .mem_to_reg_o (mem_mem_to_reg)
    );


    // ---------------------------------------------------------
    // STAGE 4: MEMORY (LSU)
    // ---------------------------------------------------------
    lsu u_lsu (
        .clk           (clk),    
        .rst_n         (rst_n),        
        .mem_read_i    (mem_mem_read),
        .mem_write_i   (mem_mem_write),
        .lsu_op_i      (mem_lsu_op),
        .addr_i        (mem_alu_result),
        .store_data_i  (mem_store_data),
        .dbus_req_o    (dbus_req_o),
        .dbus_we_o     (dbus_we_o),
        .dbus_addr_o   (dbus_addr_o),
        .dbus_wdata_o  (dbus_wdata_o),
        .dbus_be_o     (dbus_be_o),
        .dbus_gnt_i    (dbus_gnt_i),
        .dbus_rvalid_i (dbus_rvalid_i),
        .dbus_rdata_i  (dbus_rdata_i),
        .stall_lsu_o   (stall_lsu),
        .result_o      (lsu_final_data)
    );


    // ---------------------------------------------------------
    // PIPELINE REGISTER: MEM -> WB
    // ---------------------------------------------------------
    mem_wb_reg u_mem_wb (
        .clk          (clk),
        .rst_n        (rst_n), 
        .stall_i      (stall_mem_wb),
        .pc_i         (mem_pc),        
        .instr_i      (mem_instr),     
        .alu_result_i (mem_alu_result),
        .mem_data_i   (lsu_final_data),
        .rd_addr_i    (mem_rd_addr),
        .reg_write_i  (mem_reg_write),
        .mem_to_reg_i (mem_mem_to_reg),
        
        .pc_o         (wb_pc),      
        .instr_o      (wb_instr),     
        .alu_result_o (wb_alu_result),
        .mem_data_o   (wb_mem_data),
        .rd_addr_o    (wb_rd_addr),
        .reg_write_o  (wb_reg_write),
        .mem_to_reg_o (wb_mem_to_reg)
    );


    // ---------------------------------------------------------
    // STAGE 5: WRITEBACK
    // ---------------------------------------------------------
    assign wb_final_data = (wb_mem_to_reg) ? wb_mem_data : wb_alu_result;

    regfile u_regfile (
        .clk        (clk),
        .rst_n      (rst_n),
        .rs1_addr_i (dec_rs1),
        .rs1_data_o (reg_rs1_data),
        .rs2_addr_i (dec_rs2),
        .rs2_data_o (reg_rs2_data),
        .rd_addr_i  (wb_rd_addr),
        .rd_data_i  (wb_final_data),
        .rd_wen_i   (wb_reg_write)
    );

    tracer u_tracer (
        .clk         (clk),
        .valid_wb_i  (wb_reg_write), 
        .pc_i        (wb_pc),          
        .instr_i     (wb_instr),      
        .reg_write_i (wb_reg_write),
        .rd_addr_i   (wb_rd_addr),
        .rd_data_i   (wb_final_data)
    );

endmodule
