`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.02.2026 14:35:14
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


`timescale 1ns / 1ps

module async_fifo_top(
    input CLK100MHZ,
    input CPU_RESET,
    input BTNU,
    input BTND,
    input [7:0] SW,
    output reg [3:0] an,
    output reg [6:0] seg,
    output [3:0] led
);

    wire clk_fast, clk_slow;
    wire full, empty;
    wire [7:0] fifo_dout;
    wire auto_mode = SW[0];

    clk_wiz_0 clk_gen (
        .clk_in1(CLK100MHZ),
        .clk_out1(clk_fast),   // 100 MHz
        .clk_out2(clk_slow)    // 25 MHz
    );

    //-----------------------------------------
    // Manual Buttons
    //-----------------------------------------
    wire btnu_clean, btnd_clean;
    reg btnu_d, btnd_d;
    
    debouncer db_u (.clk(clk_fast), .btn_in(BTNU), .btn_out(btnu_clean));
    debouncer db_d (.clk(clk_slow), .btn_in(BTND), .btn_out(btnd_clean));

    always @(posedge clk_fast) btnu_d <= btnu_clean;
    always @(posedge clk_slow) btnd_d <= btnd_clean;

    wire wr_pulse = btnu_clean & ~btnu_d;
    wire rd_pulse = btnd_clean & ~btnd_d;

    //-----------------------------------------
    // Write Domain (100 MHz)
    //-----------------------------------------
    reg [31:0] wr_div = 0;
    reg wr_tick_reg;

    always @(posedge clk_fast) begin
        if (CPU_RESET) begin
            wr_div <= 0;
            wr_tick_reg <= 0;
        end else begin
            wr_div <= wr_div + 1;
            wr_tick_reg <= (SW[3:1] == 3'b000) ? wr_div[24] :
                           (SW[3:1] == 3'b001) ? wr_div[25] :
                           (SW[3:1] == 3'b010) ? wr_div[26] :
                           (SW[3:1] == 3'b011) ? wr_div[27] :
                           (SW[3:1] == 3'b100) ? wr_div[28] :
                           (SW[3:1] == 3'b101) ? wr_div[29] :
                           (SW[3:1] == 3'b110) ? wr_div[30] :
                                                 wr_div[31];
        end
    end

    // Edge detector for auto tick
    reg wr_tick_d;
    always @(posedge clk_fast) wr_tick_d <= wr_tick_reg;
    wire wr_enable_auto = wr_tick_reg & ~wr_tick_d;

    wire wr_enable = auto_mode ? (wr_enable_auto & ~full)
                               : (wr_pulse & ~full);

    reg [7:0] write_data = 0;
    always @(posedge clk_fast) begin
        if (CPU_RESET)
            write_data <= 0;
        else if (wr_enable)
            write_data <= write_data + 1;
    end

    //-----------------------------------------
    // Read Domain (25 MHz)
    //-----------------------------------------
    reg [31:0] rd_div = 0;
    reg rd_tick_reg;

    always @(posedge clk_slow) begin
        if (CPU_RESET) begin
            rd_div <= 0;
            rd_tick_reg <= 0;
        end else begin
            rd_div <= rd_div + 1;
            rd_tick_reg <= (SW[6:4] == 3'b000) ? rd_div[22] :
                           (SW[6:4] == 3'b001) ? rd_div[23] :
                           (SW[6:4] == 3'b010) ? rd_div[24] :
                           (SW[6:4] == 3'b011) ? rd_div[25] :
                           (SW[6:4] == 3'b100) ? rd_div[26] :
                           (SW[6:4] == 3'b101) ? rd_div[27] :
                           (SW[6:4] == 3'b110) ? rd_div[28] :
                                                 rd_div[29];
        end
    end

    // Edge detector for auto tick
    reg rd_tick_d;
    always @(posedge clk_slow) rd_tick_d <= rd_tick_reg;
    wire rd_enable_auto = rd_tick_reg & ~rd_tick_d;

    wire rd_enable = auto_mode ? (rd_enable_auto & ~empty)
                               : (rd_pulse & ~empty);

    //-----------------------------------------
    // FIFO
    //-----------------------------------------
    wire [10:0] fifo_level;

    async_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(1024)
    ) my_fifo (
        .wr_clk(clk_fast),
        .wr_rst(CPU_RESET),
        .wr_en(wr_enable),
        .din(auto_mode ? write_data : SW),
        .full(full),

        .rd_clk(clk_slow),
        .rd_rst(CPU_RESET),
        .rd_en(rd_enable),
        .dout(fifo_dout),
        .empty(empty),
        .level_out(fifo_level)
    );

    assign led[3] = full;
    assign led[2] = empty;
    assign led[1:0] = auto_mode ? 2'b11 : 2'b01;

    //-----------------------------------------
    // 7 Segment Display
    //-----------------------------------------
    reg [3:0] d3,d2,d1,d0;
    integer i;

    always @(*) begin
        {d3,d2,d1,d0} = 16'd0;
        for(i=10;i>=0;i=i-1) begin
            if(d0>=5) d0=d0+3;
            if(d1>=5) d1=d1+3;
            if(d2>=5) d2=d2+3;
            if(d3>=5) d3=d3+3;
            {d3,d2,d1,d0} = {d3[2:0],d2,d1,d0,fifo_level[i]};
        end
    end

    reg [17:0] refresh = 0;
    always @(posedge clk_fast)
        refresh <= refresh + 1;

    reg [3:0] digit;

    always @(*) begin
        case(refresh[17:16])
            2'b00: begin an=4'b1110; digit=d0; end
            2'b01: begin an=4'b1101; digit=d1; end
            2'b10: begin an=4'b1011; digit=d2; end
            2'b11: begin an=4'b0111; digit=d3; end
            default: begin an=4'b1111; digit=0; end
        endcase
    end

    always @(*) begin
        case(digit)
            0: seg=7'b1000000; 1: seg=7'b1111001;
            2: seg=7'b0100100; 3: seg=7'b0110000;
            4: seg=7'b0011001; 5: seg=7'b0010010;
            6: seg=7'b0000010; 7: seg=7'b1111000;
            8: seg=7'b0000000; 9: seg=7'b0010000;
            default: seg=7'b1111111;
        endcase
    end
endmodule

//-----------------------------------------
// Async FIFO Core
//-----------------------------------------
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 1024,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input wire wr_clk, wr_rst, wr_en,
    input wire [DATA_WIDTH-1:0] din,
    output wire full,
    input wire rd_clk, rd_rst, rd_en,
    output wire [DATA_WIDTH-1:0] dout,
    output wire empty,
    output wire [ADDR_WIDTH:0] level_out
);

    reg [ADDR_WIDTH:0] wr_ptr_bin = 0, wr_ptr_gray = 0;
    reg [ADDR_WIDTH:0] rd_ptr_bin = 0, rd_ptr_gray = 0;
    reg [ADDR_WIDTH:0] rd_sync1 = 0, rd_sync2 = 0;
    reg [ADDR_WIDTH:0] wr_sync1 = 0, wr_sync2 = 0;

    blk_mem_gen_0 mem (
        .clka(wr_clk), .wea(wr_en & !full), .addra(wr_ptr_bin[ADDR_WIDTH-1:0]), .dina(din),
        .clkb(rd_clk), .addrb(rd_ptr_bin[ADDR_WIDTH-1:0]), .doutb(dout)
    );

   wire [ADDR_WIDTH:0] wr_ptr_bin_next = wr_ptr_bin + (wr_en & !full);
    always @(posedge wr_clk or posedge wr_rst) begin
        if(wr_rst) {wr_ptr_bin, wr_ptr_gray} <= 0;
        else begin 
            wr_ptr_bin <= wr_ptr_bin + (wr_en & !full);
            wr_ptr_gray <= (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;
        end
    end
        wire [ADDR_WIDTH:0] rd_ptr_bin_next = rd_ptr_bin + (rd_en & !empty);
 
    always @(posedge rd_clk or posedge rd_rst) begin
        if(wr_rst) {rd_ptr_bin, rd_ptr_gray} <= 0;
        else begin
            rd_ptr_bin <= rd_ptr_bin + (rd_en & !empty);
            rd_ptr_gray <= (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;
        end
    end
    always @(posedge wr_clk) {rd_sync2, rd_sync1} <= {rd_sync1, rd_ptr_gray};
    always @(posedge rd_clk) {wr_sync2, wr_sync1} <= {wr_sync1, wr_ptr_gray};

    assign full = (wr_ptr_gray == {~rd_sync2[ADDR_WIDTH:ADDR_WIDTH-1], rd_sync2[ADDR_WIDTH-2:0]});
    assign empty = (rd_ptr_gray == wr_sync2);

    // Gray to Binary for Level calculation
    reg [ADDR_WIDTH:0] rd_ptr_sync_bin;
    integer j;
    always @(*) begin
        rd_ptr_sync_bin[ADDR_WIDTH] = rd_sync2[ADDR_WIDTH];
        for(j=ADDR_WIDTH-1; j>=0; j=j-1) 
            rd_ptr_sync_bin[j] = rd_ptr_sync_bin[j+1] ^ rd_sync2[j];
    end
    assign level_out = wr_ptr_bin - rd_ptr_sync_bin;
endmodule

//-----------------------------------------
// Debouncer Module
//-----------------------------------------
module debouncer(input clk, btn_in, output reg btn_out);
    reg [15:0] count = 0;
    reg sync0 = 0, sync1 = 0;
    always @(posedge clk) begin
        sync0 <= btn_in; sync1 <= sync0;
        if(sync1 == btn_out) count <= 0;
        else begin 
            count <= count + 1;
            if(count == 16'hFFFF) btn_out <= sync1;
        end
    end
endmodule
