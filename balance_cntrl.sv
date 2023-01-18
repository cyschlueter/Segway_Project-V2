`default_nettype none

module balance_cntrl #(parameter fast_sim = 1)(clk, rst_n, vld, ptch, ptch_rt, rider_off, steer_pot, en_steer, pwr_up, lft_spd, rght_spd, too_fast);

input wire clk, rst_n, vld, rider_off, en_steer, pwr_up;
input wire [15:0] ptch, ptch_rt;
input wire [11:0] steer_pot;

output logic too_fast;
output logic [11:0] lft_spd, rght_spd;


// 0 for regular simulation speed, 1 for fast simulation
// fast_sim will multiply ss_tmr increment speed by 256, as well as speed up the integrator by tapping different bits for the I term


// Interconnects for child modules
logic [11:0] PID_cntrl;
logic [7:0]  ss_tmr;

logic [11:0] pipe_PID_cntrl;
always_ff @(posedge clk) begin
  pipe_PID_cntrl <= PID_cntrl;
end


PID #(.fast_sim(fast_sim)) iPID(.clk(clk), .rst_n(rst_n), .vld(vld), .ptch(ptch), .ptch_rt(ptch_rt), .pwr_up(pwr_up), .rider_off(rider_off), .PID_cntrl(PID_cntrl), .ss_tmr(ss_tmr));
SegwayMath iSegwayMath(.clk(clk), .PID_cntrl(pipe_PID_cntrl), .ss_tmr(ss_tmr), .steer_pot(steer_pot), .en_steer(en_steer), .pwr_up(pwr_up), .lft_spd(lft_spd), .rght_spd(rght_spd), .too_fast(too_fast));
				   

endmodule

`default_nettype wire
