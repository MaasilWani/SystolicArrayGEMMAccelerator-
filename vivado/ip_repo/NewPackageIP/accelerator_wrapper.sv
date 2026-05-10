`timescale 1ns/1ps

// Drop-in replacement for the dummy PE slot.
// Responsibilities:
//   1. Read four 32-bit packed words for A from src_a_addr + 0,4,8,12.
//   2. Read four 32-bit packed words for B from src_b_addr + 0,4,8,12.
//   3. Start the compute-only TOP.
//   4. Capture up to 16 streamed 32-bit outputs.
//   5. Write 16 result words to dst_addr + 4*i.
//
// Address convention: src_a_addr/src_b_addr/dst_addr are byte offsets into the
// shared external BRAM, matching the MicroBlaze Xil_In32/Xil_Out32 convention.
module accelerator_wrapper (
    input  logic clk,
    input  logic resetn,

    // MicroBlaze control interface
    input  logic go,
    input  logic [31:0] src_a_addr,
    input  logic [31:0] src_b_addr,
    input  logic [31:0] dst_addr,
    output logic ack,
    output logic busy,
    output logic done,

    // BRAM Port B, 32-bit
    output logic [31:0] addrb,
    output logic        clkb,
    output logic [31:0] dinb,
    input  logic [31:0] doutb,
    output logic        enb,
    output logic        rstb,
    output logic [3:0]  web,

    // debug / simple status output
    output logic [31:0] test_op_v4
);

    assign clkb = clk;
    assign rstb = ~resetn;

    typedef enum logic [4:0] {
        S_IDLE,
        S_ACK,

        S_READ_A,
        S_WAIT_A,
        S_LATCH_A,

        S_READ_B,
        S_WAIT_B,
        S_LATCH_B,

        S_START_TOP,
        S_WAIT_TOP,
        S_WAIT_CAPTURE_FLUSH,

        S_PREP_WRITE,
        S_WRITE_HOLD,

        S_DONE
    } state_t;

    state_t state;

    logic [1:0] load_idx;
    logic [3:0] result_capture_idx;
    logic [3:0] result_write_idx;

    logic [3:0][31:0]  matrix_A_words;
    logic [3:0][31:0]  matrix_B_words;
    logic [15:0][31:0] result_words;

    logic        start_compute;
    logic [31:0] top_result;
    logic        top_result_valid;
    logic        top_done;

    TOP accel_top (
        .CLK             (clk),
        .nRst            (resetn),
        .start_compute   (start_compute),
        .matrix_A_input  (matrix_A_words),
        .matrix_B_input  (matrix_B_words),
        .matrix_S_output (top_result),
        .result_valid    (top_result_valid),
        .accel_done      (top_done)
    );

    assign test_op_v3 = top_result;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            state              <= S_IDLE;
            ack                <= 1'b0;
            busy               <= 1'b0;
            done               <= 1'b0;
            addrb              <= 32'd0;
            dinb               <= 32'd0;
            enb                <= 1'b0;
            web                <= 4'b0000;
            start_compute      <= 1'b0;
            load_idx           <= 2'd0;
            result_capture_idx <= 4'd0;
            result_write_idx   <= 4'd0;
            matrix_A_words     <= '0;
            matrix_B_words     <= '0;
            result_words       <= '0;
        end else begin
            // Defaults for one-cycle controls.
            ack           <= 1'b0;
            start_compute <= 1'b0;

            case (state)

            S_IDLE: begin
                busy <= 1'b0;
                enb  <= 1'b0;
                web  <= 4'b0000;
                // Keep done sticky until next go, useful for software polling.
                if (go) begin
                    done               <= 1'b0;
                    busy               <= 1'b1;
                    load_idx           <= 2'd0;
                    result_capture_idx <= 4'd0;
                    result_write_idx   <= 4'd0;
                    state              <= S_ACK;
                end
            end

            S_ACK: begin
                ack   <= 1'b1;  // lets ctrl_regs clear go
                busy  <= 1'b1;
                enb   <= 1'b0;
                web   <= 4'b0000;
                state <= S_READ_A;
            end

            // Read A word at src_a_addr + 4*load_idx.
            S_READ_A: begin
                busy  <= 1'b1;
                addrb <= src_a_addr + {28'd0, load_idx, 2'b00};
                enb   <= 1'b1;
                web   <= 4'b0000;
                state <= S_WAIT_A;
            end

            S_WAIT_A: begin
                busy  <= 1'b1;
                enb   <= 1'b0;
                web   <= 4'b0000;
                state <= S_LATCH_A;
            end

            S_LATCH_A: begin
                busy <= 1'b1;
                matrix_A_words[load_idx] <= doutb;
                if (load_idx == 2'd3) begin
                    load_idx <= 2'd0;
                    state    <= S_READ_B;
                end else begin
                    load_idx <= load_idx + 2'd1;
                    state    <= S_READ_A;
                end
            end

            // Read B word at src_b_addr + 4*load_idx.
            S_READ_B: begin
                busy  <= 1'b1;
                addrb <= src_b_addr + {28'd0, load_idx, 2'b00};
                enb   <= 1'b1;
                web   <= 4'b0000;
                state <= S_WAIT_B;
            end

            S_WAIT_B: begin
                busy  <= 1'b1;
                enb   <= 1'b0;
                web   <= 4'b0000;
                state <= S_LATCH_B;
            end

            S_LATCH_B: begin
                busy <= 1'b1;
                matrix_B_words[load_idx] <= doutb;
                if (load_idx == 2'd3) begin
                    load_idx           <= 2'd0;
                    result_capture_idx <= 4'd0;
                    state              <= S_START_TOP;
                end else begin
                    load_idx <= load_idx + 2'd1;
                    state    <= S_READ_B;
                end
            end

            S_START_TOP: begin
                busy          <= 1'b1;
                enb           <= 1'b0;
                web           <= 4'b0000;
                start_compute <= 1'b1;
                state         <= S_WAIT_TOP;
            end

            S_WAIT_TOP: begin
                busy <= 1'b1;
                enb  <= 1'b0;
                web  <= 4'b0000;
                if (top_result_valid) begin
                    result_words[result_capture_idx] <= top_result;

                    if (result_capture_idx == 4'd15) begin
                        result_write_idx <= 4'd0;
                        state            <= S_WAIT_CAPTURE_FLUSH;
                    end else begin
                        result_capture_idx <= result_capture_idx + 4'd1;
                    end
                end
            end

            S_WAIT_CAPTURE_FLUSH: begin
                busy             <= 1'b1;
                enb              <= 1'b0;
                web              <= 4'b0000;
                result_write_idx <= 4'd0;
                state            <= S_PREP_WRITE;
            end

            // Prepare write of result_words[result_write_idx].
            // The actual BRAM write occurs on the next clock edge while enb/web/dinb are stable.
            S_PREP_WRITE: begin
                busy  <= 1'b1;
                addrb <= dst_addr + {26'd0, result_write_idx, 2'b00};
                dinb  <= result_words[result_write_idx];
                enb   <= 1'b1;
                web   <= 4'b1111;
                state <= S_WRITE_HOLD;
            end

            S_WRITE_HOLD: begin
                busy <= 1'b1;
                enb  <= 1'b0;
                web  <= 4'b0000;
                if (result_write_idx == 4'd15) begin
                    state <= S_DONE;
                end else begin
                    result_write_idx <= result_write_idx + 4'd1;
                    state            <= S_PREP_WRITE;
                end
            end

            S_DONE: begin
                busy <= 1'b0;
                done <= 1'b1;
                enb  <= 1'b0;
                web  <= 4'b0000;
                state <= S_IDLE;
            end

            default: begin
                state <= S_IDLE;
                busy  <= 1'b0;
                done  <= 1'b0;
                enb   <= 1'b0;
                web   <= 4'b0000;
            end

            endcase
        end
    end

endmodule
