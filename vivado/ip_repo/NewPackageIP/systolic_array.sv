`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 05:55:57 PM
// Design Name: 
// Module Name: systolic_array
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


`timescale 1ns / 1ps
module systolic_array(
    input  logic CLK,
    input  logic nRST,
    input  logic enable_i,
    input  logic signed [3:0][7:0] a_i,
    input  logic signed [3:0][7:0] b_i,
    output logic signed [15:0][31:0] c_o
);

    logic signed [7:0] a_bus [3:0][3:0];
    logic signed [7:0] b_bus [3:0][3:0];

    // Row 0
     pe pe_00 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_i[0]),      .b_in(b_i[0]),      .a_out(a_bus[0][0]), .b_out(b_bus[0][0]), .acc_out(c_o[0]));
     pe pe_01 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[0][0]), .b_in(b_i[1]),      .a_out(a_bus[0][1]), .b_out(b_bus[0][1]), .acc_out(c_o[1]));
     pe pe_02 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[0][1]), .b_in(b_i[2]),      .a_out(a_bus[0][2]), .b_out(b_bus[0][2]), .acc_out(c_o[2]));
     pe pe_03 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[0][2]), .b_in(b_i[3]),      .a_out(a_bus[0][3]), .b_out(b_bus[0][3]), .acc_out(c_o[3]));

    // Row 1
     pe pe_10 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_i[1]),      .b_in(b_bus[0][0]), .a_out(a_bus[1][0]), .b_out(b_bus[1][0]), .acc_out(c_o[4]));
     pe pe_11 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[1][0]), .b_in(b_bus[0][1]), .a_out(a_bus[1][1]), .b_out(b_bus[1][1]), .acc_out(c_o[5]));
     pe pe_12 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[1][1]), .b_in(b_bus[0][2]), .a_out(a_bus[1][2]), .b_out(b_bus[1][2]), .acc_out(c_o[6]));
     pe pe_13 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[1][2]), .b_in(b_bus[0][3]), .a_out(a_bus[1][3]), .b_out(b_bus[1][3]), .acc_out(c_o[7]));

    // Row 2
     pe pe_20 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_i[2]),      .b_in(b_bus[1][0]), .a_out(a_bus[2][0]), .b_out(b_bus[2][0]), .acc_out(c_o[8]));
     pe pe_21 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[2][0]), .b_in(b_bus[1][1]), .a_out(a_bus[2][1]), .b_out(b_bus[2][1]), .acc_out(c_o[9]));
     pe pe_22 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[2][1]), .b_in(b_bus[1][2]), .a_out(a_bus[2][2]), .b_out(b_bus[2][2]), .acc_out(c_o[10]));
     pe pe_23 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[2][2]), .b_in(b_bus[1][3]), .a_out(a_bus[2][3]), .b_out(b_bus[2][3]), .acc_out(c_o[11]));

    // Row 3
     pe pe_30 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_i[3]),      .b_in(b_bus[2][0]), .a_out(a_bus[3][0]), .b_out(b_bus[3][0]), .acc_out(c_o[12]));
     pe pe_31 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[3][0]), .b_in(b_bus[2][1]), .a_out(a_bus[3][1]), .b_out(b_bus[3][1]), .acc_out(c_o[13]));
     pe pe_32 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[3][1]), .b_in(b_bus[2][2]), .a_out(a_bus[3][2]), .b_out(b_bus[3][2]), .acc_out(c_o[14]));
     pe pe_33 (.CLK(CLK), .nRST(nRST), .enable(enable_i), .a_in(a_bus[3][2]), .b_in(b_bus[2][3]), .a_out(a_bus[3][3]), .b_out(b_bus[3][3]), .acc_out(c_o[15]));

endmodule