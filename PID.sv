`default_nettype none

module PID
#(parameter fast_sim = 1)
(clk, rst_n, vld, ptch, ptch_rt, pwr_up, rider_off, PID_cntrl, ss_tmr);

// Module I/O
input logic [15:0] ptch, ptch_rt;
input logic clk, rst_n, vld, pwr_up, rider_off;

output logic [11:0] PID_cntrl;
output logic [7:0] ss_tmr;

// P term nets
logic signed [9:0] ptch_err_sat;
localparam signed P_COEFF = 5'h0C;
logic signed [14:0] P_term;

// I term nets
logic [14:0] I_term;
logic [17:0] add_result, int_reg_in, integrator;
logic select_add, ov;

// D term nets
logic [12:0] D_term;

// PID Control
logic [15:0] presat_PID_cntrl;

// SS TMR
logic [26:0] tmr_reg_in, tmr_reg_out;


//////////////////////////
// P Term
////////////////////////

// Saturate signed 16-bit to signed 10-bit
assign ptch_err_sat = ptch[15] && ~&ptch[14:9] ? 10'h200 : // If negative (MSB 1) and TOO negative (any 0 bits in 14:9), then saturate to 0x200
					 ~ptch[15] &&  |ptch[14:9] ? 10'h1FF : // If positive (MSB 0) and TOO positive (any 1 bits in 14:9), then saturate to 0x1FF
					  ptch[9:0];

// Perform signed multiply
assign P_term = ptch_err_sat * P_COEFF;



//////////////////////////
// I Term
////////////////////////

assign add_result = integrator + {{8{ptch_err_sat[9]}}, ptch_err_sat[9:0]}; // Adder

assign ov = ((~(integrator[17] ^ ptch_err_sat[9])) && ((integrator[17] ^ add_result[17]))); // Overflow logic: If the MSBs of the add operands match each other (XNOR), 
																							// but the result MSB does NOT match (XOR), then we have overflow

assign select_add = vld && ~ov;

// Both Muxes
assign int_reg_in = rider_off  ? 18'h00000  : // If rider is off, clear to 0
                    select_add ? add_result : // If the vld && ov select is 1, take in the result from the add block
					integrator;				  // If both were 0, maintain value of integrator register

// Register
always_ff @(posedge clk, negedge rst_n) begin
	
	if(!rst_n) begin
		integrator <= 18'h00000;
	end
	else begin
		integrator <= int_reg_in;
	end
	// Else integrator holds its value
end


// Do we need to integrate fast?
generate if(fast_sim) begin
	// We need to saturate I_term down
	assign I_term = integrator[17] && ~&integrator[16:15] ? 15'h4000 : // If negative (MSB 1) and TOO negative (any 0 bits in 14:9), then saturate to 0x200
				   ~integrator[17] &&  |integrator[16:15] ? 15'h3FFF : // If positive (MSB 0) and TOO positive (any 1 bits in 14:9), then saturate to 0x1FF
					integrator[15:1];
end else begin
	// 6-bit signed right shift to divide by 64, with 15-bit result
	assign I_term = {{3{integrator[17]}},integrator[17:6]};
end endgenerate



//////////////////////////
// D Term
////////////////////////

// 6-bit signed right shift to divide by 64, with 13-bit result
assign D_term = ~{{3{ptch_rt[15]}},ptch_rt[15:6]};


//////////////////////////
// PID Control
////////////////////////

// Sign Extend PID terms to 16-bits and add
assign presat_PID_cntrl = {P_term[14], P_term[14:0]} + {I_term[14], I_term[14:0]} + {{3{D_term[12]}}, D_term[12:0]};

// 16-bit to 12-bit saturation of PID_cntrl
assign PID_cntrl = presat_PID_cntrl[15] && ~&presat_PID_cntrl[14:11] ? 12'h800 : // If negative (MSB 1) and TOO negative (any 0 bits in 14:11), then saturate to 0x800
				  ~presat_PID_cntrl[15] &&  |presat_PID_cntrl[14:11] ? 12'h7FF : // If positive (MSB 0) and TOO positive (any 1 bits in 14:11), then saturate to 0x7FF
				   presat_PID_cntrl[11:0];



/////////////////////////////
// Soft-start Timer
///////////////////////////

// Double mux, which hardware generwates depends on fast_sim
generate if(fast_sim) begin
	assign tmr_reg_in = ~pwr_up              ? 27'h0000000 :
						(&tmr_reg_out[26:8]) ? tmr_reg_out :
						tmr_reg_out + 256;
end else begin					
	assign tmr_reg_in = ~pwr_up              ? 27'h0000000 :
						(&tmr_reg_out[26:8]) ? tmr_reg_out :
						tmr_reg_out + 1;
end endgenerate

//////////////////////////////////////////////////////////////////////////////
// This works too, but only because the synthesis tool is smart enough to
// recognize that fast_sim is a fixed parameter at time of synthesis,
// so it doesn't genetate an unnecessary mux
///////////////////////////////////////////////////////////////////////////
//
//assign tmr_reg_in = ~pwr_up              ? 27'h0000000 :
//						(&tmr_reg_out[26:8]) ? tmr_reg_out :
//						fast_sim ? tmr_reg_out + 256;
//						tmr_reg_out + 1;

// Register
always_ff @(posedge clk, negedge rst_n) begin
	
	if(!rst_n) begin
		tmr_reg_out <= 27'h0000000;
	end
	else begin
		tmr_reg_out <= tmr_reg_in;
	end
	// Else tmr_reg holds its value
end

// Keep upper 8 bits for ss_tmr
assign ss_tmr = tmr_reg_out[26:19];





endmodule

`default_nettype wire
