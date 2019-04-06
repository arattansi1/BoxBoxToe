module BoxBoxToe(SW, KEY, LEDR,
	VGA_CLK, 
	VGA_HS,
	VGA_VS,
	VGA_BLANK_N,
	VGA_SYNC_N,
	VGA_R,
	VGA_G,
	VGA_B, 
	HEX0, CLOCK_50);

	// vga outputs
   	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]

    // Switches and keys for input, hex0 and ledr for output, and clock
    input [17:0] SW;
    input [3:0] KEY;
    output [17:0] LEDR;
    output HEX0;
    input CLOCK_50;

    // enable for move confirmation and reset game
    wire enable, reset;
    assign enable = KEY[3];
    assign reset = KEY[0];
	 
    // enables, player moves
	wire writeEn;
    wire en_x, en_o;
    wire [8:0] x_moves, o_moves, game_moves;
	
    // player move output, plot enable, and player colour
	wire draw;
	wire [7:0] x, xOut;
	wire [6:0] y, yOut;
	wire plot;
	wire [2:0] colour;
	 
    // ouput game result to leds
	wire winx, wino, draw1;
	assign LEDR[17] = winx;
	assign LEDR[16] = wino;
	assign LEDR[15] = draw1;
	
    // valid move played
	wire valid;
	
    // player scores
	wire [3:0] score_x;
	wire [3:0] score_0;
	assign score_x = 4'h0;
	assign score_y = 4'h0;
	 
	//assign HEX0 = score_x;
	assign HEX1 = score_y; 
	hex_decoder h1(.hex_digit(score_x), .segments(HEX0));
	 
	 
	//assign LEDR[8:0] = x_moves[8:0];
	//assign LEDR[17:9] = o_moves[8:0];

    // Output game moves to leds
	assign LEDR[8:0] = game_moves[8:0];
	
    // Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(reset),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "grid2.mif";

    // Instance of player turn control
    player_turn_control ptc (
        .enable(enable),
        .reset(!reset),
        .clock(CLOCK_50),
        .enable_x(en_x),
        .enable_o(en_o),
        .writeEn(writeEn),
		  .VGA(VGA),
		  .valid(valid)
    );

    // instance od player data path
    player_datapath pdatap(
        .reset(!reset),
        .enable_x(en_x),
        .enable_o(en_o),
        .clock(CLOCK_50),
        .x_moves(x_moves),
        .o_moves(o_moves),
        .x_input(SW[8:0]),
        .o_input(SW[17:9]),
		.game_moves(game_moves),
		.x_out(x),
		.y_out(y),
        .writeEn(writeEn),
		  .colour(colour)
    );
	 
     // instance of check wins module
	 check_wins checw (
	 .clock(CLOCK_50),
	 .x_moves(x_moves),
	 .o_moves(o_moves),
	 .winx(winx),
	 .wino(wino),
	 .draw(draw1),
	 .game(game_moves),
	 .reset(!reset)
	 );
	 
     // instance of valid moves
	 valid_move vm (
	  .x_input(SW[7:0]),
	  .o_input(SW[17:9]),
	  .game_moves(game_moves),
	  .enable(enable),
	  .is_valid(valid),
	  .clock(CLOCK_50)
	  );
	 	 
endmodule

// Determine whose turn it is
module player_turn_control(enable, reset, clock, enable_x, enable_o, writeEn, valid);
    // required input and outputs
    input enable, reset, clock;
	input valid;
    output reg enable_x, enable_o, writeEn;

    // store cur game state
    reg [2:0] cur_state;
    reg[2:0] next_state;

    // Different states for the state table
    localparam load_x = 3'b000;
    localparam wait_x = 3'b001;
    localparam draw_x = 3'b010;
	localparam draw_x_wait= 3'b011;
    localparam load_o = 3'b100;
    localparam wait_o = 3'b101;
	localparam draw_o = 3'b110;
	localparam draw_o_wait= 3'b111;

    // State table to control player turns. First it is player x's turn, wait until input, then move onto player o's turn on
    // next input
    always@(*)
    begin: turn_state_table
		 case (cur_state)
					load_x: next_state = enable ? wait_x : load_x;
					wait_x: next_state = enable ? wait_x : load_o;
					//draw_x: next_state = enable ? draw_x_wait : draw_x;
					//draw_x_wait: next_state = enable? draw_x_wait : load_o;
					load_o: next_state = enable ? wait_o : load_o;
					wait_o: next_state = enable ? wait_o : load_x;
					//draw_o: next_state = enable ? draw_o_wait : draw_o;
					//draw_o_wait: next_state = enable? draw_o_wait : load_x;
			  default: next_state = load_x;
		endcase
    end

    // State table to control game enables required for reading in player input and drawing to VGA (either load player x or player o).
    always@(*)
    begin: player_enable_state_table
        enable_o = 1'b0;
        enable_x = 1'b0;
        writeEn = 1'b0;
        case (cur_state)
            load_x: begin
				enable_x = 1'b1;
				writeEn = 1'b1;
				end
            load_o: begin
				enable_o = 1'b1;
				writeEn = 1'b1;
				end
        endcase

    end

    // Finally, reset cur state on reset enable, or make cur_state the next state from state table
    always@(posedge clock)
    begin: store_state
        if (reset) begin
            cur_state <= wait_x;
        end else
            cur_state <= next_state;
    end

endmodule

// Determine is player move was legal
module valid_move(x_input, o_input, game_moves, enable, is_valid, clock);
    // Require player moves and single bit output
	input [8:0] x_input, o_input, game_moves;
	input clock;
	input enable;
	output reg is_valid;
	
    //check if player's move is not already a move in the stored game_moves
    // Check each player move option, set bit to 1 is move is valid
	always@(posedge clock) 
	begin
        // reset
		is_valid <= 1'b0;
		if (enable) begin
            // Check each Section and cross check with game moves, if player move is not in game moves, play was valid
            // Section 0
            if (x_input == 9'b000000001 && !o_input) begin
					if (!game_moves[0]) begin
						is_valid <= 1'b1;
					end
            // Section 1   
            end else if (x_input == 9'b000000010) begin
					if (!game_moves[1]) begin
						is_valid <= 1'b1;
					end
            // Section 2
            end else if (x_input == 9'b000000100) begin
					if (!game_moves[2]) begin
						is_valid <= 1'b1;
					end
            // Section 3
            end else if (x_input == 9'b000001000) begin
					if (!game_moves[3]) begin
						is_valid <= 1'b1;
					end
            // Section 4
            end else if (x_input == 9'b000010000) begin
					if (!game_moves[4]) begin
						is_valid <= 1'b1;
					end
            // Section 5
            end else if (x_input == 9'b000100000) begin
					if (!game_moves[5]) begin
						is_valid <= 1'b1;
					end
            // Section 6
            end else if (x_input == 9'b001000000) begin
					if (!game_moves[6]) begin
						is_valid <= 1'b1;
					end
            // Section 7
            end else if (x_input == 9'b010000000) begin
					if (!game_moves[7]) begin
						is_valid <= 1'b1;
					end
            // Section 8
            end else if (x_input == 9'b100000000) begin
					if (!game_moves[8]) begin
						is_valid <= 1'b1;
					end
            // now check for player o, same Sections
            end else if (o_input == 9'b000000001) begin
				if (!game_moves[0]) begin
						is_valid <= 1'b1;
					end
            end else if (o_input == 9'b000000010) begin
					if (!game_moves[1]) begin
						is_valid <= 1'b1;
					end
            end else if (o_input == 9'b000000100) begin
					if (!game_moves[2]) begin
						is_valid <= 1'b1;
					end
            end else if (o_input == 9'b000001000) begin
					if (!game_moves[3]) begin
						is_valid <= 1'b1;
					end
            end else if (o_input == 9'b000010000) begin
					if (!game_moves[4]) begin
						is_valid <= 1'b1;
					end
            end else if (o_input == 9'b000100000) begin
					if (game_moves[5]) begin
						is_valid <= 1'b0;
					end
            end else if (o_input == 9'b001000000) begin
					if (!game_moves[6]) begin
						is_valid <= 1'b1;
					end
            end else if (o_input == 9'b010000000) begin
					if (!game_moves[7]) begin
						is_valid <= 1'b1;
					end
            end
        end
	end 
endmodule

// control how user entered data is stored, and used to output to the de2 board and VGA
module player_datapath(reset, enable_x, enable_o, clock, x_moves, o_moves, x_input, o_input, game_moves, x_out, y_out, writeEn, colour);        
    // Require reset, all enables, clock and player input
    input reset, enable_x, enable_o, clock;
    input [8:0] x_input, o_input;
    input writeEn;

    // output the stored moves, and vga data
    output reg [8:0] x_moves, o_moves; // indiviual player moves
    output reg [8:0] game_moves; // game moves (track which sections are used)
    output [7:0] x_out;
	output [6:0] y_out;
	output [2:0] colour;
 
	reg[7:0] x;
	reg[6:0] y;
	
	reg [7:0] temp_x;
	reg [6:0] temp_y;
	reg [2:0] temp_c;
	reg [3:0] count_xy;
	
	reg [8:0] resetBoard;

    // Datapath
    always@(posedge clock)
    begin: store_moves
        // on reset, clear all data
        if (reset) begin
            x_moves <= 9'b000000000;
            o_moves <= 9'b000000000;
            game_moves <= 9'b000000000;
				resetBoard <= 9'b000000001;
        end
        // if it is player x's turn, check which section of the board they played their move and store their move
        // into the player register and game register
        else if (enable_x) begin
            // if player played in section 0, save the move in the registers 
            if (x_input == 9'b000000001) begin
                x_moves[0] <= 1'b1;
                game_moves[0] <= 1'b1;
                temp_x <= 8'd26;
					 temp_y <= 7'd20;
			    temp_c <= 3'b101;
            // Section 1
            end else if (x_input == 9'b000000010) begin
                x_moves[1] <= 1'b1;
                game_moves[1] <= 1'b1;
                temp_x <= 8'd79;
			    temp_y <= 7'd20;
			    temp_c <= 3'b101;
            // Section 2
            end else if (x_input == 9'b000000100) begin
                x_moves[2] <= 1'b1;
                game_moves[2] <= 1'b1;
                temp_x <= 8'd132;
			    temp_y <= 7'd20;
			    temp_c <= 3'b101;
            // Section 3
            end else if (x_input == 9'b000001000) begin
                x_moves[3] <= 1'b1;
                game_moves[3] <= 1'b1;
                temp_x <= 8'd26;
			    temp_y <= 7'd60;
			    temp_c <= 3'b101;
            // Section 4
            end else if (x_input == 9'b000010000) begin
                x_moves[4] <= 1'b1;
                game_moves[4] <= 1'b1;
                temp_x <= 8'd79;
			    temp_y <= 7'd60;
			    temp_c <= 3'b101;
            // Section 5
            end else if (x_input == 9'b000100000) begin
                x_moves[5] <= 1'b1;
                game_moves[5] <= 1'b1;
                temp_x <= 8'd132;
			    temp_y <= 7'd60;
			    temp_c <= 3'b101;
            // Section 6
            end else if (x_input == 9'b001000000) begin
                x_moves[6] <= 1'b1;
                game_moves[6] <= 1'b1;
                temp_x <= 8'd26;
			    temp_y <= 7'd100;
			    temp_c <= 3'b101;
            // Section 7
            end else if (x_input == 9'b010000000) begin
                x_moves[7] <= 1'b1;
                game_moves[7] <= 1'b1;
                temp_x <= 8'd79;
			    temp_y <= 7'd100;
			    temp_c <= 3'b101;
            // Section 8
            end else if (x_input == 9'b100000000) begin
                x_moves[8] <= 1'b1;
                game_moves[8] <= 1'b1;
                temp_x <= 8'd132;
			    temp_y <= 7'd100;
			    temp_c <= 3'b101;
            end
        end
        // If it is player o's turn, check the same data, but store moves in the player o register instead
        else if (enable_o) begin
            if (o_input == 9'b000000001) begin
                o_moves[0] <= 1'b1;
                game_moves[0] <= 1'b1;
                temp_x <= 8'd26;
					 temp_y <= 7'd20;
			    temp_c <= 3'b010;
            end else if (o_input == 9'b000000010) begin
                o_moves[1] <= 1'b1;
                game_moves[1] <= 1'b1;
                temp_x <= 8'd79;
			    temp_y <= 7'd20;
			    temp_c <= 3'b010;
            end else if (o_input == 9'b000000100) begin
                o_moves[2] <= 1'b1;
                game_moves[2] <= 1'b1;
                temp_x <= 8'd132;
			    temp_y <= 7'd20;
			    temp_c <= 3'b010;
            end else if (o_input == 9'b000001000) begin
                o_moves[3] <= 1'b1;
                game_moves[3] <= 1'b1;
                temp_x <= 8'd26;
			    temp_y <= 7'd60;
			    temp_c <= 3'b010;
            end else if (o_input == 9'b000010000) begin
                o_moves[4] <= 1'b1;
                game_moves[4] <= 1'b1;
                temp_x <= 8'd79;
			    temp_y <= 7'd60;
			    temp_c <= 3'b010;
            end else if (o_input == 9'b000100000) begin
                o_moves[5] <= 1'b1;
                game_moves[5] <= 1'b1;
                temp_x <= 8'd132;
			    temp_y <= 7'd60;
			    temp_c <= 3'b010;
            end else if (o_input == 9'b001000000) begin
                o_moves[6] <= 1'b1;
                game_moves[6] <= 1'b1;
                temp_x <= 8'd26;
			    temp_y <= 7'd100;
			    temp_c <= 3'b010;
            end else if (o_input == 9'b010000000) begin
                o_moves[7] <= 1'b1;
                game_moves[7] <= 1'b1;
                temp_x <= 8'd79;
			    temp_y <= 7'd100;
			    temp_c <= 3'b010;
            end else if (o_input == 9'b100000000) begin
                o_moves[8] <= 1'b1;
                game_moves[8] <= 1'b1;
                temp_x <= 8'd132;
			    temp_y <= 7'd100;
			    temp_c <= 3'b010;
            end
        end
		  
		  
		
    end
    // counter
	/*always @(posedge clock) begin
		if (!reset)
			count_xy <= 4'd0;
		else
			count_xy <= count_xy + 4'd1;
	end*/
	
	
	// set x,y colour out
	
	/*always@(posedge clock)
	 begin
	     if (!reset) count_xy <= 4'b0;
		   else if (writeEn) count_xy <= count_xy + 4'b0010;
	 end

	 always@(posedge clock)
	 begin
	     if (!reset) begin
		      x <= 8'b0;
				  y <= 7'b0;
				 colour = 3'b0;
				  end
		  else if (writeEn) begin
		      x <= temp_x + {6'b0, count_xy[1:0]};
				  y <= temp_y + {5'b0, count_xy[3:2]};
				colour = temp_c[2:0];
				  end
	end*/
	
	/*
	reset_board rboard(
	.temp_x(temp_x),
	.temp_y(temp_y),
	.colour(colour),
	.clock(clock),
	.is_reset(1'b1));
	*/
	

	assign x_out = temp_x; //+ count_xy[1:0];
	assign y_out = temp_y; //+ count_xy[3:2];
	assign colour = temp_c[2:0];


endmodule

/*
module reset_board(temp_x, temp_y, colour, clock, is_reset);
	//input [8:0] resetBoard;
	input clock, is_reset;
	output reg [7:0] temp_x;
	output reg [6:0] temp_y;
	reg [3:0] temp_c;
	output reg [3:0] colour;
	
	reg [8:0] board_reset;
	
	always@(posedge clock)
    begin
		if (is_reset) begin
		board_reset <= 9'b000000001;
		end
		if (board_reset == 9'b000000001) begin
			temp_x <= 8'd26;
			temp_y <= 7'd20;
			temp_c <= 3'b101;
			board_reset = 9'b000000010;
		end else if (board_reset == 9'b000000010) begin
			temp_x <= 8'd79;
			temp_y <= 7'd20;
			temp_c <= 3'b101;
			board_reset <= 9'b000000010;
		end else if (board_reset == 9'b000000010) begin
			temp_x <= 8'd132;
			temp_y <= 7'd20;
			temp_c <= 3'b101;
			board_reset <= 9'b000000010;
		end else if (board_reset == 9'b000000010) begin
			temp_x <= 8'd26;
			temp_y <= 7'd60;
			temp_c <= 3'b000;
			board_reset <= 9'b000000010;
		end else if (board_reset == 9'b000000010) begin
			temp_x <= 8'd79;
			temp_y <= 7'd60;
			temp_c <= 3'b000;
			board_reset <= 9'b000000010;
		end else if (board_reset == 9'b000000010) begin
			temp_x <= 8'd132;
			temp_y <= 7'd60;
			temp_c <= 3'b000;
			board_reset <= 9'b000000010;
		end else if (board_reset == 9'b000000010) begin
			temp_x <= 8'd26;
			temp_y <= 7'd100;
			temp_c <= 3'b000;
			board_reset <= 9'b000000010;
		end else if (board_reset == 9'b000000010) begin
			temp_x <= 8'd79;
			temp_y <= 7'd100;
			temp_c <= 3'b000;
			board_reset <= 9'b000000010;
		end else if (board_reset == 9'b000000010) begin
			temp_x <= 8'd132;
			temp_y <= 7'd100;
			temp_c <= 3'b000;
			board_reset <= 9'b000000000;
		end
	end
		
endmodule
*/

// check if any player won, or the game ended in a tie
module check_wins(clock, x_moves, o_moves, winx, wino, draw, game, reset);
    // input the player moves and output the result if game is done
    input clock;
	input reset;
    input [9:0] x_moves, o_moves, game;
    output reg winx, wino, draw;
	 
     // Check every possible win for both players
    always@(posedge clock)
    begin: check_win
          // clear game results on reset
		  if (reset) begin
				winx <= 1'b0;
				wino <= 1'b0;
				draw <= 1'b0;
		  end
        // check if player x won and set result for:
        // row 1
        if (x_moves[0] && x_moves[1] && x_moves[2]) begin
            winx <= 1'b1;
				wino <= 1'b0;
				draw <= 1'b0;
        // row 2
        end else if (x_moves[3] && x_moves[4] && x_moves[5]) begin
            winx <= 1'b1;
				wino <= 1'b0;
				draw <= 1'b0;
        end
        // row 3
        else if (x_moves[6] && x_moves[7] && x_moves[8]) begin
            winx <= 1'b1;
				wino <= 1'b0;
				draw <= 1'b0;
        end
        // coloumn 1
        else if (x_moves[0] && x_moves[3] && x_moves[6]) begin
            winx <= 1'b1;
				wino <= 1'b0;
				draw <= 1'b0;
        end
        // coloumn 2
        else if (x_moves[1] && x_moves[4] && x_moves[7]) begin
            winx <= 1'b1;
				wino <= 1'b0;
				draw <= 1'b0;
        end
        // coloumn 3
        else if (x_moves[2] && x_moves[5] && x_moves[8]) begin
            winx <= 1'b1;
				wino <= 1'b0;
				draw <= 1'b0;
        end
        // diagonal top left to bottom right
        else if (x_moves[0] && x_moves[4] && x_moves[8]) begin
            winx <= 1'b1;
				wino <= 1'b0;
				draw <= 1'b0;
        end
        // diagonal bottom left to top right
        else if (x_moves[2] && x_moves[4] && x_moves[6]) begin
            winx <= 1'b1;
				wino <= 1'b0;
				draw <= 1'b0;
        end

        // check same conditions for player o
        if (o_moves[0] && o_moves[1] && o_moves[2]) begin
            wino <= 1'b1;
				winx <= 1'b0;
				draw <= 1'b0;
        end else if (o_moves[3] && o_moves[4] && o_moves[5]) begin
            wino <= 1'b1;
				winx <= 1'b0;
				draw <= 1'b0;
        end
        else if (o_moves[6] && o_moves[7] && o_moves[8]) begin
            wino <= 1'b1;
				winx <= 1'b0;
				draw <= 1'b0;
        end
        else if (o_moves[0] && o_moves[3] && o_moves[6]) begin
            wino <= 1'b1;
				winx <= 1'b0;
				draw <= 1'b0;
        end
        else if (o_moves[1] && o_moves[4] && o_moves[7]) begin
            wino <= 1'b1;
				winx <= 1'b0;
				draw <= 1'b0;
        end
        else if (o_moves[2] && o_moves[5] && o_moves[8]) begin
            wino <= 1'b1;
				winx <= 1'b0;
				draw <= 1'b0;
        end
        else if (o_moves[0] && o_moves[4] && o_moves[8]) begin
            wino <= 1'b1;
				winx <= 1'b0;
				draw <= 1'b0;
        end
        else if (o_moves[2] && o_moves[4] && o_moves[6]) begin
            wino <= 1'b1;
				winx <= 1'b0;
				draw <= 1'b0;
        end
		  
          // If no one has won and game is full, game ended in a tie
		  if (!wino && !winx && game == 9'b111111111) begin
				draw <= 1'b1;
				winx <= 1'b0;
				wino <= 1'b0;
		  end
    end


endmodule

// Hex decoder provided by the professor
module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;

    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule