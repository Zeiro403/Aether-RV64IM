module perf_counters (
    input logic clk,
    input logic rst_n,

    // Architectural retirement
    input logic retire_i,

    // Instruction events -- pulse exactly once per instruction
    input logic branch_i,
    input logic branch_taken_i,
    input logic load_i,
    input logic store_i,
    input logic muldiv_i,

    // Control-flow event
    input logic redirect_i,

    // Cycle events
    input logic ex_stall_i,
    input logic mem_stall_i,

    // Counters
    output logic [63:0] cycles_o,
    output logic [63:0] instructions_o,

    output logic [63:0] branches_o,
    output logic [63:0] branches_taken_o,
    output logic [63:0] redirects_o,

    output logic [63:0] loads_o,
    output logic [63:0] stores_o,
    output logic [63:0] muldiv_instructions_o,

    output logic [63:0] ex_stall_cycles_o,
    output logic [63:0] mem_stall_cycles_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycles_o              <= 64'b0;
            instructions_o        <= 64'b0;

            branches_o            <= 64'b0;
            branches_taken_o      <= 64'b0;
            redirects_o           <= 64'b0;

            loads_o               <= 64'b0;
            stores_o              <= 64'b0;
            muldiv_instructions_o <= 64'b0;

            ex_stall_cycles_o     <= 64'b0;
            mem_stall_cycles_o    <= 64'b0;

        end else begin
            cycles_o <= cycles_o + 64'd1;

            if (retire_i)
                instructions_o <= instructions_o + 64'd1;

            if (branch_i)
                branches_o <= branches_o + 64'd1;

            if (branch_taken_i)
                branches_taken_o <= branches_taken_o + 64'd1;

            if (redirect_i)
                redirects_o <= redirects_o + 64'd1;

            if (load_i)
                loads_o <= loads_o + 64'd1;

            if (store_i)
                stores_o <= stores_o + 64'd1;

            if (muldiv_i)
                muldiv_instructions_o <=
                    muldiv_instructions_o + 64'd1;

            if (ex_stall_i)
                ex_stall_cycles_o <= ex_stall_cycles_o + 64'd1;

            if (mem_stall_i)
                mem_stall_cycles_o <= mem_stall_cycles_o + 64'd1;
        end
    end

endmodule
