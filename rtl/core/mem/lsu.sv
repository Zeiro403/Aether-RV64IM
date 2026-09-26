module lsu 
import riscv_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // ============================================================
    // MEM Stage Interface
    // ============================================================

    input  logic        start_i,
    input  lsu_op_t     op_i,
    input  logic [63:0] addr_i,
    input  logic [63:0] store_data_i,

    output logic        done_o,
    output logic [63:0] result_o,

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
    input  logic [63:0] dbus_rdata_i
);

    typedef enum logic [1:0] {
        LSU_IDLE,
        LSU_REQUEST,
        LSU_WAIT_RESP,
        LSU_DONE
    } lsu_state_t;

    lsu_state_t state_q;

    // ============================================================
    // Latched Transaction
    // ============================================================

    lsu_op_t     op_q;
    logic [63:0] addr_q;
    logic [63:0] store_data_q;

    logic [63:0] result_q;

    logic [2:0] addr_offset;

    assign addr_offset = addr_q[2:0];


    // ============================================================
    // Operation Classification
    // ============================================================

    logic op_is_load;
    logic op_is_store;

    assign op_is_load  = lsu_is_load(op_q);
    assign op_is_store = lsu_is_store(op_q);


    // ============================================================
    // Completion Interface
    // ============================================================

    assign done_o   = (state_q == LSU_DONE);
    assign result_o = result_q;


// ============================================================
// Bus Transaction Outputs
// ============================================================
//
// Request is asserted only until the bus accepts the transaction.
//
// Transaction attributes remain stable while waiting for the
// response. This is particularly important for dbus_we_o because
// the current AXI wrapper uses it to select R vs B response.
// ============================================================

always_comb begin

    dbus_req_o   = (state_q == LSU_REQUEST);

    dbus_we_o    = op_is_store;
    dbus_addr_o  = addr_q;

    dbus_wdata_o = store_data_q;
    dbus_be_o    = 8'b0;


    if (op_is_store) begin

        case (op_q)

            LSU_SB: begin
                dbus_wdata_o =
                    store_data_q <<
                    {addr_offset, 3'b000};

                dbus_be_o =
                    8'b0000_0001 << addr_offset;
            end


            LSU_SH: begin
                dbus_wdata_o =
                    store_data_q <<
                    {addr_offset, 3'b000};

                dbus_be_o =
                    8'b0000_0011 << addr_offset;
            end


            LSU_SW: begin
                dbus_wdata_o =
                    store_data_q <<
                    {addr_offset, 3'b000};

                dbus_be_o =
                    8'b0000_1111 << addr_offset;
            end


            LSU_SD: begin
                dbus_wdata_o = store_data_q;
                dbus_be_o    = 8'b1111_1111;
            end


            default: begin
                dbus_wdata_o = store_data_q;
                dbus_be_o    = 8'b0;
            end

        endcase
    end
end


    // ============================================================
    // Load Result Formatting
    // ============================================================
/* verilator lint_off UNUSEDSIGNAL */
    logic [63:0] shifted_rdata;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [63:0] formatted_load_data;

    assign shifted_rdata =
        dbus_rdata_i >> {addr_offset, 3'b000};

    always_comb begin

        formatted_load_data = 64'b0;

        case (op_q)

            LSU_LB:
                formatted_load_data =
                    {{56{shifted_rdata[7]}},
                     shifted_rdata[7:0]};

            LSU_LBU:
                formatted_load_data =
                    {56'b0, shifted_rdata[7:0]};

            LSU_LH:
                formatted_load_data =
                    {{48{shifted_rdata[15]}},
                     shifted_rdata[15:0]};

            LSU_LHU:
                formatted_load_data =
                    {48'b0, shifted_rdata[15:0]};

            LSU_LW:
                formatted_load_data =
                    {{32{shifted_rdata[31]}},
                     shifted_rdata[31:0]};

            LSU_LWU:
                formatted_load_data =
                    {32'b0, shifted_rdata[31:0]};

            LSU_LD:
                formatted_load_data =
                    dbus_rdata_i;

            default:
                formatted_load_data = 64'b0;

        endcase
    end


    // ============================================================
    // Transaction State
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state_q <= LSU_IDLE;

            op_q         <= LSU_NONE;
            addr_q       <= 64'b0;
            store_data_q <= 64'b0;

            result_q <= 64'b0;

        end else begin

            case (state_q)

                // ------------------------------------------------
                // Capture one memory operation.
                // ------------------------------------------------

                LSU_IDLE: begin

                    if (start_i) begin

                        op_q         <= op_i;
                        addr_q       <= addr_i;
                        store_data_q <= store_data_i;

                        state_q <= LSU_REQUEST;
                    end
                end


                // ------------------------------------------------
                // Hold the request until the bus accepts it.
                // ------------------------------------------------

                LSU_REQUEST: begin

                    if (dbus_gnt_i) begin

                        // Some simple memories may return rvalid
                        // in the same cycle as grant.
                        if (dbus_rvalid_i) begin

                            if (op_is_load)
                                result_q <= formatted_load_data;

                            state_q <= LSU_DONE;

                        end else begin

                            state_q <= LSU_WAIT_RESP;
                        end
                    end
                end


                // ------------------------------------------------
                // Accepted transaction; wait for completion.
                // ------------------------------------------------

                LSU_WAIT_RESP: begin

                    if (dbus_rvalid_i) begin

                        if (op_is_load)
                            result_q <= formatted_load_data;

                        state_q <= LSU_DONE;
                    end
                end


                // ------------------------------------------------
                // Completion visible for one cycle.
                // ------------------------------------------------

                LSU_DONE: begin
                    state_q <= LSU_IDLE;
                end


                default: begin
                    state_q <= LSU_IDLE;
                end

            endcase
        end
    end
endmodule
