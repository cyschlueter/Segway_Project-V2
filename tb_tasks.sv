package tb_tasks;
	
	task automatic startSegway(ref logic clk, ref logic [7:0] cmd, ref logic send_cmd, ref logic cmd_sent);
		begin
			cmd = 8'h67;
			@(negedge clk) send_cmd = 1'b1; 
			@(negedge clk) send_cmd = 1'b0;
			
			// Wait for cmd to be sent
			@(posedge cmd_sent); repeat(2) @(negedge clk);
		end
	endtask
	
	task automatic stepOn(ref logic clk, ref logic [11:0] ld_cell_lft, ref logic [11:0] ld_cell_rght, input logic [11:0] rider_total_weight, ref logic rider_off);
		begin
			
			ld_cell_lft = {1'b0, rider_total_weight[11:1]}; // first foot on, half weight on one load cell
			
			repeat(25000) @(posedge clk); // wait
			ld_cell_lft = rider_total_weight; // second foot up, full weight on one load cell
			
			// Now rider is on (rider_off == 0)
			// repeat(2) @(negedge clk);
			// if(rider_off_out !== 1'b0) begin
				// $display("ERROR: #2a Heavy rider should trigger rider_off == 0");
				// error = 1;
			// end
			
			repeat(25000) @(posedge clk); // wait
			ld_cell_lft = {1'b0, rider_total_weight[11:1]}; // second foot on, half weight on each load cell
			ld_cell_rght = {1'b0, rider_total_weight[11:1]}; // second foot on, half weight on each load cell
		
			// Wait for Segway A2D to recognize rider is on
			@(negedge rider_off); repeat(2) @(negedge clk);
		end
	endtask
	
	task automatic stepOff(ref logic clk, ref logic [11:0] ld_cell_lft, ref logic [11:0] ld_cell_rght, ref logic rider_off);
		begin
			ld_cell_lft = 12'b0; // step off both ld cells
			ld_cell_rght = 12'b0;
			
			// Wait for Segway A2D to recognize rider is off
			@(posedge rider_off); repeat(2) @(negedge clk);
		end
	endtask
	
	task automatic stopSegway(ref logic clk, ref logic [7:0] cmd, ref logic  send_cmd, ref logic cmd_sent);
		begin
			cmd = 8'h73;
			@(negedge clk) send_cmd = 1'b1; 
			@(negedge clk) send_cmd = 1'b0;
			
			// Wait for cmd to be sent
			@(posedge cmd_sent); repeat(2) @(negedge clk);
		end
	endtask
	
	// Applies stimulus of a rider leaning forward/backward
	task automatic lean(ref logic clk, ref logic signed [15:0] rider_lean, input int signed lean);  // Can be forward (+) or backward (-)
		begin
			//LEAN MUST NOT EXCEED 0x1FFF positive of 0xE000 negative
			@(posedge clk);
			
			if (lean > $signed(16'h1FFF)) begin
				rider_lean = 16'h1FFE;
			end
			else if (lean < $signed(16'hE000)) begin
				rider_lean = 16'hE001;
			end
			else begin
				rider_lean = lean;
			end
		end
	endtask
	
	// Applies stimulus of a rider balancing their weight between the left/right load cells
	task automatic balance(ref logic clk, ref logic [11:0] ld_cell_lft, ref logic [11:0] ld_cell_rght, input logic [11:0] rider_total_weight,  // Side-to-side:   right == 1 is right, right == 0 is left   
						   input logic right, input logic unsigned [1:0] balance_amt, ref logic [11:0] segway_ld_lft, ref logic [11:0] segway_ld_rght); 														 // balance_amt = 00 is balanced, balance_amt = 111 is leaning A LOT to the right or left
		begin
			if(right) begin
				case(balance_amt) inside 
					2'b00: begin
						ld_cell_lft = {1'b0, rider_total_weight[11:1]};
						ld_cell_rght = {1'b0, rider_total_weight[11:1]};
					end
					2'b01: begin
						ld_cell_lft = {{2{1'b0}}, rider_total_weight[11:2]};  							 // 1/4
						ld_cell_rght = rider_total_weight[11:0] - {{2{1'b0}}, rider_total_weight[11:2]}; // 3/4 = 4/4 - 1/4
					end
					2'b10: begin
						ld_cell_lft = {{4{1'b0}}, rider_total_weight[11:4]};  							 // 1/16
						ld_cell_rght = rider_total_weight[11:0] - {{4{1'b0}}, rider_total_weight[11:4]}; // 15/16 = 16/16 - 1/16					
					end
					2'b11: begin
						ld_cell_lft = {{6{1'b0}}, rider_total_weight[11:6]};  							 // 1/64
						ld_cell_rght = rider_total_weight[11:0] - {{6{1'b0}}, rider_total_weight[11:6]}; // 63/64 = 64/64 - 63/64
					end
				endcase
			end
			else begin
				case(balance_amt) inside
					2'b00: begin
						ld_cell_lft = {1'b0, rider_total_weight[11:1]};
						ld_cell_rght = {1'b0, rider_total_weight[11:1]};
					end
					2'b01: begin
						ld_cell_lft = rider_total_weight[11:0] - {{2{1'b0}}, rider_total_weight[11:2]}; // 3/4 = 4/4 - 1/4
						ld_cell_rght = {{2{1'b0}}, rider_total_weight[11:2]};  							// 1/4
					end
					2'b10: begin
						ld_cell_lft = rider_total_weight[11:0] - {{4{1'b0}}, rider_total_weight[11:4]}; // 15/16 = 16/16 - 1/16
						ld_cell_rght = {{4{1'b0}}, rider_total_weight[11:4]};  							// 1/16			
					end
					2'b11: begin
						ld_cell_lft = rider_total_weight[11:0] - {{6{1'b0}}, rider_total_weight[11:6]}; // 63/64 = 64/64 - 63/64
						ld_cell_rght = {{6{1'b0}}, rider_total_weight[11:6]};  							// 1/64
					end
				endcase
			end		
		end
		
		while(ld_cell_lft != segway_ld_lft) begin
			#10;
		end
		while(ld_cell_rght != segway_ld_rght) begin
			#10;
		end
		
		repeat(2) @(negedge clk);
		
	endtask
	
	// Check that PID makes the platform converge to zero (within tolerance) within wait_time MICROSECONDS
	task automatic checkThetaPlatform(ref logic signed [15:0] theta_platform, input logic [9:0] tolerance, input int unsigned wait_time, ref logic error); 
		begin
			logic unsigned [15:0] abs_theta_platform;
		
			while(wait_time > 0) begin
				#1000; // Wait 1 thousand ns (1 us)
				wait_time--;
			end
			
			if(theta_platform[15]) begin
				abs_theta_platform = ~theta_platform;
			end
			else begin
				abs_theta_platform = theta_platform;
			end
			
			if(theta_platform === 16'hxxxx) begin
				$display("ERROR: theta platform was unknown %t",$time());
				error = 1;
			end
			else if(abs_theta_platform > tolerance) begin
				$display("ERROR: theta platform was not close to zero (not within tolerance) %t",$time());
				error = 1;
			end
			else begin
				$display("PASS: theta platform was close to zero (within tolerance) %t",$time());
			end
		end
	endtask
	
	// Check that the current Segway states match the expected
	task automatic checkSegwayState(input logic [1:0] auth_state, input logic [1:0] exp_auth_state, input logic [1:0] steer_state, input logic [1:0] exp_steer_state, ref logic error); 
		begin
			if(auth_state !== exp_auth_state) begin
				$display("ERROR: auth_blk state did not match expected auth_blk state %t",$time());
				error = 1;
			end
			else begin
				$display("PASS: auth_blk state matched expected auth_blk state %t",$time());
			end
			
			if(steer_state !== exp_steer_state) begin
				$display("ERROR: steer_en state did not match expected steer_en state %t",$time());
				error = 1;
			end
			else begin
				$display("PASS: steer_en state matched expected steer_en state %t",$time());
			end
		end
	endtask
	
	task automatic steer(input logic right, input logic [1:0] steer_amt, ref logic [11:0] steerPot);
		begin
		//get an amount as input and steer by that amount. Positive to the right, negative to the left
		
		if (right) begin
		  case (steer_amt) inside 
			 2'b00: steerPot = 12'h800;  //if steer_amt is 0 we go STRAIGHT
			 2'b01: steerPot = 12'h900;
			 2'b10: steerPot = 12'hA00;
			 2'b11: steerPot = 12'hB00;  //as far right as we can go

		  endcase
		end //end if right
		else begin
		   case(steer_amt) inside 
			 2'b00: steerPot = 12'h7ff;  //if steer_amt is 0 we go STRAIGHT
			 2'b01: steerPot = 12'h6ff;
			 2'b10: steerPot = 12'h5ff;
			 2'b11: steerPot = 12'h4ff;  //as far left as we can go
		endcase //end left side
		end
		
		end
	endtask
	
	// Check Segway steering (steerpot)
	task automatic checkSteering(ref logic clk, input logic right, ref logic signed [11:0] rght_spd, ref logic signed [11:0] lft_spd, ref logic error); 
		begin
			//not fully sure how to check exact number so this just checks if a right turn turns right and a left turn turns left
			if (right) begin
				#10000;
				if (rght_spd > lft_spd) begin
					$display("ERROR: Segway did not turn right when requested %t",$time());
					error = 1;
				end //end check
				else begin
					$display("PASS: Segway did turn right when requested %t",$time());
				end
			end //end if right
			else begin
				#10000;
				if (lft_spd > rght_spd) begin
					$display("ERROR: Segway did not turn left when requested %t",$time());
					error = 1;
				end //end check
				else begin
					$display("PASS: Segway did turn left when requested %t",$time());
				end
			end //end left 
		end  //end initial begin	
	endtask







endpackage
