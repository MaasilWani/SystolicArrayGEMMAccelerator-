module ctrl_regs_fsm #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 32
)(
    // AXI-Lite interface
    input  logic                            s_axi_aclk,
    input  logic                            s_axi_aresetn,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,  //Microblaze Address
    input  logic                            s_axi_awvalid, //Address is Valid, Master is ready
    output logic                            s_axi_awready, //Slave recieved the address

    input  logic [C_S_AXI_DATA_WIDTH-1:0]  s_axi_wdata, //Microblaze sends data
    input  logic                            s_axi_wvalid, //Microblaze Data is Valud
    output logic                            s_axi_wready, //Slave recieved data

    output logic [1:0]                      s_axi_bresp,  //Sends Response code
    output logic                            s_axi_bvalid, //Response Code redy
    input  logic                            s_axi_bready, //Recieved Response code

    input  logic [C_S_AXI_ADDR_WIDTH-1:0]  s_axi_araddr, //read addr
    input  logic                            s_axi_arvalid, //addr valid
    output logic                            s_axi_arready, //slave recieved addr

    output logic [C_S_AXI_DATA_WIDTH-1:0]  s_axi_rdata, //value
    output logic [1:0]                      s_axi_rresp, //response code
    output logic                            s_axi_rvalid, //data is ready
    input  logic                            s_axi_rready, //got data

    // PE Controller interface
    output logic [31:0]                     src_a_addr, //Where A is stored
    output logic [31:0]                     src_b_addr, //Where B is tsored
    output logic [31:0]                     dst_addr, //Wher C shoud be stored
    output logic                            go, //Go send to PE conteoller

    input  logic                            ack, //Input from PE controller ack Go
    input  logic                            busy, //PE COntroller busy
    input  logic                            done, //Done
    output logic                            test_op_FSM_NEW2 //does nothing
);

// ─── Internal Registers ──────────────────────────────────────────────
logic [31:0] reg_src_a_addr;
logic [31:0] reg_src_b_addr;
logic [31:0] reg_dst_addr;
logic        reg_go;
logic        reg_ack;

// ─── Read FSM ────────────────────────────────────────────────────────
localparam S_READ_ADDR = 1'b0;
localparam S_READ_DATA = 1'b1;

logic read_state;
logic [31:0] read_data_reg;

assign s_axi_arready = (read_state == S_READ_ADDR);
assign s_axi_rvalid  = (read_state == S_READ_DATA);
assign s_axi_rdata   = read_data_reg;
assign s_axi_rresp   = 2'b00;

always_ff @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        read_state    <= S_READ_ADDR;
        read_data_reg <= 0;
    end else if (read_state == S_READ_ADDR) begin
        if (s_axi_arvalid) begin
            read_state <= S_READ_DATA;
            case (s_axi_araddr[4:2])
                3'b000: read_data_reg <= reg_src_a_addr;
                3'b001: read_data_reg <= reg_src_b_addr;
                3'b010: read_data_reg <= reg_dst_addr;
                3'b100: read_data_reg <= {31'b0, reg_go};
                3'b101: read_data_reg <= {31'b0, reg_ack};
                3'b110: read_data_reg <= {31'b0, busy};
                3'b111: read_data_reg <= {31'b0, done};
                default: read_data_reg <= 32'hDEADBEEF;
            endcase
        end
    end else if (read_state == S_READ_DATA) begin
        if (s_axi_rready)
            read_state <= S_READ_ADDR;
    end
end

// ─── Write FSM ───────────────────────────────────────────────────────
localparam S_WRITE_ADDR = 2'b00;
localparam S_WRITE_DATA = 2'b01;
localparam S_WRITE_RESP = 2'b11;

logic [1:0]  write_state;
logic [31:0] write_addr_reg;

assign s_axi_awready = (write_state == S_WRITE_ADDR);
assign s_axi_wready  = (write_state == S_WRITE_DATA);
assign s_axi_bvalid  = (write_state == S_WRITE_RESP);
assign s_axi_bresp   = 2'b00;

always_ff @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        write_state    <= S_WRITE_ADDR;
        write_addr_reg <= 0;
        reg_src_a_addr <= 0;
        reg_src_b_addr <= 0;
        reg_dst_addr   <= 0;
        reg_go         <= 0;
    end else begin
        //reg_go <= 0; // auto-clear every cycle
        if(ack) reg_go <= 0; // Clear go when PE controller acks it
        case (write_state)
            S_WRITE_ADDR: begin
                if (s_axi_awvalid) begin
                    write_addr_reg <= s_axi_awaddr;
                    write_state    <= S_WRITE_DATA;
                end
            end
            S_WRITE_DATA: begin
                if (s_axi_wvalid) begin
                    case (write_addr_reg[4:2])
                        3'b000: reg_src_a_addr <= s_axi_wdata;
                        3'b001: reg_src_b_addr <= s_axi_wdata;
                        3'b010: reg_dst_addr   <= s_axi_wdata;
                        3'b100: reg_go         <= s_axi_wdata[0];
                        default: ;
                    endcase
                    write_state <= S_WRITE_RESP;
                end
            end
            S_WRITE_RESP: begin
                if (s_axi_bready)
                    write_state <= S_WRITE_ADDR;
            end
        endcase
    end
end

// ─── Output Assignments ──────────────────────────────────────────────
assign src_a_addr = reg_src_a_addr;
assign src_b_addr = reg_src_b_addr;
assign dst_addr   = reg_dst_addr;
assign go         = reg_go;
assign test_op_FSM_NEW2 = ~reg_go;

// __ Input from PE controller assignments ___________________________
assign reg_ack = ack;

endmodule