

# add waves to waveform
add wave Clock_50
#add wave -divider {***************}
#add wave uut/SRAM_we_n
#add wave -decimal uut/SRAM_write_data
#add wave -hexadecimal uut/SRAM_address
add wave -decimal uut/top_state

############## Milestone 1 ####################
#add wave -hexadecimal uut/m1_j
#add wave -hexadecimal uut/m1_row
#add wave -hexadecimal uut/mR_even
#add wave -hexadecimal uut/mR_odd
#add wave -hexadecimal uut/mG_even
#add wave -hexadecimal uut/mG_odd
#add wave -hexadecimal uut/mB_even
#add wave -hexadecimal uut/mB_odd
#add wave -decimal uut/M1_unit/m1_state
#add wave -hexadecimal uut/M1_unit/u_p5
#add wave -hexadecimal uut/M1_unit/u_p3
#add wave -hexadecimal uut/M1_unit/u_p1
#add wave -hexadecimal uut/M1_unit/u_m1
#add wave -hexadecimal uut/M1_unit/u_m3
#add wave -hexadecimal uut/M1_unit/u_m5
#add wave -divider {****************}
#add wave -hexadecimal uut/M1_unit/v_p5
#add wave -hexadecimal uut/M1_unit/v_p3
#add wave -hexadecimal uut/M1_unit/v_p1
#add wave -hexadecimal uut/M1_unit/v_m1
#add wave -hexadecimal uut/M1_unit/v_m3
#add wave -hexadecimal uut/M1_unit/v_m5
#add wave -divider {****************}
#add wave -decimal uut/SRAM_write_data_a
#add wave -decimal uut/SRAM_write_data_b
#add wave -hexadecimal uut/M1_unit/u_even
#add wave -hexadecimal uut/M1_unit/v_even
#add wave -hexadecimal uut/M1_unit/R_accE
#add wave -hexadecimal uut/mR_even
#add wave -hexadecimal uut/M1_unit/G_accE
#add wave -hexadecimal uut/mG_even
#add wave -hexadecimal uut/M1_unit/B_accE
#add wave -hexadecimal uut/mB_even
#add wave -divider {****************}
#add wave -decimal uut/SRAM_read_data
#add wave -hexadecimal uut/M1_unit/u_buf
#add wave -hexadecimal uut/M1_unit/v_buf
#add wave -decimal uut/M1_unit/y_buf

################# Milestone 2 #####################
add wave -decimal uut/M2_unit/m2_state
add wave -hexadecimal uut/M2_unit/sp_read_cycle
add wave -decimal uut/M2_unit/stage_a
add wave -decimal uut/M2_unit/stage_b
add wave -decimal uut/M2_unit/stage_c
add wave -hexadecimal uut/M2_unit/t_computations

add wave -divider {***************************}

add wave uut/SRAM_we_n
add wave -decimal uut/SRAM_write_data
add wave -unsigned uut/M2_unit/read_address_uv
add wave -unsigned uut/M2_unit/write_address_uv
add wave -unsigned uut/SRAM_address
add wave -hexadecimal uut/SRAM_read_data
add wave -hexadecimal uut/M2_unit/dp0_write_data_a

add wave -divider {***************************}

add wave -hexadecimal uut/M2_unit/write_address_y
add wave uut/M2_unit/read_y_done
add wave uut/M2_unit/y_done
add wave -binary uut/M2_unit/result_t_aa
add wave -binary uut/M2_unit/result_t_ab
add wave -binary uut/M2_unit/result_s_aa
add wave -binary uut/M2_unit/result_s_ab
add wave -hexadecimal uut/M2_unit/c_pair

add wave -divider {***************************}

add wave -decimal uut/M2_unit/prod1
add wave -decimal uut/M2_unit/t_aa
add wave -decimal uut/M2_unit/t_ab
add wave -decimal uut/M2_unit/t_ba
add wave -decimal uut/M2_unit/t_bb

add wave -divider {***************************}

add wave -decimal uut/M2_unit/op1
add wave -decimal uut/M2_unit/op2
add wave -decimal uut/M2_unit/op3
add wave -decimal uut/M2_unit/op4

add wave -divider {***************************}

add wave -decimal uut/M2_unit/m2_state
add wave -decimal uut/M2_unit/dp0_write_data_a
add wave -decimal uut/M2_unit/dp0_write_data_b
add wave -decimal uut/M2_unit/dp0_read_data_a
add wave -decimal uut/M2_unit/dp0_read_data_b
add wave -decimal uut/M2_unit/dp1_write_data_a
add wave -decimal uut/M2_unit/dp1_write_data_b
add wave -decimal uut/M2_unit/dp1_read_data_a
add wave -decimal uut/M2_unit/dp1_read_data_b
add wave -decimal uut/M2_unit/dp2_write_data_a
add wave -decimal uut/M2_unit/dp2_write_data_b
add wave -decimal uut/M2_unit/dp2_read_data_a
add wave -decimal uut/M2_unit/dp2_read_data_b
add wave -decimal uut/M2_unit/sa_adr
add wave -decimal uut/M2_unit/sb_adr
