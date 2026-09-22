module axi_ram_sim (
    input  logic        clk,
    input  logic        rst_n,

    // I-Bus (Read Only)
    input  logic [63:0] axi_i_araddr,
    input  logic        axi_i_arvalid,
    output logic        axi_i_arready,
    output logic [31:0] axi_i_rdata,
    output logic [1:0]  axi_i_rresp,
    output logic        axi_i_rvalid,
    input  logic        axi_i_rready,

    // D-Bus (Read/Write)
    input  logic [63:0] axi_d_araddr,
    input  logic        axi_d_arvalid,
    output logic        axi_d_arready,
    output logic [63:0] axi_d_rdata,
    output logic [1:0]  axi_d_rresp,
    output logic        axi_d_rvalid,
    input  logic        axi_d_rready,

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

    // =========================================================
    // MEMORY ARRAY
    // =========================================================
    // 1MB RAM. We store it as 32-bit words because $readmemh expects it,
    // but we will access it logically as bytes to prevent alignment bugs.
    logic [31:0] mem [0:262143]; 

    initial begin
        $readmemh("sw/program.hex", mem);
    end

    // Helper logic to convert 64-bit addresses to 32-bit word indices
    logic [17:0] i_idx, d_rd_idx, d_wr_idx;
    assign i_idx    = axi_i_araddr[19:2];
    
    // For D-Bus, we mask off the bottom 3 bits to force 8-byte alignment
    assign d_rd_idx = {axi_d_araddr[19:3], 1'b0}; 
    assign d_wr_idx = {axi_d_awaddr[19:3], 1'b0};

    // =========================================================
    // I-BUS: READ LOGIC
    // =========================================================
    assign axi_i_arready = 1'b1;
    assign axi_i_rresp   = 2'b00;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) axi_i_rvalid <= 1'b0;
        else begin
            if (axi_i_arvalid && axi_i_arready) begin
                axi_i_rdata  <= mem[i_idx];
                axi_i_rvalid <= 1'b1;
            end else if (axi_i_rready) axi_i_rvalid <= 1'b0;
        end
    end

    // =========================================================
    // D-BUS: READ LOGIC
    // =========================================================
    assign axi_d_arready = 1'b1;
    assign axi_d_rresp   = 2'b00;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) axi_d_rvalid <= 1'b0;
        else begin
            if (axi_d_arvalid && axi_d_arready) begin
                // Fetch two consecutive 32-bit words to form the 64-bit return data
                axi_d_rdata  <= {mem[d_rd_idx + 1], mem[d_rd_idx]};
                axi_d_rvalid <= 1'b1;
            end else if (axi_d_rready) axi_d_rvalid <= 1'b0;
        end
    end

    // =========================================================
    // D-BUS: WRITE LOGIC
    // =========================================================
    assign axi_d_awready = 1'b1;
    assign axi_d_wready  = 1'b1;
    assign axi_d_bresp   = 2'b00;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) axi_d_bvalid <= 1'b0;
        else begin
            if (axi_d_awvalid && axi_d_wvalid) begin
                // Lower 32-bit word (Word 0)
                if (axi_d_wstrb[0]) mem[d_wr_idx][7:0]   <= axi_d_wdata[7:0];
                if (axi_d_wstrb[1]) mem[d_wr_idx][15:8]  <= axi_d_wdata[15:8];
                if (axi_d_wstrb[2]) mem[d_wr_idx][23:16] <= axi_d_wdata[23:16];
                if (axi_d_wstrb[3]) mem[d_wr_idx][31:24] <= axi_d_wdata[31:24];
                
                // Upper 32-bit word (Word 1)
                if (axi_d_wstrb[4]) mem[d_wr_idx + 1][7:0]   <= axi_d_wdata[39:32];
                if (axi_d_wstrb[5]) mem[d_wr_idx + 1][15:8]  <= axi_d_wdata[47:40];
                if (axi_d_wstrb[6]) mem[d_wr_idx + 1][23:16] <= axi_d_wdata[55:48];
                if (axi_d_wstrb[7]) mem[d_wr_idx + 1][31:24] <= axi_d_wdata[63:56];
                
                axi_d_bvalid <= 1'b1;
            end else if (axi_d_bready) axi_d_bvalid <= 1'b0;
        end
    end

    // =========================================================
    // UNUSED SIGNALS SINK
    // =========================================================
    /* verilator lint_off UNUSED */
    logic unused_addr_bits;
    assign unused_addr_bits = ^({
        axi_i_araddr[63:20], axi_i_araddr[1:0],
        axi_d_araddr[63:20], axi_d_araddr[2:0],
        axi_d_awaddr[63:20], axi_d_awaddr[2:0]
    });
    /* verilator lint_on UNUSED */

endmodule
