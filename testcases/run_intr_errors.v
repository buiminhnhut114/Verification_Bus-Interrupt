`ifndef RUN_TEST_INTR_ERRORS_V
`define RUN_TEST_INTR_ERRORS_V
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTICR   = 10'h011;

localparam [15:0] M_FE = 16'h0080;
localparam [15:0] M_PE = 16'h0100;
localparam [15:0] M_BE = 16'h0200;
localparam [15:0] M_OE = 16'h0400;
localparam [15:0] M_ERR = 16'h0780;

task do_err(input [8*2-1:0] nm, input [15:0] m);
  reg [15:0] ris, mis;
begin
`ifdef TB_HAS_DUMMY
  if (m==M_FE) tb_make_error("FE");
  if (m==M_PE) tb_make_error("PE");
  if (m==M_BE) tb_make_error("BE");
  if (m==M_OE) tb_make_error("OE");

  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ({nm," RIS"}, ris & m, m);
  CHECK_EQ({nm," MIS"}, mis & m, m);
  apb_write(OFF_UARTICR, m);
`else
  $display("[SKIP] RTL mode w/o error injector; expect none: %s", nm);
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ({nm," RIS 0"}, ris & m, 16'h0);
  CHECK_EQ({nm," MIS 0"}, mis & m, 16'h0);
`endif
end
endtask

task run_test; begin
  $display("\n[TC] UARTEINTR — Error sources (FE/PE/BE/OE)");
  apb_write(OFF_UARTIMSC, M_ERR);
  do_err("FE", M_FE);
  do_err("PE", M_PE);
  do_err("BE", M_BE);
  do_err("OE", M_OE);
end
endtask
`endif

