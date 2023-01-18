`default_nettype none

module rst_synch(RST_n, clk, rst_n);

input logic clk, RST_n; // Push button reset, clk
output logic rst_n; // Synchronized active low reset


logic middle;


// First negedge FF
always_ff @(negedge clk, negedge RST_n) begin

	if(!RST_n) 
		middle <= 1'b0;
	else
		middle <= 1'b1;
	// Else FF output will maintain its value
end

// Second negedge FF
always_ff @(negedge clk, negedge RST_n) begin

	if(!RST_n) 
		rst_n <= 1'b0;
	else
		rst_n <= middle;
	// Else FF output will maintain its value
end


endmodule

`default_nettype wire
