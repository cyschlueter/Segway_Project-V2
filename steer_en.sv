module steer_en(clk, rst_n, lft_ld, rght_ld, en_steer, rider_off);

parameter fast_sim = 1;
localparam MIN_RIDER_WT = 10'h200;
localparam WT_HYSTERESIS = 8'h40;

// Inputs and outputs
input clk, rst_n;
input [11:0] lft_ld, rght_ld;

output logic en_steer, rider_off;

// Internal Signals
// Processed inputs
wire sum_lt_min, sum_gt_min, diff_gt_1_4, diff_gt_15_16;
wire [12:0] sum;
wire [11:0] diff, abs_diff;

assign sum = lft_ld + rght_ld;
assign diff = lft_ld - rght_ld;
assign abs_diff = diff[11] ? ~diff + 1'b1 : diff;

assign sum_lt_min = sum < (MIN_RIDER_WT - WT_HYSTERESIS) ? 1 : 0;
assign sum_gt_min = sum > (MIN_RIDER_WT + WT_HYSTERESIS) ? 1 : 0;

assign diff_gt_1_4 = abs_diff > sum[12:2] ? 1 : 0;
assign diff_gt_15_16 = abs_diff > (sum - sum[12:4]) ? 1 : 0;

// Timer
wire clr, full;
reg [25:0] clk_reg;

always_ff @(posedge clk) begin
  if (clr)
    clk_reg <= 26'h0000000;
  else
    clk_reg <= clk_reg + 1'b1;
end

// Timer full at 1.34 sec if no fast sim, only 2^14 ticks if fast_sim
generate
  if (fast_sim)
    assign full = clk_reg == 14'h3FFF;
  else
    assign full = clk_reg == 26'h3FE56C0;
endgenerate

logic pipe_en_steer, pipe_rider_off;
always_ff @(posedge clk) begin
  en_steer <= pipe_en_steer;
  rider_off <= pipe_rider_off;
end

// State machine instantiation
steer_en_SM SEM(.clk(clk), .rst_n(rst_n), .sum_lt_min(sum_lt_min), .sum_gt_min(sum_gt_min), 
                .diff_gt_1_4(diff_gt_1_4), .diff_gt_15_16(diff_gt_15_16), .clr_tmr(clr), 
                .tmr_full(full), .en_steer(pipe_en_steer), .rider_off(pipe_rider_off));


endmodule
