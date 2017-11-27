`timescale 1ns/100ps
`default_nettype none

`include "define_state.h"

module Milestone2 (

    input logic             CLOCK,
    input logic             Resetn,
    
    input logic             start_m2,
    output logic            m2_done,
    
    output logic   [6:0]    dp0_adr_a,
    output logic   [6:0]    dp0_adr_b,
    output logic   [31:0]   dp0_write_data_a,
    output logic   [31:0]   dp0_write_data_b,
    output logic            dp0_enable_a,
    output logic            dp0_enable_b,
    input logic    [31:0]   dp0_read_data_a,
    input logic    [31:0]   dp0_read_data_b,
    
    output logic   [6:0]    dp1_adr_a,
    output logic   [6:0]    dp1_adr_b,
    output logic   [31:0]   dp1_write_data_a,
    output logic   [31:0]   dp1_write_data_b,
    output logic            dp1_enable_a,
    output logic            dp1_enable_b,
    input logic    [31:0]   dp1_read_data_a,
    input logic    [31:0]   dp1_read_data_b,
    
    output logic   [6:0]    dp2_adr_a,
    output logic   [6:0]    dp2_adr_b,
    output logic   [31:0]   dp2_write_data_a,
    output logic   [31:0]   dp2_write_data_b,
    output logic            dp2_enable_a,
    output logic            dp2_enable_b,
    input logic    [31:0]   dp2_read_data_a,
    input logic    [31:0]   dp2_read_data_b,
    
    
    output logic   [17:0]   SRAM_address,
    output logic   [15:0]   SRAM_write_data,
    input logic    [15:0]   SRAM_read_data,
    output logic            SRAM_we_enable
);

milestone_2_state m2_state;

//counting the times we have copmuted a T matrix; counts to 2400
logic [11:0] t_computations;

//SRAM address offsets
logic [17:0] yidct_offset, uidct_offset, vidct_offset, u_offset, v_offset, uvidct_offset, uv_offset;

// For iterations through the C and C-transpose matrix -- use two values at a time
logic [4:0] c_pair, transpose_pair, c_pair_count, transpose_pair_count;

//for the first 64 reads of Y
logic toggle;
logic [1:0] reads, writes;
logic [5:0] reads_writes;

//for the first time computing matrix T
logic start_T, T_end, last_multiplication;
logic [1:0] stage_a, stage_b, stage_c, compute_end;
logic [2:0] leadT;
logic [3:0] sp_read_cycle;

//for megastate 1
logic out1_first, last_multiplication_out;
logic [1:0] stage_a_out, stage_b_out, stage_c_out, compute_end_out;
logic [2:0] out2;
logic [3:0] t_read_cycle;

//for last 32 writes of v
logic [5:0] writeout;

//dp addresses for reading values from two separate rows of an 88 matrix
logic [6:0] s_prime_adr, sp_adrb, ta_adr, tb_adr, sa_adr, sb_adr;

//MACS and result registers
logic [31:0] t_aa, t_ab, t_ba, t_bb, result_t_aa, result_t_ab, result_t_ba, result_t_bb;
logic [31:0] s_aa, s_ab, s_ba, s_bb, result_s_aa, result_s_ab, result_s_ba, result_s_bb;

//multiplier variables
logic [31:0] op1, op2, op3, op4, prod1, prod2, prod3, prod4;
logic [63:0] prod1_long, prod2_long, prod3_long, prod4_long;

//multipliers
assign prod1_long = $signed(op1)*$signed(op3);//op1*op3;
assign prod1 = prod1_long[31:0];

assign prod2_long = $signed(op1)*$signed(op4);//op1*op4;
assign prod2 = prod2_long[31:0];

assign prod3_long = $signed(op2)*$signed(op3);//op2*op3;
assign prod3 = prod3_long[31:0];

assign prod4_long = $signed(op2)*$signed(op4);//op2*op4;
assign prod4 = prod4_long[31:0];

//SRAM offsets
assign yidct_offset = 18'd76800;
assign uidct_offset = 18'd153600;
assign vidct_offset = 18'd192000;
assign u_offset = 18'd38400;
assign v_offset = 18'd57600;
assign uvidct_offset = (t_computations > 12'd1799) ? vidct_offset : uidct_offset;
assign uv_offset = (t_computations > 12'd1800) ? v_offset : u_offset; //***************************************************

//modulo-counter system for reading Y
logic [17:0] read_address_y;
logic [8:0] RA_ry, CA_ry;
logic [5:0] counterM_ry, counterC_ry;
logic [4:0] counterR_ry;
logic [2:0] ri_ry, ci_ry;
logic read_flagY, read_y_done;

assign ri_ry = counterM_ry[5:3];
assign ci_ry = counterM_ry[2:0];
assign RA_ry = {counterR_ry,ri_ry};
assign CA_ry = {counterC_ry,ci_ry};
assign read_address_y = yidct_offset + {RA_ry,8'd0} + {RA_ry,6'd0} + CA_ry;

//modulo-counter system for writing Y
logic [17:0] write_address_y;
logic [7:0] RA_wy, CA_wy;
logic [5:0] counterC_wy;
logic [4:0] counterM_wy, counterR_wy;
logic [2:0] ri_wy;
logic [1:0] ci_wy;
logic write_flagY, y_done;

assign ri_wy = counterM_wy[4:2];
assign ci_wy = counterM_wy[1:0];
assign RA_wy = {counterR_wy,ri_wy};
assign CA_wy = {counterC_wy,ci_wy};
assign write_address_y = {RA_wy,7'd0} + {RA_wy,5'd0} + CA_wy;

//modulo-counter system for reading U/V
logic [17:0] read_address_uv;
logic [7:0] RA_ruv, CA_ruv;
logic [5:0] counterM_ruv;
logic [4:0] counterR_ruv, counterC_ruv;
logic [2:0] ri_ruv, ci_ruv;
logic read_flagUV, read_uv_done;

assign ri_ruv = counterM_ruv[5:3];
assign ci_ruv = counterM_ruv[2:0];
assign RA_ruv = {counterR_ruv,ri_ruv};
assign CA_ruv = {counterC_ruv,ci_ruv};
assign read_address_uv = uvidct_offset + {RA_ruv,7'd0} + {RA_ruv,5'd0} + CA_ruv;

//modulo-counter system for writing U/V
logic [17:0] write_address_uv;
logic [7:0] RA_wuv, CA_wuv;
logic [4:0] counterM_wuv, counterR_wuv, counterC_wuv;
logic [2:0] ri_wuv;
logic [1:0] ci_wuv;
logic write_flagUV, uv_done;

assign ri_wuv = counterM_wuv[4:2];
assign ci_wuv = counterM_wuv[1:0];
assign RA_wuv = {counterR_wuv,ri_wuv};
assign CA_wuv = {counterC_wuv,ci_wuv};
assign write_address_uv = uv_offset + {RA_wuv,6'd0} + {RA_wuv,4'd0} + CA_wuv;

//assign op3 = (c_pair == 5'd0 ? 32'h000005A8 : (c_pair == 5'd1 ? 32'h000007D8 : 5'd10));
//assign op4 = (c_pair == 5'd0 ? 32'h000005A8 : (c_pair == 5'd1 ? 32'h000007D8 : 5'd10));

always_comb begin

    if (c_pair == 5'd0) begin
        op3 = 32'h000005A8;
        op4 = 32'h000005A8;
    end
    else if (c_pair == 5'd1) begin
        op3 = 32'h000007D8;
        op4 = 32'h000006A6;
    end
    else if (c_pair == 5'd2) begin
        op3 = 32'h00000764;
        op4 = 32'h0000030F;
    end
    else if (c_pair == 5'd3) begin
        op3 = 32'h000006A6;
        op4 = 32'hFFFFFE71;
    end
    else if (c_pair == 5'd4) begin
        op3 = 32'h000005A8;
        op4 = 32'hFFFFFA58;
    end
    else if (c_pair == 5'd5) begin
        op3 = 32'h00000471;
        op4 = 32'hFFFFF828;
    end
    else if (c_pair == 5'd6) begin
        op3 = 32'h0000030F;
        op4 = 32'hFFFFF89C;
    end
    else if (c_pair == 5'd7) begin
        op3 = 32'h0000018F;
        op4 = 32'hFFFFFB8F;
    end
    else if (c_pair == 5'd8) begin
        op3 = 32'h000005A8;
        op4 = 32'h000005A8;
    end
    else if (c_pair == 5'd9) begin
        op3 = 32'h00000471;
        op4 = 32'h0000018F;
    end
    else if (c_pair == 5'd10) begin
        op3 = 32'hFFFFFCF1;
        op4 = 32'hFFFFF89C;
    end
    else if (c_pair == 5'd11) begin
        op3 = 32'hFFFFF828;
        op4 = 32'hFFFFFB8F;
    end
    else if (c_pair == 5'd12) begin
        op3 = 32'hFFFFFA58;
        op4 = 32'h000005A8;
    end
    else if (c_pair == 5'd13) begin
        op3 = 32'h0000018F;
        op4 = 32'h000006A6;
    end
    else if (c_pair == 5'd14) begin
        op3 = 32'h00000764;
        op4 = 32'hFFFFFCF1;
    end
    else if (c_pair == 5'd15) begin
        op3 = 32'h000006A6;
        op4 = 32'hFFFFF828;
    end
    else if (c_pair == 5'd16) begin
        op3 = 32'h000005A8;
        op4 = 32'h000005A8;
    end
    else if (c_pair == 5'd17) begin
        op3 = 32'hFFFFFE71;
        op4 = 32'hFFFFFB8F;
    end
    else if (c_pair == 5'd18) begin
        op3 = 32'hFFFFF89C;
        op4 = 32'hFFFFFCF1;
    end
    else if (c_pair == 5'd19) begin
        op3 = 32'h00000471;
        op4 = 32'h000007D8;
    end
    else if (c_pair == 5'd20) begin
        op3 = 32'h000005A8;
        op4 = 32'hFFFFFA58;
    end
    else if (c_pair == 5'd21) begin
        op3 = 32'hFFFFF95A;
        op4 = 32'hFFFFFE71;
    end
    else if (c_pair == 5'd22) begin
        op3 = 32'hFFFFFCF1;
        op4 = 32'h00000764;
    end
    else if (c_pair == 5'd23) begin
        op3 = 32'h000007D8;
        op4 = 32'hFFFFF95A;
    end
    else if (c_pair == 5'd24) begin
        op3 = 32'h000005A8;
        op4 = 32'h000005A8;
    end
    else if (c_pair == 5'd25) begin
        op3 = 32'hFFFFF95A;
        op4 = 32'hFFFFF828;
    end
    else if (c_pair == 5'd26) begin
        op3 = 32'h0000030F;
        op4 = 32'h00000764;
    end
    else if (c_pair == 5'd27) begin
        op3 = 32'h0000018F;
        op4 = 32'hFFFFF95A;
    end
    else if (c_pair == 5'd28) begin
        op3 = 32'hFFFFFA58;
        op4 = 32'h000005A8;
    end
    else if (c_pair == 5'd29) begin
        op3 = 32'h000007D8;
        op4 = 32'hFFFFFB8F;
    end
    else if (c_pair == 5'd30) begin
        op3 = 32'hFFFFF89C;
        op4 = 32'h0000030F;
    end
    else begin
        op3 = 32'h00000471;
        op4 = 32'hFFFFFE71;
    end
        
end

always_ff @(posedge CLOCK or negedge Resetn) begin
    if (~Resetn) begin
       
        read_y_done <= 1'b0;
        y_done <= 1'b0;
        read_uv_done <= 1'b0;
        uv_done <= 1'b0;

        counterM_ry <= 6'd0;
        counterC_ry <= 6'd0;
        counterR_ry <= 5'd0;
        counterM_wy <= 5'd0;
        counterC_wy <= 6'd0;
        counterR_wy <= 5'd0;
        counterM_ruv <= 6'd0;
        counterC_ruv <= 5'd0;
        counterR_ruv <= 5'd0;
        counterM_wuv <= 5'd0;
        counterC_wuv <= 5'd0;
        counterR_wuv <= 5'd0;

    end else begin
    
        if (read_flagY) begin
            counterM_ry <= counterM_ry + 6'd1;
            if (counterM_ry == 6'd63) begin
                if (counterC_ry == 6'd39) begin
                    counterC_ry <= 6'd0;
                    if (counterR_ry == 5'd29) begin
                        counterR_ry <= 5'd0;
                        read_y_done <= 1'b1;
                    end else begin
                        counterR_ry <= counterR_ry + 5'd1;
                    end
                end else
                    counterC_ry <= counterC_ry + 6'd1;
            end
        end
        
        if (write_flagY) begin
            counterM_wy <= counterM_wy + 5'd1;
            if (counterM_wy == 5'd31) begin
                if (counterC_wy == 6'd39) begin
                    counterC_wy <= 6'd0;
                    if (counterR_wy == 5'd29) begin
                        counterR_wy <= 5'd0;
                        y_done <= 1'b1;
                    end else begin
                        counterR_wy <= counterR_wy + 5'd1;
                    end
                end else begin
                    counterC_wy <= counterC_wy + 6'd1;
                end
            end
        end
        
        if (read_flagUV) begin
            counterM_ruv <= counterM_ruv + 6'd1;
            if (counterM_ruv == 6'd63) begin
                if (counterC_ruv == 5'd19) begin
                    counterC_ruv <= 5'd0;
                    if (counterR_ruv == 5'd29) begin
                        counterR_ruv <= 5'd0;
                        read_uv_done <= 1'b1;
                    end else begin
                        counterR_ruv <= counterR_ruv + 5'd1;
                    end
                end else begin
                    counterC_ruv <= counterC_ruv + 5'd1;
                end
            end
        end
        
        if (write_flagUV) begin
            counterM_wuv <= counterM_wuv + 5'd1;
            if (counterM_wuv == 5'd31) begin
                if (counterC_wuv == 5'd19) begin
                    counterC_wuv <= 5'd0;
                    if (counterR_wuv == 5'd29) begin
                        counterR_wuv <= 5'd0;
                        uv_done <= 1'b1;
                    end else begin
                        counterR_wuv <= counterR_wuv + 5'd1;
                    end
                end else begin
                    counterC_wuv <= counterC_wuv + 5'd1;
                end
            end
        end
        
    end
        
end

always_ff @(posedge CLOCK or negedge Resetn) begin

    if (~Resetn) begin
        
        m2_done <= 1'b0;
        m2_state <= S_idle2;
        
        /*read_flagY <= 1'b0;
        read_flagUV <= 1'b0;
        write_flagY <= 1'b0;
        write_flagUV <= 1'b0;
        read_y_done <= 1'b0;
        y_done <= 1'b0;
        read_uv_done <= 1'b0;
        uv_done <= 1'b0;

        counterM_ry <= 6'd0;
        counterC_ry <= 6'd0;
        counterR_ry <= 5'd0;
        counterM_wy <= 5'd0;
        counterC_wy <= 6'd0;
        counterR_wy <= 5'd0;
        counterM_ruv <= 6'd0;
        counterC_ruv <= 5'd0;
        counterC_ruv <= 5'd0;
        counterM_wuv <= 5'd0;
        counterC_wuv <= 5'd0;
        counterR_wuv <= 5'd0;*/

    end else begin                  
    
        case(m2_state)
        
        S_idle2: begin
		  
				read_flagY <= 1'b0;
			  read_flagUV <= 1'b0;
			  write_flagY <= 1'b0;
			  write_flagUV <= 1'b0;
            
            toggle <= 1'b1;
            reads <= 2'd3;
            reads_writes <= 6'd61;
            writes <= 2'd3;
            
            start_T <= 1'b1;
            leadT <= 3'd0;
            sp_read_cycle <= 4'd0;
            T_end <= 1'b0;
            stage_a <= 2'd2;
            stage_b <= 2'd3;
            stage_c <= 2'd3;
            compute_end <= 2'd2;
            last_multiplication <= 1'b1;
            
            out1_first <= 1'b1;
            out2 <= 3'd0;
            t_read_cycle <= 4'd0;
            stage_a_out <= 2'd2;
            stage_b_out <= 2'd3;
            stage_c_out <= 2'd3;
            compute_end_out <= 2'd2;
            last_multiplication_out <= 1'b1;
            
            writeout <= 6'd0; 
            
            c_pair <= 5'd0;
            c_pair_count <= 5'd0;
            transpose_pair <= 5'd0;
            transpose_pair_count <= 5'd0;
            
            t_aa <= 32'd0;
            t_ab <= 32'd0;
            t_ba <= 32'd0;
            t_bb <= 32'd0;
            result_t_aa <= 32'd0;
            result_t_ab <= 32'd0;
            result_t_ba <= 32'd0;
            result_t_bb <= 32'd0;
            s_aa <= 32'd0;
            s_ab <= 32'd0;
            s_ba <= 32'd0;
            s_bb <= 32'd0;
            result_s_aa <= 32'd0;
            result_s_ab <= 32'd0;
            result_s_ba <= 32'd0;
            result_s_bb <= 32'd0;
            
            s_prime_adr <= 7'd0;
            sp_adrb <= 7'd8;
            ta_adr <= 7'd0;
            tb_adr <= 7'd8;
            sa_adr <= 7'd0;
            sb_adr <= 7'd8;
            
            SRAM_we_enable <= 1'b1;
            dp0_enable_a <= 1'b0;
            dp0_enable_b <= 1'b0;
            dp1_enable_a <= 1'b0;
            dp1_enable_b <= 1'b0;
            dp2_enable_a <= 1'b0;
            dp2_enable_b <= 1'b0;
            
            t_computations <= 12'd0;
            
            SRAM_write_data <= 8'd0;
            SRAM_address <= 18'd0;
            
            if (start_m2)
                m2_state <= S_read_in;
        end
        
        
        
        ///////////////////////////////////////////////////////READ STATE///////////////////////////////////////////////////////////////
        S_read_in: begin
            //1 cycle to toggle read_flag_Y
            if (toggle) begin
                m2_done <= 1'b0;
                toggle <= ~toggle;
                read_flagY <= 1'b1;
            end
            //3 cycles to begin reading from SRAM
            else if (|reads) begin
                SRAM_address <= read_address_y;
                SRAM_we_enable <= 1'b1;
                reads <= reads - 1'd1;
            end
            //61 cycles to finish reading from SRAM and begin writing into DP RAM
            else if (|reads_writes) begin
                SRAM_address <= read_address_y;
                SRAM_we_enable <= 1'b1;
                
                dp0_adr_a <= s_prime_adr;
                s_prime_adr <= s_prime_adr + 1'd1;
                dp0_write_data_a <= { {16{ SRAM_read_data[15]}}, SRAM_read_data };
                dp0_enable_a <= 1'b1;
                
                reads_writes <= reads_writes - 6'd1;
                if (reads_writes == 6'd1)
                    read_flagY <= 1'b0;
            end
            //3 cycles to finish writing to DPRAM
            else if (|writes) begin
                dp0_adr_a <= s_prime_adr;
                s_prime_adr <= s_prime_adr + 1'd1;
                dp0_write_data_a <= { {16{ SRAM_read_data[15]}}, SRAM_read_data };
                dp0_enable_a <= 1'b1;
                writes <= writes - 1'd1;
            end else begin
                dp0_enable_a <= 1'b0;
                s_prime_adr <= 7'd0;
                m2_state <= S_compute_in;
            end
            
        end
        /////////////////////////////////////////////////////COMPOOT T//////////////////////////////////////////////////////////////////
        S_compute_in: begin
            
            if(start_T) begin
                if(leadT < 3'd2) begin
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;
                    leadT <= leadT + 1'd1;//needs to be initialized
                end
                else if (leadT == 3'd2) begin
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;
                    
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;
                    leadT <= leadT + 1'd1;
                end
                else begin
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;
                    
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;
                    
                    if(leadT == 3'd3) begin
                        t_aa <= prod1;
                        t_ab <= prod2;
                        t_ba <= prod3;
                        t_bb <= prod4;
                    end
                    else begin
                        t_aa <= t_aa + prod1;
                        t_ab <= t_ab + prod2;
                        t_ba <= t_ba + prod3;
                        t_bb <= t_bb + prod4;
                    end
                    
                    if (leadT == 3'd7) begin
                        leadT <= 3'd0; //**********************************************************************************
                        s_prime_adr <= 7'd0;
                        sp_adrb <= 7'd8;
                        sp_read_cycle <= 4'd1;
                        start_T <= 1'b0;
                    end else
                        leadT <= leadT + 1'd1;
                end
            end
            else if (!T_end) begin
            
                //2 cycles to read(0) and compute(-1)
                if (|stage_a) begin
                    //accumulating matrix values
                    t_aa <= t_aa + prod1;
                    t_ab <= t_ab + prod2;
                    t_ba <= t_ba + prod3;
                    t_bb <= t_bb + prod4;

                    //preparing next addresses to read from dual port
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;

                    //reading s' values from dual port
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;

                    stage_a <= stage_a - 2'd1;
                end
                
                //3 cycles to read(0), write(-1) and compute(0)
                else if (|stage_b) begin
                    //final matrix values (from previous stage)
                    if(stage_b == 2'd3) begin
                        result_t_aa <= t_aa + prod1;
                        result_t_ab <= t_ab + prod2;
                        result_t_ba <= t_ba + prod3;
                        result_t_bb <= t_bb + prod4;
                    end
                    //accumulating and computing matrix values
                    //reset case (from previous accumulation)
                    else if (stage_b == 2'd2) begin
                            //((c_pair_count == 5'd1) || (c_pair_count  == 5'd9) || (c_pair_count  == 5'd17) || (c_pair_count  == 5'd25)) begin
                        t_aa <= prod1;
                        t_ab <= prod2;
                        t_ba <= prod3;
                        t_bb <= prod4;
                    end
                    //common accumulation case
                    else begin
                        t_aa <= t_aa + prod1;
                        t_ab <= t_ab + prod2;
                        t_ba <= t_ba + prod3;
                        t_bb <= t_bb + prod4;
                    end 

                    //preparing next addresses to read from dual port
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;

                    //reading s' values from dual port
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;

                    //writing the 4 T values into dp-ram 1
                    //first pair
                    if (stage_b == 2'd2) begin
                        dp1_adr_a <= ta_adr;
                        dp1_adr_b <= tb_adr;
                        dp1_write_data_a <= { {8{result_t_aa[31]}} , result_t_aa[31:8] };
                        dp1_write_data_b <= { {8{result_t_ba[31]}} , result_t_ba[31:8] };
                        dp1_enable_a <= 1'b1;
                        dp1_enable_b <= 1'b1;
                        ta_adr <= ta_adr + 1'd1;
                        tb_adr <= tb_adr + 1'd1;
                    end
                    //second pair
                    if (stage_b == 2'd1) begin
                        dp1_adr_a <= ta_adr;
                        dp1_adr_b <= tb_adr;
                        dp1_write_data_a <= { {8{result_t_ab[31]}} , result_t_ab[31:8] };
                        dp1_write_data_b <= { {8{result_t_bb[31]}} , result_t_bb[31:8] };
                        dp1_enable_a <= 1'b1;
                        dp1_enable_b <= 1'b1;
                        //matrix address incrementation
                        if ((ta_adr == 6'd7) || (ta_adr == 6'd23) || (ta_adr == 6'd39) || (ta_adr == 6'd55)) begin
                            ta_adr <= ta_adr + 7'd9;
                            tb_adr <= tb_adr + 7'd9;
                        end else begin
                            ta_adr <= ta_adr + 1'd1;
                            tb_adr <= tb_adr + 1'd1;
                        end
                    end
                    stage_b <= stage_b - 2'd1;
                end //stage_b
                
                //3 cycles to read(0) and compute (0)
                else begin //stage_c
                
                    //ensure no unwanted writes into dp-ram 1
                    dp1_enable_a <= 1'b0;
                    dp1_enable_b <= 1'b0;

                    //accumulating the results of the previous cycle's multiplication
                    t_aa <= t_aa + prod1;
                    t_ab <= t_ab + prod2;
                    t_ba <= t_ba + prod3;
                    t_bb <= t_bb + prod4;

                    //setting operands for the matrix multiplications
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;

                    // reading s' values 
                    if (stage_c == 2'd1) begin //last read of the current set of 4 multiplications
                        dp0_adr_a <= s_prime_adr;
                        dp0_adr_b <= sp_adrb;
                        dp0_enable_a <= 1'b0;
                        dp0_enable_b <= 1'b0;

                        //reset stage flags
                        stage_a <= 2'd2;
                        stage_b <= 2'd3;
                        stage_c <= 2'd3;
                        
                        sp_read_cycle <= sp_read_cycle + 4'd1;

                        if (sp_read_cycle == 4'd15) begin // have done all reads to compute the current 8 by 8 matrix
                            s_prime_adr <= 6'd0;
                            sp_adrb <= 6'd8;
                            T_end <= 1'b1;
                        end
                        //begin using next two rows of s'
                        else if ((sp_read_cycle == 4'd3) || (sp_read_cycle == 4'd7) || (sp_read_cycle == 4'd11)) begin
                            s_prime_adr <= s_prime_adr + 6'd9;
                            sp_adrb <= sp_adrb + 6'd9;
                        end else begin // reset the s' values to the start of the rows
                            s_prime_adr <= s_prime_adr - 6'd7;
                            sp_adrb <= sp_adrb - 6'd7;
                        end
                    end else begin
                        dp0_adr_a <= s_prime_adr;
                        dp0_adr_b <= sp_adrb;
                        dp0_enable_a <= 1'b0;
                        dp0_enable_b <= 1'b0;
                        s_prime_adr <= s_prime_adr + 1'd1;
                        sp_adrb <= sp_adrb + 1'd1;
                        stage_c <= stage_c - 2'd1;
                    end
                end //end stage_c 
                
            //T_end - begin lead out (5 cycles)
            end else begin
                //first 2 cycles: computing and accumulating (-1)
                if (|compute_end) begin
                    t_aa <= t_aa + prod1;
                    t_ab <= t_ab + prod2;
                    t_ba <= t_ba + prod3;
                    t_bb <= t_bb + prod4;

                    //setting operands for the matrix multiplications
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;  
                    
                    compute_end <= compute_end - 1'd1;
                end 

                // next cycle: final accumulation (-1)
                else if (last_multiplication) begin
                    last_multiplication <= 1'b0;
                    result_t_aa <= t_aa + prod1;
                    result_t_ab <= t_ab + prod2;
                    result_t_ba <= t_ba + prod3;
                    result_t_bb <= t_bb + prod4;
                end 

                // next cycle: writing(-1) first pair into DPRAM
                else if (tb_adr == 6'd62) begin
                    dp1_adr_a <= ta_adr;
                    dp1_adr_b <= tb_adr;
                    dp1_write_data_a <= { {8{result_t_aa[31]}} , result_t_aa[31:8] };
                    dp1_write_data_b <= { {8{result_t_ba[31]}} , result_t_ba[31:8] };
                    dp1_enable_a <= 1'b1;
                    dp1_enable_b <= 1'b1;
                    ta_adr <= ta_adr + 1'd1;
                    tb_adr <= tb_adr + 1'd1;
                end 

                // last cycle: writing(-1) second pair into DPRAM, reset for next megastate reentry
                else begin
                    dp1_adr_a <= ta_adr;
                    dp1_adr_b <= tb_adr;
                    dp1_write_data_a <= { {8{result_t_ab[31]}} , result_t_ab[31:8] };
                    dp1_write_data_b <= { {8{result_t_bb[31]}} , result_t_bb[31:8] };
                    dp1_enable_a <= 1'b1;
                    dp1_enable_b <= 1'b1;
                    ta_adr <= 7'd0;
                    tb_adr <= 7'd1;
                    
                    t_computations <= 1'd1;
                    
                    start_T <= 1'b1;
                    leadT <= 3'd0;
                    sp_read_cycle <= 4'd0;
                    T_end <= 1'b0;
                    stage_a <= 2'd2;
                    stage_b <= 2'd3;
                    stage_c <= 2'd3;
                    compute_end <= 2'd2;
                    last_multiplication <= 1'b1;
                    
                    m2_state <= S_megastate_1a;
                end
            end
        end //end compute_in
        
        
        /////////////////////////////////////////////////////MEGASTATE 1a//////////////////////////////////////////////////////////////////
        S_megastate_1a: begin
            dp1_adr_a <= ta_adr;
            ta_adr <= ta_adr + 7'd8;
            dp1_adr_b <= tb_adr;
            tb_adr <= tb_adr + 7'd8;
            dp1_enable_a <= 1'b0;
            dp1_enable_b <= 1'b0;
            if (out1_first) begin
                out1_first <= 1'b0;
            end else begin
                out1_first <= 1'b1;
                m2_state <= S_megastate_1b;  
            end
        end
        
        
        /////////////////////////////////////////////////////MEGASTATE 1b//////////////////////////////////////////////////////////////////
        S_megastate_1b: begin
            //accumulation
            if (out2 == 3'd1) begin
                s_aa <= prod1;
                s_ab <= prod3;
                s_ba <= prod2;
                s_bb <= prod4;
            end
            else if (out2 > 3'd1) begin
                s_aa <= s_aa + prod1;
                s_ab <= s_ab + prod3;
                s_ba <= s_ba + prod2;
                s_bb <= s_bb + prod4;
            end
            
            //address incrementation
            dp1_adr_a <= ta_adr;
            ta_adr <= ta_adr + 7'd8;
            dp1_adr_b <= tb_adr;
            tb_adr <= tb_adr + 7'd8;
            dp1_enable_a <= 1'b0;
            dp1_enable_b <= 1'b0;

            //data reading 
            op1 <= dp1_read_data_a;
            op2 <= dp1_read_data_b;
            c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
            c_pair_count <= c_pair_count + 1'd1;
            out2 <= out2 + 1'd1;
            
            if (out2 == 3'd2) begin
                if (!read_y_done)
                    read_flagY <= 1'b1;
                else
                    read_flagUV <= 1'b1;
            end
            else if (out2 > 3'd2) begin
                if (!read_y_done)
                    SRAM_address <= read_address_y;
                else
                    SRAM_address <= read_address_uv;
                SRAM_we_enable <= 1'b1;
            end
            
            //state transitions and reset
            if (out2 == 3'd5) begin
                out2 <= 3'd0;
                ta_adr <= 7'd2;
                tb_adr <= 7'd3;
                t_read_cycle <= 4'd1;
                m2_state <= S_megastate_1c;
            end
        end
        
        
        /////////////////////////////////////////////////////MEGASTATE 1c//////////////////////////////////////////////////////////////////
        S_megastate_1c: begin //common case of 
        
            //2 cycles of reads (0) and computes (-1)
            if (|stage_a_out) begin
            
                if (stage_a_out == 2'd2) begin
                    if (!read_y_done) begin
                        SRAM_address <= read_address_y;
                        read_flagY <= 1'b0;
                    end else begin
                        SRAM_address <= read_address_uv;
                        read_flagUV <= 1'b0;
                    end
                    SRAM_we_enable <= 1'b1;
                end
                
                dp0_adr_a <= s_prime_adr;
                s_prime_adr <= s_prime_adr + 1'd1;
                dp0_write_data_a <= { {16{ SRAM_read_data[15]}}, SRAM_read_data };
                dp0_enable_a <= 1'b1;
                
                //reads
                s_aa <= s_aa + prod1;
                s_ab <= s_ab + prod3;
                s_ba <= s_ba + prod2;
                s_bb <= s_bb + prod4;

                //address increments
                dp1_adr_a <= ta_adr;
                ta_adr <= ta_adr + 7'd8;
                dp1_adr_b <= tb_adr;
                tb_adr <= tb_adr + 7'd8;
                dp1_enable_a <= 1'b0;
                dp1_enable_b <= 1'b0;
                
                //computes
                op1 <= dp1_read_data_a;
                op2 <= dp1_read_data_b;
                c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
                c_pair_count <= c_pair_count + 1'd1;
                
                if (stage_a_out == 2'd1) begin
                    if ( (t_read_cycle == 4'd4) || (t_read_cycle == 4'd8) || (t_read_cycle == 4'd12) ) begin
                        c_pair_count <= c_pair_count + 5'd1;
                    end else begin
                        c_pair_count <= c_pair_count - 5'd7;
                    end
                end

                stage_a_out <= stage_a_out - 2'd1;
            end
            else if (|stage_b_out) begin
                //accumulating the results of the previous cycle's multiplication
                if(stage_b_out == 2'd3) begin
                    result_s_aa <= s_aa + prod1;
                    result_s_ab <= s_ab + prod3;
                    result_s_ba <= s_ba + prod2;
                    result_s_bb <= s_bb + prod4; 
                end
                
                //accumulating results of current cycle multiplication
                else if (stage_b_out == 2'd2) begin
                    s_aa <= prod1;
                    s_ab <= prod3;
                    s_ba <= prod2;
                    s_bb <= prod4;
                end
                else begin
                    s_aa <= s_aa + prod1;
                    s_ab <= s_ab + prod3;
                    s_ba <= s_ba + prod2;
                    s_bb <= s_bb + prod4;
                end 
                
                if (stage_b_out > 3'd1) begin
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_write_data_a <= { {16{ SRAM_read_data[15]}}, SRAM_read_data };
                    dp0_enable_a <= 1'b1;
                end
                else begin
                    dp0_enable_a <= 1'b0;
                    if (!read_y_done)
                        read_flagY <= 1'b1;
                    else
                        read_flagUV <= 1'b1;
                end
                    
                //reading s values from dp-ram 1
                dp1_adr_a <= ta_adr;
                ta_adr <= ta_adr + 7'd8;
                dp1_adr_b <= tb_adr;
                tb_adr <= tb_adr + 7'd8;
                dp1_enable_a <= 1'b0;
                dp1_enable_b <= 1'b0;

                //setting operands for the matrix multiplications
                op1 <= dp1_read_data_a;
                op2 <= dp1_read_data_b;
                c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
                c_pair_count <= c_pair_count + 1'd1;

                //writing the 4 s values into dp-ram 2
                if (stage_b_out == 2'd2) begin
                    dp2_adr_a <= sa_adr;
                    dp2_adr_b <= sb_adr;
                    dp2_write_data_a <= result_s_aa;
                    dp2_write_data_b <= result_s_ba;
                    dp2_enable_a <= 1'b1;
                    dp2_enable_b <= 1'b1;
                    sa_adr <= sa_adr + 1'd1;
                    sb_adr <= sb_adr + 1'd1;
                end
                else if (stage_b_out == 2'd1) begin
                    dp2_adr_a <= sa_adr;
                    dp2_adr_b <= sb_adr;
                    dp2_write_data_a <= result_s_ab;
                    dp2_write_data_b <= result_s_bb;
                    dp2_enable_a <= 1'b1;
                    dp2_enable_b <= 1'b1;

                    if ((sa_adr == 6'd7) || (sa_adr == 6'd23) || (sa_adr == 6'd39) || (sa_adr == 6'd55)) begin
                        sa_adr <= sa_adr + 7'd9;
                        sb_adr <= sb_adr + 7'd9;
                    end else begin
                        sa_adr <= sa_adr + 1'd1;
                        sb_adr <= sb_adr + 1'd1;
                    end
                end
                stage_b_out <= stage_b_out - 2'd1;
            end //stage_b
            
            //3 cycles to read and compute for the current cycle (0)
            else begin //stage_c
            
                dp2_enable_a <= 1'b0;
                dp2_enable_b <= 1'b0;
            
                if (!read_y_done)
                    SRAM_address <= read_address_y;
                else
                    SRAM_address <= read_address_uv;
                SRAM_we_enable <= 1'b1;

                //accumulating the results of the previous cycle's multiplication
                s_aa <= s_aa + prod1;
                s_ab <= s_ab + prod3;
                s_ba <= s_ba + prod2;
                s_bb <= s_bb + prod4;

                //setting operands for the matrix multiplications
                op1 <= dp1_read_data_a;
                op2 <= dp1_read_data_b;
                c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
                c_pair_count <= c_pair_count + 1'd1;

                // reading s values 
                if (stage_c_out == 2'd1) begin //last read of the current set of 4 multiplications
                    dp1_adr_a <= ta_adr;
                    dp1_adr_b <= tb_adr;
                    dp1_enable_a <= 1'b0;
                    dp1_enable_b <= 1'b0;

                    stage_a_out <= 2'd2;
                    stage_b_out <= 2'd3;
                    stage_c_out <= 2'd3;
                    
                    t_read_cycle <= t_read_cycle + 4'd1;
                    
                    if (ta_adr == 7'd56) begin
                        ta_adr <= 7'd2;
                        tb_adr <= 7'd3;
                        //c_pair_count <= c_pair_count - 5'd7;
                    end
                    else if (ta_adr == 7'd58) begin
                        ta_adr <= 7'd4;
                        tb_adr <= 7'd5;
                    end
                    else if (ta_adr == 7'd60) begin
                        ta_adr <= 7'd6;
                        tb_adr <= 7'd7;
                    end
                    else begin
                        if (t_read_cycle == 4'd15) begin
                            ta_adr <= 7'd0;
                            tb_adr <= 7'd8;
                            m2_state <= S_megastate_1d;
                        end else begin
                            ta_adr <= 7'd0;
                            tb_adr <= 7'd1;
                        end
                    end
                    
                end else begin
                    dp1_adr_a <= ta_adr;
                    ta_adr <= ta_adr + 7'd8;
                    dp1_adr_b <= tb_adr;
                    tb_adr <= tb_adr + 7'd8;
                    dp1_enable_a <= 1'b0;
                    dp1_enable_b <= 1'b0;
                    stage_c_out <= stage_c_out - 2'd1;
                end
            end //end stage_c
        end //end megastate_1c
        
        
        
        /////////////////////////////////////////////////////MEGASTATE 1d//////////////////////////////////////////////////////////////////
        //5 cycle lead out state
        S_megastate_1d: begin
            //2 computes and accumulations
            if (|compute_end_out) begin
                
                if (compute_end_out == 2'd2) begin
                    if (!read_y_done) begin
                        SRAM_address <= read_address_y;
                        read_flagY <= 1'b0;
                    end else begin
                        SRAM_address <= read_address_uv;
                        read_flagUV <= 1'b0;
                    end
                    SRAM_we_enable <= 1'b1;
                end
                
                dp0_adr_a <= s_prime_adr;
                s_prime_adr <= s_prime_adr + 1'd1;
                dp0_write_data_a <= { {16{ SRAM_read_data[15]}}, SRAM_read_data };
                dp0_enable_a <= 1'b1;
                    
                s_aa <= s_aa + prod1;
                s_ab <= s_ab + prod3;
                s_ba <= s_ba + prod2;
                s_bb <= s_bb + prod4;

                //setting operands for the matrix multiplications
                op1 <= dp1_read_data_a;
                op2 <= dp1_read_data_b;
                c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
                c_pair_count <= c_pair_count + 1'd1;

                compute_end_out <= compute_end_out - 2'd1;
            end 
            
            //last accumulation
            else if (last_multiplication_out) begin
                last_multiplication_out <= 1'b0;
                result_s_aa <= s_aa + prod1;
                result_s_ab <= s_ab + prod3;
                result_s_ba <= s_ba + prod2;
                result_s_bb <= s_bb + prod4;
                dp0_adr_a <= s_prime_adr;
                s_prime_adr <= s_prime_adr + 1'd1;
                dp0_write_data_a <= { {16{ SRAM_read_data[15]}}, SRAM_read_data };
                dp0_enable_a <= 1'b1;
            end 
            //second last write into DPRAM
            else if (sb_adr == 6'd62) begin
                dp2_adr_a <= sa_adr;
                dp2_adr_b <= sb_adr;
                dp2_write_data_a <= result_s_aa;
                dp2_write_data_b <= result_s_ba;
                dp2_enable_a <= 1'b1;
                dp2_enable_b <= 1'b1;
                sa_adr <= sa_adr + 1'd1;
                sb_adr <= sb_adr + 1'd1;
                dp0_adr_a <= s_prime_adr;
                s_prime_adr <= 7'd0;
                dp0_write_data_a <= { {16{ SRAM_read_data[15]}}, SRAM_read_data };
                dp0_enable_a <= 1'b1;
            end 
            
            //last write into DPRAM
            else begin
                dp0_enable_a <= 1'b0;
                dp2_adr_a <= sa_adr;
                dp2_adr_b <= sb_adr;
                dp2_write_data_a <= result_s_ab;
                dp2_write_data_b <= result_s_bb;
                dp2_enable_a <= 1'b1;
                dp2_enable_b <= 1'b1;
                sa_adr <= 7'd0;
                sb_adr <= 7'd1;
                
                out1_first <= 1'b1; // still needs to be initialized
                out2 <= 3'd0;
                t_read_cycle <= 4'd0;
                stage_a_out <= 2'd2;
                stage_b_out <= 2'd3;
                stage_c_out <= 2'd3;
                compute_end_out <= 2'd2;
                last_multiplication_out <= 1'b1;
                
                m2_state <= S_megastate_2;
            end
        end //end megastate_1d
        
        
         /////////////////////////////////////////////////////MEGASTATE 2//////////////////////////////////////////////////////////////////
        S_megastate_2: begin
            
            if(start_T) begin
                dp2_enable_a <= 1'b0;
                dp2_enable_b <= 1'b0;
                
                if(leadT < 3'd2) begin
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;
                    leadT <= leadT + 1'd1;//needs to be initialized
                end
                else if (leadT == 3'd2) begin
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;
                    
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;
                    leadT <= leadT + 1'd1;
                end
                else begin
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;
                    
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;
                    
                    if(leadT == 3'd3) begin
                        t_aa <= prod1;
                        t_ab <= prod2;
                        t_ba <= prod3;
                        t_bb <= prod4;
                    end
                    else begin
                        t_aa <= t_aa + prod1;
                        t_ab <= t_ab + prod2;
                        t_ba <= t_ba + prod3;
                        t_bb <= t_bb + prod4;
                    end
                    
                    if (leadT > 3'd5) begin
                        dp2_adr_a <= sa_adr;
                        sa_adr <= sa_adr + 7'd2;
                        dp2_adr_b <= sb_adr;
                        sb_adr <= sb_adr + 7'd2;
                        dp2_enable_a <= 1'b0;
                        dp2_enable_b <= 1'b0;
                    end
                    
                    if (leadT == 3'd7) begin
                        if (!y_done)
                            write_flagY <= 1'b1;
                        else
                            write_flagUV <= 1'b1;
                        leadT <= 3'd0;
                        s_prime_adr <= 7'd0;
                        sp_adrb <= 7'd8;
                        sp_read_cycle <= 4'd1;
                        start_T <= 1'b0;
                    end else begin
                        leadT <= leadT + 1'd1;
                    end
                end
            end // end start_T
            else if (!T_end) begin
                //2 cycles to read(0) and compute(-1)
                if (|stage_a) begin
                    //accumulating matrix values
                    t_aa <= t_aa + prod1;
                    t_ab <= t_ab + prod2;
                    t_ba <= t_ba + prod3;
                    t_bb <= t_bb + prod4;

                    //preparing next addresses to read from dual port
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;

                    //reading s' values from dual port
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;
                    
                    if (!y_done)
                        SRAM_address <= write_address_y;
                    else
                        SRAM_address <= write_address_uv;
                        
                    SRAM_write_data[15:8] <= (dp2_read_data_a[31]) ? 8'd0 : ( (|dp2_read_data_a[30:24]) ? 8'd255 : dp2_read_data_a[23:16] );
                    SRAM_write_data[7:0] <= (dp2_read_data_b[31]) ? 8'd0 : ( (|dp2_read_data_b[30:24]) ? 8'd255 : dp2_read_data_b[23:16] );
                    SRAM_we_enable <= 1'b0;
                    
                    if (stage_a == 2'd1) begin
                        if (!y_done)
                            write_flagY <= 1'b0;
                        else
                            write_flagUV <= 1'b0;
                    end
                    
                    stage_a <= stage_a - 2'd1;
                end // end of stage a
                
                //3 cycles to read(0), write(-1) and compute(0)
                else if (|stage_b) begin
                    SRAM_we_enable <= 1'b1;
                    //final matrix values (from previous stage)
                    if(stage_b == 2'd3) begin
                        result_t_aa <= t_aa + prod1;
                        result_t_ab <= t_ab + prod2;
                        result_t_ba <= t_ba + prod3;
                        result_t_bb <= t_bb + prod4;
                    end
                    //accumulating and computing matrix values
                    //reset case (from previous accumulation)
                    else if ((c_pair_count == 5'd1) || (c_pair_count == 5'd9) || (c_pair_count == 5'd17) || (c_pair_count == 5'd25)) begin
                        t_aa <= prod1;
                        t_ab <= prod2;
                        t_ba <= prod3;
                        t_bb <= prod4;
                    end
                    //common accumulation case
                    else begin
                        t_aa <= t_aa + prod1;
                        t_ab <= t_ab + prod2;
                        t_ba <= t_ba + prod3;
                        t_bb <= t_bb + prod4;
                    end 

                    //preparing next addresses to read from dual port
                    dp0_adr_a <= s_prime_adr;
                    s_prime_adr <= s_prime_adr + 1'd1;
                    dp0_adr_b <= sp_adrb;
                    sp_adrb <= sp_adrb + 1'd1;
                    dp0_enable_a <= 1'b0;
                    dp0_enable_b <= 1'b0;

                    //reading s' values from dual port
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;

                    //writing the 4 T values into dp-ram 1
                    //first pair
                    if (stage_b == 2'd2) begin
                        dp1_adr_a <= ta_adr;
                        dp1_adr_b <= tb_adr;
                        dp1_write_data_a <= { {8{result_t_aa[31]}} , result_t_aa[31:8] };
                        dp1_write_data_b <= { {8{result_t_ba[31]}} , result_t_ba[31:8] };
                        dp1_enable_a <= 1'b1;
                        dp1_enable_b <= 1'b1;
                        ta_adr <= ta_adr + 1'd1;
                        tb_adr <= tb_adr + 1'd1;
                    end
                    //second pair
                    if (stage_b == 2'd1) begin
                        dp1_adr_a <= ta_adr;
                        dp1_adr_b <= tb_adr;
                        dp1_write_data_a <= { {8{result_t_ab[31]}} , result_t_ab[31:8] };
                        dp1_write_data_b <= { {8{result_t_bb[31]}} , result_t_bb[31:8] };
                        dp1_enable_a <= 1'b1;
                        dp1_enable_b <= 1'b1;
                        //matrix address incrementation
                        if ((ta_adr == 6'd7) || (ta_adr == 6'd23) || (ta_adr == 6'd39) || (ta_adr == 6'd55)) begin
                            ta_adr <= ta_adr + 7'd9;
                            tb_adr <= tb_adr + 7'd9;
                        end else begin
                            ta_adr <= ta_adr + 1'd1;
                            tb_adr <= tb_adr + 1'd1;
                        end
                    end
                    stage_b <= stage_b - 2'd1;
                end //stage_b
                //3 cycles to read(0) and compute (0)
                
                else begin//stage_c

                    dp1_enable_a <= 1'b0;
                    dp1_enable_b <= 1'b0;

                    //accumulating the results of the previous cycle's multiplication
                    t_aa <= t_aa + prod1;
                    t_ab <= t_ab + prod2;
                    t_ba <= t_ba + prod3;
                    t_bb <= t_bb + prod4;

                    //setting operands for the matrix multiplications
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;

                    // reading s' values 
                    if (stage_c == 2'd1) begin //last read of the current set of 4 multiplications
                        dp0_adr_a <= s_prime_adr;
                        dp0_adr_b <= sp_adrb;
                        dp0_enable_a <= 1'b0;
                        dp0_enable_b <= 1'b0;

                        //reset stage flags
                        stage_a <= 2'd2;
                        stage_b <= 2'd3;
                        stage_c <= 2'd3;
                        
                        sp_read_cycle <= sp_read_cycle + 4'd1;

                        if (sp_read_cycle == 4'd15) begin // have done all reads to compute the current 8 by 8 matrix
                            s_prime_adr <= 6'd0;
                            sp_adrb <= 6'd8;
                            T_end <= 1'b1;
                        end
                        //begin using next two rows of s'
                        else if ((sp_read_cycle == 4'd3) ||(sp_read_cycle == 4'd7) || (sp_read_cycle == 4'd11)) begin
                            s_prime_adr <= s_prime_adr + 6'd9;
                            sp_adrb <= sp_adrb + 6'd9;
                        end else begin // reset the s' values to the start of the rows
                            s_prime_adr <= s_prime_adr - 6'd7;
                            sp_adrb <= sp_adrb - 6'd7;
                        end
                    end else begin
                        dp0_adr_a <= s_prime_adr;
                        dp0_adr_b <= sp_adrb;
                        dp0_enable_a <= 1'b0;
                        dp0_enable_b <= 1'b0;
                        s_prime_adr <= s_prime_adr + 1'd1;
                        sp_adrb <= sp_adrb + 1'd1;
                        stage_c <= stage_c - 2'd1;
                    end
                    
                    if (stage_c < 2'd3) begin
                        dp2_adr_a <= sa_adr;
                        dp2_adr_b <= sb_adr;
                        dp2_enable_a <= 1'b0;
                        dp2_enable_b <= 1'b0;
                        sa_adr <= sa_adr + 7'd2;
                        sb_adr <= sb_adr + 7'd2;
                    end
                    
                    if (stage_c == 2'd1) begin
                        if (!y_done)
                            write_flagY <= 1'b1;
                        else
                            write_flagUV <= 1'b1;
                    end
                end //end stage_c 
                
            //begin lead out (5 cycles)
            end else begin //T_end
                //first 2 cycles: computing and accumulating (-1)
                if (|compute_end) begin
                    t_aa <= t_aa + prod1;
                    t_ab <= t_ab + prod2;
                    t_ba <= t_ba + prod3;
                    t_bb <= t_bb + prod4;

                    //setting operands for the matrix multiplications
                    op1 <= dp0_read_data_a;
                    op2 <= dp0_read_data_b;
                    c_pair <= c_pair_count; //sets op3 and op4 as values from the C matrix
                    c_pair_count <= c_pair_count + 1'd1;  
                    
                    if (!y_done)
                        SRAM_address <= write_address_y;
                    else
                        SRAM_address <= write_address_uv;
                    SRAM_write_data[15:8] <= (dp2_read_data_a[31]) ? 8'd0 : ( (|dp2_read_data_a[30:24]) ? 8'd255 : dp2_read_data_a[23:16] );
                    SRAM_write_data[7:0] <= (dp2_read_data_b[31]) ? 8'd0 : ( (|dp2_read_data_b[30:24]) ? 8'd255 : dp2_read_data_b[23:16] );
                    SRAM_we_enable <= 1'b0;
                    
                    if (compute_end == 2'd1) begin
                        if (!y_done)
                            write_flagY <= 1'b0;
                        else
                            write_flagUV <= 1'b0;
                    end
                    
                    compute_end <= compute_end - 1'd1;
                end 

                // next cycle: final accumulation (-1)
                else if (last_multiplication) begin
                    SRAM_we_enable <= 1'b1;
                    last_multiplication <= 1'b0;
                    result_t_aa <= t_aa + prod1;
                    result_t_ab <= t_ab + prod2;
                    result_t_ba <= t_ba + prod3;
                    result_t_bb <= t_bb + prod4;
                end 

                // next cycle: writing(-1) first pair into DPRAM
                else if (tb_adr == 6'd62) begin
                    dp1_adr_a <= ta_adr;
                    dp1_adr_b <= tb_adr;
                    dp1_write_data_a <= { {8{result_t_aa[31]}} , result_t_aa[31:8] };
                    dp1_write_data_b <= { {8{result_t_ba[31]}} , result_t_ba[31:8] };
                    dp1_enable_a <= 1'b1;
                    dp1_enable_b <= 1'b1;
                    ta_adr <= ta_adr + 1'd1;
                    tb_adr <= tb_adr + 1'd1;
                end 

                // last cycle: writing(-1) second pair into DPRAM, reset for next megastate reentry
                else begin
                    dp1_adr_a <= ta_adr;
                    dp1_adr_b <= tb_adr;
                    dp1_write_data_a <= { {8{result_t_ab[31]}} , result_t_ab[31:8] };
                    dp1_write_data_b <= { {8{result_t_bb[31]}} , result_t_bb[31:8] };
                    dp1_enable_a <= 1'b1;
                    dp1_enable_b <= 1'b1;
                    ta_adr <= 6'd0;
                    tb_adr <= 6'd1;
                    
                    start_T <= 1'b1;
                    leadT <= 3'd0;
                    sp_read_cycle <= 4'd0;
                    T_end <= 1'b0;
                    stage_a <= 2'd2;
                    stage_b <= 2'd3;
                    stage_c <= 2'd3;
                    
                    compute_end <= 2'd2;
                    last_multiplication <= 1'b1;
                    
                    sa_adr <= 7'd0;
                    sb_adr <= 7'd8;
                    
                    if (t_computations == 12'd2399) begin
                        m2_state <= S_compute_out1;
                    end else begin
                        m2_state <= S_megastate_1a;
                        t_computations <= t_computations + 12'd1;
                    end
                end
            end
        end //end MEGASTATE2 -- 
            
        //begin computation for S
        ///////////////////////////////////////////////////////COMPOOT S/////////////////////////////////////////////////////////////////////
        //2 cycles reading the t matrix    
        S_compute_out1: begin
            dp1_adr_a <= ta_adr;
            ta_adr <= ta_adr + 7'd8;
            dp1_adr_b <= tb_adr;
            tb_adr <= tb_adr + 7'd8;
            dp1_enable_a <= 1'b0;
            dp1_enable_b <= 1'b0;
            if (out1_first) begin
                out1_first <= 1'b0;
            end else
                m2_state <= S_compute_out2;  
        end
        
        //6 cycles reading the t matrix and computing and accumulating the results (0)    
        S_compute_out2: begin
            //accumulation
            if (out2 == 3'd1) begin
                s_aa <= prod1;
                s_ab <= prod3;
                s_ba <= prod2;
                s_bb <= prod4;
            end
            else if (out2 > 3'd1) begin
                s_aa <= s_aa + prod1;
                s_ab <= s_ab + prod3;
                s_ba <= s_ba + prod2;
                s_bb <= s_bb + prod4;
            end
            
            //address incrementation
            dp1_adr_a <= ta_adr;
            ta_adr <= ta_adr + 7'd8;
            dp1_adr_b <= tb_adr;
            tb_adr <= tb_adr + 7'd8;
            dp1_enable_a <= 1'b0;
            dp1_enable_b <= 1'b0;

            //data reading 
            op1 <= dp1_read_data_a;
            op2 <= dp1_read_data_b;
            c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
            c_pair_count <= c_pair_count + 1'd1;
            out2 <= out2 + 1'd1;
            
            //state transitions and reset
            if (out2 == 3'd5) begin
                ta_adr <= 7'd2;
                tb_adr <= 7'd3;
                t_read_cycle <= 4'd1;
                m2_state <= S_compute_out3;
            end
        end
        
        S_compute_out3: begin //common case of 
            //2 cycles of reads (0) and computes (-1)
            if (|stage_a_out) begin
                //reads
                s_aa <= s_aa + prod1;
                s_ab <= s_ab + prod3;
                s_ba <= s_ba + prod2;
                s_bb <= s_bb + prod4;

                //address increments
                dp1_adr_a <= ta_adr;
                ta_adr <= ta_adr + 7'd8;
                dp1_adr_b <= tb_adr;
                tb_adr <= tb_adr + 7'd8;
                dp1_enable_a <= 1'b0;
                dp1_enable_b <= 1'b0;
                
                //computes
                op1 <= dp1_read_data_a;
                op2 <= dp1_read_data_b;
                c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
                c_pair_count <= c_pair_count + 1'd1;
                
                if (stage_a_out == 2'd1) begin
                    if ( (t_read_cycle == 4'd4) || (t_read_cycle == 4'd8) || (t_read_cycle == 4'd12) ) begin
                        c_pair_count <= c_pair_count + 5'd1;
                    end else begin
                        c_pair_count <= c_pair_count - 5'd7;
                    end
                end

                stage_a_out <= stage_a_out - 2'd1;
            end
            else if (|stage_b_out) begin
                //accumulating the results of the previous cycle's multiplication
                if(stage_b_out == 2'd3) begin
                    result_s_aa <= s_aa + prod1;
                    result_s_ab <= s_ab + prod3;
                    result_s_ba <= s_ba + prod2;
                    result_s_bb <= s_bb + prod4;
                end
                
                //accumulating results of current cycle multiplication
                /*else if ((transpose_pair_count == 5'd1) || (transpose_pair_count == 5'd9) || (transpose_pair_count == 5'd17) || (transpose_pair_count == 5'd25)) begin*/
                else if (stage_b_out == 2'd2) begin
                    s_aa <= prod1;
                    s_ab <= prod3;
                    s_ba <= prod2;
                    s_bb <= prod4;
                end
                else begin
                    s_aa <= s_aa + prod1;
                    s_ab <= s_ab + prod3;
                    s_ba <= s_ba + prod2;
                    s_bb <= s_bb + prod4;
                end 

                //reading s values from dp-ram 1
                dp1_adr_a <= ta_adr;
                ta_adr <= ta_adr + 7'd8;
                dp1_adr_b <= tb_adr;
                tb_adr <= tb_adr + 7'd8;
                dp1_enable_a <= 1'b0;
                dp1_enable_b <= 1'b0;

                //setting operands for the matrix multiplications
                op1 <= dp1_read_data_a;
                op2 <= dp1_read_data_b;
                c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
                c_pair_count <= c_pair_count + 1'd1;

                //writing the 4 s values into dp-ram 2
                if (stage_b_out == 2'd2) begin
                    dp2_adr_a <= sa_adr;
                    dp2_adr_b <= sb_adr;
                    dp2_write_data_a <= result_s_aa;
                    dp2_write_data_b <= result_s_ba;
                    dp2_enable_a <= 1'b1;
                    dp2_enable_b <= 1'b1;
                    sa_adr <= sa_adr + 1'd1;
                    sb_adr <= sb_adr + 1'd1;
                end
                else if (stage_b_out == 2'd1) begin
                    dp2_adr_a <= sa_adr;
                    dp2_adr_b <= sb_adr;
                    dp2_write_data_a <= result_s_ab;
                    dp2_write_data_b <= result_s_bb;
                    dp2_enable_a <= 1'b1;
                    dp2_enable_b <= 1'b1;

                    if ((sa_adr == 6'd7) || (sa_adr == 6'd23) || (sa_adr == 6'd39) || (sa_adr == 6'd55)) begin
                        sa_adr <= sa_adr + 6'd9;
                        sb_adr <= sb_adr + 6'd9;
                    end else begin
                        sa_adr <= sa_adr + 1'd1;
                        sb_adr <= sb_adr + 1'd1;
                    end
                end
                stage_b_out <= stage_b_out - 2'd1;
            end //stage_b
            
            //3 cycles to read and compute for the current cycle (0)
            else begin //stage_c

                dp2_enable_a <= 1'b0;
                dp2_enable_b <= 1'b0;

                //accumulating the results of the previous cycle's multiplication
                s_aa <= s_aa + prod1;
                s_ab <= s_ab + prod3;
                s_ba <= s_ba + prod2;
                s_bb <= s_bb + prod4;

                //setting operands for the matrix multiplications
                op1 <= dp1_read_data_a;
                op2 <= dp1_read_data_b;
                c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
                c_pair_count <= c_pair_count + 1'd1;

                // reading s values 
                if (stage_c_out == 2'd1) begin //last read of the current set of 4 multiplications
                    dp1_adr_a <= ta_adr;
                    dp1_adr_b <= tb_adr;
                    dp1_enable_a <= 1'b0;
                    dp1_enable_b <= 1'b0;

                    stage_a_out <= 2'd2;
                    stage_b_out <= 2'd3;
                    stage_c_out <= 2'd3;
                    
                    t_read_cycle <= t_read_cycle + 4'd1;

                    /*if (t_read_cycle == 4'd15) begin // have done all reads to compute the current 8 by 8 matrix
                        ta_adr <= 6'd0;
                        tb_adr <= 6'd8;
                        m2_state <= S_compute_out4;
                    end
                    //begin using next two rows of s'
                    else if ((t_read_cycle == 4'd3) || (t_read_cycle == 4'd7) || (t_read_cycle == 4'd11)) begin
                        ta_adr <= ta_adr + 6'd9;
                        tb_adr <= tb_adr + 6'd9;
                    end else begin // reset the s values to the start of the rows
                        ta_adr <= ta_adr - 6'd7;
                        tb_adr <= tb_adr - 6'd7;
                    end*/
                    
                    if (ta_adr == 7'd56) begin
                        ta_adr <= 7'd2;
                        tb_adr <= 7'd3;
                        //c_pair_count <= c_pair_count - 5'd7;
                    end
                    else if (ta_adr == 7'd58) begin
                        ta_adr <= 7'd4;
                        tb_adr <= 7'd5;
                    end
                    else if (ta_adr == 7'd60) begin
                        ta_adr <= 7'd6;
                        tb_adr <= 7'd7;
                    end
                    else begin
                        if (t_read_cycle == 4'd15) begin
                            ta_adr <= 7'd0;
                            tb_adr <= 7'd8;
                            //c_pair_count <= 5'd0;
                            m2_state <= S_compute_out4;
                        end else begin
                            ta_adr <= 7'd0;
                            tb_adr <= 7'd1;
                            //c_pair_count <= c_pair_count + 5'd1; //*********** IS THIS RIGHT????????? ********************
                        end
                    end
                    
                end else begin
                    dp1_adr_a <= ta_adr;
                    ta_adr <= ta_adr + 7'd8;
                    dp1_adr_b <= tb_adr;
                    tb_adr <= tb_adr + 7'd8;
                    dp1_enable_a <= 1'b0;
                    dp1_enable_b <= 1'b0;
                    stage_c_out <= stage_c_out - 2'd1;
                end
            end //end stage_c
        end //end compute_out3
        
        //5 cycle lead out state
        S_compute_out4: begin
            //2 computes and accumulations
            if (|compute_end_out) begin
                s_aa <= s_aa + prod1;
                s_ab <= s_ab + prod3;
                s_ba <= s_ba + prod2;
                s_bb <= s_bb + prod4;

                //setting operands for the matrix multiplications
                op1 <= dp1_read_data_a;
                op2 <= dp1_read_data_b;
                c_pair <= c_pair_count; //sets op3 and op4 as values from the C transpose matrix
                c_pair_count <= c_pair_count + 1'd1;

                compute_end_out <= compute_end_out - 2'd1;
            end 
            
            //last accumulation
            else if (last_multiplication_out) begin
                last_multiplication_out <= 1'b0;
                result_s_aa <= s_aa + prod1;
                result_s_ab <= s_ab + prod3;
                result_s_ba <= s_ba + prod2;
                result_s_bb <= s_bb + prod4;
            end 
            //second last write into DPRAM
            else if (sb_adr == 6'd62) begin
                dp2_adr_a <= sa_adr;
                dp2_adr_b <= sb_adr;
                dp2_write_data_a <= result_s_aa;
                dp2_write_data_b <= result_s_ba;
                dp2_enable_a <= 1'b1;
                dp2_enable_b <= 1'b1;
                sa_adr <= sa_adr + 1'd1;
                sb_adr <= sb_adr + 1'd1;
            end 
            
            //last write into DPRAM
            else begin
                dp2_adr_a <= sa_adr;
                dp2_adr_b <= sb_adr;
                dp2_write_data_a <= result_s_ab;
                dp2_write_data_b <= result_s_bb;
                dp2_enable_a <= 1'b1;
                dp2_enable_b <= 1'b1;
                sa_adr <= 7'd0;
                sb_adr <= 7'd1;
                m2_state <= S_write_outa;
            end
        end
        
        
        
        /////////////////////////////////////////////////////////WRITE STATE///////////////////////////////////////////////////////////////////   
        //initialize writeout to 0
        S_write_outa: begin
            dp2_adr_a <= sa_adr;
            sa_adr <= sa_adr + 7'd2;
            dp2_adr_b <= sb_adr;
            sb_adr <= sb_adr + 7'd2;
            dp2_enable_a <= 1'b0;
            dp2_enable_b <= 1'b0;
            writeout <= writeout + 6'd1;
            if (writeout == 6'd1) begin
                write_flagUV <= 1'b1;
                m2_state <= S_write_outb;
            end
        end
            
        S_write_outb: begin
            SRAM_address <= write_address_uv;
            SRAM_write_data[15:8] <= (dp2_read_data_a[31]) ? 8'd0 : ( (|dp2_read_data_a[30:24]) ? 8'd255 : dp2_read_data_a[23:16] );
            SRAM_write_data[7:0] <= (dp2_read_data_b[31]) ? 8'd0 : ( (|dp2_read_data_b[30:24]) ? 8'd255 : dp2_read_data_b[23:16] );
            SRAM_we_enable <= 1'b0;
            
            dp2_adr_a <= sa_adr;
            dp2_adr_b <= sa_adr;
            dp2_enable_a <= 1'b0;
            dp2_enable_b <= 1'b0;
            sa_adr <= sa_adr + 7'd2;
            sb_adr <= sb_adr + 7'd2;
            
            writeout <= writeout + 6'd1;
            if (writeout == 6'd31)
                m2_state <= S_write_outc;
        end
        
        S_write_outc: begin
            SRAM_address <= write_address_uv;
            SRAM_write_data[15:8] <= (dp2_read_data_a[31]) ? 8'd0 : ( (|dp2_read_data_a[30:24]) ? 8'd255 : dp2_read_data_a[23:16] );
            SRAM_write_data[7:0] <= (dp2_read_data_b[31]) ? 8'd0 : ( (|dp2_read_data_b[30:24]) ? 8'd255 : dp2_read_data_b[23:16] );
            SRAM_we_enable <= 1'b0;
            
            writeout <= writeout + 6'd1;
            if (writeout == 6'd33) begin
                m2_state <= S_idle2;
                m2_done <= 1'b1;
                write_flagUV <= 1'b0;
            end
        end
        
        endcase
    
    end
end
endmodule