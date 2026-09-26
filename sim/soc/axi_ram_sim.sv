module axi_ram_sim (
    input  logic        clk,
    input  logic        rst_n,

    // ============================================================
    // I-BUS AXI4-Lite Slave
    // ============================================================

    input  logic [63:0] axi_i_araddr,
    input  logic        axi_i_arvalid,
    output logic        axi_i_arready,

    output logic [31:0] axi_i_rdata,
    output logic [1:0]  axi_i_rresp,
    output logic        axi_i_rvalid,
    input  logic        axi_i_rready,

    // ============================================================
    // D-BUS AXI4-Lite Read Slave
    // ============================================================

    input  logic [63:0] axi_d_araddr,
    input  logic        axi_d_arvalid,
    output logic        axi_d_arready,

    output logic [63:0] axi_d_rdata,
    output logic [1:0]  axi_d_rresp,
    output logic        axi_d_rvalid,
    input  logic        axi_d_rready,

    // ============================================================
    // D-BUS AXI4-Lite Write Slave
    // ============================================================

    input  logic [63:0] axi_d_awaddr,
    input  logic        axi_d_awvalid,
    output logic        axi_d_awready,

    input  logic [63:0] axi_d_wdata,
    input  logic [7:0]  axi_d_wstrb,
    input  logic        axi_d_wvalid,
    output logic        axi_d_wready,

    output logic [1:0]  axi_d_bresp,
    output logic        axi_d_bvalid,
    input  logic        axi_d_bready
);

    // ============================================================
    // Memory
    // ============================================================

    logic [31:0] mem [0:262143];

    initial begin
        $readmemh("sw/program.hex", mem);
    end


    // ============================================================
    // Stress Configuration
    // ============================================================
    //
    // Normal mode:
    //     READY channels are immediately available.
    //     Responses are generated with the minimum registered delay.
    //
    // AXI_STRESS:
    //
    //     I-ARREADY : 1-cycle delay
    //     I-RVALID  : 2-cycle delay
    //
    //     D-ARREADY : 2-cycle delay
    //     D-RVALID  : 3-cycle delay
    //
    //     D-AWREADY : 1-cycle delay
    //     D-WREADY  : 3-cycle delay
    //     D-BVALID  : 2-cycle delay
    //
    // AW and W intentionally complete in different cycles.
    // ============================================================

`ifdef AXI_STRESS

    localparam int unsigned I_AR_DELAY = 1;
    localparam int unsigned I_R_DELAY  = 2;

    localparam int unsigned D_AR_DELAY = 2;
    localparam int unsigned D_R_DELAY  = 3;

    localparam int unsigned D_AW_DELAY = 1;
    localparam int unsigned D_W_DELAY  = 3;
    localparam int unsigned D_B_DELAY  = 2;

`else

    localparam int unsigned I_AR_DELAY = 0;
    localparam int unsigned I_R_DELAY  = 0;

    localparam int unsigned D_AR_DELAY = 0;
    localparam int unsigned D_R_DELAY  = 0;

    localparam int unsigned D_AW_DELAY = 0;
    localparam int unsigned D_W_DELAY  = 0;
    localparam int unsigned D_B_DELAY  = 0;

`endif


    // ============================================================
    // Response Codes
    // ============================================================

    assign axi_i_rresp = 2'b00;
    assign axi_d_rresp = 2'b00;
    assign axi_d_bresp = 2'b00;


    // ============================================================
    // I-BUS State
    // ============================================================

    logic        i_ar_waiting_q;
    logic [7:0]  i_ar_delay_q;

    logic        i_read_pending_q;
    logic [17:0] i_read_index_q;
    logic [7:0]  i_r_delay_q;


    // ============================================================
    // D-BUS Read State
    // ============================================================

    logic        d_ar_waiting_q;
    logic [7:0]  d_ar_delay_q;

    logic        d_read_pending_q;
    logic [17:0] d_read_index_q;
    logic [7:0]  d_r_delay_q;


    // ============================================================
    // D-BUS Write State
    // ============================================================

    logic       d_aw_waiting_q;
    logic [7:0] d_aw_delay_q;

    logic       d_w_waiting_q;
    logic [7:0] d_w_delay_q;

    logic       d_aw_captured_q;
    logic       d_w_captured_q;

    logic [17:0] d_write_index_q;
    logic [63:0] d_write_data_q;
    logic [7:0]  d_write_strb_q;

    logic       d_b_pending_q;
    logic [7:0] d_b_delay_q;


    // ============================================================
    // I-BUS AR Delay Generator
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            i_ar_waiting_q <= 1'b0;
            i_ar_delay_q   <= 8'b0;

        end else begin

            if (
                !i_ar_waiting_q &&
                !i_read_pending_q &&
                !axi_i_rvalid &&
                axi_i_arvalid
            ) begin

                i_ar_waiting_q <= 1'b1;
                i_ar_delay_q   <= I_AR_DELAY[7:0];

            end else if (i_ar_waiting_q) begin

                if (i_ar_delay_q != 0)
                    i_ar_delay_q <= i_ar_delay_q - 8'd1;

                if (
                    (i_ar_delay_q == 0) &&
                    axi_i_arvalid
                ) begin

                    i_ar_waiting_q <= 1'b0;
                end
            end
        end
    end


    assign axi_i_arready =
        i_ar_waiting_q &&
        (i_ar_delay_q == 0) &&
        !i_read_pending_q &&
        !axi_i_rvalid;


    // ============================================================
    // I-BUS Read Response
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            i_read_pending_q <= 1'b0;
            i_read_index_q   <= 18'b0;
            i_r_delay_q      <= 8'b0;

            axi_i_rvalid     <= 1'b0;
            axi_i_rdata      <= 32'b0;

        end else begin

            if (
                axi_i_rvalid &&
                axi_i_rready
            ) begin

                axi_i_rvalid <= 1'b0;
            end


            if (
                axi_i_arvalid &&
                axi_i_arready
            ) begin

                i_read_index_q <= axi_i_araddr[19:2];

                i_read_pending_q <= 1'b1;
                i_r_delay_q      <= I_R_DELAY[7:0];
            end


            if (i_read_pending_q) begin

                if (i_r_delay_q != 0) begin

                    i_r_delay_q <= i_r_delay_q - 8'd1;

                end else if (!axi_i_rvalid) begin

                    axi_i_rdata <= mem[i_read_index_q];

                    axi_i_rvalid <= 1'b1;

                    i_read_pending_q <= 1'b0;
                end
            end
        end
    end


    // ============================================================
    // D-BUS AR Delay Generator
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            d_ar_waiting_q <= 1'b0;
            d_ar_delay_q   <= 8'b0;

        end else begin

            if (
                !d_ar_waiting_q &&
                !d_read_pending_q &&
                !axi_d_rvalid &&
                axi_d_arvalid
            ) begin

                d_ar_waiting_q <= 1'b1;
                d_ar_delay_q   <= D_AR_DELAY[7:0];

            end else if (d_ar_waiting_q) begin

                if (d_ar_delay_q != 0)
                    d_ar_delay_q <= d_ar_delay_q - 8'd1;

                if (
                    (d_ar_delay_q == 0) &&
                    axi_d_arvalid
                ) begin

                    d_ar_waiting_q <= 1'b0;
                end
            end
        end
    end


    assign axi_d_arready =
        d_ar_waiting_q &&
        (d_ar_delay_q == 0) &&
        !d_read_pending_q &&
        !axi_d_rvalid;


    // ============================================================
    // D-BUS Read Response
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            d_read_pending_q <= 1'b0;
            d_read_index_q   <= 18'b0;
            d_r_delay_q      <= 8'b0;

            axi_d_rvalid     <= 1'b0;
            axi_d_rdata      <= 64'b0;

        end else begin

            if (
                axi_d_rvalid &&
                axi_d_rready
            ) begin

                axi_d_rvalid <= 1'b0;
            end


            if (
                axi_d_arvalid &&
                axi_d_arready
            ) begin

                d_read_index_q <= {
                    axi_d_araddr[19:3],
                    1'b0
                };

                d_read_pending_q <= 1'b1;
                d_r_delay_q      <= D_R_DELAY[7:0];
            end


            if (d_read_pending_q) begin

                if (d_r_delay_q != 0) begin

                    d_r_delay_q <= d_r_delay_q - 8'd1;

                end else if (!axi_d_rvalid) begin

                    axi_d_rdata <= {
                        mem[d_read_index_q + 18'd1],
                        mem[d_read_index_q]
                    };

                    axi_d_rvalid <= 1'b1;

                    d_read_pending_q <= 1'b0;
                end
            end
        end
    end


    // ============================================================
    // D-BUS AW Delay Generator
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            d_aw_waiting_q <= 1'b0;
            d_aw_delay_q   <= 8'b0;

        end else begin

            if (
                !d_aw_waiting_q &&
                !d_aw_captured_q &&
                !axi_d_bvalid &&
                !d_b_pending_q &&
                axi_d_awvalid
            ) begin

                d_aw_waiting_q <= 1'b1;
                d_aw_delay_q   <= D_AW_DELAY[7:0];

            end else if (d_aw_waiting_q) begin

                if (d_aw_delay_q != 0)
                    d_aw_delay_q <= d_aw_delay_q - 8'd1;

                if (
                    (d_aw_delay_q == 0) &&
                    axi_d_awvalid
                ) begin

                    d_aw_waiting_q <= 1'b0;
                end
            end
        end
    end


    assign axi_d_awready =
        d_aw_waiting_q &&
        (d_aw_delay_q == 0) &&
        !d_aw_captured_q &&
        !axi_d_bvalid &&
        !d_b_pending_q;


    // ============================================================
    // D-BUS W Delay Generator
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            d_w_waiting_q <= 1'b0;
            d_w_delay_q   <= 8'b0;

        end else begin

            if (
                !d_w_waiting_q &&
                !d_w_captured_q &&
                !axi_d_bvalid &&
                !d_b_pending_q &&
                axi_d_wvalid
            ) begin

                d_w_waiting_q <= 1'b1;
                d_w_delay_q   <= D_W_DELAY[7:0];

            end else if (d_w_waiting_q) begin

                if (d_w_delay_q != 0)
                    d_w_delay_q <= d_w_delay_q - 8'd1;

                if (
                    (d_w_delay_q == 0) &&
                    axi_d_wvalid
                ) begin

                    d_w_waiting_q <= 1'b0;
                end
            end
        end
    end


    assign axi_d_wready =
        d_w_waiting_q &&
        (d_w_delay_q == 0) &&
        !d_w_captured_q &&
        !axi_d_bvalid &&
        !d_b_pending_q;


    // ============================================================
    // D-BUS Write Capture
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            d_aw_captured_q <= 1'b0;
            d_w_captured_q  <= 1'b0;

            d_write_index_q <= 18'b0;
            d_write_data_q  <= 64'b0;
            d_write_strb_q  <= 8'b0;

            d_b_pending_q   <= 1'b0;
            d_b_delay_q     <= 8'b0;

            axi_d_bvalid    <= 1'b0;

        end else begin

            // ----------------------------------------------------
            // Consume B response
            // ----------------------------------------------------

            if (
                axi_d_bvalid &&
                axi_d_bready
            ) begin

                axi_d_bvalid <= 1'b0;
            end


            // ----------------------------------------------------
            // Capture AW
            // ----------------------------------------------------

            if (
                axi_d_awvalid &&
                axi_d_awready
            ) begin

                d_write_index_q <= {
                    axi_d_awaddr[19:3],
                    1'b0
                };

                d_aw_captured_q <= 1'b1;
            end


            // ----------------------------------------------------
            // Capture W
            // ----------------------------------------------------

            if (
                axi_d_wvalid &&
                axi_d_wready
            ) begin

                d_write_data_q <= axi_d_wdata;
                d_write_strb_q <= axi_d_wstrb;

                d_w_captured_q <= 1'b1;
            end


            // ----------------------------------------------------
            // Perform write once both channels are captured
            // ----------------------------------------------------

            if (
                d_aw_captured_q &&
                d_w_captured_q &&
                !d_b_pending_q &&
                !axi_d_bvalid
            ) begin

                if (d_write_strb_q[0])
                    mem[d_write_index_q][7:0]
                        <= d_write_data_q[7:0];

                if (d_write_strb_q[1])
                    mem[d_write_index_q][15:8]
                        <= d_write_data_q[15:8];

                if (d_write_strb_q[2])
                    mem[d_write_index_q][23:16]
                        <= d_write_data_q[23:16];

                if (d_write_strb_q[3])
                    mem[d_write_index_q][31:24]
                        <= d_write_data_q[31:24];


                if (d_write_strb_q[4])
                    mem[d_write_index_q + 18'd1][7:0]
                        <= d_write_data_q[39:32];

                if (d_write_strb_q[5])
                    mem[d_write_index_q + 18'd1][15:8]
                        <= d_write_data_q[47:40];

                if (d_write_strb_q[6])
                    mem[d_write_index_q + 18'd1][23:16]
                        <= d_write_data_q[55:48];

                if (d_write_strb_q[7])
                    mem[d_write_index_q + 18'd1][31:24]
                        <= d_write_data_q[63:56];


                d_aw_captured_q <= 1'b0;
                d_w_captured_q  <= 1'b0;

                d_b_pending_q <= 1'b1;
                d_b_delay_q   <= D_B_DELAY[7:0];
            end


            // ----------------------------------------------------
            // Delayed B response
            // ----------------------------------------------------

            if (d_b_pending_q) begin

                if (d_b_delay_q != 0) begin

                    d_b_delay_q <= d_b_delay_q - 8'd1;

                end else if (!axi_d_bvalid) begin

                    axi_d_bvalid <= 1'b1;
                    d_b_pending_q <= 1'b0;
                end
            end
        end
    end


    // ============================================================
    // Intentionally Ignored Address Bits
    // ============================================================

    /* verilator lint_off UNUSED */
    logic unused_address_bits;

    assign unused_address_bits = ^{
        axi_i_araddr[63:20],
        axi_i_araddr[1:0],

        axi_d_araddr[63:20],
        axi_d_araddr[2:0],

        axi_d_awaddr[63:20],
        axi_d_awaddr[2:0]
    };
    /* verilator lint_on UNUSED */

endmodule
