`ifndef DEFINE_STATE

// This defines the states
typedef enum logic [2:0] {
	S_IDLE,
	S_ENABLE_UART_RX,
	S_WAIT_UART_RX,
    S_MILESTONE_1,
    S_MILESTONE_2
} top_state_type;

typedef enum logic [1:0] {
	S_RXC_IDLE,
	S_RXC_SYNC,
	S_RXC_ASSEMBLE_DATA,
	S_RXC_STOP_BIT
} RX_Controller_state_type;

typedef enum logic [2:0] {
	S_US_IDLE,
	S_US_STRIP_FILE_HEADER_1,
	S_US_STRIP_FILE_HEADER_2,
	S_US_START_FIRST_BYTE_RECEIVE,
	S_US_WRITE_FIRST_BYTE,
	S_US_START_SECOND_BYTE_RECEIVE,
	S_US_WRITE_SECOND_BYTE
} UART_SRAM_state_type;

typedef enum logic [3:0] {
	S_VS_WAIT_NEW_PIXEL_ROW,
	S_VS_NEW_PIXEL_ROW_DELAY_1,
	S_VS_NEW_PIXEL_ROW_DELAY_2,
	S_VS_NEW_PIXEL_ROW_DELAY_3,
	S_VS_NEW_PIXEL_ROW_DELAY_4,
	S_VS_NEW_PIXEL_ROW_DELAY_5,
	S_VS_FETCH_PIXEL_DATA_0,
	S_VS_FETCH_PIXEL_DATA_1,
	S_VS_FETCH_PIXEL_DATA_2,
	S_VS_FETCH_PIXEL_DATA_3
} VGA_SRAM_state_type;

typedef enum logic [4:0] {
    S_idle,
    S_lead0,
    S_lead1,
    S_lead2,
    S_lead3,
    S_lead4,
    S_lead5,
    S_lead6,
    S_lead7,
    S_lead8,
    S_lead9,
    S_lead10,
    S_lead11,
    S_lead12,
    S_lead13,
    S_c0,
    S_c1,
    S_c2,
    S_c3,
    S_c4,
    S_c5,
    S_out0,
    S_out1,
    S_out2,
    S_out3
} milestone_1_state;

typedef enum logic [3:0] {
    S_idle2,
    S_read_in,
    S_compute_in,
    S_megastate_1a,
    S_megastate_1b,
    S_megastate_1c,
    S_megastate_1d,
    S_megastate_2,
    S_compute_out1,
    S_compute_out2,
    S_compute_out3,
    S_compute_out4,
    S_write_outa,
    S_write_outb,
    S_write_outc
} milestone_2_state;

`define DEFINE_STATE 1
`endif
