module UART_tx(clk, rst_n, TX, trmt, tx_data, tx_done);

// Inputs and outputs
input clk, rst_n, trmt; // trmt indicates transmission start
input [7:0] tx_data;

output TX; // Current output of serial
output reg tx_done; // High when transmit of byte is done


// States for state machine
typedef enum reg {IDLE, TRANSMITTING} state_t;
state_t currentState, nextState;

// Internal signals
reg load; // Whether a new byte can be loaded in
reg shift; // Whether to shift transmission to next bit of byte
reg transmitting; // Currently transmitting


// Bit shift counter ---------------------------------------------------
reg [3:0] bit_cnt;

// Bit transmitted succesfully on shift
always_ff @(posedge clk) begin
  unique case({load,shift}) inside
    2'b1x: bit_cnt <= 4'b0;
    2'b01: bit_cnt <= bit_cnt + 1;
    default: bit_cnt <= bit_cnt;
  endcase
end


// Baud rate timer -----------------------------------------------------
reg [11:0] baud_cnt;

// 12 bit counter
always_ff @(posedge clk) begin
  case({(load | shift), currentState}) inside
    2'b1x: baud_cnt <= 12'h000;
    2'b01: baud_cnt <= baud_cnt + 1;
    default: baud_cnt <= baud_cnt;
  endcase
end

// For 19200 baud rate on 50MHz clock, trigger shift every 2604 clocks
localparam divider = 2604; // 50Mhz / 19200

assign shift = baud_cnt >= divider ? 1'b1 : 1'b0;


// Serial output --------------------------------------------------------
reg [9:0] tx_shft_reg;

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    tx_shft_reg <= 9'h1FF;
  else
    unique case({load, shift}) inside
      2'b1x: tx_shft_reg <= {tx_data, 1'b0}; // Load data when idle
      2'b01: tx_shft_reg <= {1'b1, tx_shft_reg[8:1]}; // Shift by one on shift
      default: tx_shft_reg <= tx_shft_reg; 
    endcase
end

assign TX = tx_shft_reg[0];


// State machine -------------------------------------------------------
reg set_done, clr_done; // Outputs to indicate if current transmission finished

// State holder
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    currentState <= IDLE;
  else
    currentState <= nextState;
end

// Next state logic
always_comb begin
  // Defaults to idle state
  nextState = IDLE;
  load = 0;
  transmitting = 0;
  set_done = 1;
  clr_done = 0;

  case(currentState)
    IDLE: if (trmt) begin
      nextState = TRANSMITTING;
      load = 1;
    end
    // Transmission is done once 10 bits have been transmitted
    TRANSMITTING: if (bit_cnt < 4'hA) begin
      nextState = TRANSMITTING;
      load = 0;
      transmitting = 1;
      set_done = 0;
      clr_done = 1;
    end
  endcase
end


// Done signal ---------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    tx_done <= 1'b0;
  else if (clr_done)
    tx_done <= 1'b0;
  else if (set_done)
    tx_done <= 1'b1;
end




endmodule
