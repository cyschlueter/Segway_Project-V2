module SegwayMath(clk, PID_cntrl, ss_tmr, steer_pot, en_steer, 
                  pwr_up, lft_spd, rght_spd, too_fast);


// Inputs
input signed [11:0] PID_cntrl;
input [11:0] steer_pot;
input [7:0] ss_tmr; // soft start timer
input en_steer, pwr_up;
input logic clk;

//Outputs
output signed [11:0] lft_spd, rght_spd; // Motor speeds
output logic too_fast; 



// Control signal with soft start ---------------------------
wire signed [11:0] PID_ss;
wire signed [19:0] PID_ss_pre;

// Adjust control signal by ss_tmr / 256
assign PID_ss_pre = ($signed({1'b0, ss_tmr}) * PID_cntrl);
assign PID_ss = PID_ss_pre[19:8]; 





// Calculate torque of both motors --------------------------
wire signed [12:0] lft_torque, rght_torque;
wire [11:0] sat_steer_pot;
wire signed [11:0] signed_steer_pot;
wire signed [12:0] proc_steer_pot;

// Saturate steer_pot between 0x200 and 0xE00
assign sat_steer_pot = ~(|steer_pot[11:9]) ? 12'h200 :
                       (&steer_pot[11:9]) ? 12'hE00 :
                       steer_pot[11:0];

// Make signed, multiply by 3/16 and extend to 13 bit
assign signed_steer_pot = (sat_steer_pot - 12'h7ff);
assign proc_steer_pot = {{4{signed_steer_pot[11]}},signed_steer_pot[11:3]} + 
                         {{5{signed_steer_pot[11]}},signed_steer_pot[11:4]};

// Account for steer_pot if steering is enabled
assign lft_torque = en_steer ? {PID_ss[11], PID_ss} + proc_steer_pot :
                    {PID_ss[11], PID_ss};

assign rght_torque = en_steer ? {PID_ss[11], PID_ss} - proc_steer_pot :
                    {PID_ss[11], PID_ss};




// Torque deadzone shaping --------------------------------
localparam MIN_DUTY = 13'h3C0;
localparam LOW_TORQUE_BAND = 8'h3C;
localparam GAIN_MULT = 6'h10;

// Left torque
// Adjust torque so always outside deadzone
wire signed [12:0] lft_torque_comp, lft_pwr_torque, lft_shaped;

assign lft_torque_comp = lft_torque[12] ? lft_torque - MIN_DUTY :
                         lft_torque + MIN_DUTY;

assign lft_pwr_torque = (lft_torque > $signed(LOW_TORQUE_BAND) || -lft_torque > $signed(LOW_TORQUE_BAND)) ? 
                        lft_torque_comp : ($signed(GAIN_MULT) * lft_torque);

// Only power if on
assign lft_shaped = pwr_up ? lft_pwr_torque : 13'h0000;


// Right torque
// Adjust torque so always outside deadzone
wire signed [12:0] rght_torque_comp, rght_pwr_torque, rght_shaped;

assign rght_torque_comp = rght_torque[12] ? rght_torque - MIN_DUTY :
                          rght_torque + MIN_DUTY;

assign rght_pwr_torque = (rght_torque > $signed(LOW_TORQUE_BAND) || -rght_torque > $signed(LOW_TORQUE_BAND)) ? 
                         rght_torque_comp : ($signed(GAIN_MULT) * rght_torque);
// Only power if on
assign rght_shaped = pwr_up ? rght_pwr_torque : 13'h0000;



// Final saturation and over speed detect -----------------
localparam SPEED_ALERT = 12'd1792;

assign lft_spd = (lft_shaped[12] & ~lft_shaped[11]) ? 12'h800 :
                 (~lft_shaped[12] & lft_shaped[11]) ? 12'h7FF :
                 lft_shaped[11:0];

assign rght_spd = (rght_shaped[12] & ~rght_shaped[11]) ? 12'h800 :
                  (~rght_shaped[12] & rght_shaped[11]) ? 12'h7FF :
                  rght_shaped[11:0];

logic pipe_too_fast;
assign pipe_too_fast = lft_spd > $signed(SPEED_ALERT) || rght_spd > $signed(SPEED_ALERT);

always_ff @(posedge clk) begin
  too_fast <= pipe_too_fast;
end



endmodule
