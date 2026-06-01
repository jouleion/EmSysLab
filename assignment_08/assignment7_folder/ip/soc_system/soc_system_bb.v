
module soc_system (
	clk_clk,
	esl_bus_demo_0_encoder_PITCH_ENC_A,
	esl_bus_demo_0_encoder_PITCH_ENC_B,
	esl_bus_demo_0_encoder_YAW_ENC_A,
	esl_bus_demo_0_encoder_YAW_ENC_B,
	esl_bus_demo_0_gpio_SW,
	esl_bus_demo_0_gpio_LED,
	hps_0_h2f_reset_reset_n,
	memory_mem_a,
	memory_mem_ba,
	memory_mem_ck,
	memory_mem_ck_n,
	memory_mem_cke,
	memory_mem_cs_n,
	memory_mem_ras_n,
	memory_mem_cas_n,
	memory_mem_we_n,
	memory_mem_reset_n,
	memory_mem_dq,
	memory_mem_dqs,
	memory_mem_dqs_n,
	memory_mem_odt,
	memory_mem_dm,
	memory_oct_rzqin,
	reset_reset_n);	

	input		clk_clk;
	input		esl_bus_demo_0_encoder_PITCH_ENC_A;
	input		esl_bus_demo_0_encoder_PITCH_ENC_B;
	input		esl_bus_demo_0_encoder_YAW_ENC_A;
	input		esl_bus_demo_0_encoder_YAW_ENC_B;
	input	[3:0]	esl_bus_demo_0_gpio_SW;
	output	[7:0]	esl_bus_demo_0_gpio_LED;
	output		hps_0_h2f_reset_reset_n;
	output	[14:0]	memory_mem_a;
	output	[2:0]	memory_mem_ba;
	output		memory_mem_ck;
	output		memory_mem_ck_n;
	output		memory_mem_cke;
	output		memory_mem_cs_n;
	output		memory_mem_ras_n;
	output		memory_mem_cas_n;
	output		memory_mem_we_n;
	output		memory_mem_reset_n;
	inout	[31:0]	memory_mem_dq;
	inout	[3:0]	memory_mem_dqs;
	inout	[3:0]	memory_mem_dqs_n;
	output		memory_mem_odt;
	output	[3:0]	memory_mem_dm;
	input		memory_oct_rzqin;
	input		reset_reset_n;
endmodule
