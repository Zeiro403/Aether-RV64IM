module core_axi_wrapper (
    input  logic        clk,
    input  logic        rst_n,

    // ============================================================
    // I-BUS AXI4-Lite Read Master
    // ============================================================

    output logic [63:0] axi_i_araddr,
    output logic [2:0]  axi_i_arprot,
    output logic        axi_i_arvalid,
    input  logic        axi_i_arready,

    input  logic [31:0] axi_i_rdata,
    input  logic [1:0]  axi_i_rresp,
    input  logic        axi_i_rvalid,
    output logic        axi_i_rready,

    // ============================================================
    // D-BUS AXI4-Lite Read Master
    // ============================================================

    output logic [63:0] axi_d_araddr,
    output logic [2:0]  axi_d_arprot,
    output logic        axi_d_arvalid,
    input  logic        axi_d_arready,

    input  logic [63:0] axi_d_rdata,
    input  logic [1:0]  axi_d_rresp,
    input  logic        axi_d_rvalid,
    output logic        axi_d_rready,

    // ============================================================
    // D-BUS AXI4-Lite Write Master
    // ============================================================

    output logic [63:0] axi_d_awaddr,
    output logic [2:0]  axi_d_awprot,
    output logic        axi_d_awvalid,
    input  logic        axi_d_awready,

    output logic [63:0] axi_d_wdata,
    output logic [7:0]  axi_d_wstrb,
    output logic        axi_d_wvalid,
    input  logic        axi_d_wready,

    input  logic [1:0]  axi_d_bresp,
    input  logic        axi_d_bvalid,
    output logic        axi_d_bready,

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

    // ============================================================
    // Core-native bus signals
    // ============================================================

    logic        ibus_req;
    logic        ibus_gnt;
    logic        ibus_rvalid;
    logic [63:0] ibus_addr;
    logic [31:0] ibus_rdata;

    logic        dbus_req;
    logic        dbus_we;
    logic        dbus_gnt;
    logic        dbus_rvalid;
    logic [7:0]  dbus_be;
    logic [63:0] dbus_addr;
    logic [63:0] dbus_wdata;
    logic [63:0] dbus_rdata;


    // ============================================================
    // I-BUS AXI state
    // ============================================================

    typedef enum logic [1:0] {
        I_IDLE,
        I_SEND_AR,
        I_WAIT_R
    } ibus_state_t;

    ibus_state_t i_state_q;

    logic [63:0] i_addr_q;


    // ============================================================
    // D-BUS AXI state
    // ============================================================

    typedef enum logic [2:0] {
        D_IDLE,
        D_SEND_AR,
        D_WAIT_R,
        D_SEND_WRITE,
        D_WAIT_B
    } dbus_state_t;

    dbus_state_t d_state_q;

    logic [63:0] d_addr_q;
    logic [63:0] d_wdata_q;
    logic [7:0]  d_be_q;

    // Write address and data channels handshake independently.
    logic d_aw_done_q;
    logic d_w_done_q;


    // ============================================================
    // I-BUS outputs
    // ============================================================

    assign axi_i_araddr  = i_addr_q;
    assign axi_i_arprot  = 3'b100;
    assign axi_i_arvalid = (i_state_q == I_SEND_AR);

    // Once the address has been accepted, the wrapper is always
    // ready to consume the corresponding instruction response.
    assign axi_i_rready =
        (i_state_q == I_WAIT_R);

    assign ibus_rdata = axi_i_rdata;


    // ============================================================
    // D-BUS outputs
    // ============================================================

    assign axi_d_araddr  = d_addr_q;
    assign axi_d_arprot  = 3'b000;
    assign axi_d_arvalid = (d_state_q == D_SEND_AR);

    assign axi_d_rready =
        (d_state_q == D_WAIT_R);


    assign axi_d_awaddr = d_addr_q;
    assign axi_d_awprot = 3'b000;

    assign axi_d_awvalid =
        (d_state_q == D_SEND_WRITE) &&
        !d_aw_done_q;


    assign axi_d_wdata = d_wdata_q;
    assign axi_d_wstrb = d_be_q;

    assign axi_d_wvalid =
        (d_state_q == D_SEND_WRITE) &&
        !d_w_done_q;


    assign axi_d_bready =
        (d_state_q == D_WAIT_B);

    assign dbus_rdata = axi_d_rdata;


    // ============================================================
    // Core-side response pulses
    // ============================================================

    assign ibus_rvalid =
        (i_state_q == I_WAIT_R) &&
        axi_i_rvalid;

    assign dbus_rvalid =
        (
            (d_state_q == D_WAIT_R) &&
            axi_d_rvalid
        ) ||
        (
            (d_state_q == D_WAIT_B) &&
            axi_d_bvalid
        );


    // ============================================================
    // Core-side request acceptance
    // ============================================================
    //
    // The native core interface presents a request and waits for
    // gnt before considering that request accepted.
    //
    // We accept/latch a new request whenever the corresponding
    // wrapper FSM is idle.
    // ============================================================

    assign ibus_gnt =
        (i_state_q == I_IDLE) &&
        ibus_req;

    assign dbus_gnt =
        (d_state_q == D_IDLE) &&
        dbus_req;


    // ============================================================
    // I-BUS transaction FSM
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            i_state_q <= I_IDLE;
            i_addr_q  <= 64'b0;

        end else begin

            case (i_state_q)

                // ------------------------------------------------
                // Capture core request.
                // ------------------------------------------------

                I_IDLE: begin

                    if (ibus_req) begin

                        i_addr_q  <= ibus_addr;
                        i_state_q <= I_SEND_AR;
                    end
                end


                // ------------------------------------------------
                // Hold ARVALID/address until slave accepts it.
                // ------------------------------------------------

                I_SEND_AR: begin

                    if (axi_i_arready) begin
                        i_state_q <= I_WAIT_R;
                    end
                end


                // ------------------------------------------------
                // Wait for instruction data.
                // ------------------------------------------------

                I_WAIT_R: begin

                    if (axi_i_rvalid) begin
                        i_state_q <= I_IDLE;
                    end
                end


                default: begin

                    i_state_q <= I_IDLE;
                end

            endcase
        end
    end


    // ============================================================
    // D-BUS transaction FSM
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            d_state_q   <= D_IDLE;

            d_addr_q    <= 64'b0;
            d_wdata_q   <= 64'b0;
            d_be_q      <= 8'b0;

            d_aw_done_q <= 1'b0;
            d_w_done_q  <= 1'b0;

        end else begin

            case (d_state_q)

                // ------------------------------------------------
                // Capture one core data request.
                // ------------------------------------------------

                D_IDLE: begin

                    d_aw_done_q <= 1'b0;
                    d_w_done_q  <= 1'b0;

                    if (dbus_req) begin

                        d_addr_q  <= dbus_addr;
                        d_wdata_q <= dbus_wdata;
                        d_be_q    <= dbus_be;

                        if (dbus_we)
                            d_state_q <= D_SEND_WRITE;
                        else
                            d_state_q <= D_SEND_AR;
                    end
                end


                // ------------------------------------------------
                // Read address channel.
                // ------------------------------------------------

                D_SEND_AR: begin

                    if (axi_d_arready) begin
                        d_state_q <= D_WAIT_R;
                    end
                end


                // ------------------------------------------------
                // Read response channel.
                // ------------------------------------------------

                D_WAIT_R: begin

                    if (axi_d_rvalid) begin
                        d_state_q <= D_IDLE;
                    end
                end


                // ------------------------------------------------
                // Write address/data channels.
                //
                // AXI allows AW and W to handshake in different
                // cycles. Track each channel independently.
                // ------------------------------------------------

                D_SEND_WRITE: begin

                    if (
                        !d_aw_done_q &&
                        axi_d_awready
                    ) begin
                        d_aw_done_q <= 1'b1;
                    end


                    if (
                        !d_w_done_q &&
                        axi_d_wready
                    ) begin
                        d_w_done_q <= 1'b1;
                    end


                    // Both channels may complete in this cycle, or
                    // one may have completed in an earlier cycle.
                    if (
                        (d_aw_done_q || axi_d_awready) &&
                        (d_w_done_q  || axi_d_wready)
                    ) begin

                        d_state_q <= D_WAIT_B;
                    end
                end


                // ------------------------------------------------
                // Write response.
                // ------------------------------------------------

                D_WAIT_B: begin

                    if (axi_d_bvalid) begin
                        d_state_q <= D_IDLE;
                    end
                end


                default: begin

                    d_state_q <= D_IDLE;

                    d_aw_done_q <= 1'b0;
                    d_w_done_q  <= 1'b0;
                end

            endcase
        end
    end


    // ============================================================
    // Core
    // ============================================================

    core_top u_core (
        .clk                      (clk),
        .rst_n                    (rst_n),

        // Instruction bus
        .ibus_req_o               (ibus_req),
        .ibus_addr_o              (ibus_addr),
        .ibus_gnt_i               (ibus_gnt),
        .ibus_rvalid_i            (ibus_rvalid),
        .ibus_rdata_i             (ibus_rdata),

        // Data bus
        .dbus_req_o               (dbus_req),
        .dbus_we_o                (dbus_we),
        .dbus_be_o                (dbus_be),
        .dbus_addr_o              (dbus_addr),
        .dbus_wdata_o             (dbus_wdata),
        .dbus_gnt_i               (dbus_gnt),
        .dbus_rvalid_i            (dbus_rvalid),
        .dbus_rdata_i             (dbus_rdata),

        // Performance monitoring
        .perf_cycles_o            (perf_cycles_o),
        .perf_instructions_o      (perf_instructions_o),

        .perf_branches_o          (perf_branches_o),
        .perf_branches_taken_o    (perf_branches_taken_o),
        .perf_redirects_o         (perf_redirects_o),

        .perf_loads_o             (perf_loads_o),
        .perf_stores_o            (perf_stores_o),
        .perf_muldiv_o            (perf_muldiv_o),

        .perf_ex_stall_cycles_o   (perf_ex_stall_cycles_o),
        .perf_mem_stall_cycles_o  (perf_mem_stall_cycles_o)
    );


    // ============================================================
    // AXI response status
    // ============================================================
    //
    // Aether currently has no architectural bus-fault exception.
    // Response codes are therefore intentionally observed only as
    // unused status.
    // ============================================================

    /* verilator lint_off UNUSED */
    logic [5:0] unused_axi_resp;

    assign unused_axi_resp = {
        axi_i_rresp,
        axi_d_rresp,
        axi_d_bresp
    };
    /* verilator lint_on UNUSED */

endmodule
