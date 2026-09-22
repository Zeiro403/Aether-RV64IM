module prefetch_buffer #(
    parameter DEPTH = 4
)(
    input  logic        clk,
    input  logic        rst_n,
    
    // Fetch/Core_top connections
    input  logic        flush_i,       // Clear FIFO and drop in-flight data
    input  logic [63:0] flush_addr_i,  // New PC to fetch after flush
    input  logic        ready_i,       // CPU is ready to accept the next instruction.

    output logic        valid_o,       // Buffer has at least one valid instruction
    output logic [31:0] instr_o,       // The instruction data
    output logic [63:0] pc_o,          // The PC associated with the instruction
    
    // I-BUS connections
    output logic        ibus_req_o,
    output logic [63:0] ibus_addr_o,

    input  logic        ibus_gnt_i,
    input  logic        ibus_rvalid_i,
    input  logic [31:0] ibus_rdata_i
);

    // -- FIFO Memory --
    logic [31:0] instr_fifo [DEPTH-1:0];
    logic [63:0] pc_fifo    [DEPTH-1:0];
    
    // Pointers and Count
    logic [$clog2(DEPTH)-1:0]   wr_ptr, rd_ptr;
    logic [$clog2(DEPTH+1)-1:0] fifo_count;
    
    // -- PC Trackers --
    logic [63:0] fetch_pc_q;    // Tracks the address we are requesting
    logic [63:0] response_pc_q; // Tracks the address of the incoming data
    
    // -- In-Flight Management --
    logic [3:0] outstanding_q;  // How many requests are currently in the bus?
    logic [3:0] drop_q;         // How many returning requests should be trashed?

    logic req_success;
    assign req_success = ibus_req_o && ibus_gnt_i;

    // ---------------------------------------------------------
    // 1. Bus Control & Overflow Prevention
    // ---------------------------------------------------------
    // Only send a request if the FIFO has guaranteed space for ALL in-flight transactions
    logic space_available;
    assign space_available = (fifo_count + outstanding_q) < DEPTH;
    
    assign ibus_req_o  = space_available && !flush_i;
    assign ibus_addr_o = fetch_pc_q;

    // ---------------------------------------------------------
    // 2. Drop Counter
    // ---------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outstanding_q <= '0;
            drop_q        <= '0;
        end else begin
            // Keep a count of transactions in the bus
            outstanding_q <= outstanding_q + {3'b0, req_success} - {3'b0, ibus_rvalid_i};
            
            if (flush_i) begin
                // When a branch occurs everything outstanding must be dropped.
                drop_q <= outstanding_q + {3'b0, req_success} - {3'b0, ibus_rvalid_i};
            end else if (ibus_rvalid_i && (drop_q > 0)) begin
                // Safely discard the stale data as it arrives
                drop_q <= drop_q - 1;
            end
        end
    end

    // 3. PC Tracking
    always_ff @(posedge clk or negedge rst_n) begin : pc_tracking
        if (!rst_n) begin
            fetch_pc_q    <= 64'h8000_0000;
            response_pc_q <= 64'h8000_0000;
        end else if (flush_i) begin
            fetch_pc_q    <= flush_addr_i;
            response_pc_q <= flush_addr_i;
        end else begin
            if (req_success) begin
                fetch_pc_q <= fetch_pc_q + 64'd4;
            end
            
            // Only increment when valid instruction accepted.
            if (ibus_rvalid_i && (drop_q == 0)) begin
                response_pc_q <= response_pc_q + 64'd4;
            end
        end
    end

    // ---------------------------------------------------------
    // 4. FIFO Read/Write Logic
    // ---------------------------------------------------------
    logic fifo_push, fifo_pop;
    assign fifo_push = ibus_rvalid_i && (drop_q == 0) && !flush_i;
    assign fifo_pop  = ready_i && valid_o && !flush_i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr     <= '0;
            rd_ptr     <= '0;
            fifo_count <= '0;
        end else if (flush_i) begin
            wr_ptr     <= '0;
            rd_ptr     <= '0;
            fifo_count <= '0;
        end else begin
            // Count logic
            if (fifo_push && !fifo_pop)
                fifo_count <= fifo_count + 1;
            else if (!fifo_push && fifo_pop)
                fifo_count <= fifo_count - 1;
                
            // Write logic
            if (fifo_push) begin
                instr_fifo[wr_ptr] <= ibus_rdata_i;
                pc_fifo[wr_ptr]    <= response_pc_q;
                wr_ptr             <= wr_ptr + 1;
            end
            
            // Read logic
            if (fifo_pop) begin
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

    // ---------------------------------------------------------
    // 5. Outputs
    // ---------------------------------------------------------
    assign valid_o = (fifo_count > 0);
    assign instr_o = instr_fifo[rd_ptr];
    assign pc_o    = pc_fifo[rd_ptr];

endmodule
