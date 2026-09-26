module fetch #(
    parameter logic [63:0] RESET_VECTOR = 64'h8000_0000
) (
    input  logic        clk,
    input  logic        rst_n,

    // Pipeline Connections
    output logic        valid_o,
    output logic [63:0] pc_o,
    output logic [31:0] instr_o,

    input  logic        ready_i,

    // Redirect fetching to a new PC.
    input  logic        redirect_valid_i,
    input  logic [63:0] redirect_pc_i,

    // Instruction Bus
    output logic        ibus_req_o,
    output logic [63:0] ibus_addr_o,
    input  logic        ibus_gnt_i,

    input  logic        ibus_rvalid_i,
    input  logic [31:0] ibus_rdata_i
);

    typedef enum logic [1:0] {
        FETCH_REQUEST,      // Requesting next instruction
        FETCH_WAIT_RESP,    // Request accepted; waiting for response
        FETCH_BUFFER,       // Instruction buffered for pipeline
        FETCH_DROP_RESP     // Waiting to discard stale response
    } fetch_state_t;

    fetch_state_t state_q;


    // Address of the next instruction that should be requested.
    logic [63:0] next_pc_q;

    // PC belonging to the currently outstanding bus request.
    logic [63:0] req_pc_q;

    // One-entry output buffer.
    logic [63:0] buffer_pc_q;
    logic [31:0] buffer_instr_q;

    always_comb begin : CONTROL

        // Defaults
        ibus_req_o  = 1'b0;
        ibus_addr_o = next_pc_q;

        valid_o = 1'b0;
        pc_o    = buffer_pc_q;
        instr_o = buffer_instr_q;

        case (state_q)

            FETCH_REQUEST: begin
                ibus_req_o  = 1'b1;
            end

            FETCH_WAIT_RESP: begin
                ibus_req_o = 1'b0;
            end

            FETCH_BUFFER: begin
                valid_o = 1'b1;
            end

            FETCH_DROP_RESP: begin
                ibus_req_o = 1'b0;
            end

            default: begin
                ibus_req_o = 1'b0;
                valid_o    = 1'b0;
            end

        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin : DATAPATH

        if (!rst_n) begin

            state_q        <= FETCH_REQUEST;

            next_pc_q      <= RESET_VECTOR;
            req_pc_q       <= RESET_VECTOR;

            buffer_pc_q    <= 64'b0;
            buffer_instr_q <= 32'b0;

        end else begin
            case (state_q)

                // REQUEST
                FETCH_REQUEST: begin

                    // redirect and grant arrive together
                    if (redirect_valid_i && ibus_gnt_i) begin
                        
                        next_pc_q <= redirect_pc_i;

                        state_q <= FETCH_DROP_RESP;

                    end

                    // redirect but no grant
                    else if (redirect_valid_i) begin

                        next_pc_q <= redirect_pc_i;

                        state_q <= FETCH_REQUEST;

                    end

                    // only grant
                    else if (ibus_gnt_i) begin

                        req_pc_q <= next_pc_q;
                        
                        next_pc_q <= next_pc_q + 64'd4;

                        state_q <= FETCH_WAIT_RESP;

                    end
                end

                // WAIT_RESP
                FETCH_WAIT_RESP: begin

                    // Redirect and response arrive together.
                    if (redirect_valid_i && ibus_rvalid_i) begin

                        next_pc_q <= redirect_pc_i;

                        state_q <= FETCH_REQUEST;

                    end

                    // Redirect while waiting for response.
                    else if (redirect_valid_i) begin

                        next_pc_q <= redirect_pc_i;

                        state_q <= FETCH_DROP_RESP;

                    end

                    // Normal instruction response
                    else if (ibus_rvalid_i) begin

                        buffer_pc_q    <= req_pc_q;
                        buffer_instr_q <= ibus_rdata_i;

                        state_q <= FETCH_BUFFER;

                    end
                end

                // BUFFER
                FETCH_BUFFER: begin

                    // Redirect has priority over downstream consume.
                    if (redirect_valid_i) begin

                        next_pc_q <= redirect_pc_i;

                        state_q <= FETCH_REQUEST;

                    end

                    // Pipeline consumes instruction.
                    else if (ready_i) begin

                        state_q <= FETCH_REQUEST;

                    end
                end

                // DROP_RESP
                FETCH_DROP_RESP: begin

                    // Always remember the newest redirect target.
                    if (redirect_valid_i) begin
                        next_pc_q <= redirect_pc_i;
                    end

                    // Do not buffer it. Simply discard the data.
                    if (ibus_rvalid_i) begin
                        state_q <= FETCH_REQUEST;
                    end
                end

                default: begin

                    state_q   <= FETCH_REQUEST;
                    next_pc_q <= RESET_VECTOR;

                end

            endcase
        end
    end

endmodule
