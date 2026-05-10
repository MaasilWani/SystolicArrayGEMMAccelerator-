`timescale 1ns/1ps

// Compute controller for Team 1's systolic array.
// This version has no BRAM knowledge. It consumes already-loaded
// packed A/B matrix words and streams them into team1_top.
module FSM(
    input  logic CLK,
    input  logic nRst,
    input  logic go_sig,

    input  logic [3:0][31:0] matrix_A_input,
    input  logic [3:0][31:0] matrix_B_input,
    output logic [31:0] matrix_S_output,

    // systolic array outputs (from team1_top)
    input  logic read_enable,
    input  logic signed [31:0] c_out_value,

    // systolic array inputs (to team1_top)
    output logic write_enable,
    output logic writing_a_values,
    output logic compute_enable,
    output logic signed [3:0][7:0] ab_in,

    // result stream / completion outputs
    output logic result_valid,
    output logic fsm_done
);

typedef enum logic [2:0] {
    IDLE,
    LOAD_A,
    LOAD_B,
    COMPUTE_NO_OUTPUT,
    COMPUTE_OUTPUT
} state_t;

state_t current_state, next_state;

logic [4:0] count, next_count;
logic [3:0][31:0] matrix_A_latched;
logic [3:0][31:0] matrix_B_latched;

always_ff @(posedge CLK or negedge nRst) begin
    if (!nRst) begin
        current_state    <= IDLE;
        count            <= 5'd0;
        matrix_A_latched <= '0;
        matrix_B_latched <= '0;
    end else begin
        current_state <= next_state;
        count         <= next_count;

        if (current_state == IDLE && go_sig) begin
            matrix_A_latched <= matrix_A_input;
            matrix_B_latched <= matrix_B_input;
        end
    end
end

always_comb begin
    next_state       = current_state;
    next_count       = count + 5'd1;

    writing_a_values = 1'b0;
    compute_enable   = 1'b0;
    write_enable     = 1'b0;
    matrix_S_output  = 32'd0;
    ab_in            = '0;
    result_valid     = 1'b0;
    fsm_done         = 1'b0;

    case (current_state)

    IDLE: begin
        next_count = 5'd0;
        if (go_sig) begin
            next_state = LOAD_A;
            next_count = 5'd0;
        end
    end

    LOAD_A: begin
        writing_a_values = 1'b1;
        write_enable     = 1'b1;
        ab_in            = matrix_A_latched[count[1:0]];

        if (count == 5'd3) begin
            next_state = LOAD_B;
            next_count = 5'd0;
        end
    end

    LOAD_B: begin
        writing_a_values = 1'b0;
        write_enable     = 1'b1;
        ab_in            = matrix_B_latched[count[1:0]];

        if (count == 5'd3) begin
            next_state = COMPUTE_NO_OUTPUT;
            next_count = 5'd0;
        end
    end

    COMPUTE_NO_OUTPUT: begin
        compute_enable = 1'b1;
        if (count == 5'd3) begin
            next_state = COMPUTE_OUTPUT;
            next_count = 5'd0;
        end
    end

    COMPUTE_OUTPUT: begin
        compute_enable = 1'b1;

        if (read_enable) begin
            matrix_S_output = c_out_value;
            result_valid    = 1'b1;
        end

        if (count == 5'd16) begin
            next_state = IDLE;
            next_count = 5'd0;
            fsm_done   = 1'b1;
        end
    end

    default: begin
        next_state = IDLE;
        next_count = 5'd0;
    end

    endcase
end

endmodule
