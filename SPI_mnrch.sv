`default_nettype none
module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, cmd, done, rd_data);

// Input, output, and internal signals -----------------
input wire clk, rst_n, MISO, wrt;
input wire [15:0] cmd;

output wire SCLK, MOSI;
output reg SS_n, done;
output wire [15:0] rd_data;

// SCLK generating counter
reg [3:0] sclk_cntr;

// Shift register signals
reg MISO_smpl;
reg [15:0] shft_reg;

// Bit shift counter
reg [3:0] bit_cntr;
wire done15;

// State machine 
reg init, smpl, shft, set_done, ld_SCLK;

typedef enum reg [1:0] {IDLE, FRONTP, TRANSMITTING, BACKP} state_t;
state_t state, nState;



// SCLK generator --------------------------------------
always_ff @(posedge clk) begin
  if (ld_SCLK)
    sclk_cntr <= 4'b1011;
  else
    sclk_cntr <= sclk_cntr + 1'b1;
end

assign SCLK = sclk_cntr[3];



// Shift register --------------------------------------
// Sampler
always_ff @(posedge clk) begin
  if (smpl)
    MISO_smpl <= MISO;
end

// Shift reg, LSB in MSB out
always_ff @(posedge clk) begin
  casex ({init, shft}) 
    2'b1x: shft_reg <= cmd;
    2'b01: shft_reg <= {shft_reg[14:0], MISO_smpl};
    default: shft_reg <= shft_reg;
  endcase
end

assign MOSI = shft_reg[15];
assign rd_data = shft_reg;

// Bit Counter ------------------------------------------
always_ff @(posedge clk) begin
  if (init)
    bit_cntr <= 4'b0000;
  else if (shft)
    bit_cntr <= bit_cntr + 1'b1;
end

assign done15 = &bit_cntr;



// State Machine ----------------------------------------
// State holder
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    state <= IDLE;
  else
    state <= nState;
end

// Next state and output logic
always_comb begin
  // Default values to avoid latch
  nState = IDLE;
  smpl = 0;
  shft = 0;
  ld_SCLK = 0;
  init = 0;
  set_done = 0;
  case (state)
    IDLE: 
      if (wrt) begin
        init = 1;
        nState = FRONTP; 
      end
      else
        ld_SCLK = 1;
    FRONTP: 
      if (sclk_cntr == 4'h1)
        nState = TRANSMITTING;
      else
        nState = FRONTP;
    TRANSMITTING: 
      if (done15)
        nState = BACKP;
      else begin
        nState = TRANSMITTING;
        if (sclk_cntr == 4'h8)
          smpl = 1;
        else if (sclk_cntr == 4'h0)
          shft = 1;
      end
    BACKP:
      if (sclk_cntr == 4'h8) begin
        nState = BACKP;
        smpl = 1;
      end
      else if (sclk_cntr == 4'hE) begin
        nState = BACKP;
        shft = 1;
      end
      else if (sclk_cntr == 4'hF) begin
        nState = IDLE;
        ld_SCLK = 1;
        set_done = 1;
      end
      else
        nState = BACKP;
  endcase
end


// SS_n and done signals --------------------------------
// SS_n
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    SS_n <= 1'b1;
  else if (set_done)
    SS_n <= 1'b1;
  else if (init)
    SS_n <= 1'b0;
end

// done
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    done <= 1'b0;
  else if (set_done)
    done <= 1'b1;
  else if (init)
    done <= 1'b0;
end

endmodule

`default_nettype wire
