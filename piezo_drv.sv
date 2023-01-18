module piezo_drv #(parameter fast_sim = 1) (clk, rst_n, en_steer, too_fast, batt_low, piezo, piezo_n);

// Inputs and outputs
input clk, rst_n, en_steer, too_fast, batt_low;

output reg piezo, piezo_n;



wire noteFinished, threeSec;

reg [1:0] nextDuration;
reg resetPoll, playBuzzer;

typedef enum reg [1:0] {INC, T, S, H} Length_t;
typedef enum reg [1:0] {NG6, NC7, NE7, NG7} Freq_t;

Freq_t note_to_play;


// 3s timer for polling ------------------------------------------------------------
reg [27:0] repeatTimer;

generate
  if (fast_sim) begin
    always_ff @(posedge clk, negedge rst_n) begin
      if (!rst_n)
        repeatTimer <= 28'h0000000;
      else if (resetPoll)
        repeatTimer <= 28'h0000000;
      else if (~threeSec)
        repeatTimer <= repeatTimer + 64;
    end
  end
  else begin
    always_ff @(posedge clk, negedge rst_n) begin
      if (!rst_n)
        repeatTimer <= 28'h0000000;
      else if (resetPoll)
        repeatTimer <= 28'h0000000;
      else if (~threeSec)
        repeatTimer <= repeatTimer + 1;
    end
  end
endgenerate


assign threeSec = (repeatTimer == 28'h8F0D180) ? 1 : 0; // Once 150M cycles - 3s

// Note duration timer ------------------------------------------------------------
reg [24:0] durationTimer;

generate
  if (fast_sim) begin
    always_ff @(posedge clk) begin
      case (nextDuration)
        INC: durationTimer <= durationTimer + 64;
        T: durationTimer <= 25'h1800000; // 2^25 - 2^23
        S: durationTimer <= 25'h1C00000;  // 2^25 0 2^22
        H: durationTimer <= 0; 
      endcase
    end

    assign noteFinished = &durationTimer[24:6] ? 1 : 0;
  end
  else begin
    always_ff @(posedge clk) begin
      case (nextDuration)
        INC: durationTimer <= durationTimer + 1;
        T: durationTimer <= 25'h1800000; // 2^25 - 2^23
        S: durationTimer <= 25'h1C00000;  // 2^25 0 2^22
        H: durationTimer <= 0; 
      endcase
    end

    assign noteFinished = &durationTimer ? 1 : 0;
  end
endgenerate



// Note frequency timer -----------------------------------------------------------
reg [14:0] freqTimer;
wire rawPiezoOn, rawPiezoOff;

generate
  if (fast_sim) begin
    always_ff @(posedge clk, negedge rst_n) begin
      if (!rst_n)
        freqTimer <= 15'h0000;
      else if (rawPiezoOn)
        freqTimer <= 15'h0000;
      else
        freqTimer <= freqTimer + 64;
    end
  end
  else begin
    always_ff @(posedge clk, negedge rst_n) begin
      if (!rst_n)
        freqTimer <= 15'h0000;
      else if (rawPiezoOn)
        freqTimer <= 15'h0000;
      else
        freqTimer <= freqTimer + 1;
    end
  end
endgenerate

logic [14:0] notePeriod;
always_comb begin
  case (note_to_play)
      NG6: notePeriod = 31888;
      NC7: notePeriod = 23888;
      NE7: notePeriod = 18960;
      NG7: notePeriod = 15944;
  endcase
end

generate
  if (fast_sim) begin
    assign rawPiezoOn = freqTimer[14:6] == notePeriod[14:6] ? 1 : 0;
    assign rawPiezoOff = freqTimer[14:6] == {1'b0, notePeriod[14:7]} ? 1 : 0;
  end
  else begin
    assign rawPiezoOn = freqTimer == notePeriod ? 1 : 0;
    assign rawPiezoOff = freqTimer == {1'b0, notePeriod[14:1]} ? 1 : 0;
  end
endgenerate 

    ////////////////////////////////////////////////////////////////////////////////
	//
	// STATE MACHINE LOGIC
	//
	// Inputs:  en_steer, batt_low, too_fast, noteFinished, threeSec
	// Outputs: note_to_play, nextDuration, playBuzzer
	//
	// Example: In state G6, output G6 as note_to_play 
	//          with nextDuration = INC
	//          When going from state G6 to play next note 
	//          C7, output nextDuration = T (to set durationTimer)
	//
	/////////////////////////////////////////////////////////////////////
	
	// State machine states and signals
	typedef enum reg [2:0] {IDLE, G6, C7, E7a, G7a1, G7a2, E7b, G7b} state_t;
	state_t state, nxt_state;

  
	// Next state and reset logic
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			state <= IDLE;
		end
		else begin
			state <= nxt_state;
		end
	end
  
  
	// State transitions (input/outputs)
	always_comb begin
  
		// default nxt_state and outputs
		nxt_state = IDLE;
		note_to_play = NG6;   // DONT CARE
		nextDuration = H;	  // DONT CARE
		playBuzzer = 1'b0;
		resetPoll = 1'b0;
	  
		case(state)
			IDLE: 
				if(too_fast) begin
					nxt_state = G6;
					note_to_play = NG6;   // DONT CARE
					nextDuration = T;
					playBuzzer = 1'b0;
					resetPoll = 1'b1;
				end
				else if(threeSec && batt_low) begin
					nxt_state = G7b;
					note_to_play = NG6;   // DONT CARE
					nextDuration = H;
					playBuzzer = 1'b0;
					resetPoll = 1'b1;
				end
				else if(threeSec && en_steer) begin
					nxt_state = G6;
					note_to_play = NG6;   // DONT CARE
					nextDuration = T;
					playBuzzer = 1'b0;
					resetPoll = 1'b1;
				end
				else begin
					nxt_state = IDLE;
					note_to_play = NG6;   // DONT CARE
					nextDuration = INC;
					playBuzzer = 1'b0;
				end
			G6: 
				if(!(en_steer || too_fast || batt_low)) begin  // If we lose all stimulus, return to IDLE and shut off buzzer
					nxt_state = IDLE;
					note_to_play = NG7;
					nextDuration = T;  // DONT CARE
					playBuzzer = 1'b0;
				end
				else if(noteFinished && too_fast) begin
					nxt_state = C7;
					note_to_play = NG6;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && batt_low) begin
					nxt_state = IDLE;
					note_to_play = NG6;
					nextDuration = H;	  // DONT CARE
					playBuzzer = 1'b1;
				end
				else if(noteFinished && en_steer) begin
					nxt_state = C7;
					note_to_play = NG6;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else begin
					nxt_state = G6;
					note_to_play = NG6;
					nextDuration = INC;
					playBuzzer = 1'b1;
				end
			C7: 
				if(!(en_steer || too_fast || batt_low)) begin  // If we lose all stimulus, return to IDLE and shut off buzzer
					nxt_state = IDLE;
					note_to_play = NG7;
					nextDuration = T;  // DONT CARE
					playBuzzer = 1'b0;
				end
				else if(noteFinished && too_fast) begin
					nxt_state = E7a;
					note_to_play = NC7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && batt_low) begin
					nxt_state = G6;
					note_to_play = NC7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && en_steer) begin
					nxt_state = E7a;
					note_to_play = NC7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else begin
					nxt_state = C7;
					note_to_play = NC7;
					nextDuration = INC;
					playBuzzer = 1'b1;
				end
			E7a: 
				if(!(en_steer || too_fast || batt_low)) begin  // If we lose all stimulus, return to IDLE and shut off buzzer
					nxt_state = IDLE;
					note_to_play = NG7;
					nextDuration = T;  // DONT CARE
					playBuzzer = 1'b0;
				end
				else if(noteFinished && too_fast) begin
					nxt_state = IDLE;
					note_to_play = NE7;
					nextDuration = H; // DONT CARE
					playBuzzer = 1'b1;
				end
				else if(noteFinished && batt_low) begin
					nxt_state = C7;
					note_to_play = NE7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && en_steer) begin
					nxt_state = G7a1;
					note_to_play = NE7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else begin
					nxt_state = E7a;
					note_to_play = NE7;
					nextDuration = INC;
					playBuzzer = 1'b1;
				end
			G7a1: 
				if(!(en_steer || too_fast || batt_low)) begin  // If we lose all stimulus, return to IDLE and shut off buzzer
					nxt_state = IDLE;
					note_to_play = NG7;
					nextDuration = T;  // DONT CARE
					playBuzzer = 1'b0;
				end
				else if(noteFinished && too_fast) begin
					nxt_state = G6;
					note_to_play = NG7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && batt_low) begin
					nxt_state = E7a;
					note_to_play = NG7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && en_steer) begin
					nxt_state = G7a2;
					note_to_play = NG7;
					nextDuration = S;
					playBuzzer = 1'b1;
				end
				else begin
					nxt_state = G7a1;
					note_to_play = NG7;
					nextDuration = INC;
					playBuzzer = 1'b1;
				end
			G7a2: 
				if(!(en_steer || too_fast || batt_low)) begin  // If we lose all stimulus, return to IDLE and shut off buzzer
					nxt_state = IDLE;
					note_to_play = NG7;
					nextDuration = T;  // DONT CARE
					playBuzzer = 1'b0;
				end
				else if(noteFinished && too_fast) begin
					nxt_state = G6;
					note_to_play = NG7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && batt_low) begin
					nxt_state = G7a1;
					note_to_play = NG7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && en_steer) begin
					nxt_state = E7b;
					note_to_play = NG7;
					nextDuration = S;
					playBuzzer = 1'b1;
				end
				else begin
					nxt_state = G7a2;
					note_to_play = NG7;
					nextDuration = INC;
					playBuzzer = 1'b1;
				end
			E7b: 
				if(!(en_steer || too_fast || batt_low)) begin  // If we lose all stimulus, return to IDLE and shut off buzzer
					nxt_state = IDLE;
					note_to_play = NG7;
					nextDuration = T;  // DONT CARE
					playBuzzer = 1'b0;
				end
				else if(noteFinished && too_fast) begin
					nxt_state = G6;
					note_to_play = NE7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && batt_low) begin
					nxt_state = G7a2;
					note_to_play = NE7;
					nextDuration = S;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && en_steer) begin
					nxt_state = G7b;
					note_to_play = NE7;
					nextDuration = H;
					playBuzzer = 1'b1;
				end
				else begin
					nxt_state = E7b;
					note_to_play = NE7;
					nextDuration = INC;
					playBuzzer = 1'b1;
				end
			G7b: 
				if(!(en_steer || too_fast || batt_low)) begin  // If we lose all stimulus, return to IDLE and shut off buzzer
					nxt_state = IDLE;
					note_to_play = NG7;
					nextDuration = T;  // DONT CARE
					playBuzzer = 1'b0;
				end
				else if(noteFinished && too_fast) begin
					nxt_state = G6;
					note_to_play = NG7;
					nextDuration = T;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && batt_low) begin
					nxt_state = E7b;
					note_to_play = NG7;
					nextDuration = S;
					playBuzzer = 1'b1;
				end
				else if(noteFinished && en_steer) begin
					nxt_state = IDLE;
					note_to_play = NG7;
					nextDuration = H;	  // DONT CARE
					playBuzzer = 1'b1;
				end
				else begin
					nxt_state = G7b;
					note_to_play = NG7;
					nextDuration = INC;
					playBuzzer = 1'b1;
				end
			default:
			begin
				nxt_state = IDLE;
				note_to_play = NG6;   // DONT CARE
				nextDuration = H;	  // DONT CARE
				playBuzzer = 1'b0;
			end
		endcase
	end



// SR flops for piezo and piezo_n

wire turnPiezoOff, turnPiezoOn;

assign turnPiezoOn = rawPiezoOn & playBuzzer;
assign turnPiezoOff = rawPiezoOff | ~playBuzzer;

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    piezo <= 0;
  else if (turnPiezoOff)
    piezo <= 0;
  else if (turnPiezoOn)
    piezo <= 1;
end

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    piezo_n <= 0;
  else if (turnPiezoOff)
    piezo_n <= 1;
  else if (turnPiezoOn)
    piezo_n <= 0;
end

endmodule
