`timescale 1ns/100ps
`default_nettype none

`include "define_state.h"

module Milestone1 (
   input  logic            CLOCK,
   input  logic            Resetn, 

   input  logic            m1_start,
   output  logic            m1_done,
   
   output logic   [7:0]    j,
   output logic   [7:0]    row,
   
   output logic   [7:0]    R_even, R_odd, G_even, G_odd, B_even, B_odd,
   //output logic   [4:0]    m1_state,
   
   output logic   [17:0]   SRAM_address,
   output logic   [15:0]   SRAM_write_data,
   input logic    [15:0]   SRAM_read_data,
   output logic            SRAM_we_enable
);

milestone_1_state m1_state;

//shift reg variables
logic [7:0] u_p5, u_p3, u_p1, u_m1, u_m3, u_m5, v_p5, v_p3, v_p1, v_m1, v_m3, v_m5;

//RBG variables
//logic [7:0] R_even, R_odd, G_even, G_odd, B_even, B_odd;

//buffer variables
logic [15:0] u_buf, v_buf, y_buf;

//U' & V' variables
logic [15:0] u_even, v_even;
logic [31:0] u_odd, v_odd;

//accumulator variables
logic [31:0] u_acc, v_acc, R_accE, R_accO, G_accE, G_accO, B_accE, B_accO;

//# of pixel pairs and rows
//logic [7:0] row; //will go from 0 to 239
//logic [15:0] j;

//flags and output
logic first_row_value;

//address variables
logic [17:0] y_adr, u_adr, v_adr, rgb_adr;

//multiplier variables
logic [31:0] op1, op2, op3, op4, op5, op6, op7, op8, prod1, prod2, prod3, prod4;
logic [63:0] prod1_long, prod2_long, prod3_long, prod4_long;

//multipliers
assign prod1_long = op1*op2;//$signed(op1*op2);
assign prod1 = prod1_long[31:0];

assign prod2_long = op3*op4;//$signed(op3*op4);
assign prod2 = prod2_long[31:0];

assign prod3_long = op5*op6;//$signed(op5*op6);
assign prod3 = prod3_long[31:0];

assign prod4_long = op7*op8;//$signed(op7*op8);
assign prod4 = prod4_long[31:0];

//always_comb begin
//	if (S_c0 && (j != 8'd159)) begin
//		Uodd = u_acc + prod1;
//		u_odd = Uodd[23:8];
//		Vodd = v_acc + prod2;
//		v_odd = Vodd[23:8];
//	end
//end


always @(posedge CLOCK or negedge Resetn) begin

    if (~Resetn) begin
        
        m1_state <= S_idle;
        
        m1_done <= 1'b0;
    
    end else begin

        case (m1_state)
        S_idle: begin

	       m1_done <= 1'b0;

            y_adr <= 18'd0;
            u_adr <= 18'd38400;
            v_adr <= 18'd57600;
            rgb_adr <= 18'd146944;
            SRAM_we_enable <= 1'b1;
            SRAM_write_data <= 16'd0;

            first_row_value <= 1'b1;
            row <= 8'd0;
            j <= 8'd0;

            u_buf <= 16'd0;
            v_buf <= 16'd0;
            y_buf <= 16'd0;

            u_p5 <= 8'd0;
            u_p3 <= 8'd0;
            u_p1 <= 8'd0;
            u_m1 <= 8'd0;
            u_m3 <= 8'd0;
            u_m5 <= 8'd0;
            v_p5 <= 8'd0;
            v_p3 <= 8'd0;
            v_p1 <= 8'd0;
            v_m1 <= 8'd0;
            v_m3 <= 8'd0;
            v_m5 <= 8'd0;

            R_even <= 8'd0;
            R_odd <= 8'd0;
            G_even <= 8'd0;
            G_odd <= 8'd0;
            B_even <= 8'd0;
            B_odd <= 8'd0;

            u_even <= 16'd0;
            u_odd <= 16'd0;
            v_even <= 16'd0;
            v_odd <= 16'd0;

            u_acc <= 32'd0;
            v_acc <= 32'd0;
            R_accE <= 32'd0;
            R_accO <= 32'd0;
            G_accE <= 32'd0;
            G_accO <= 32'd0;
            B_accE <= 32'd0;
            B_accO <= 32'd0;

            op1 <= 32'd0;
            op2 <= 32'd0;
            op3 <= 32'd0;
            op4 <= 32'd0;
            op5 <= 32'd0;
            op6 <= 32'd0;
            op7 <= 32'd0;
            op8 <= 32'd0;

            if (m1_start)
                m1_state <= S_lead0;

        end

        //read U[0 1]
        S_lead0: begin 
            SRAM_address <= u_adr;
            u_adr <= u_adr + 1'b1;

            SRAM_we_enable <= 1'b1;

            m1_state <= S_lead1;
        end

        // read V[0 1]
        S_lead1: begin 
            SRAM_address <= v_adr;
            v_adr <= v_adr + 1'b1;

            SRAM_we_enable <= 1'b1;

            m1_state <= S_lead2;
        end

        // read U[2 3]
        S_lead2: begin	
            SRAM_address <= u_adr;
            u_adr <= u_adr + 1'b1;

            SRAM_we_enable <= 1'b1;

            m1_state <= S_lead3;
        end

        // read V[2 3] and place the read data of U[0 1] into the U buffer
        S_lead3: begin 
            SRAM_address <= v_adr;
            v_adr <= v_adr + 1'b1;

            SRAM_we_enable <= 1'b1;

            u_buf <= SRAM_read_data;

            m1_state <= S_lead4;
        end

        // read Y[0 1] and place the read data of V[0 1] into the V buffer
        // set the lead in values of the U' shift registers; j-5, j-3, and j-1 are all given the value of the first value of the row in U
        S_lead4: begin 
            SRAM_address <= y_adr;
            y_adr <= y_adr + 1'b1;

            SRAM_we_enable <= 1'b1;

            v_buf <= SRAM_read_data;

            u_m5 <= u_buf[15:8];
            u_m3 <= u_buf[15:8];
            u_m1 <= u_buf[15:8];
            u_p1 <= u_buf[7:0];
            u_even <= u_buf[15:8];

            m1_state <= S_lead5;
        end

        // place the read data of U[2 3] into the U buffer
        // set the lead in values of the V' shift registers; j-5, j-3, and j-1 are all given the value of the first value of the row in V
        S_lead5:  begin
            u_buf <= SRAM_read_data;

            v_m5 <= v_buf[15:8];
            v_m3 <= v_buf[15:8];
            v_m1 <= v_buf[15:8];
            v_p1 <= v_buf[7:0];
            v_even <= v_buf[15:8];

            m1_state <= S_lead6;
        end

        // place the read data of V[2 3] into the V buffer
        // set the lead in values of U' j+3 and j+5
        S_lead6: begin
            v_buf <= SRAM_read_data;

            u_p3 <= u_buf[15:8];
            u_p5 <= u_buf[7:0];

            m1_state <= S_lead7;
        end

        // place the read data of Y[0 1] into the Y buffer
        // set the lead in values of V' j+3 and j+5
        S_lead7: begin 
            y_buf <= SRAM_read_data;

            v_p3 <= v_buf[15:8];
            v_p5 <= v_buf[7:0];

            m1_state <= S_lead8;
        end

        S_lead8: begin
            SRAM_address <= u_adr;
            u_adr <= u_adr +1'b1;

            SRAM_we_enable <= 1'b1;

            op1 <= 16'd21;
            op2 <= u_p5;
            op3 <= 16'd21;
            op4 <= v_p5;

            u_p5 <= u_p3;
            u_p3 <= u_p1;
            u_p1 <= u_m1;
            u_m1 <= u_m3;
            u_m3 <= u_m5;
            u_m5 <= u_p5;

            v_p5 <= v_p3;
            v_p3 <= v_p1;
            v_p1 <= v_m1;
            v_m1 <= v_m3;
            v_m3 <= v_m5;
            v_m5 <= v_p5;

            m1_state <= S_lead9;
        end

        S_lead9: begin
            SRAM_address <= v_adr;
            v_adr <= v_adr +1'b1;

            SRAM_we_enable <= 1'b1;

            op1 <= 16'd52;
            op2 <= u_p5;
            op3 <= 16'd52;
            op4 <= v_p5;

            u_acc <= 16'd128 + prod1;//$signed(16'd128 + prod1);
            v_acc <= 16'd128 + prod2;//$signed(16'd128 + prod2);

            u_p5 <= u_p3;
            u_p3 <= u_p1;
            u_p1 <= u_m1;
            u_m1 <= u_m3;
            u_m3 <= u_m5;
            u_m5 <= u_p5;

            v_p5 <= v_p3;
            v_p3 <= v_p1;
            v_p1 <= v_m1;
            v_m1 <= v_m3;
            v_m3 <= v_m5;
            v_m5 <= v_p5;

            m1_state <= S_lead10;
        end

        S_lead10: begin
            op1 <= 16'd159;
            op2 <= u_p5;
            op3 <= 16'd159;
            op4 <= v_p5;

            u_acc <= u_acc - prod1;//$signed(u_acc - prod1); 
            v_acc <= v_acc - prod2;//$signed(v_acc - prod2);

            u_p5 <= u_p3;
            u_p3 <= u_p1;
            u_p1 <= u_m1;
            u_m1 <= u_m3;
            u_m3 <= u_m5;
            u_m5 <= u_p5;

            v_p5 <= v_p3;
            v_p3 <= v_p1;
            v_p1 <= v_m1;
            v_m1 <= v_m3;
            v_m3 <= v_m5;
            v_m5 <= v_p5;

            m1_state <= S_lead11;
        end

        S_lead11: begin
            u_buf <= SRAM_read_data;

            op1 <= 16'd159;
            op2 <= u_p5;
            op3 <= 16'd159;
            op4 <= v_p5;

            u_acc <= u_acc + prod1;//$signed(u_acc + prod1);
            v_acc <= v_acc + prod2;//$signed(v_acc + prod2);

            u_p5 <= u_p3;
            u_p3 <= u_p1;
            u_p1 <= u_m1;
            u_m1 <= u_m3;
            u_m3 <= u_m5;
            u_m5 <= u_p5;

            v_p5 <= v_p3;
            v_p3 <= v_p1;
            v_p1 <= v_m1;
            v_m1 <= v_m3;
            v_m3 <= v_m5;
            v_m5 <= v_p5;

            m1_state <= S_lead12;
        end

        S_lead12: begin
            v_buf <= SRAM_read_data;

            op1 <= 16'd52;
            op2 <= u_p5;
            op3 <= 16'd52;
            op4 <= v_p5;

            u_acc <= u_acc + prod1;//$signed(u_acc + prod1); 
            v_acc <= v_acc + prod2;//$signed(v_acc + prod2);

            u_p5 <= u_p3;
            u_p3 <= u_p1;
            u_p1 <= u_m1;
            u_m1 <= u_m3;
            u_m3 <= u_m5;
            u_m5 <= u_p5;

            v_p5 <= v_p3;
            v_p3 <= v_p1;
            v_p1 <= v_m1;
            v_m1 <= v_m3;
            v_m3 <= v_m5;
            v_m5 <= v_p5;

            m1_state <= S_lead13;
        end

        //end of lead in; have all y, u, and v values needed to compute RGB pixels 0 and 1 *******
        S_lead13: begin
            op1 <= 16'd21;
            op2 <= u_p5;
            op3 <= 16'd21;
            op4 <= v_p5;

            u_acc <= u_acc - prod1;//$signed(u_acc - prod1);
            v_acc <= v_acc - prod2;//$signed(v_acc - prod2);

            u_p5 <= u_buf[15:8];

            v_p5 <= v_buf[15:8];

            first_row_value <= 1'b1;

            m1_state <= S_c0;
        end

        //common case

        S_c0: begin
            SRAM_we_enable <= 1'b1;
            if (j[0] && (j < 8'd154)) begin
                SRAM_address <= u_adr;
                u_adr <= u_adr + 1'b1;

                SRAM_we_enable <= 1'b1;
            end

            if (j != 8'd159) begin
                op1 <= 16'd21;
                op2 <= u_p5;
                op3 <= 16'd21;
                op4 <= v_p5;

                u_p5 <= u_p3;
                u_p3 <= u_p1;
                u_p1 <= u_m1;
                u_m1 <= u_m3;
                u_m3 <= u_m5;
                u_m5 <= u_p5;

                v_p5 <= v_p3;
                v_p3 <= v_p1;
                v_p1 <= v_m1;
                v_m1 <= v_m3;
                v_m3 <= v_m5;
                v_m5 <= v_p5;
            end
            
            u_odd <= u_acc + prod1;//$signed(u_acc + prod1); // final addition for the previous cycle computation*********************
            v_odd <= v_acc + prod2;//$signed(v_acc + prod2);

            op5 <= 32'd76284;
            op6 <= y_buf[15:8] - 8'd16;//$signed(y_buf[15:8] - 8'd16);
            op7 <= 32'd76284; 
            op8 <= y_buf[7:0] - 8'd16;//$signed(y_buf[7:0] - 8'd16);

            if (!first_row_value) begin
                if (R_accE[31] == 1'b1) begin
                    R_even <= 8'd0;
                end else if (R_accE[24] == 1'b1) begin
                    R_even <= 8'd255;
                end else begin
                    R_even <= R_accE[23:16];
                end

                if (R_accO[31] == 1'b1) begin
                    R_odd <= 8'd0;
                end else if (R_accO[24] == 1'b1) begin
                    R_odd <= 8'd255;
                end else begin
                    R_odd <= R_accO[23:16];
                end

                if (G_accE[31] == 1'b1) begin
                    G_even <= 8'd0;
                end else if (G_accE[24] == 1'b1) begin
                    G_even <= 8'd255;
                end else begin
                    G_even <= G_accE[23:16];
                end

                if (G_accO[31] == 1'b1) begin
                    G_odd <= 8'd0;
                end else if (G_accO[24] == 1'b1) begin
                    G_odd <= 8'd255;
                end else begin
                    G_odd <= G_accO[23:16];
                end

                if (B_accE[31] == 1'b1) begin
                    B_even <= 8'd0;
                end else if (B_accE[24] == 1'b1) begin
                    B_even <= 8'd255;
                end else begin
                    B_even <= B_accE[23:16];
                end

                if (B_accO[31] == 1'b1) begin
                    B_odd <= 8'd0;
                end else if (B_accO[24] == 1'b1) begin
                    B_odd <= 8'd255;
                end else begin
                    B_odd <= B_accO[23:16];
                end
            end


            m1_state <= S_c1;
        end

        S_c1: begin
            if (j[0] && (j < 8'd154)) begin
                SRAM_address <= v_adr;
                v_adr <= v_adr + 1'b1;

                SRAM_we_enable <= 1'b1;
            end

            if (j != 8'd159) begin
                op1 <= 16'd52;
                op2 <= u_p5;
                op3 <= 16'd52;
                op4 <= v_p5;

                u_acc <= 16'd128 + prod1;//$signed(16'd128 + prod1); 
                v_acc <= 16'd128 + prod2;//$signed(16'd128 + prod2);

                u_p5 <= u_p3;
                u_p3 <= u_p1;
                u_p1 <= u_m1;
                u_m1 <= u_m3;
                u_m3 <= u_m5;
                u_m5 <= u_p5;

                v_p5 <= v_p3;
                v_p3 <= v_p1;
                v_p1 <= v_m1;
                v_m1 <= v_m3;
                v_m3 <= v_m5;
                v_m5 <= v_p5;
            end

            op5 <= 32'd104595;
            op6 <= v_even - 16'd128;//$signed(v_even - 16'd128);
            op7 <= 32'd104595;
            op8 <= v_odd[23:8] - 16'd128;//$signed(v_odd[23:8] - 16'd128);

            R_accE <= prod3;
            G_accE <= prod3;
            B_accE <= prod3;
            R_accO <= prod4;
            G_accO <= prod4;
            B_accO <= prod4;

            m1_state <= S_c2;
        end

        S_c2: begin
            if (j != 8'd159) begin
               SRAM_address <= y_adr;
               y_adr <= y_adr + 1'b1;

               SRAM_we_enable <= 1'b1;

                op1 <= 16'd159;
                op2 <= u_p5;
                op3 <= 16'd159;
                op4 <= v_p5;

                u_acc <= u_acc - prod1;//$signed(u_acc - prod1); 
                v_acc <= v_acc - prod2;//$signed(v_acc - prod2);

                u_p5 <= u_p3;
                u_p3 <= u_p1;
                u_p1 <= u_m1;
                u_m1 <= u_m3;
                u_m3 <= u_m5;
                u_m5 <= u_p5;

                v_p5 <= v_p3;
                v_p3 <= v_p1;
                v_p1 <= v_m1;
                v_m1 <= v_m3;
                v_m3 <= v_m5;
                v_m5 <= v_p5;
            end

            op5 <= 32'd25624;
            op6 <= u_even - 16'd128;//$signed(u_even - 16'd128);
            op7 <= 32'd25624;
            op8 <= u_odd[23:8] - 16'd128;//$signed(u_odd[23:8] - 16'd128);

            R_accE <= R_accE + prod3;//$signed(R_accE + prod3);
            R_accO <= R_accO + prod4;//$signed(R_accO + prod4);

            m1_state <= S_c3;
        end

        S_c3: begin
            if (!first_row_value) begin
                SRAM_address <= rgb_adr;
                rgb_adr <= rgb_adr + 1'd1;
                SRAM_write_data[15:8] <= R_even;
                SRAM_write_data[7:0] <= G_even;

                SRAM_we_enable <= 1'b0;
            end

            if (j[0] && (j < 8'd154)) begin
                u_buf <= SRAM_read_data;
            end

            if (j != 8'd159) begin
                op1 <= 16'd159;
                op2 <= u_p5;
                op3 <= 16'd159;
                op4 <= v_p5;

                u_acc <= u_acc + prod1;//$signed(u_acc + prod1); 
                v_acc <= v_acc + prod2;//$signed(v_acc + prod2);

                u_p5 <= u_p3;
                u_p3 <= u_p1;
                u_p1 <= u_m1;
                u_m1 <= u_m3;
                u_m3 <= u_m5;
                u_m5 <= u_p5;

                v_p5 <= v_p3;
                v_p3 <= v_p1;
                v_p1 <= v_m1;
                v_m1 <= v_m3;
                v_m3 <= v_m5;
                v_m5 <= v_p5;
            end

            op5 <= 32'd53281;
            op6 <= v_even - 16'd128;//$signed(v_even - 16'd128);
            op7 <= 32'd53281;
            op8 <= v_odd[23:8] - 16'd128;//$signed(v_odd[23:8] - 16'd128);

            G_accE <= G_accE - prod3;//$signed(G_accE - prod3);
            G_accO <= G_accO - prod4;//$signed(G_accO - prod4);

            m1_state <= S_c4;
        end

        S_c4: begin
            if (!first_row_value) begin
                SRAM_address <= rgb_adr;
                rgb_adr <= rgb_adr + 1'd1;
                SRAM_write_data[15:8] <= B_even;
                SRAM_write_data[7:0] <= R_odd;

                SRAM_we_enable <= 1'b0;
            end

            if (j[0] && (j < 8'd154)) begin
                v_buf <= SRAM_read_data;
            end

            if (j != 8'd159) begin
                op1 <= 16'd52;
                op2 <= u_p5;
                op3 <= 16'd52;
                op4 <= v_p5;

                u_acc <= u_acc + prod1;//$signed(u_acc + prod1); 
                v_acc <= v_acc + prod2;//$signed(v_acc + prod2);

                u_p5 <= u_p3;
                u_p3 <= u_p1;
                u_p1 <= u_m1;
                u_m1 <= u_m3;
                u_m3 <= u_m5;
                u_m5 <= u_p5;

                v_p5 <= v_p3;
                v_p3 <= v_p1;
                v_p1 <= v_m1;
                v_m1 <= v_m3;
                v_m3 <= v_m5;
                v_m5 <= v_p5;
            end

            op5 <= 32'd132251;
            op6 <= u_even - 16'd128;//$signed(u_even - 16'd128);
            op7 <= 32'd132251;
            op8 <= u_odd[23:8] - 16'd128;//$signed(u_odd[23:8] - 16'd128);

            G_accE <= G_accE - prod3;//$signed(G_accE - prod3);
            G_accO <= G_accO - prod4;//$signed(G_accO - prod4);

            m1_state <= S_c5;
        end

        S_c5: begin
            if (!first_row_value) begin
                SRAM_address <= rgb_adr;
                rgb_adr <= rgb_adr + 1'd1;
                SRAM_write_data[15:8] <= G_odd;
                SRAM_write_data[7:0] <= B_odd;

                SRAM_we_enable <= 1'b0;
            end else begin
                first_row_value <= 1'b0;
            end

            if (j != 8'd159) begin
                y_buf <= SRAM_read_data;

                op1 <= 16'd21;
                op2 <= u_p5;
                op3 <= 16'd21;
                op4 <= v_p5;

                u_acc <= u_acc - prod1;//$signed(u_acc - prod1); 
                v_acc <= v_acc - prod2;//$signed(v_acc - prod2);

                u_even <= u_m3;
                v_even <= v_m3;

                if (j > 8'd154) begin
                    u_p5 <= u_p3;
                    v_p5 <= v_p3;
                end else if (j[0]) begin
                    u_p5 <= u_buf[15:8];
                    v_p5 <= v_buf[15:8];
                end else begin
                    u_p5 <= u_buf[7:0];
                    v_p5 <= v_buf[7:0];
                end
            end

            B_accE <= B_accE + prod3;//$signed(B_accE + prod3);
            B_accO <= B_accO + prod4;//$signed(B_accO + prod4);

            if (j == 8'd159) begin
                j <= 1'd0;
                m1_state <= S_out0;
            end else begin
                j <= j + 1'd1;
                m1_state <= S_c0;
            end
        end
        
        
        //Start of lead out

        S_out0: begin
            SRAM_we_enable <= 1'b1;
            if (R_accE[31] == 1'b1) begin
                R_even <= 8'd0;
            end else if (R_accE[24] == 1'b1) begin
                R_even <= 8'd255;
            end else begin
                R_even <= R_accE[23:16];
            end

            if (R_accO[31] == 1'b1) begin
                R_odd <= 8'd0;
            end else if (R_accO[24] == 1'b1) begin
                R_odd <= 8'd255;
            end else begin
                R_odd <= R_accO[23:16];
            end

            if (G_accE[31] == 1'b1) begin
                G_even <= 8'd0;
            end else if (G_accE[24] == 1'b1) begin
                G_even <= 8'd255;
            end else begin
                G_even <= G_accE[23:16];
            end

            if (G_accO[31] == 1'b1) begin
                G_odd <= 8'd0;
            end else if (G_accO[24] == 1'b1) begin
                G_odd <= 8'd255;
            end else begin
                G_odd <= G_accO[23:16];
            end

            if (B_accE[31] == 1'b1) begin
                B_even <= 8'd0;
            end else if (B_accE[24] == 1'b1) begin
                B_even <= 8'd255;
            end else begin
                B_even <= B_accE[23:16];
            end

            if (B_accO[31] == 1'b1) begin
                B_odd <= 8'd0;
            end else if (B_accO[24] == 1'b1) begin
                B_odd <= 8'd255;
            end else begin
                B_odd <= B_accO[23:16];
            end

            m1_state <= S_out1;
        end

        S_out1: begin
            SRAM_address <= rgb_adr;
            rgb_adr <= rgb_adr + 1'd1;
            SRAM_write_data[15:8] <= R_even;
            SRAM_write_data[7:0] <= G_even;

            SRAM_we_enable <= 1'b0;

            m1_state <= S_out2;
        end

        S_out2: begin
            SRAM_address <= rgb_adr;
            rgb_adr <= rgb_adr + 1'd1;
            SRAM_write_data[15:8] <= B_even;
            SRAM_write_data[7:0] <= R_odd;
            //SRAM_write_data <= {B_even, R_odd};

            SRAM_we_enable <= 1'b0;

            m1_state <= S_out3;
        end

        S_out3: begin
            SRAM_address <= rgb_adr;
            rgb_adr <= rgb_adr + 1'd1;
            SRAM_write_data[15:8] <= G_odd;
            SRAM_write_data[7:0] <= B_odd;
            //SRAM_write_data <= {G_odd, B_odd};
            SRAM_we_enable <= 1'b0;

            if (row == 8'd239) begin
                m1_done <= 1'b1;
                m1_state <= S_idle;
            end else begin
                row <= row + 1'd1;
                m1_state <= S_lead0;
            end
        end
        default: m1_state <= S_idle;
        endcase
    end
end
endmodule
