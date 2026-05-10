`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 05:55:57 PM
// Design Name: 
// Module Name: fifo
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


module fifo#(
        parameter DEPTH = 8
    )(
    input logic CLK, nRST, write_i, read_i,
    input logic signed [7:0] wdata_i,
    output logic signed [7:0] rdata_o,
    output logic empty_o, full_o
    );
    
    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    logic signed [7:0] mem [DEPTH-1:0];
    logic [ADDR_WIDTH-1:0] wptr, rptr;
    logic [ADDR_WIDTH:0] count;
    
    assign empty_o = (count == 0);
    assign full_o = (count == DEPTH);
    assign rdata_o = mem[rptr];
    
    always_ff @(posedge CLK) begin
        // write
        if (write_i && !full_o) begin
            mem[wptr] <= wdata_i;
        end
    end
    
    always_ff @(posedge CLK, negedge nRST) begin
        if (!nRST) begin
            wptr <= '0;
            rptr <= '0;
            count <= '0;
            
        end else begin
            // write
            if (write_i && !full_o) begin
                wptr <= wptr + 1;
            end
            // read
            if (read_i && !empty_o) begin
                rptr <= rptr + 1;
            end
            // update current count
            if (write_i && !full_o && !(read_i && !empty_o)) begin
                // write only
                count <= count + 1;
            end else if (read_i && !empty_o && !(write_i && !full_o)) begin
                // read only
                count <= count - 1;
            end else begin
                // both write and read            
                count <= count;
            end
            
        end
    end
    
    
    
endmodule
