module imm_gen 
import riscv_pkg::*;
(
    input  logic [31:0] instr_i,
    output logic [63:0] imm_o
);

    opcode_t opcode;
    assign opcode = opcode_t'(instr_i[6:0]);

    always_comb begin : imm_gen
        imm_o = 64'b0; // default

        case (opcode)
            // I-Type immediates
            OP_IMM, OP_LOAD, OP_JALR, OP_IMM_32: begin
                imm_o = {{52{instr_i[31]}}, 
                        instr_i[31:20]};
            end

            //System immediates
            OP_SYSTEM: begin
                imm_o = {59'b0, instr_i[19:15]};
            end

            // S-Type immediates
            OP_STORE: begin
                imm_o = {{52{instr_i[31]}}, 
                        instr_i[31:25], 
                        instr_i[11:7]};
            end

            // B-Type immediates
            OP_BRANCH: begin
                imm_o = {{51{instr_i[31]}},
                        instr_i[31], instr_i[7],
                        instr_i[30:25], instr_i[11:8],
                        1'b0};
            end

            // J-Type immediates
            OP_JAL: begin
                imm_o = {{43{instr_i[31]}},
                        instr_i[31],
                        instr_i[19:12],
                        instr_i[20],
                        instr_i[30:21],
                        1'b0};
            end

            // U-Type immediates
            OP_LUI, OP_AUIPC: begin
                imm_o = {{32{instr_i[31]}}, 
                        instr_i[31:12], 12'b0};
            end

            // No immediate field instructions
            OP_REG, OP_REG_32, OP_FENCE: begin
                imm_o = 64'b0;
            end

            default: imm_o = 64'b0;
        endcase
    end

endmodule
