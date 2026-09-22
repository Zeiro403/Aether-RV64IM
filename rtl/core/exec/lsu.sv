module lsu 
    import riscv_pkg::*;
(
    input  logic        clk,   
    input  logic        rst_n, 

    // Pipeline Control Signals
    input  logic        mem_read_i,
    input  logic        mem_write_i,

    // Data Signals
    input  lsu_op_t     lsu_op_i,
    input  logic [63:0] addr_i,      
    input  logic [63:0] store_data_i,
    
    // D-Bus Signals
    output logic        dbus_req_o,
    output logic        dbus_we_o,    
    output logic [63:0] dbus_addr_o,
    output logic [63:0] dbus_wdata_o,
    output logic [7:0]  dbus_be_o,    
    input  logic        dbus_gnt_i,     
    input  logic        dbus_rvalid_i,  
    input  logic [63:0] dbus_rdata_i,   

    //Stall
    output logic        stall_lsu_o,

    // To Writeback
    output logic [63:0] result_o
);

    logic [2:0] addr_offset;

    assign dbus_addr_o = addr_i;
    assign addr_offset = addr_i[2:0];
    assign dbus_we_o   = mem_write_i; 

    // Handshake FSM
    typedef enum logic {
        IDLE,
        WAIT_RVALID
    } lsu_state_t;

    lsu_state_t state_q, state_n;
    logic is_mem_op;
    
    assign is_mem_op = mem_read_i || mem_write_i;

    always_comb begin
        state_n     = state_q;
        dbus_req_o  = 1'b0;
        stall_lsu_o = 1'b0;

        case (state_q)
            IDLE: begin
                if (is_mem_op) begin
                    dbus_req_o = 1'b1;
                    
                    // If memory doesn't instantly finish the transaction = stall
                    if (!dbus_gnt_i || !dbus_rvalid_i) begin
                        stall_lsu_o = 1'b1;
                        // If grant but no data yet = move to wait state
                        if (dbus_gnt_i) begin
                            state_n = WAIT_RVALID; 
                        end
                    end
                end
            end

            WAIT_RVALID: begin
                stall_lsu_o = 1'b1; // Keep pipeline frozen
                
                // Drop the request so we don't trigger a duplicate transaction
                dbus_req_o  = 1'b0; 
                
                if (dbus_rvalid_i) begin
                    stall_lsu_o = 1'b0; // Data arrived = Unfreeze pipeline
                    state_n     = IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state_q <= IDLE;
        else        state_q <= state_n;
    end
    
    // STORE ALIGNMENT
    always_comb begin
        dbus_wdata_o = store_data_i;
        dbus_be_o    = 8'b0;

        if (mem_write_i) begin
            case (lsu_op_i)
                LSU_SB: begin
                    dbus_wdata_o = store_data_i << {addr_offset, 3'b000};
                    dbus_be_o    = 8'b0000_0001 << addr_offset;
                end
                LSU_SH: begin
                    dbus_wdata_o = store_data_i << {addr_offset, 3'b000};
                    dbus_be_o    = 8'b0000_0011 << addr_offset;
                end
                LSU_SW: begin
                    dbus_wdata_o = store_data_i << {addr_offset, 3'b000};
                    dbus_be_o    = 8'b0000_1111 << addr_offset;
                end
                LSU_SD: begin
                    dbus_wdata_o = store_data_i;
                    dbus_be_o    = 8'b1111_1111;
                end
                default: dbus_be_o = 8'b0;
            endcase
        end
    end
    
    // LOAD ALIGNMENT & SIGN EXTENSION
    /* verilator lint_off UNUSED */
    logic [63:0] raw_shifted;
    /* verilator lint_on UNUSED */
    
    // Process the incoming data from the bus
    assign raw_shifted = dbus_rdata_i >> {addr_offset, 3'b000};

    always_comb begin
        result_o = 64'b0;
        if (mem_read_i) begin
            case (lsu_op_i)
                LSU_LB:  result_o = {{56{raw_shifted[7]}},  raw_shifted[7:0]};
                LSU_LBU: result_o = {56'b0,                 raw_shifted[7:0]};
                LSU_LH:  result_o = {{48{raw_shifted[15]}}, raw_shifted[15:0]};
                LSU_LHU: result_o = {48'b0,                 raw_shifted[15:0]};
                LSU_LW:  result_o = {{32{raw_shifted[31]}}, raw_shifted[31:0]};
                LSU_LWU: result_o = {32'b0,                 raw_shifted[31:0]};
                LSU_LD:  result_o = dbus_rdata_i;
                default: result_o = 64'b0;
            endcase
        end
    end
endmodule
