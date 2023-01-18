`default_nettype none 

module Auth_blk(clk, rst_n, RX, rider_off, pwr_up);
	///////////////////////////////////////////////
	// Authorization block is made up of UART
	// receiver and state machine 
	///////////////////////////////////////////
	input logic clk, rst_n, RX, rider_off;
	output logic pwr_up;
	
	
	// Internal signals
	logic rx_rdy, clr_rx_rdy;
	logic [7:0] rx_data;
	
	
	// Instance of UART_rx
	UART_rx iRX(.RX(RX), .clr_rdy(clr_rx_rdy), .clk(clk), .rst_n(rst_n), .rx_data(rx_data), .rdy(rx_rdy));
	
	
	
	////////////////////////////////////////
	//
	// AUTH_SM STATE MACHINE LOGIC
	//
	////////////////////////////////////
	
	typedef enum reg [1:0] {OFF, PWR1, PWR2, UNUSED} state_t;
  
	state_t state, nxt_state;

	// Next state and reset logic
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			state <= OFF;
		end
		else begin
			state <= nxt_state;
		end
	end
  
  
	// Diagram from Midterm
	// State transitions (input/outputs)
	always_comb begin
  
		// default nxt_state and outputs
		nxt_state = OFF;
		pwr_up = 0;
		clr_rx_rdy = 0;

		case(state)
			OFF: 
				if(~rider_off && rx_rdy && rx_data === 8'h67) begin
					nxt_state = PWR1;
					clr_rx_rdy = 1;
					pwr_up = 1;					
				end
				else begin
					nxt_state = OFF;
					clr_rx_rdy = 0;
					pwr_up = 0;	
				end
			PWR1: 
				if(rider_off && rx_rdy && rx_data === 8'h73) begin // If the rider is off when we rcv stop, go to OFF
					nxt_state = OFF;
					clr_rx_rdy = 1;
					pwr_up = 0;					
				end
				else if(~rider_off && rx_rdy && rx_data === 8'h73) begin // If the rider is NOT off and we rcv stop, go to PWR2
					nxt_state = PWR2;
					clr_rx_rdy = 1;
					pwr_up = 1;			// Remain powered up		
				end
				else begin
					nxt_state = PWR1;
					clr_rx_rdy = 0;
					pwr_up = 1;	        // Else remain powered up in PWR1
				end
			PWR2: 
				if(rider_off) begin     // If the rider steps off when in PWR2, go to OFF
					nxt_state = OFF;
					clr_rx_rdy = 0;
					pwr_up = 0;		    // Power down			
				end
				else if(~rider_off && rx_rdy && rx_data === 8'h67) begin // If the rider is still on and we rcv go, we can stay powered up to PWR1
					nxt_state = PWR1;
					clr_rx_rdy = 1;
					pwr_up = 1;			// Stay powered up		
				end
				else begin
					nxt_state = PWR2;
					clr_rx_rdy = 0;
					pwr_up = 1;	        // Else remain powered up in PWR2
				end
			default:
				begin
					nxt_state = OFF;
					pwr_up = 0;
					clr_rx_rdy = 0;
				end
		endcase
	end

endmodule

`default_nettype wire
