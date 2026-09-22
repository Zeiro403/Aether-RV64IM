module core_axi_wrapper (
    input  logic        clk,
    input  logic        rst_n,

    // ---------------------------------------------------------
    // I-BUS : Read-Only AXI4-Lite Master
    // ---------------------------------------------------------
    // Read Address Channel (AR)
    output logic [63:0] axi_i_araddr,
    output logic [2:0]  axi_i_arprot,
    output logic        axi_i_arvalid,
    input  logic        axi_i_arready,

    // Read Data Channel (R)
    input  logic [31:0] axi_i_rdata,
    input  logic [1:0]  axi_i_rresp,
    input  logic        axi_i_rvalid,
    output logic        axi_i_rready,

    // ---------------------------------------------------------
    // D-BUS : R/W AXI4-Lite Master
    // ---------------------------------------------------------
    // Read Address Channel (AR)
    output logic [63:0] axi_d_araddr,
    output logic [2:0]  axi_d_arprot,
    output logic        axi_d_arvalid,
    input  logic        axi_d_arready,
    
    // Read Data Channel (R)
    input  logic [63:0] axi_d_rdata,
    input  logic [1:0]  axi_d_rresp,
    input  logic        axi_d_rvalid,
    output logic        axi_d_rready,
    
    // Write Address Channel (AW)
    output logic [63:0] axi_d_awaddr,
    output logic [2:0]  axi_d_awprot,
    output logic        axi_d_awvalid,
    input  logic        axi_d_awready,
    
    // Write Data Channel (W)
    output logic [63:0] axi_d_wdata,
    output logic [7:0]  axi_d_wstrb,   
    output logic        axi_d_wvalid,
    input  logic        axi_d_wready,
    
    // Write Response Channel (B)
    input  logic [1:0]  axi_d_bresp,   
    input  logic        axi_d_bvalid,
    output logic        axi_d_bready
);

    // Internal Wires
    logic        ibus_req, ibus_gnt, ibus_rvalid;
    logic [63:0] ibus_addr;
    logic [31:0] ibus_rdata;

    logic        dbus_req, dbus_we, dbus_gnt, dbus_rvalid;
    logic [7:0]  dbus_be;
    logic [63:0] dbus_addr, dbus_wdata, dbus_rdata;

    // =========================================================
    // 1. INSTRUCTION BUS TRANSLATION (Read Only)
    // =========================================================
    
    assign axi_i_araddr  = ibus_addr;
    assign axi_i_arvalid = ibus_req;
    assign axi_i_arprot  = 3'b100; // Unprivileged, Secure, Instruction Access
    assign ibus_gnt      = axi_i_arready;

    assign axi_i_rready  = 1'b1;   // Master is always ready to accept instruction
    assign ibus_rvalid   = axi_i_rvalid;
    assign ibus_rdata    = axi_i_rdata;

    // =========================================================
    // 2. DATA BUS TRANSLATION (Read & Write)
    // =========================================================    
    
    // --- READ CHANNELS (AR / R) ---
    assign axi_d_arvalid = dbus_req & ~dbus_we;
    assign axi_d_araddr  = dbus_addr;
    assign axi_d_arprot  = 3'b000; // Unprivileged, Secure, Data Access
    assign axi_d_rready  = 1'b1;   // Core is always ready to accept data

    // --- WRITE CHANNELS (AW / W / B) ---
    assign axi_d_awvalid = dbus_req & dbus_we;
    assign axi_d_awaddr  = dbus_addr;
    assign axi_d_awprot  = 3'b000;
    
    assign axi_d_wvalid  = dbus_req & dbus_we; 
    assign axi_d_wdata   = dbus_wdata;
    assign axi_d_wstrb   = dbus_be;
    
    assign axi_d_bready  = 1'b1;   // Core is always ready to accept "Write Success" response
    
    // Grant: Only if slave sends ready signal to accept what we are sending
    assign dbus_gnt    = dbus_we ? (axi_d_awready & axi_d_wready) : axi_d_arready;
    
    // Valid: If Write, we wait for the 'B' (Response) channel. If Read, wait for the 'R' (Data) channel
    assign dbus_rvalid = dbus_we ? axi_d_bvalid : axi_d_rvalid;
    
    // Data is directly routed
    assign dbus_rdata  = axi_d_rdata;

    // =========================================================
    // CORE INSTANTIATION
    // =========================================================
    core_top u_core (
        .clk           (clk),
        .rst_n         (rst_n),
        .ibus_req_o    (ibus_req),
        .ibus_addr_o   (ibus_addr),
        .ibus_gnt_i    (ibus_gnt),   
        .ibus_rvalid_i (ibus_rvalid), 
        .ibus_rdata_i  (ibus_rdata),
        .dbus_req_o    (dbus_req),
        .dbus_we_o     (dbus_we),
        .dbus_be_o     (dbus_be),
        .dbus_addr_o   (dbus_addr),
        .dbus_wdata_o  (dbus_wdata),
        .dbus_gnt_i    (dbus_gnt),      
        .dbus_rvalid_i (dbus_rvalid),  
        .dbus_rdata_i  (dbus_rdata)
    );


    // =========================================================
    // UNUSED SIGNALS SINK
    // =========================================================
    /* verilator lint_off UNUSED */
    logic [1:0] unused_i_rresp;
    logic [1:0] unused_d_rresp;
    logic [1:0] unused_d_bresp;
    
    assign unused_i_rresp = axi_i_rresp;
    assign unused_d_rresp = axi_d_rresp;
    assign unused_d_bresp = axi_d_bresp;
    /* verilator lint_on UNUSED */

endmodule
