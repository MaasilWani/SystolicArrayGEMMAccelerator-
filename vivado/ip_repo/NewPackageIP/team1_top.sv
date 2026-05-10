`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 02:01:07 PM
// Design Name: 
// Module Name: team1_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module team1_top(
    input logic CLK,
    input logic nRST,
    input logic signed [3:0][7:0] ab_in, // max 32 bits input
    input logic write_enable,      // 1 while host is writing into FIFOs
    input logic writing_a_values,  // 1 when we are writing the values of A in the FIFOS
    input logic compute_enable,
    output logic read_enable,      // 1: c_out_value holds next matrix element (16 cycles from cycle==4)
    output logic signed [31:0] c_out_value
);

// FIFO SIGNALS
logic [3:0] write_A, read_A, empty_A, full_A;
logic signed [3:0][7:0] wdata_A, rdata_A;

logic [3:0] write_B, read_B, empty_B, full_B;
logic signed [3:0][7:0] wdata_B, rdata_B;

// SYSTOLIC ARRAY SIGNALS
logic enable_array;
logic signed [3:0][7:0] a_array;
logic signed [3:0][7:0] b_array;

// INTERNAL SIGNALS
logic [4:0] cycle; // timer to keep track of cycle for skew
logic signed [15:0][31:0] c_out;
(* keep = "true" *) logic [3:0] index_out;
logic prev_compute_enable;

genvar i;
generate
    for (i = 0; i < 4; i++) begin : GEN_FIFO
        fifo #(.DEPTH(4)) fifo_A (
            .CLK(CLK),
            .nRST(nRST),
            .write_i(write_A[i]),
            .read_i(read_A[i]),
            .wdata_i(wdata_A[i]),
            .rdata_o(rdata_A[i]),
            .empty_o(empty_A[i]),
            .full_o(full_A[i])
        );
        fifo #(.DEPTH(4)) fifo_B (
            .CLK(CLK),
            .nRST(nRST),
            .write_i(write_B[i]),
            .read_i(read_B[i]),
            .wdata_i(wdata_B[i]),
            .rdata_o(rdata_B[i]),
            .empty_o(empty_B[i]),
            .full_o(full_B[i])
        );
    end
endgenerate

// FILL UP FIFOs - 8 cycles
always_comb begin
    for (int i = 0; i < 4; i++) begin
        write_A[i] = 'b0;
        write_B[i] = 'b0;
        wdata_A[i] = 'b0;
        wdata_B[i] = 'b0;
    end
    
    if (write_enable) begin
        if (writing_a_values) begin
            for (int i = 0; i < 4; i++) begin
                write_A[i] = 1'b1;
                wdata_A[i] = ab_in[i]; 
            end
        end else begin
            for (int i = 0; i < 4; i++) begin
                write_B[i] = 1'b1;
                wdata_B[i] = ab_in[i]; 
            end
        end
    end
end

// COMPUTE - 10 cycles
always_ff @(posedge CLK, negedge nRST) begin
    if (!nRST) begin
        cycle <= '0;
    end else begin
        if (!compute_enable) begin
            cycle <= '0;
        end else begin
            cycle <= cycle + 1;
        end
    end
end

always_comb begin
    enable_array = 1'b0;

    read_A[0] = 1'b0; read_A[1] = 1'b0; read_A[2] = 1'b0; read_A[3] = 1'b0;
    read_B[0] = 1'b0; read_B[1] = 1'b0; read_B[2] = 1'b0; read_B[3] = 1'b0;
    a_array[0] = '0;  a_array[1] = '0;  a_array[2] = '0;  a_array[3] = '0;
    b_array[0] = '0;  b_array[1] = '0;  b_array[2] = '0;  b_array[3] = '0;

    if (compute_enable) begin
        enable_array = 1'b1;

        case (cycle)
            5'd1: begin
                if (!empty_A[0]) begin read_A[0] = 1'b1; a_array[0] = rdata_A[0]; end
                if (!empty_B[0]) begin read_B[0] = 1'b1; b_array[0] = rdata_B[0]; end
            end
            5'd2: begin
                if (!empty_A[0]) begin read_A[0] = 1'b1; a_array[0] = rdata_A[0]; end
                if (!empty_A[1]) begin read_A[1] = 1'b1; a_array[1] = rdata_A[1]; end
                if (!empty_B[0]) begin read_B[0] = 1'b1; b_array[0] = rdata_B[0]; end
                if (!empty_B[1]) begin read_B[1] = 1'b1; b_array[1] = rdata_B[1]; end
            end
            5'd3: begin
                if (!empty_A[0]) begin read_A[0] = 1'b1; a_array[0] = rdata_A[0]; end
                if (!empty_A[1]) begin read_A[1] = 1'b1; a_array[1] = rdata_A[1]; end
                if (!empty_A[2]) begin read_A[2] = 1'b1; a_array[2] = rdata_A[2]; end
                if (!empty_B[0]) begin read_B[0] = 1'b1; b_array[0] = rdata_B[0]; end
                if (!empty_B[1]) begin read_B[1] = 1'b1; b_array[1] = rdata_B[1]; end
                if (!empty_B[2]) begin read_B[2] = 1'b1; b_array[2] = rdata_B[2]; end
            end
            5'd4: begin
                if (!empty_A[0]) begin read_A[0] = 1'b1; a_array[0] = rdata_A[0]; end
                if (!empty_A[1]) begin read_A[1] = 1'b1; a_array[1] = rdata_A[1]; end
                if (!empty_A[2]) begin read_A[2] = 1'b1; a_array[2] = rdata_A[2]; end
                if (!empty_A[3]) begin read_A[3] = 1'b1; a_array[3] = rdata_A[3]; end
                if (!empty_B[0]) begin read_B[0] = 1'b1; b_array[0] = rdata_B[0]; end
                if (!empty_B[1]) begin read_B[1] = 1'b1; b_array[1] = rdata_B[1]; end
                if (!empty_B[2]) begin read_B[2] = 1'b1; b_array[2] = rdata_B[2]; end
                if (!empty_B[3]) begin read_B[3] = 1'b1; b_array[3] = rdata_B[3]; end
            end
            5'd5: begin
                if (!empty_A[1]) begin read_A[1] = 1'b1; a_array[1] = rdata_A[1]; end
                if (!empty_A[2]) begin read_A[2] = 1'b1; a_array[2] = rdata_A[2]; end
                if (!empty_A[3]) begin read_A[3] = 1'b1; a_array[3] = rdata_A[3]; end
                if (!empty_B[1]) begin read_B[1] = 1'b1; b_array[1] = rdata_B[1]; end
                if (!empty_B[2]) begin read_B[2] = 1'b1; b_array[2] = rdata_B[2]; end
                if (!empty_B[3]) begin read_B[3] = 1'b1; b_array[3] = rdata_B[3]; end
            end
            5'd6: begin
                if (!empty_A[2]) begin read_A[2] = 1'b1; a_array[2] = rdata_A[2]; end
                if (!empty_A[3]) begin read_A[3] = 1'b1; a_array[3] = rdata_A[3]; end
                if (!empty_B[2]) begin read_B[2] = 1'b1; b_array[2] = rdata_B[2]; end
                if (!empty_B[3]) begin read_B[3] = 1'b1; b_array[3] = rdata_B[3]; end
            end
            5'd7: begin
                if (!empty_A[3]) begin read_A[3] = 1'b1; a_array[3] = rdata_A[3]; end
                if (!empty_B[3]) begin read_B[3] = 1'b1; b_array[3] = rdata_B[3]; end
            end
            default: begin
                // all defaults already set above
            end
        endcase
    end
end

always_comb begin
    index_out = cycle - 5'd5;
    if (cycle >= 5'd5 && cycle <= 5'd20) begin
        c_out_value = c_out[index_out];
        read_enable = 1;
    end else begin
        c_out_value = 0;
        read_enable = 0;
    end
end

systolic_array sa (
    .CLK    (CLK),
    .nRST   (nRST),
    .enable_i (enable_array),
    .a_i   (a_array),
    .b_i   (b_array),
    .c_o  (c_out)
);
  

endmodule