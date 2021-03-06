//=============================================================================================
// Module:   Daul Port RAM
// Describe: 
// Notes:    
//=============================================================================================

module dpram4096x16
#(
	parameter DATA_WIDTH = 16, 
	parameter ADDR_WIDTH = 13
)
(
	input clka,clkb,
	input wea,
	input [(DATA_WIDTH-1):0] dina,
	input [(ADDR_WIDTH-1):0] addra, addrb,
	output reg [(DATA_WIDTH-1):0] doutb
);

	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

	always @ (posedge clka)
	begin
		if (wea) 
		begin
			ram[addra] <= dina;
		end
	end 

	always @ (posedge clkb)
	begin
		begin
			doutb <= ram[addrb];
		end
	end 

endmodule
