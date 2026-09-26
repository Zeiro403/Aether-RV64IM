module alu 
import riscv_pkg::*;
(
    input  alu_op_t     alu_op_i,
    input  logic [63:0] op_a_i,
    input  logic [63:0] op_b_i,
    output logic [63:0] result_o
);

    logic [31:0] temp_result;

    always_comb begin
        temp_result = '0;
        result_o = '0;
        case (alu_op_i)
            // Arithmetic
            ALU_ADD:  result_o = op_a_i + op_b_i;
            ALU_SUB:  result_o = op_a_i - op_b_i;
            ALU_ADDW: begin
                temp_result = op_a_i[31:0] + op_b_i[31:0];
                result_o = {{32{temp_result[31]}}, temp_result};

            end
            ALU_SUBW: begin 
                temp_result = op_a_i[31:0] - op_b_i[31:0];
                result_o = {{32{temp_result[31]}}, temp_result};
            end
            
            // Logical
            ALU_AND:  result_o = op_a_i & op_b_i;
            ALU_OR:   result_o = op_a_i | op_b_i;
            ALU_XOR:  result_o = op_a_i ^ op_b_i;
            
            // Comparisons
            ALU_SLT:  result_o = ($signed(op_a_i) < $signed(op_b_i)) ? 64'd1 : 64'd0;
            ALU_SLTU: result_o = (op_a_i < op_b_i) ? 64'd1 : 64'd0;
            
            // Shifts
            ALU_SLL:  result_o = op_a_i << op_b_i[5:0];
            ALU_SRL:  result_o = op_a_i >> op_b_i[5:0];
            ALU_SRA:  result_o = $signed(op_a_i) >>> op_b_i[5:0];
            ALU_SLLW: begin
                temp_result = op_a_i[31:0] << op_b_i[4:0];
                result_o = {{32{temp_result[31]}}, temp_result};
            end
            ALU_SRLW: begin
                temp_result = op_a_i[31:0] >> op_b_i[4:0];
                result_o = {{32{temp_result[31]}}, temp_result};
            end
            ALU_SRAW: begin
                temp_result = $signed(op_a_i[31:0]) >>> op_b_i[4:0];
                result_o = {{32{temp_result[31]}}, temp_result};
            end
            
            default:  result_o = '0;
        endcase
    end

endmodule
