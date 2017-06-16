//=============================================================================================
// Module:   LED Panel Driver
// Describe: Dual-Port-RAM to HUB75
// Notes:    
//=============================================================================================

module matrix_new
(
	rst_n,
	clk,

	wr_clk,
	wr,
	wr_addr,
	wr_data,

	r0,
	g0,
	b0,
	r1,
	g1,
	b1,
	a,
	blank,
	sclk,
	latch
);

   //`define    SCAN_REVRS //scan reverse , pixel 24x48
	parameter COL_NUM_LOG2 = 7;	
	parameter PIXEL_BIT    = 5;
	
	input	wire						rst_n;
	input	wire						clk;

	input	wire						wr_clk;
	input	wire						wr;
	input	wire	[COL_NUM_LOG2+4:0]	wr_addr;	//32*256
	input	wire	[15:0]				wr_data;

	//input	wire			buffer_select;
	//output	wire			buffer_current;
	//output	reg				col_done;
	//output	reg				frame_done;
	//output	reg		[3:0]	row_num;
	

	output	reg		[3:0]				r0;
	output	reg		[3:0]				g0;
	output	reg		[3:0]				b0;
	output	reg		[3:0]				r1;
	output	reg		[3:0]				g1;
	output	reg		[3:0]				b1;
	output	reg		[3:0]				a;
	output	reg							blank;
	output	reg							sclk;
	output	reg							latch;

//---------------------------------------------------------------------------------------------
// state machine states
//

localparam WAIT = 0,
		   BLANK = 1,
		   LATCH = 2,
		   UNBLANK = 3,
		   READ = 4,
		   SHIFT1 = 5,
		   SHIFT2 = 6;


//---------------------------------------------------------------------------------------------
// registers and wires
//

reg [2:0] state;

reg [15:0] timer;
reg [3:0] delay;
//reg rd_buffer;
reg [3:0] 				rd_row;
reg [2:0] 				rd_bit;
reg  [COL_NUM_LOG2-1:0] rd_col;
wire [COL_NUM_LOG2+3:0] rd_addr;
wire [127:0] 			rd_data;
wire [7:0] rd_r1, rd_g1, rd_b1, rd_r0, rd_g0, rd_b0;
wire [7:0] rd_r11, rd_g11, rd_b11, rd_r10, rd_g10, rd_b10;
wire [7:0] rd_r21, rd_g21, rd_b21, rd_r20, rd_g20, rd_b20;
wire [7:0] rd_r31, rd_g31, rd_b31, rd_r30, rd_g30, rd_b30;
wire rd_r1_bit, rd_g1_bit, rd_b1_bit, rd_r0_bit, rd_g0_bit, rd_b0_bit;
wire rd_r11_bit, rd_g11_bit, rd_b11_bit, rd_r10_bit, rd_g10_bit, rd_b10_bit;
wire rd_r21_bit, rd_g21_bit, rd_b21_bit, rd_r20_bit, rd_g20_bit, rd_b20_bit;
wire rd_r31_bit, rd_g31_bit, rd_b31_bit, rd_r30_bit, rd_g30_bit, rd_b30_bit;


//---------------------------------------------------------------------------------------------
// memories
// not the most efficient use of block RAM but good enough for 1 to 16 panels in an LX9
//
// words   0 to  511 are display buffer 0
// words 512 to 1024 are display buffer 1
// bits [23:12] are rows 16 to 31  => r1, g1, b1 and in _hi memory
// bits [11: 0] are rows  0 to 15  => r0, g0, b0 and in _lo memory
//

wire wr_hi = wr && !wr_addr[COL_NUM_LOG2+4];
wire wr_lo = wr && wr_addr[COL_NUM_LOG2+4];
wire wr_left0  = (wr_addr[COL_NUM_LOG2-1:COL_NUM_LOG2-2] == 0);
wire wr_left1  = (wr_addr[COL_NUM_LOG2-1:COL_NUM_LOG2-2] == 1);
wire wr_right0 = (wr_addr[COL_NUM_LOG2-1:COL_NUM_LOG2-2] == 2);
wire wr_right1 = (wr_addr[COL_NUM_LOG2-1:COL_NUM_LOG2-2] == 3);

// hi-0
dpram4096x16
#(
	.DATA_WIDTH				(16),
	.ADDR_WIDTH				(COL_NUM_LOG2+4-2)

)
dpram4096x16_hi_0
(
	.clka					(wr_clk),
	.wea					(wr_hi & wr_left0),
	.addra					({wr_addr[COL_NUM_LOG2+3:COL_NUM_LOG2],wr_addr[COL_NUM_LOG2-3:0]}),
	.dina					(wr_data),
	.clkb					(clk),
	.addrb					(rd_addr),
	.doutb					(rd_data[15:0])
);

// hi-1
dpram4096x16
#(
	.DATA_WIDTH				(16),
	.ADDR_WIDTH				(COL_NUM_LOG2+4-2)

)
dpram4096x16_hi_1
(
	.clka					(wr_clk),
	.wea					(wr_hi & wr_left1),
	.addra					({wr_addr[COL_NUM_LOG2+3:COL_NUM_LOG2],wr_addr[COL_NUM_LOG2-3:0]}),
	.dina					(wr_data),
	.clkb					(clk),
	.addrb					(rd_addr),
	.doutb					(rd_data[31:16])
);

// hi-2
dpram4096x16
#(
	.DATA_WIDTH				(16),
	.ADDR_WIDTH				(COL_NUM_LOG2+4-2)

)
dpram4096x16_hi_2
(
	.clka					(wr_clk),
	.wea					(wr_hi & wr_right0),
	.addra					({wr_addr[COL_NUM_LOG2+3:COL_NUM_LOG2],wr_addr[COL_NUM_LOG2-3:0]}),
	.dina					(wr_data),
	.clkb					(clk),
	.addrb					(rd_addr),
	.doutb					(rd_data[47:32])
);

// hi-3
dpram4096x16
#(
	.DATA_WIDTH				(16),
	.ADDR_WIDTH				(COL_NUM_LOG2+4-2)

)
dpram4096x16_hi_3
(
	.clka					(wr_clk),
	.wea					(wr_hi & wr_right1),
	.addra					({wr_addr[COL_NUM_LOG2+3:COL_NUM_LOG2],wr_addr[COL_NUM_LOG2-3:0]}),
	.dina					(wr_data),
	.clkb					(clk),
	.addrb					(rd_addr),
	.doutb					(rd_data[63:48])
);

// lo-0
dpram4096x16
#(
	.DATA_WIDTH				(16),
	.ADDR_WIDTH				(COL_NUM_LOG2+4-2)

)
dpram4096x16_lo_0
(
	.clka					(wr_clk),
	.wea					(wr_lo & wr_left0),
	.addra					({wr_addr[COL_NUM_LOG2+3:COL_NUM_LOG2],wr_addr[COL_NUM_LOG2-3:0]}),
	.dina					(wr_data),
	.clkb					(clk),
	.addrb					(rd_addr),
	.doutb					(rd_data[79:64])
);

// lo-1
dpram4096x16
#(
	.DATA_WIDTH				(16),
	.ADDR_WIDTH				(COL_NUM_LOG2+4-2)

)
dpram4096x16_lo_1
(
	.clka					(wr_clk),
	.wea					(wr_lo & wr_left1),
	.addra					({wr_addr[COL_NUM_LOG2+3:COL_NUM_LOG2],wr_addr[COL_NUM_LOG2-3:0]}),
	.dina					(wr_data),
	.clkb					(clk),
	.addrb					(rd_addr),
	.doutb					(rd_data[95:80])
);

// lo-2
dpram4096x16
#(
	.DATA_WIDTH				(16),
	.ADDR_WIDTH				(COL_NUM_LOG2+4-2)

)
dpram4096x16_lo_2
(
	.clka					(wr_clk),
	.wea					(wr_lo & wr_right0),
	.addra					({wr_addr[COL_NUM_LOG2+3:COL_NUM_LOG2],wr_addr[COL_NUM_LOG2-3:0]}),
	.dina					(wr_data),
	.clkb					(clk),
	.addrb					(rd_addr),
	.doutb					(rd_data[111:96])
);

// lo-3
dpram4096x16
#(
	.DATA_WIDTH				(16),
	.ADDR_WIDTH				(COL_NUM_LOG2+4-2)

)
dpram4096x16_lo_3
(
	.clka					(wr_clk),
	.wea					(wr_lo & wr_right1),
	.addra					({wr_addr[COL_NUM_LOG2+3:COL_NUM_LOG2],wr_addr[COL_NUM_LOG2-3:0]}),
	.dina					(wr_data),
	.clkb					(clk),
	.addrb					(rd_addr),
	.doutb					(rd_data[127:112])
);

// turn current buffer, row, column, and bit number into a memory address
//assign buffer_current = rd_buffer;
assign rd_addr = {rd_row, rd_col[COL_NUM_LOG2-3:0]};

// turn read data into individual pixel bits
assign rd_r31 = rd_data[127:123];
assign rd_g31 = rd_data[122:118];
assign rd_b31 = rd_data[116:112];
assign rd_r30 = rd_data[63:59];
assign rd_g30 = rd_data[58:54];
assign rd_b30 = rd_data[52:48];

assign rd_r21 = rd_data[111:107];
assign rd_g21 = rd_data[106:102];
assign rd_b21 = rd_data[100:96];
assign rd_r20 = rd_data[47:43];
assign rd_g20 = rd_data[42:38];
assign rd_b20 = rd_data[36:32];

assign rd_r11 = rd_data[95:91];
assign rd_g11 = rd_data[90:86];
assign rd_b11 = rd_data[84:80];
assign rd_r10 = rd_data[31:27];
assign rd_g10 = rd_data[26:22];
assign rd_b10 = rd_data[20:16];

assign rd_r1 = rd_data[79:75];
assign rd_g1 = rd_data[74:70];
assign rd_b1 = rd_data[68:64];
assign rd_r0 = rd_data[15:11];
assign rd_g0 = rd_data[10: 6];
assign rd_b0 = rd_data[ 4: 0];

assign rd_r31_bit = rd_r31[rd_bit];
assign rd_g31_bit = rd_g31[rd_bit];
assign rd_b31_bit = rd_b31[rd_bit];
assign rd_r30_bit = rd_r30[rd_bit];
assign rd_g30_bit = rd_g30[rd_bit];
assign rd_b30_bit = rd_b30[rd_bit];

assign rd_r21_bit = rd_r21[rd_bit];
assign rd_g21_bit = rd_g21[rd_bit];
assign rd_b21_bit = rd_b21[rd_bit];
assign rd_r20_bit = rd_r20[rd_bit];
assign rd_g20_bit = rd_g20[rd_bit];
assign rd_b20_bit = rd_b20[rd_bit];

assign rd_r11_bit = rd_r11[rd_bit];
assign rd_g11_bit = rd_g11[rd_bit];
assign rd_b11_bit = rd_b11[rd_bit];
assign rd_r10_bit = rd_r10[rd_bit];
assign rd_g10_bit = rd_g10[rd_bit];
assign rd_b10_bit = rd_b10[rd_bit];

assign rd_r1_bit = rd_r1[rd_bit];
assign rd_g1_bit = rd_g1[rd_bit];
assign rd_b1_bit = rd_b1[rd_bit];
assign rd_r0_bit = rd_r0[rd_bit];
assign rd_g0_bit = rd_g0[rd_bit];
assign rd_b0_bit = rd_b0[rd_bit];


//---------------------------------------------------------------------------------------------
// clocked logic
//

always @ (posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		r0 <= 0;
		g0 <= 0;
		b0 <= 0;
		r1 <= 0;
		g1 <= 0;
		b1 <= 0;
		a <= 0;
		blank <= 1;
		sclk <= 0;
		latch <= 0;

		state <= READ;

		timer <= 0;
		delay <= 0;

		//rd_buffer <= 0;
		rd_row <= 0;
		rd_bit <= 0;
		
		`ifdef SCAN_REVRS
			rd_col <= 2**COL_NUM_LOG2 - 1 - 16 * (COL_NUM_LOG2 - 5);
		`else
			rd_col <= 0;
		`endif
		
	end
	else
	begin
		// implemnt timer for binary coded modulation
		// bit plane 0 is displayed for ~192 clock cycles
		// each succesfive bit plane is displayed for 2x the clocks of the previous bit plane
		if (timer == 0)
		begin
			case (rd_bit)
				0: timer <= 140;
				1: timer <= 255;
				2: timer <= 511;
				3: timer <= 1023;
				4: timer <= 2047;
				5: timer <= 4095;
				6: timer <= 8191;
				7: timer <= 16383;
			endcase
		end
		else
		begin
			timer <= timer - 1;
		end

		// state machine
		case (state)

			// wait for timer to expire then blank the display
			WAIT: begin
				sclk <= 0;
				
				if (timer == 0)
				begin
					blank <= 1;
					delay <= 8;
					state <= BLANK;
				end
			end

			// wait a while then latch in data previosly shifted into display
			BLANK: begin
				if (delay == 0)
				begin
					latch <= 1;
					delay <= 8;
					state <= LATCH;
					a <= rd_row;
				end
				else
				begin
					delay <= delay - 1;
				end
			end

			// wait a while then unblank the display to display the latched data
			LATCH: begin
				if (delay == 0)
				begin
					blank <= 0;
					latch <= 0;
					state <= UNBLANK;
				end
				else
				begin
					delay <= delay - 1;
				end
			end

			// find the next bit, row, column, and buffer to display
			// this is converted to a read address using combinatorial logic above
			UNBLANK: begin			
				if (rd_bit == PIXEL_BIT - 1)
				begin
					rd_bit <= 0;
					if (rd_row == 15)
					begin
						rd_row <= 0;
					end
					else
					begin
						rd_row <= rd_row + 1;
					end
				end
				else
				begin
					rd_bit <= rd_bit + 1;
				end

				`ifdef SCAN_REVRS
					rd_col <= 2**COL_NUM_LOG2 - 1 - 16 * (COL_NUM_LOG2 - 5);
				`else
					rd_col <= 0;
				`endif			
				
				state <= READ;
			end
			
			// the read, shift1, and shift2 states could be reduced to two states
			// if I knew which edge of sclk latched the data into the shift registers
			// this is good enough for one panel but for more than about four panels
			// it'd be worth reducing to two clocks instead of three clocks.

			// wait for read data to be output from RAM
			READ: begin
				state <= SHIFT1;
				sclk <= 0;
				//frame_done <= 0;
			end

			// drive the column data out the outputs
			SHIFT1: begin
				sclk <= 0;			
				r0[3] <= rd_r30_bit;
				g0[3] <= rd_g30_bit;
				b0[3] <= rd_b30_bit;
				r1[3] <= rd_r31_bit;
				g1[3] <= rd_g31_bit;
				b1[3] <= rd_b31_bit;
		
				r0[2] <= rd_r20_bit;
				g0[2] <= rd_g20_bit;
				b0[2] <= rd_b20_bit;
				r1[2] <= rd_r21_bit;
				g1[2] <= rd_g21_bit;
				b1[2] <= rd_b21_bit;		

				r0[1] <= rd_r10_bit;
				g0[1] <= rd_g10_bit;
				b0[1] <= rd_b10_bit;
				r1[1] <= rd_r11_bit;
				g1[1] <= rd_g11_bit;
				b1[1] <= rd_b11_bit;		
			
				r0[0] <= rd_r0_bit;
				g0[0] <= rd_g0_bit;
				b0[0] <= rd_b0_bit;
				r1[0] <= rd_r1_bit;
				g1[0] <= rd_g1_bit;
				b1[0] <= rd_b1_bit;
				state <= SHIFT2;
			end

			// clock the data into the RAM, move to next column, repeat 32x
			`ifdef SCAN_REVRS
			SHIFT2: begin
				sclk <= 1;
				if (rd_col == 0)
				begin
					rd_col <= 2**COL_NUM_LOG2 - 1 - 16 * (COL_NUM_LOG2 - 5);
					state <= WAIT;
				end
				else
				begin
					rd_col <= rd_col - 1;
					state <= SHIFT1;
				end
			end			
			`else
			SHIFT2: begin
				sclk <= 1;
				if (rd_col == 2**(COL_NUM_LOG2-2) - 1)
				begin
					rd_col <= 0;
					state <= WAIT;
				end
				else
				begin
					rd_col <= rd_col + 1;
					state <= SHIFT1;
				end
			end
			`endif

		endcase
	end
end

endmodule
