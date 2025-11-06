`ifndef RUN_TEST_INTR_MODEM_V
`define RUN_TEST_INTR_MODEM_V
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;

localparam [15:0] M_RI  = 16'h0001;
localparam [15:0] M_CTS = 16'h0002;
localparam [15:0] M_DCD = 16'h0004;
localparam [15:0] M_DSR = 16'h0008;
localparam [15:0] M_MS  = 16'h000F;

task one_modem(input [8*3-1:0] nm, input [3:0] which, input [15:0] m);
  reg [15:0] ris, mis;
begin
  apb_write(OFF_UARTIMSC, m);       // mask one at a time
`ifdef TB_HAS_DUMMY
  tb_modem_toggle(which);
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ({nm," RIS"}, ris & m, m);
  CHECK_EQ({nm," MIS"}, mis & m, m);
  apb_write(OFF_UARTICR, m);
`else
  $display("[SKIP] RTL mode w/o modem stim; expect none: %s", nm);
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ({nm," RIS 0"}, ris & m, 16'h0);
  CHECK_EQ({nm," MIS 0"}, mis & m, 16'h0);
`endif
end
endtask

task run_test; begin
  $display("\n[TC] UARTMSINTR — Modem status");
  one_modem("RI" , 4'b0001, M_RI );
  one_modem("CTS", 4'b0010, M_CTS);
  one_modem("DCD", 4'b0100, M_DCD);
  one_modem("DSR", 4'b1000, M_DSR);
end
endtask
`endif

