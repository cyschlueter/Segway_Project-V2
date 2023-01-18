`default_nettype none

module PWM11(clk, rst_n, duty, PWM_sig, PWM_synch, OVR_I_blank_n);

input logic [10:0] duty;
input logic clk, rst_n;

output logic PWM_sig, PWM_synch, OVR_I_blank_n;

logic [10:0] cnt;
wire en = 1'b1; 							// Always enabled
wire set, reset;


// Combinational logic for set/reset FF
assign set   = ~|cnt; 						// If cnt is all zeroes
assign reset =   cnt >= duty ? 1 : 0; 		// If cnt >= duty


// Set/Reset FF for PWM_sig output
always_ff @(posedge clk, negedge rst_n) begin

	if(!rst_n) 
		PWM_sig <= 1'b0;
	else if(reset)
		PWM_sig <= 1'b0;
	else if(set)
		PWM_sig <= 1'b1;
	// Else PWM_sig will maintain its value
end


// Counter
always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cnt <= 11'h000;
	else if (en)
		cnt <= cnt + 1;
end 

		
// Logic for additional outputs
assign PWM_synch = &cnt;
assign OVR_I_blank_n = |(cnt[10:8]); 		// If cnt > 255
		


endmodule

`default_nettype wire
