`default_nettype none

//this submission is for team MEAT MANE: patrick, wilson, cody, cy
module inertial_integrator(clk, rst_n, vld, ptch_rt, AZ, ptch);

input logic clk, rst_n, vld;
input logic [15:0] ptch_rt, AZ;
output logic signed [15:0] ptch;

logic [26:0] ptch_int;
logic [15:0] ptch_rt_comp;
logic signed [15:0]  AZ_comp;
logic signed [15:0]  ptch_acc;
logic signed [25:0] ptch_acc_product;
logic signed [26:0] fusion_ptch_offset;

localparam PTCH_RT_OFFSET = 16'h0050;
localparam AZ_OFFSET = 16'h00A0;

assign ptch_rt_comp = ptch_rt - PTCH_RT_OFFSET;

// accumulator
always @(posedge clk, negedge rst_n) begin

	if(!rst_n)
		ptch_int <= 0;
	else if (vld) begin
		if (ptch_acc > ptch) // if pitch calculated from accel > pitch calculated from gyro
			fusion_ptch_offset = +27'd1024;
		else
			fusion_ptch_offset = -27'd1024;
	
		ptch_int <= ptch_int + (fusion_ptch_offset - {{11{ptch_rt_comp[15]}}, ptch_rt_comp});
	
	end

end 

assign ptch = ptch_int[26:11];


assign AZ_comp = AZ - AZ_OFFSET;
assign ptch_acc_product = AZ_comp * $signed(327);
assign ptch_acc = {{3{ptch_acc_product[25]}},ptch_acc_product[25:13]};

endmodule

`default_nettype wire
