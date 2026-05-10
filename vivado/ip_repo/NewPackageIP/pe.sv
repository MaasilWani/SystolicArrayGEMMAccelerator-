`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 05:55:57 PM
// Design Name: 
// Module Name: pe
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


module pe(
    input logic CLK, nRST, enable,
    input logic signed [7:0] a_in, b_in,
    output logic signed [7:0] a_out, b_out,
    output logic signed [31:0] acc_out
    );
    
    logic signed [31:0] acc_reg;
    
    always_ff @(posedge CLK, negedge nRST) begin
        if (!nRST) begin
            a_out <= '0;
            b_out <= '0;
            acc_reg <= '0;
        end else begin
            // accumulate & propagate
            if (enable) begin
                a_out <= a_in;
                b_out <= b_in;
                acc_reg <= acc_reg + (a_in * b_in);
            end else begin
                a_out <= '0;
                b_out <= '0;
                acc_reg <= '0;
            end
        end
    end
    
    assign acc_out = acc_reg;
    
endmodule
