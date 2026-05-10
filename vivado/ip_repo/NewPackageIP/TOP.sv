`timescale 1ns/1ps

// Compute-only accelerator top.
// BRAM loading/writeback is handled outside this module by accelerator_wrapper.
module TOP (
    input  logic CLK,
    input  logic nRst,

    input  logic start_compute,
    input  logic [3:0][31:0] matrix_A_input,
    input  logic [3:0][31:0] matrix_B_input,

    output logic [31:0] matrix_S_output,
    output logic        result_valid,
    output logic        accel_done
);

    // FSM -> team1_top
    logic                    write_enable;
    logic                    writing_a_values;
    logic                    compute_enable;
    logic signed [3:0][7:0]  ab_in;

    // team1_top -> FSM
    logic                    read_enable;
    logic signed [31:0]      c_out_value;

    FSM fsm_i (
        .CLK              (CLK),
        .nRst             (nRst),
        .go_sig           (start_compute),
        .matrix_A_input   (matrix_A_input),
        .matrix_B_input   (matrix_B_input),
        .matrix_S_output  (matrix_S_output),
        .read_enable      (read_enable),
        .c_out_value      (c_out_value),
        .write_enable     (write_enable),
        .writing_a_values (writing_a_values),
        .compute_enable   (compute_enable),
        .ab_in            (ab_in),
        .result_valid     (result_valid),
        .fsm_done         (accel_done)
    );

    team1_top systolic_i (
        .CLK              (CLK),
        .nRST             (nRst),
        .ab_in            (ab_in),
        .write_enable     (write_enable),
        .writing_a_values (writing_a_values),
        .compute_enable   (compute_enable),
        .read_enable      (read_enable),
        .c_out_value      (c_out_value)
    );

endmodule
