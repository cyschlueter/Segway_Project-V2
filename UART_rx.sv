module UART_rx(clk, rst_n, RX, clr_rdy, rx_data, rdy);

// Inputs and outputs
input clk, rst_n, RX, clr_rdy; // RX is state of serial line
output [7:0] rx_data; // Read byte
output reg rdy; // If output is ready

// States for state machine and internal signals ---------------
typedef enum reg {INITIAL, RECEIVING} state_t;
state_t state, nextState;

// State machine outputs
reg start, receiving, set_rdy; 

// Whether to read in next bit
wire shift;

// Bit counter -----------------------------------------------
reg [3:0] bit_cnt;

// Bit received succesfully on shift
always_ff @(posedge clk) begin
  unique case({start,shift}) inside
    2'b1x: bit_cnt <= 4'b0;
    2'b01: bit_cnt <= bit_cnt + 1;
    default: bit_cnt <= bit_cnt;
  endcase
end

// Baud rate timer for sampling -----------------------------
reg [11:0] baud_cnt;
wire [11:0] shiftDelay;


// Want to wait half cycle for first to get sampling in middle of bit
// Want to wait full cycle for rest to stay in middle
assign shiftDelay = start ? 12'h516: 12'hA2C;

// 12 bit decrementer
always_ff @(posedge clk) begin
  case({(start | shift), state}) inside
    2'b1x: baud_cnt <= shiftDelay;
    2'b01: baud_cnt <= baud_cnt - 1;
    default: baud_cnt <= baud_cnt;
  endcase
end

// Want to  shift once timer hits 0
assign shift = ~(|baud_cnt);

// Serial input ---------------------------------------------
// Stabilize RX input through 2 flip flops
reg q1, rxStable;
always_ff @(posedge clk) begin
  q1 <= RX;
  rxStable <= q1;
end

// Shift in serial bit once shift signal is asserted
reg [8:0] rx_shft_reg;
always_ff @(posedge clk) begin
  if (shift)
    rx_shft_reg = {rxStable,rx_shft_reg[8:1]};
end

assign rx_data = rx_shft_reg[7:0];

// State machine --------------------------------------------
// State holder
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    state <= INITIAL;
  else
    state <= nextState;
end

// Next state logic
always_comb begin
  // Default values to initial state to avoid latches
  nextState = INITIAL;
  start = 0;
  receiving = 0;
  set_rdy = 0;
  case (state) inside
    INITIAL: if (~rxStable) begin // When start condition asserted
      nextState = RECEIVING;
      start = 1;
      receiving = 1;
    end
    RECEIVING: if (bit_cnt < 4'hA) begin // Done once 10 bits read in
      nextState = RECEIVING;
      receiving = 1;
    end
    else begin
      set_rdy = 1;
    end
  endcase
end


// Done signal ----------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    rdy <= 1'b0;
  else if (start | clr_rdy)
    rdy <= 1'b0;
  else if (set_rdy)
    rdy <= 1'b1;
end


endmodule
