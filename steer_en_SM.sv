module steer_en_SM(clk,rst_n,tmr_full,sum_gt_min,sum_lt_min,diff_gt_1_4,
                   diff_gt_15_16,clr_tmr,en_steer,rider_off);

  input clk;				// 50MHz clock
  input rst_n;				// Active low asynch reset
  input tmr_full;			// asserted when timer reaches 1.3 sec
  input sum_gt_min;			// asserted when left and right load cells together exceed min rider weight
  input sum_lt_min;			// asserted when left_and right load cells are less than min_rider_weight

  input diff_gt_1_4;		// asserted if load cell difference exceeds 1/4 sum (rider not situated)
  input diff_gt_15_16;		// asserted if load cell difference is great (rider stepping off)
  output logic clr_tmr;		// clears the 1.3sec timer
  output logic en_steer;	// enables steering (goes to balance_cntrl)
  output logic rider_off;	// held high in intitial state when waiting for sum_gt_min
  
  // You fill out the rest...use good SM coding practices ///

  // Define states
  typedef enum reg [1:0] {INITIAL, VERIFY_STABILITY, STEERING_ENABLED} state_t;
  state_t state, nextState;

  // State holder
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      state <= INITIAL;
    else
      state <= nextState;
  end

  // Logic for next state and outputs
  always_comb begin
    // Default values to initial state to prevent latch
    nextState = INITIAL;
    en_steer = 0;
    rider_off = 1;
    clr_tmr = 0;
    
    case(state) inside
      INITIAL: if (sum_gt_min) begin
        nextState = VERIFY_STABILITY;
        clr_tmr = 1;
        rider_off = 0;
      end
      VERIFY_STABILITY: if (!sum_lt_min) begin
        if (diff_gt_1_4) begin
          nextState = VERIFY_STABILITY;
          clr_tmr = 1;
          rider_off = 0;
        end
        else if (tmr_full) begin
          nextState = STEERING_ENABLED;
          rider_off = 0;
        end
        else begin
          nextState = VERIFY_STABILITY;
          rider_off = 0;
        end
      end
      STEERING_ENABLED: if (!sum_lt_min) begin
        if (diff_gt_15_16) begin
          nextState = VERIFY_STABILITY;
          rider_off = 0;
          clr_tmr = 1;
        end
        else begin
          nextState = STEERING_ENABLED;
          rider_off = 0;
          en_steer = 1;
        end
      end
    endcase
  end
endmodule
