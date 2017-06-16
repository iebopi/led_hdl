//=============================================================================================
// Module:   Color LED Ctrl
// Describe: Translate MCU 8080 signal to HUB75.
// Notes:    Seperated HUB75 x4
//=============================================================================================

module led_ctrl_top
(
	//rst_n,
	clk_in,
	r0,
	g0,
	b0,
	r1,
	g1,
	b1,
	a,
	blank,
	sclk,
	latch,
	
	a3,
	blank3,
	sclk3,
	latch3,
	
	led,
	
	mcu_csx,
	mcu_wrx,
	mcu_rdx, // mcu read not used
	mcu_dat,
    mcu_dcx,
	
	clk_arm
	);
	
	parameter COL_NUM_LOG2 = 8;
	
	// mcu 8080 interface
	input				mcu_csx;
	input				mcu_wrx;
	input				mcu_rdx;
	input	[15:0]		mcu_dat;
	input				mcu_dcx;
	
	output				clk_arm;

	input				clk_in; //25M
	output				led;
	
	reg		[23:0]		heartbeat_led;
	assign				led	= heartbeat_led[23];

	// output signal

	output	[3:0]		r0;
	output	[3:0]		g0;
	output	[3:0]		b0;
	output	[3:0]		r1;
	output	[3:0]		g1;
	output	[3:0]		b1;
	output	[3:0]		a;
	output				blank;
	output				sclk;
	output				latch;
	
	output	[3:0]		a3;
	output				blank3;
	output				sclk3;
	output				latch3;	
	
	//clk clk_100 
	wire				locked;
	wire				rst_n = locked;
	wire				clk,clk_100;
	
	pll	pll_inst
(
	.areset		( 1'b0 ),
	.inclk0		( clk_in ),
	.c0 		( clk_100 ),		// 100M
	.c1 		( clk ),			// 25M
	.c2 		(  ),	// 100M
	.c3			( clk_arm ),		// 12M
	.locked 	( locked )
	);
	
	
	wire	[COL_NUM_LOG2+4:0]		wr_addr;
	wire	[31:0]					wr_data;
	wire							wr;
	


	matrix_new
#(
	.COL_NUM_LOG2			(COL_NUM_LOG2)
)
	inst_matrix_new
(
	.rst_n					(rst_n),
	.clk					(clk),

	.wr_clk					(clk_100),
	.wr						(wr),
	.wr_addr				(wr_addr),
	.wr_data				(wr_data),

	.r0						(r0),
	.g0						(g0),
	.b0						(b0),
	.r1						(r1),
	.g1						(g1),
	.b1						(b1),
	.a						(a),
	.blank					(blank),
	.sclk					(sclk),
	.latch					(latch)
);

	assign    a3		=  a;
	assign    blank3	=  blank;
	assign    sclk3		=  sclk;
	assign    latch3	=  latch;	

	

	if8080
#(
	.COL_NUM_LOG2			(COL_NUM_LOG2)	
)
	inst_if8080_new
(
	.clk					(clk_100),
	.rst_n					(rst_n),
	
	// mcu 8080 interface
	.mcu_csx				(mcu_csx),
	.mcu_wrx				(mcu_wrx),
	.mcu_rdx				(mcu_rdx), // mcu read not used
	.mcu_dat				(mcu_dat),
	.mcu_dcx				(mcu_dcx),
	
	// module enable
	.if8080_enable			(1'b1),
	
	.daulram_wr_en			(wr),
	.daulram_wr_dat			(wr_data),
	.daulram_wr_addr		(wr_addr)
	
);



	//	heartbeat led
	always @(posedge clk)
	begin
		if(!rst_n)
			heartbeat_led	<= 0;
		else
			heartbeat_led	<= heartbeat_led + 1'b1;
	
	end
	
	
	
endmodule
