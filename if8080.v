//=============================================================================================
// Module:   MCU 8080 interface
// Describe: Storage MCU 8080 signal to Dual-Port-RAM
// Notes:    
//=============================================================================================

module if8080
(
	clk,
	rst_n,
	
	// mcu 8080 interface
	mcu_csx,
	mcu_wrx,
	mcu_rdx, // not used
	mcu_dat,
	mcu_dcx,
	
	// module enable
	if8080_enable,
	
	daulram_wr_en,
	daulram_wr_dat,
	daulram_wr_addr,
	
	state,
	mcu_wr_enable_dbg
	
);

	//`define     SW24X48  // use pixel 32x48
	parameter   COL_NUM_LOG2 = 7;

	input				clk;   // 100M
	input				rst_n;
	
	// mcu 8080 interface
	input				mcu_csx;
	input				mcu_wrx;
	input				mcu_rdx;
	input	[15:0]		mcu_dat;
	input				mcu_dcx;
	
	// module enable
	input				if8080_enable;

	output							daulram_wr_en;
	output	[15:0]					daulram_wr_dat;
	output	[COL_NUM_LOG2+4:0]		daulram_wr_addr;
	
	output  [3:0]		state;
	
	output	reg			mcu_wr_enable_dbg;
	
	localparam  IDLE         = 0,
				CMDX1        = 1,
				CMDX2        = 2,
				CMDY_START   = 3,
				CMDY1        = 4,
				CMDY2        = 5,
				WAIT         = 6,
				DATA_START   = 7,
				DATA         = 8;
	
	// detect the rising edge
	reg	[2:0]	mcu_wrx_dly;
	always @(posedge clk)
	begin
		if(!rst_n)
			mcu_wrx_dly <= 0;
		else
			mcu_wrx_dly <= {mcu_wrx_dly[1:0],mcu_wrx};
	end
	
	wire mcu_wr_enable = (!mcu_wrx_dly[2]) & mcu_wrx_dly[1];
	
	
	reg		[3:0]				state,state_next;
	reg		[COL_NUM_LOG2+4:0]	pixel_cnt,pixel_cnt_next;
	reg     [COL_NUM_LOG2-1:0]  pixel_startx,pixel_startx_next;
	reg     [COL_NUM_LOG2-1:0]  pixel_endx,pixel_endx_next;
	reg     [ 4:0]  			pixel_starty,pixel_starty_next;
	reg     [ 4:0]  			pixel_endy,pixel_endy_next;
	reg     [COL_NUM_LOG2+5:0]  pixel_number,pixel_number_next;
	
	reg							daulram_wr_en,daulram_wr_en_next;
	reg		[15:0]				daulram_wr_dat,daulram_wr_dat_next;
	reg		[COL_NUM_LOG2+4:0]	daulram_wr_addr,daulram_wr_addr_next;
	
	
	always @(posedge clk)
	begin
		if(!rst_n)
		begin
			state            <= IDLE;
			
			pixel_cnt        <= 0;
			pixel_startx     <= 0;
			pixel_endx       <= 0;
			pixel_starty     <= 0;
			pixel_endy       <= 0;
			pixel_number     <= 0;
			
			daulram_wr_dat   <= 0;
			daulram_wr_en    <= 0;
			daulram_wr_addr  <= 0;
		end
		else
		begin
			state            <= state_next;
			
			pixel_cnt        <= pixel_cnt_next;
			pixel_startx     <= pixel_startx_next;
			pixel_endx       <= pixel_endx_next;
			pixel_starty     <= pixel_starty_next;
			pixel_endy       <= pixel_endy_next;
			pixel_number     <= pixel_number_next;

			daulram_wr_dat   <= daulram_wr_dat_next;
			daulram_wr_en    <= daulram_wr_en_next;
			daulram_wr_addr  <= daulram_wr_addr_next;
		end
	end
	
	always @ *
	begin
		// default
		state_next        = state;

		pixel_cnt_next    = pixel_cnt;
		pixel_startx_next = pixel_startx;
		pixel_endx_next   = pixel_endx;
		pixel_starty_next = pixel_starty;
		pixel_endy_next   = pixel_endy;
		pixel_number_next = pixel_number;
		
		daulram_wr_dat_next  = daulram_wr_dat;
		daulram_wr_en_next   = 0;
		daulram_wr_addr_next = daulram_wr_addr;
		
		
		case(state)
			IDLE:
			begin
				if( if8080_enable & mcu_wr_enable & (mcu_dcx == 0) & (mcu_dat==16'h002a) )
					state_next = CMDX1;
			end
			
			CMDX1: // start of coordinate-x
			begin
				if(mcu_wr_enable & (mcu_dcx == 1))
				begin
					state_next = CMDX2;
					pixel_startx_next = mcu_dat;
				end
			end
			
			CMDX2: // end of coordinate-x
			begin
				if(mcu_wr_enable & (mcu_dcx == 1))
				begin
					state_next = CMDY_START;
					pixel_endx_next = mcu_dat;
				end
			end
			
			CMDY_START: // detect the recv of coordinate-y
			begin
				if( mcu_wr_enable & (mcu_dcx == 0) & (mcu_dat == 16'h002b) )
					state_next = CMDY1;	
			end
			
			CMDY1: // start of coordinate-y
			begin
				if(mcu_wr_enable & (mcu_dcx == 1))
				begin
					state_next = CMDY2;
					`ifdef SW24X48  // use pixel 32x48
						pixel_starty_next = (mcu_dat > 11) ? mcu_dat + 4 : mcu_dat;
					`else
						pixel_starty_next = mcu_dat;
					`endif
				end
			end
			
			CMDY2: // end of coordinate-y
			begin
				if(mcu_wr_enable & (mcu_dcx == 1))
				begin
					state_next = WAIT;
					`ifdef SW24X48  // use pixel 32x48
						pixel_endy_next = (mcu_dat > 11) ? mcu_dat + 4 : mcu_dat;
					`else
						pixel_endy_next = mcu_dat;
					`endif
				end
			end
			
			WAIT: // wait a clk
			begin
				state_next = DATA_START;
				pixel_number_next = 1 + ( (pixel_endy - pixel_starty) << COL_NUM_LOG2 ) + (pixel_endx - pixel_startx);
			end
			DATA_START: // detect recv of pixel data
			begin
				if( mcu_wr_enable & (mcu_dcx == 0) & (mcu_dat == 16'h002c) )
				begin
					state_next = DATA;
					pixel_cnt_next = 0;			
				end
			end
			
			DATA: // recv pixel data
			begin
				if(mcu_wr_enable & (mcu_dcx == 1))
				begin
					if(pixel_cnt == pixel_number-1)
					begin
						state_next = IDLE;
					end
					else
					begin
						pixel_cnt_next = pixel_cnt + 1;
					end
					
					daulram_wr_dat_next  = mcu_dat;
					daulram_wr_en_next   = 1'b1;
					daulram_wr_addr_next = pixel_cnt + ( pixel_starty  << COL_NUM_LOG2 ) + pixel_startx;
				end
				else
					daulram_wr_en_next = 0;
				
			end
			
			default:
			begin
				state_next = IDLE;
			end
		
		endcase
	
	end
	
	
	// debug
	always @(posedge clk)
	begin
		if(!rst_n)
			mcu_wr_enable_dbg <= 0;
		else
			mcu_wr_enable_dbg <= mcu_wr_enable;
	end


endmodule
