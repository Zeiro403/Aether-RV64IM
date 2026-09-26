module hazard_unit 
import riscv_pkg::*;
(
    // ============================================================
    // ID Stage
    // ============================================================

    input  logic       id_valid_i,
    input  logic       id_uses_rs1_i,
    input  logic       id_uses_rs2_i,
    input  logic [4:0] id_rs1_i,
    input  logic [4:0] id_rs2_i,

    // ============================================================
    // EX Stage
    // ============================================================

    input  logic       ex_valid_i,
    input  logic       ex_uses_rs1_i,
    input  logic       ex_uses_rs2_i,
    input  logic [4:0] ex_rs1_i,
    input  logic [4:0] ex_rs2_i,

    input  logic [4:0] ex_rd_i,
    input  logic       ex_reg_write_i,
    input  logic       ex_is_load_i,

    // 1 = EX instruction can advance toward MEM.
    input  logic       ex_ready_i,

    // ============================================================
    // MEM Stage
    // ============================================================

    input  logic       mem_valid_i,
    input  logic [4:0] mem_rd_i,
    input  logic       mem_reg_write_i,

    // 1 = value in MEM is currently safe to forward into EX.
    //
    // For a normal ALU instruction this will generally be 1.
    // For a load waiting for memory it will be 0 until the load
    // result is actually available.
    input  logic       mem_result_ready_i,

    // 1 = MEM instruction can advance toward WB.
    input  logic       mem_ready_i,

    // ============================================================
    // WB Stage
    // ============================================================

    input  logic       wb_valid_i,
    input  logic [4:0] wb_rd_i,
    input  logic       wb_reg_write_i,

    // ============================================================
    // Control-flow Recovery
    // ============================================================

    // Indicates that younger instructions currently in the
    // frontend / decode path must be discarded.
    //
    // Examples:
    //   - taken branch / jump in current implementation
    //   - branch misprediction later
    //   - other EX-stage redirect
    input  logic       redirect_i,

    // ============================================================
    // Forwarding Control
    // ============================================================

    output forward_sel_t forward_a_o,
    output forward_sel_t forward_b_o,

    // ============================================================
    // Pipeline Control
    // ============================================================

    // Hold the corresponding pipeline stage/register.
    output logic stall_if_o,
    output logic stall_id_o,
    output logic stall_ex_o,
    output logic stall_mem_o,

    // Invalidate / bubble the corresponding pipeline register.
    output logic flush_if_id_o,
    output logic flush_id_ex_o,
    output logic flush_ex_mem_o
);

    // ============================================================
    // Internal Hazard Signals
    // ============================================================

    logic load_use_hazard;

    logic id_rs1_dep_ex;
    logic id_rs2_dep_ex;

    logic ex_rs1_dep_mem;
    logic ex_rs1_dep_wb;

    logic ex_rs2_dep_mem;
    logic ex_rs2_dep_wb;

    logic ex_blocked;
    logic mem_blocked;


    // ============================================================
    // ID -> EX Dependency Detection
    // ============================================================
    //
    // The classic load-use hazard:
    //
    //      ld  x5, 0(x6)
    //      add x7, x5, x8
    //
    // The ADD cannot immediately enter EX because the load result
    // is not yet available at the time the ADD would require it.
    //
    // uses_rs1 / uses_rs2 prevent false dependencies for
    // instructions whose encoding contains those bit fields but
    // which do not architecturally read the corresponding register.
    // ============================================================

    always_comb begin
        id_rs1_dep_ex = 1'b0;
        id_rs2_dep_ex = 1'b0;

        if (id_valid_i &&
            ex_valid_i &&
            ex_reg_write_i &&
            (ex_rd_i != 5'd0)) begin

            id_rs1_dep_ex =
                id_uses_rs1_i &&
                (id_rs1_i == ex_rd_i);

            id_rs2_dep_ex =
                id_uses_rs2_i &&
                (id_rs2_i == ex_rd_i);
        end
    end


    always_comb begin
        load_use_hazard = 1'b0;

        if (ex_is_load_i &&
            (id_rs1_dep_ex || id_rs2_dep_ex)) begin

            load_use_hazard = 1'b1;
        end
    end


    // ============================================================
    // EX Operand Dependency Detection
    // ============================================================
    //
    // These signals determine whether an operand currently needed
    // by EX should come from:
    //
    //      1. MEM
    //      2. WB
    //      3. the value originally read from the register file
    //
    // MEM has priority over WB because MEM contains the younger
    // instruction and therefore the newer architectural value.
    // ============================================================

    always_comb begin
        ex_rs1_dep_mem = 1'b0;
        ex_rs1_dep_wb  = 1'b0;

        ex_rs2_dep_mem = 1'b0;
        ex_rs2_dep_wb  = 1'b0;

        // --------------------------------------------------------
        // RS1 dependencies
        // --------------------------------------------------------

        if (ex_valid_i && ex_uses_rs1_i) begin

            if (mem_valid_i &&
                mem_reg_write_i &&
                (mem_rd_i != 5'd0) &&
                (mem_rd_i == ex_rs1_i)) begin

                ex_rs1_dep_mem = 1'b1;
            end

            if (wb_valid_i &&
                wb_reg_write_i &&
                (wb_rd_i != 5'd0) &&
                (wb_rd_i == ex_rs1_i)) begin

                ex_rs1_dep_wb = 1'b1;
            end
        end


        // --------------------------------------------------------
        // RS2 dependencies
        // --------------------------------------------------------

        if (ex_valid_i && ex_uses_rs2_i) begin

            if (mem_valid_i &&
                mem_reg_write_i &&
                (mem_rd_i != 5'd0) &&
                (mem_rd_i == ex_rs2_i)) begin

                ex_rs2_dep_mem = 1'b1;
            end

            if (wb_valid_i &&
                wb_reg_write_i &&
                (wb_rd_i != 5'd0) &&
                (wb_rd_i == ex_rs2_i)) begin

                ex_rs2_dep_wb = 1'b1;
            end
        end
    end


    // ============================================================
    // Forwarding Selection
    // ============================================================
    //
    // Priority:
    //
    //      MEM > WB > Register File
    //
    // Example:
    //
    //      addi x5, x0, 1
    //      addi x5, x5, 1
    //      add  x6, x5, x7
    //
    // Both MEM and WB may appear to contain x5, but MEM contains
    // the newer value and must therefore win.
    //
    // A MEM value is only selected when mem_result_ready_i is high.
    // This prevents forwarding an incomplete load result.
    // ============================================================

    always_comb begin
        forward_a_o = FWD_REG;
        forward_b_o = FWD_REG;

        // --------------------------------------------------------
        // Operand A
        // --------------------------------------------------------

        if (ex_rs1_dep_mem && mem_result_ready_i) begin
            forward_a_o = FWD_MEM;

        end else if (ex_rs1_dep_wb) begin
            forward_a_o = FWD_WB;
        end


        // --------------------------------------------------------
        // Operand B
        // --------------------------------------------------------

        if (ex_rs2_dep_mem && mem_result_ready_i) begin
            forward_b_o = FWD_MEM;

        end else if (ex_rs2_dep_wb) begin
            forward_b_o = FWD_WB;
        end
    end


    // ============================================================
    // Generic Stage Backpressure
    // ============================================================
    //
    // The hazard unit deliberately does not know WHY a stage is
    // blocked.
    //
    // Examples:
    //
    // EX may become not-ready because of:
    //      - MUL/DIV
    //      - future FPU
    //      - another multi-cycle execution unit
    //
    // MEM may become not-ready because of:
    //      - LSU transaction
    //      - future D-cache miss
    //      - external memory latency
    //
    // This keeps pipeline control independent from the particular
    // implementation of those units.
    // ============================================================

    always_comb begin
        ex_blocked  = ex_valid_i  && !ex_ready_i;
        mem_blocked = mem_valid_i && !mem_ready_i;
    end


    // ============================================================
    // Pipeline Stall / Flush Control
    // ============================================================
    //
    // Priority conceptually:
    //
    //      redirect
    //          >
    //      MEM blocked
    //          >
    //      EX blocked
    //          >
    //      load-use hazard
    //          >
    //      normal flow
    //
    // STALL means:
    //      Hold the current contents of a stage.
    //
    // FLUSH means:
    //      Invalidate the contents / inject a bubble.
    //
    // These are deliberately separate concepts.
    // ============================================================

    always_comb begin

        // --------------------------------------------------------
        // Defaults: normal pipeline flow
        // --------------------------------------------------------

        stall_if_o  = 1'b0;
        stall_id_o  = 1'b0;
        stall_ex_o  = 1'b0;
        stall_mem_o = 1'b0;

        flush_if_id_o = 1'b0;
        flush_id_ex_o = 1'b0;
        flush_ex_mem_o = 1'b0;


        // --------------------------------------------------------
        // 1. Redirect
        // --------------------------------------------------------
        //
        // Redirect is assumed to originate from the EX stage.
        //
        // Instructions in IF and ID are younger than the redirecting
        // instruction and therefore belong to the wrong path.
        //
        // EX/MEM is NOT flushed here because the redirecting
        // instruction itself may still have an architectural effect,
        // e.g. JAL/JALR writing PC+4 into rd.
        // --------------------------------------------------------

        if (redirect_i) begin

            flush_if_id_o = 1'b1;
            flush_id_ex_o = 1'b1;

        end


        // --------------------------------------------------------
        // 2. MEM blocked
        // --------------------------------------------------------
        //
        // MEM cannot advance.
        //
        // Therefore EX must not overwrite EX/MEM, and everything
        // behind EX must also remain stationary.
        // --------------------------------------------------------

        else if (mem_blocked) begin

            stall_if_o  = 1'b1;
            stall_id_o  = 1'b1;
            stall_ex_o  = 1'b1;
            stall_mem_o = 1'b1;

        end


        // --------------------------------------------------------
        // 3. EX blocked
        // --------------------------------------------------------
        //
        // Current EX instruction cannot advance.
        //
        // Hold the frontend, ID, and EX instruction.
        // MEM is allowed to continue advancing.
        // --------------------------------------------------------

        else if (ex_blocked) begin

            stall_if_o = 1'b1;
            stall_id_o = 1'b1;
            stall_ex_o = 1'b1;

        end


        // --------------------------------------------------------
        // 4. Load-use dependency
        // --------------------------------------------------------
        //
        // Hold the instruction currently in Decode.
        //
        // Allow the load in EX to advance into MEM.
        //
        // Insert a bubble into ID/EX so the dependent instruction
        // does not enter EX too early.
        // --------------------------------------------------------

        else if (load_use_hazard) begin

            stall_if_o = 1'b1;
            stall_id_o = 1'b1;

            flush_id_ex_o = 1'b1;

        end
    end

endmodule
