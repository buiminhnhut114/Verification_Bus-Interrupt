`ifndef RUN_TEST_INTR_ERRORS_V
`define RUN_TEST_INTR_ERRORS_V

localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTICR   = 10'h011;
localparam [15:0] M_FE = 16'h0080, M_PE = 16'h0100, M_BE = 16'h0200, M_OE = 16'h0400;
localparam [15:0] M_ERR = M_FE|M_PE|M_BE|M_OE;

task run_test;
  reg [15:0] ris;
begin
  $display("\n[TC] Error interrupts — FE/PE/BE/OE");
  apb_write(OFF_UARTIMSC, M_ERR);

`ifndef USE_RTL
  tb_make_error("FE"); tb_make_error("PE"); tb_make_error("BE"); tb_make_error("OE");
`endif

  apb_read(OFF_UARTRIS, ris);
  CHECK_EQ("FERIS", ris & M_FE, M_FE);
  CHECK_EQ("PERIS", ris & M_PE, M_PE);
  CHECK_EQ("BERIS", ris & M_BE, M_BE);
  CHECK_EQ("OERIS", ris & M_OE, M_OE);

  apb_write(OFF_UARTICR, M_ERR);
  apb_read(OFF_UARTRIS, ris); CHECK_EQ("All errors cleared", ris & M_ERR, 16'h0);
end
endtask
`endif

