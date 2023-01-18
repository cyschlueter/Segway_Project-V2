import tb_tasks::*;

module Segway_tb();
			
//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo,piezo_n;
logic cmd_sent;
wire rst_n;					// synchronized global reset

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] cmd;				// command host is sending to DUT
reg send_cmd;				// asserted to initiate sending of command
reg signed [15:0] rider_lean;
reg [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
reg OVR_I_lft, OVR_I_rght;
int forward = 16'h0FFF;

///// Internal registers for testing purposes??? /////////
localparam rider_total_weight = 12'h280;

// Error check wire
logic error;

////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Segway with Inertial sensor //
//////////////////////////////////////////////////////////////	
SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                  .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM1_lft(PWM1_lft),
				  .PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
				  .PWM2_rght(PWM2_rght),.rider_lean(rider_lean));				  

/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
ADC128S_FC iA2D(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
             .MISO(A2D_MISO),.MOSI(A2D_MOSI),.ld_cell_lft(ld_cell_lft),.ld_cell_rght(ld_cell_rght),
			 .steerPot(steerPot),.batt(batt));			
	 
////// Instantiate DUT ////////
Segway #(.fast_sim(1'b1)) iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
            .INERT_SCLK(SCLK),.INERT_MISO(MISO),.INERT_INT(INT),.A2D_SS_n(A2D_SS_n),
			.A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
			.PWM1_lft(PWM1_lft),.PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
			.PWM2_rght(PWM2_rght),.OVR_I_lft(OVR_I_lft),.OVR_I_rght(OVR_I_rght),
			.piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));

//// Instantiate UART_tx (mimics command from BLE module) //////
UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));


//////////////////////
//  Segway States  //
////////////////////
typedef enum reg [1:0] {OFF, PWR1, PWR2, UNUSED} auth_state_t;
typedef enum reg [1:0] {INITIAL, VERIFY_STABILITY, STEERING_ENABLED} steer_state_t;
typedef enum reg [1:0] {BALANCED, THREE_FOURTHS, FIFTEEN_SIXTEENTHS, UNBALANCED} balance_t;
typedef enum reg {FORWARD, BACKWARD} lean_t;
typedef enum reg {LEFT, RIGHT} right_left_t;
	// iDUT.iAuth.state  [1:0]
	// iDUT.iSTR.SEM.state   [1:0]

right_left_t steer_direction;
lean_t lean_direction;

initial begin
	error = 0;
    	clk = 0;
	RST_n = 0;
	
	// Neutral inputs
	lean(clk, rider_lean, 16'h0); // No lean
	steerPot = 12'h800; // Straight steerPot
	batt = 12'h7FF; // High battery
	OVR_I_lft = 1'b0;
	OVR_I_rght = 1'b0;
	steer_direction = LEFT;

	
	@(posedge clk);
	@(negedge clk);
	RST_n = 1;			// deassert reset at negedge of clock
  
	/// Your magic goes here ///
	
	
	/////////////////////////
	// GET ON AND STARTUP //
	///////////////////////
	startSegway(clk, cmd, send_cmd, cmd_sent);
	  
	checkSegwayState(iDUT.iAuth.state, OFF, iDUT.iSTR.SEM.state, INITIAL, error);
	  
	stepOn(clk, ld_cell_lft, ld_cell_rght, rider_total_weight, iDUT.rider_off);
	
	startSegway(clk, cmd, send_cmd, cmd_sent);
	
	checkSegwayState(iDUT.iAuth.state, PWR1, iDUT.iSTR.SEM.state, STEERING_ENABLED, error);
	
	
	
	///////////////////////
	// BALANCE AND LEAN //
	/////////////////////
	
	// BALANCE
	// Does the Segway go back into VERIFY_STABILITY if the rider becomes too unbalanced?
	
	
	balance(clk, ld_cell_lft, ld_cell_rght, rider_total_weight, LEFT, THREE_FOURTHS, iDUT.lft_ld, iDUT.rght_ld);
	
	checkSegwayState(iDUT.iAuth.state, PWR1, iDUT.iSTR.SEM.state, STEERING_ENABLED, error);
	
	#6000000;
	
	balance(clk, ld_cell_lft, ld_cell_rght, rider_total_weight, LEFT, UNBALANCED, iDUT.lft_ld, iDUT.rght_ld);
		
	checkSegwayState(iDUT.iAuth.state, PWR1, iDUT.iSTR.SEM.state, VERIFY_STABILITY, error);
	
	#6000000;
	
	
	
	// Slowly transition back to balanced
	balance(clk, ld_cell_lft, ld_cell_rght, rider_total_weight, LEFT, FIFTEEN_SIXTEENTHS, iDUT.lft_ld, iDUT.rght_ld);
	
	#3000000;
	
	balance(clk, ld_cell_lft, ld_cell_rght, rider_total_weight, LEFT, THREE_FOURTHS, iDUT.lft_ld, iDUT.rght_ld);
	
	#3000000;

	balance(clk, ld_cell_lft, ld_cell_rght, rider_total_weight, LEFT, BALANCED, iDUT.lft_ld, iDUT.rght_ld);
	
	//#1500000000; // 1.5s (Wait over 1.3s)
	#5000000; // Less time because of fast_sim
	
	checkSegwayState(iDUT.iAuth.state, PWR1, iDUT.iSTR.SEM.state, STEERING_ENABLED, error);
	
	#3000000;
	

	 
	// LEAN
	// iPHYS.theta_platform
	lean(clk, rider_lean, $signed(16'h00A8)); // Lean a little forward
	
	checkThetaPlatform(iPHYS.theta_platform, 10'h200, 10, error);
	
	#10000000;
	
	
	lean(clk, rider_lean, $signed(16'h3FF6)); // Lean a LOT forward
	
	checkThetaPlatform(iPHYS.theta_platform, 10'h200, 20000, error);
	
	#10000000;
	
	
	lean(clk, rider_lean, $signed(16'hFFC7)); // Lean a little backward
	
	checkThetaPlatform(iPHYS.theta_platform, 10'h200, 12000, error);
	
	#10000000;
	
	
	lean(clk, rider_lean, $signed(16'h8001)); // Lean a LOT backward
	
	checkThetaPlatform(iPHYS.theta_platform, 10'h200, 20000, error);
	
	#10000000;

	

	///////////////
	// STEERING //
	/////////////

	// STEERING WHILE LEANING BACKWARDS
	
	lean(clk, rider_lean, $signed(16'hFF00)); // Lean backward
	
	#10000000;

	steer_direction = RIGHT;
	
	//first go straight
	steer(steer_direction, 2'b00, steerPot);
	#5000000;
	
	
	//go right a little
	steer(steer_direction, 2'b01, steerPot);
	#5000000;
	
	checkSteering(clk, steer_direction, iDUT.rght_spd, iDUT.lft_spd, error);


	steer_direction = LEFT;
	
	//go left a lot
	steer(steer_direction, 2'b11, steerPot);
	#5000000;
	
	checkSteering(clk, steer_direction, iDUT.rght_spd, iDUT.lft_spd, error);



	// STEERING WHILE LEANING FORWARDS

	lean(clk, rider_lean, $signed(16'h00FF)); // Lean a med amount forward
	#30000000;

	
	//first go straight
	steer(steer_direction, 2'b00, steerPot);
	#5000000;
	
	
	//go left a little
	steer(steer_direction, 2'b01, steerPot);
	#5000000;
	
	checkSteering(clk, steer_direction, iDUT.rght_spd, iDUT.lft_spd, error);


	steer_direction = RIGHT;
	
	//go RIGHT a lot
	steer(steer_direction, 2'b11, steerPot);
	#5000000;
	
	checkSteering(clk, steer_direction, iDUT.rght_spd, iDUT.lft_spd, error);


	
	
	///////////////////////
	// GET OFF AND STOP //
	/////////////////////

	// STOP LEANING AND STEERING
	steer(steer_direction, 2'b00, steerPot);
	lean(clk, rider_lean, $signed(16'h0000));
	#5000000;

	stopSegway(clk, cmd, send_cmd, cmd_sent);
	  
	checkSegwayState(iDUT.iAuth.state, PWR2, iDUT.iSTR.SEM.state, STEERING_ENABLED, error);
	  
	stepOff(clk, ld_cell_lft, ld_cell_rght, iDUT.rider_off);
	
	checkSegwayState(iDUT.iAuth.state, OFF, iDUT.iSTR.SEM.state, INITIAL, error);
	
	#3000000;
	
	if(error) begin
		$display("ONE OR MORE ERRORS DETECTED\n");
	end
	if(!error) begin
		$display("YAHOO! All tests passed!\n");
	end
	  
	$stop();
end

always begin
  lean_direction <= lean_t'(rider_lean[15]);
  #10 clk = ~clk;
end
  

endmodule
