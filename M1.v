`timescale 1ns/100ps
`default_nettype none

`include "define_state.h"


module M1 (
  input logic Clock,
  input logic Resetn,
  input logic Start,
  output logic Stop,
		
  output logic[17:0]   SRAM_address,
  output logic[15:0]   SRAM_write_data,
  output logic         SRAM_we_n,
  input logic[15:0]    SRAM_read_data
);

logic [17:0] Y_START = 18'd0;
logic [17:0] U_START = 18'd38400;
logic [17:0] V_START = 18'd57600;
logic [17:0] RGB_START = 18'd146944;

logic [15:0] IMG_WIDTH = 16'd320;
logic [15:0] IMG_HEIGHT = 16'd240;
logic [31:0] NUM_ITERATIONS = 32'd19200;//(IMG_WIDTH * IMG_HEIGHT) >> 2;

logic [7:0] Yp0, Yp1, Yp2, Yp3; //No need to buffer since no upsampling. Just fetch the correct address.
logic [7:0] YP0, YP1, YP2, YP3;
logic [7:0] Un4, Un2, U0, Up2, Up4, Up6, Up8, Up10;
logic [7:0] UP8, UP10;
logic [7:0] Vn4, Vn2, V0, Vp2, Vp4, Vp6, Vp8, Vp10; //Vp10,8 always_comb set, rest always_ff.
logic [7:0] VP8, VP10;

logic signed [31:0] mult00, mult01, mult10, mult11, mult20, mult21, mult30, mult31;
logic signed [63:0] MULT0, MULT1, MULT2, MULT3;

logic [7:0] R0, G0, B0, R1, G1, B1, R2, G2, B2, R3, G3, B3; //FF
logic [7:0] r0, g0, b0, r1, g1, b1, r2, g2, b2, r3, g3, b3; //comb
logic signed [31:0] r_unclipped, g_unclipped, b_unclipped; //comb

logic signed [31:0] U_0, U_1, U_2, U_3,
                    V_0, V_1, V_2, V_3;


logic signed [31:0] U_3B0, U_3B1, U_3B2;
logic signed [63:0] A11, A21, A31_0, A31_1, A31_2, A31_3;

logic[17:0] ITERATION;

enum logic [7:0] {
  IDLE,
  I0, I1, I2, I3, I4, I5, I6,
  C0, C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11,
  O0
} STATE;


always_comb begin
  MULT0 = $signed(mult00 * mult01);
  MULT1 = $signed(mult10 * mult11);
  MULT2 = $signed(mult20 * mult21);
  MULT3 = $signed(mult30 * mult31);
end

always_comb begin
  YP0 = 0; YP1 = 0; YP2 = 0; YP3 = 0;
  UP8 = 0; UP10 = 0;
  VP8 = 0; VP10 = 0;
  r_unclipped = 0; g_unclipped = 0; b_unclipped = 0;
  mult00 = 0; mult01 = 0;
  mult10 = 0; mult11 = 0;
  mult20 = 0; mult21 = 0;
  mult30 = 0; mult31 = 0;
  r0 = 0; r1 = 0; r2 = 0; r3 = 0;
  g0 =0; g1 = 0; g2 = 0; g3 = 0;
  b0 = 0; b1 = 0; b2 = 0; b3 = 0;

  case(STATE)
	C3: begin
		YP0 = SRAM_read_data[15:8];
		YP1 = SRAM_read_data[7:0];

		mult00 = 32'd76284;
		mult01 = YP0 - 8'd16;
		mult10 = 32'd76284;
		mult11 = YP1 - 8'd16;

	end
	C4: begin
		YP2 = SRAM_read_data[15:8];
		YP3 = SRAM_read_data[7:0];

		mult20 = 32'd76284;
		mult21 = YP2 - 8'd16;
		mult30 = 32'd76284;
		mult31 = YP3 - 8'd16;
		
	end
	C5: begin
		if((ITERATION % (IMG_WIDTH >> 2)) > ((IMG_WIDTH >> 2) - 3)) begin
			UP8 = Up6;
			UP10 = Up6;
		end
		else begin
			UP8 = SRAM_read_data[15:8];
			UP10 = SRAM_read_data[7:0];
		end

		//For U_1
		mult00 = 32'd21;
		mult01 = Up6 + Un4;
		mult10 = 32'd52;
		mult11 = Up4 + Un2;
		mult20 = 32'd159;
		mult21 = Up2 + U0; //Between p(+)2 and 0, therefore 1.

		//For U_3, buffered.
		mult30 = 32'd21;
		mult31 = UP8 + Un2;
	end
	C6: begin
		if((ITERATION % (IMG_WIDTH >> 2)) > ((IMG_WIDTH >> 2) - 3)) begin
			VP8 = Vp6;
			VP10 = Vp6;
		end
		else begin
			VP8 = SRAM_read_data[15:8];
			VP10 = SRAM_read_data[7:0];
		end

		//For V_1
		mult00 = 32'd21;
		mult01 = Vp6 + Vn4;
		mult10 = 32'd52;
		mult11 = Vp4 + Vn2;
		mult20 = 32'd159;
		mult21 = Vp2 + V0; //Between V+2 and V0, so V_1.
		
		//For U_3, buffered.
		mult30 = 32'd52;
		mult31 = Up6 + U0;
	end
	C7: begin
		mult00 = 32'd104595;
		mult01 = V_0 - 32'd128;
		mult10 = -32'd25624;
		mult11 = U_0 - 32'd128;
		mult20 = -32'd53281;
		mult21 = V_0 - 32'd128;
		mult30 = 32'd132251;
		mult31 = U_0 - 32'd128;

		r_unclipped = (A31_0 + MULT0) >>> 16;
		g_unclipped = (A31_0 + MULT1 + MULT2) >>> 16;
		b_unclipped = (A31_0 + MULT3) >>> 16;

		if(r_unclipped >= 0) begin
			if(r_unclipped < 256) r0 = r_unclipped[7:0];
			else r0 = 8'd255;
		end
		else r0 = 0;

		if(g_unclipped > 0) begin
			if(g_unclipped < 256) g0 = g_unclipped[7:0];
			else g0 = 8'd255;
		end
		else g0 = 0;

		if(b_unclipped > 0) begin
			if(b_unclipped < 256) b0 = b_unclipped[7:0];
			else b0 = 8'd255;
		end
		else b0 = 0;
	end
	C8: begin
		mult00 = 32'd104595;
		mult01 = V_1 - 32'd128;
		mult10 = -32'd25624;
		mult11 = U_1 - 32'd128;
		mult20 = -32'd53281;
		mult21 = V_1 - 32'd128;
		mult30 = 32'd132251;
		mult31 = U_1 - 32'd128;


		r_unclipped = (A31_1 + MULT0) >>> 16;
		g_unclipped = (A31_1 + MULT1 + MULT2) >>> 16;
		b_unclipped = (A31_1 + MULT3) >>> 16;

		if(r_unclipped >= 0) begin
			if(r_unclipped < 256) r1 = r_unclipped[7:0];
			else r1 = 8'd255;
		end
		else r1 = 0;

		if(g_unclipped > 0) begin
			if(g_unclipped < 256) g1 = g_unclipped[7:0];
			else g1 = 8'd255;
		end
		else g1 = 0;

		if(b_unclipped > 0) begin
			if(b_unclipped < 256) b1 = b_unclipped[7:0];
			else b1 = 8'd255;
		end
		else b1 = 0;
	end
	C9: begin
		//For V_3
		mult00 = 32'd21;
		mult01 = Vp8 + Vn2;
		mult10 = 32'd52;
		mult11 = Vp6 + V0;
		mult20 = 32'd159;
		mult21 = Vp4 + Vp2; //3 in between.

		//For U_3, buffered.
		mult30 = 32'd159;
		mult31 = Up4 + Up2; //Between 2 and 4, therefore 3.
	end
	C10: begin
		mult00 = 32'd104595;
		mult01 = V_2 - 32'd128;
		mult10 = -32'd25624;
		mult11 = U_2 - 32'd128;
		mult20 = -32'd53281;
		mult21 = V_2 - 32'd128;
		mult30 = 32'd132251;
		mult31 = U_2 - 32'd128;

		r_unclipped = (A31_2 + MULT0) >>> 16;
		g_unclipped = (A31_2 + MULT1 + MULT2) >>> 16;
		b_unclipped = (A31_2 + MULT3) >>> 16;

		if(r_unclipped >= 0) begin
			if(r_unclipped < 256) r2 = r_unclipped[7:0];
			else r2 = 8'd255;
		end
		else r2 = 0;

		if(g_unclipped > 0) begin
			if(g_unclipped < 256) g2 = g_unclipped[7:0];
			else g2 = 8'd255;
		end
		else g2 = 0;

		if(b_unclipped > 0) begin
			if(b_unclipped < 256) b2 = b_unclipped[7:0];
			else b2 = 8'd255;
		end
		else b2 = 0;
	end
	C11: begin
		mult00 = 32'd104595;
		mult01 = V_3 - 32'd128;
		mult10 = -32'd25624;
		mult11 = U_3 - 32'd128;
		mult20 = -32'd53281;
		mult21 = V_3 - 32'd128;
		mult30 = 32'd132251;
		mult31 = U_3 - 32'd128;

		r_unclipped = (A31_3 + MULT0) >>> 16;
		g_unclipped = (A31_3 + MULT1 + MULT2) >>> 16;
		b_unclipped = (A31_3 + MULT3) >>> 16;

		if(r_unclipped >= 0) begin
			if(r_unclipped < 256) r3 = r_unclipped[7:0];
			else r3 = 8'd255;
		end
		else r3 = 0;

		if(g_unclipped > 0) begin
			if(g_unclipped < 256) g3 = g_unclipped[7:0];
			else g3 = 8'd255;
		end
		else g3 = 0;

		if(b_unclipped > 0) begin
			if(b_unclipped < 256) b3 = b_unclipped[7:0];
			else b3 = 8'd255;
		end
		else b3 = 0;
	end
  endcase
end

logic [17:0] IDLE_PERIOD_WRITE_ADDRESS;
logic [15:0] IDLE_PERIOD_WRITE_DATA;
logic IDLE_SHOULD_WRITE_BE_PERFORMED;

always_ff @(posedge Clock or negedge Resetn) begin
  if(~Resetn) begin
	STATE <= IDLE;
	Stop <= 0;

	R0 <= 0; R1 <= 0; R2 <= 0; R3 <= 0;
	G0 <= 0; G1 <= 0; G2 <= 0; G3 <= 0;
	B0 <= 0; B1 <= 0; B2 <= 0; B3 <= 0;
	U_0 <= 0; U_1 <= 0; U_2 <= 0; U_3 <= 0;
	V_0 <= 0; V_1 <= 0; V_2 <= 0; V_3 <= 0;

	Yp0 <= 0; Yp1 <= 0; Yp2 <= 0; Yp3 <=0;
	Un4 <=0; Un2 <=0; U0 <= 0; Up2 <= 0; Up4 <=0; Up6 <= 0; Up8 <= 0; Up10 <= 0;
	Vn4 <= 0; Vn2 <= 0; V0 <= 0; Vp2 <=0; Vp4 <= 0; Vp6 <= 0; Vp8 <= 0; Vp10 <=0;

	IDLE_PERIOD_WRITE_ADDRESS <= 0;
	IDLE_PERIOD_WRITE_DATA <= 0;
	IDLE_SHOULD_WRITE_BE_PERFORMED <= 0;
  end
  else begin
	case(STATE)
		IDLE: begin
			SRAM_address <= 0;
			SRAM_write_data <= 0;
			SRAM_we_n <= 1;

			ITERATION <= 0;

			if(Start && ~Stop) STATE <= I0;
			else STATE <= IDLE;
		end
		I0: begin
			SRAM_we_n <= 1;
			SRAM_address <= U_START + ITERATION;
			STATE <= I1;
		end
		I1: begin
			SRAM_we_n <= 1;
			SRAM_address <= U_START + ITERATION + 1;
			STATE <= I2;
		end
		I2: begin
			SRAM_we_n <= 1;
			SRAM_address <= V_START + ITERATION;
			STATE <= I3;
		end
		I3: begin
			Up2 <= SRAM_read_data[7:0];
			U0 <= SRAM_read_data[15:8];
			Un2 <= SRAM_read_data[15:8];
			Un4 <= SRAM_read_data[15:8];

			SRAM_we_n <= 1;
			SRAM_address <= V_START + ITERATION + 1;
			STATE <= I4;
		end
		I4: begin
			Up4 <= SRAM_read_data[15:8];
			Up6 <= SRAM_read_data[7:0];
			Up8 <= 0;
			Up10 <= 0;

			STATE <= I5;
		end
		I5: begin
			Vp2 <= SRAM_read_data[7:0];
			V0 <= SRAM_read_data[15:8];
			Vn2 <= SRAM_read_data[15:8];
			Vn4 <= SRAM_read_data[15:8];

			STATE <= I6;
		end
		I6: begin
			Vp4 <= SRAM_read_data[15:8];
			Vp6 <= SRAM_read_data[7:0];
			Vp8 <= 0;
			Vp10 <= 0;

			STATE <= C0;
		end
		C0: begin
			SRAM_address <= Y_START + (ITERATION << 1);
			SRAM_we_n <= 1;

			STATE <= C1;
		end
		C1: begin
			SRAM_address <= Y_START + 1 + (ITERATION << 1);
			SRAM_we_n <= 1;

			STATE <= C2;
		end
		C2: begin
			SRAM_address <= U_START + ITERATION + 2; //+2 for the read being +2 addresses (+4 values) ahead.
			SRAM_we_n <= 1;

			
			STATE <= C3;
		end
		C3: begin
			SRAM_address <= V_START + ITERATION + 2; //+2 for the read being +2 addresses (+4 values) ahead.
			SRAM_we_n <= 1;

			Yp0 <= YP0;
			Yp1 <= YP1;

			A31_0 <= MULT0;
			A31_1 <= MULT1;

			STATE <= C4;
		end
		C4: begin
			if(IDLE_SHOULD_WRITE_BE_PERFORMED) begin
				SRAM_we_n <= 0;
				SRAM_address <= IDLE_PERIOD_WRITE_ADDRESS;
				SRAM_write_data <= IDLE_PERIOD_WRITE_DATA;
				IDLE_SHOULD_WRITE_BE_PERFORMED <= 0;
			end

			A31_2 <= MULT2;
			A31_3 <= MULT3;
			
			Yp2 <= YP2;
			Yp3 <= YP3;

			STATE <= C5;
		end
		C5: begin
			Up10 <= UP10;
			Up8 <= UP8;

			U_0 <= U0;
			U_1 <= (MULT0 + MULT2 + 32'd128 - MULT1) >> 8;
			U_2 <= Up2;
			
			U_3B0 <= MULT3;
			SRAM_we_n <= 1;
			STATE <= C6;
		end
		C6: begin
			Vp10 <= VP10;
			Vp8 <= VP8;

			V_0 <= V0;
			V_1 <= (MULT0 - MULT1 + MULT2 + 32'd128) >> 8;
			V_2 <= Vp2;

			U_3B1 <= MULT3;

			STATE <= C7;
		end
		C7: begin
			R0 <= r0;
			G0 <= g0;
			B0 <= b0;

			SRAM_we_n <= 0;
			SRAM_address <= RGB_START + 0 + (ITERATION << 2) + (ITERATION << 1);
			SRAM_write_data <= {r0, g0};

			STATE <= C8;
		end
		C8: begin
			R1 <= r1;
			G1 <= g1;
			B1 <= b1;

			SRAM_we_n <= 0;
			SRAM_address <= RGB_START + 1 + (ITERATION << 2) + (ITERATION << 1);
			SRAM_write_data <= {B0, r1};

			STATE <= C9;
		end
		C9: begin
			U_3B2 <= MULT3; //Not ready for this clock cycle.
			U_3 <= (U_3B0 - U_3B1 + MULT3 + 32'd128) >> 8;
			V_3 <= (MULT0 - MULT1 + MULT2 + 32'd128) >> 8;

			SRAM_we_n <= 0;
			SRAM_address <= RGB_START + 2 + (ITERATION << 2) + (ITERATION << 1);
			SRAM_write_data <= {G1, B1};

			STATE <= C10;
		end
		C10: begin
			R2 <= r2;
			G2 <= g2;
			B2 <= b2;

			SRAM_we_n <= 0;
			SRAM_address <= RGB_START + 3 + (ITERATION << 2) + (ITERATION << 1);
			SRAM_write_data <= {r2, g2};

			STATE <= C11;
		end
		C11: begin
			R3 <= r3;
			G3 <= g3;
			B3 <= b3;

			SRAM_we_n <= 0;
			SRAM_address <= RGB_START + 4 + (ITERATION << 2) + (ITERATION << 1);
			SRAM_write_data <= {B2, r3};

			//C12 absorb:
			IDLE_PERIOD_WRITE_ADDRESS <= RGB_START + 5 + (ITERATION << 2) + (ITERATION << 1);
			IDLE_PERIOD_WRITE_DATA <= {g3, b3};
			IDLE_SHOULD_WRITE_BE_PERFORMED <= 1;

			Up10 <= 0; Up8 <= 0; 
			Up6 <= Up10; Up4 <= Up8; Up2 <= Up6; U0 <= Up4; Un2 <= Up2; Un4 <= U0;

			Vp10 <= 0; Vp8 <= 0; 
			Vp6 <= Vp10; Vp4 <= Vp8; Vp2 <= Vp6; V0 <= Vp4; Vn2 <= Vp2; Vn4 <= V0;
			

			ITERATION <= ITERATION + 1;

			if(ITERATION == NUM_ITERATIONS - 1) STATE <= O0;
			else if(ITERATION % (IMG_WIDTH >> 2) == ((IMG_WIDTH >> 2) - 1)) STATE <= I0; //Downsampled original with WIDTH/2.
			else STATE <= C0;
		end
		O0: begin
			//This state exists to make the final writeout that can't be fulfilled during the IO IDLE period
			//in the next common cycle, since there won't be a next common cycle.
			if(IDLE_SHOULD_WRITE_BE_PERFORMED) begin
				SRAM_we_n <= 0;
				SRAM_address <= IDLE_PERIOD_WRITE_ADDRESS;
				SRAM_write_data <= IDLE_PERIOD_WRITE_DATA;
				IDLE_SHOULD_WRITE_BE_PERFORMED <= 0;
			end

			STATE <= IDLE;
			Stop <= 1;
		end
	endcase
  end
end
endmodule