module soc_top (
    input  logic clk,
    input  logic rst_n,

    // =========================================================
    // Hardware Testbench Hooks
    // =========================================================

    output logic sim_exit_o,
    output logic sim_pass_o,

    // =========================================================
    // Performance Monitoring
    // =========================================================

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

    // =========================================================
    // AXI4-LITE BUS SIGNALS
    // =========================================================
    
    // Instruction Bus (I-Bus)
    logic [63:0] axi_i_araddr;
    logic [2:0]  axi_i_arprot;
    logic        axi_i_arvalid;
    logic        axi_i_arready;
    logic [31:0] axi_i_rdata;
    logic [1:0]  axi_i_rresp;
    logic        axi_i_rvalid;
    logic        axi_i_rready;

    // Data Bus (D-Bus) Read Channels
    logic [63:0] axi_d_araddr;
    logic [2:0]  axi_d_arprot;
    logic        axi_d_arvalid;
    logic        axi_d_arready;
    logic [63:0] axi_d_rdata;
    logic [1:0]  axi_d_rresp;
    logic        axi_d_rvalid;
    logic        axi_d_rready;

    // Data Bus (D-Bus) Write Channels
    logic [63:0] axi_d_awaddr;
    logic [2:0]  axi_d_awprot;
    logic        axi_d_awvalid;
    logic        axi_d_awready;
    logic [63:0] axi_d_wdata;
    logic [7:0]  axi_d_wstrb;
    logic        axi_d_wvalid;
    logic        axi_d_wready;
    logic [1:0]  axi_d_bresp;
    logic        axi_d_bvalid;
    logic        axi_d_bready;

    // =========================================================
    // HARDWARE SNOOP LOGIC (TEST EXIT DETECTOR)
    // =========================================================
    // We spy on the AXI Write Address and Write Data channels.
    // If the CPU tries to write to the magic exit address, we flag the testbench.
    assign sim_exit_o = (axi_d_awvalid && (axi_d_awaddr == 64'hF0000000));
    assign sim_pass_o = (axi_d_wdata[31:0] == 32'd1) || (axi_d_wdata[63:32] == 32'd1);
    // =========================================================
    // CPU INSTANTIATION (Master)
    // =========================================================
    core_axi_wrapper u_core_wrapper (
        .clk            (clk),
        .rst_n          (rst_n),
        
        // I-Bus
        .axi_i_araddr   (axi_i_araddr),
        .axi_i_arprot   (axi_i_arprot),
        .axi_i_arvalid  (axi_i_arvalid),
        .axi_i_arready  (axi_i_arready),
        .axi_i_rdata    (axi_i_rdata),
        .axi_i_rresp    (axi_i_rresp),
        .axi_i_rvalid   (axi_i_rvalid),
        .axi_i_rready   (axi_i_rready),
        
        // D-Bus
        .axi_d_araddr   (axi_d_araddr),
        .axi_d_arprot   (axi_d_arprot),
        .axi_d_arvalid  (axi_d_arvalid),
        .axi_d_arready  (axi_d_arready),
        .axi_d_rdata    (axi_d_rdata),
        .axi_d_rresp    (axi_d_rresp),
        .axi_d_rvalid   (axi_d_rvalid),
        .axi_d_rready   (axi_d_rready),
        .axi_d_awaddr   (axi_d_awaddr),
        .axi_d_awprot   (axi_d_awprot),
        .axi_d_awvalid  (axi_d_awvalid),
        .axi_d_awready  (axi_d_awready),
        .axi_d_wdata    (axi_d_wdata),
        .axi_d_wstrb    (axi_d_wstrb),
        .axi_d_wvalid   (axi_d_wvalid),
        .axi_d_wready   (axi_d_wready),
        .axi_d_bresp    (axi_d_bresp),
        .axi_d_bvalid   (axi_d_bvalid),
        .axi_d_bready   (axi_d_bready),
        // Performance
        .perf_cycles_o           (perf_cycles_o),
        .perf_instructions_o     (perf_instructions_o),

        .perf_branches_o         (perf_branches_o),
        .perf_branches_taken_o   (perf_branches_taken_o),
        .perf_redirects_o        (perf_redirects_o),

        .perf_loads_o            (perf_loads_o),
        .perf_stores_o           (perf_stores_o),
        .perf_muldiv_o           (perf_muldiv_o),

        .perf_ex_stall_cycles_o  (perf_ex_stall_cycles_o),
        .perf_mem_stall_cycles_o (perf_mem_stall_cycles_o)
    );

    // =========================================================
    // SIMULATION RAM INSTANTIATION (Slave)
    // =========================================================
    axi_ram_sim u_ram (
        .clk            (clk),
        .rst_n          (rst_n),
        
        // I-Bus (Notice we don't connect arprot to the RAM, it doesn't care)
        .axi_i_araddr   (axi_i_araddr),
        .axi_i_arvalid  (axi_i_arvalid),
        .axi_i_arready  (axi_i_arready),
        .axi_i_rdata    (axi_i_rdata),
        .axi_i_rresp    (axi_i_rresp),
        .axi_i_rvalid   (axi_i_rvalid),
        .axi_i_rready   (axi_i_rready),
        
        // D-Bus
        .axi_d_araddr   (axi_d_araddr),
        .axi_d_arvalid  (axi_d_arvalid),
        .axi_d_arready  (axi_d_arready),
        .axi_d_rdata    (axi_d_rdata),
        .axi_d_rresp    (axi_d_rresp),
        .axi_d_rvalid   (axi_d_rvalid),
        .axi_d_rready   (axi_d_rready),
        .axi_d_awaddr   (axi_d_awaddr),
        .axi_d_awvalid  (axi_d_awvalid),
        .axi_d_awready  (axi_d_awready),
        .axi_d_wdata    (axi_d_wdata),
        .axi_d_wstrb    (axi_d_wstrb),
        .axi_d_wvalid   (axi_d_wvalid),
        .axi_d_wready   (axi_d_wready),
        .axi_d_bresp    (axi_d_bresp),
        .axi_d_bvalid   (axi_d_bvalid),
        .axi_d_bready   (axi_d_bready)
    );


    // =========================================================
    // UNUSED SIGNALS SINK
    // =========================================================
    // The RAM simulator doesn't care about AXI security/protection bits.
    /* verilator lint_off UNUSED */
    logic [8:0] unused_prot;
    assign unused_prot = {axi_i_arprot, axi_d_arprot, axi_d_awprot};
    /* verilator lint_on UNUSED */

endmodule
