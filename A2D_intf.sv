module A2D_intf(clk, rst_n, nxt, lft_ld, rght_ld, steer_pot, batt, SS_n, SCLK, MOSI, MISO);

// Inputs and outputs 
input clk, rst_n, nxt, MISO;

output SS_n, SCLK, MOSI;
output reg [11:0] lft_ld, rght_ld, steer_pot, batt;

// Instantiate SPI monarch device
// Internal SPI signals
reg wrt;
wire done;
logic [15:0] cmd;
wire [15:0] rd_data;

SPI_mnrch iSPI_MNRCH(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), 
                     .wrt(wrt), .cmd(cmd), .done(done), .rd_data(rd_data));

// State machine and internal signals
typedef enum reg [1:0] {IDLE, WAIT_DATA, STALL, UPDATE} State_t;
State_t state, nState;

reg update, incrChannel;
reg [1:0] currChannel;
logic lft_en, rght_en, steer_en, batt_en;

// State machine ---------------------------------------------------------------------------------
// State storer
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    state <= IDLE;
  else
    state <= nState;
end

// nState logic
always_comb begin
  // Default signals to avoid latch
  wrt = 0;
  update = 0;
  incrChannel = 0;
  
  case (state)
    IDLE:
      if (nxt) begin
        nState = WAIT_DATA;
        wrt = 1;
      end
      else
        nState = IDLE;
    WAIT_DATA:
      if (done) begin
        nState = STALL;
        incrChannel = 1;
      end
      else
        nState = WAIT_DATA;
    STALL: begin
      nState = UPDATE;
      wrt = 1;
    end
    UPDATE:
      if (done) begin
        nState = IDLE;
        update = 1;
      end
      else
        nState = UPDATE;
  endcase
end

// Conversion type tracker and logic -------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    currChannel <= 2'h0;
  else if (incrChannel)
    currChannel <= currChannel + 1'b1;
end

always_comb begin
  // Default signals to avoid latch
  lft_en = 0;
  rght_en = 0;
  steer_en = 0;
  batt_en = 0;
  cmd = 16'hxxxx;

  if (update) begin
    case (currChannel) 
      0: batt_en = 1;
      1: lft_en = 1;
      2: rght_en = 1;
      3: steer_en = 1;
    endcase
  end
  case (currChannel) 
    0: cmd = {2'h0, 3'h0, 11'h000};
    1: cmd = {2'h0, 3'h4, 11'h000};
    2: cmd = {2'h0, 3'h5, 11'h000};
    3: cmd = {2'h0, 3'h6, 11'h000};
  endcase
end


// Registers storing converted outputs -----------------------------------------------------------
// lft_ld
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    lft_ld <= 12'h000;
  else if (lft_en)
    lft_ld <= rd_data[11:0];
end

// rght_ld
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    rght_ld <= 12'h000;
  else if (rght_en)
    rght_ld <= rd_data[11:0];
end

// steer_pot
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    steer_pot <= 12'h000;
  else if (steer_en)
    steer_pot <= rd_data[11:0];
end

// batt
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    batt <= 12'h000;
  else if (batt_en)
    batt <= rd_data[11:0];
end

endmodule
