`ifndef RUN_TEST_INTR_MODEM_V
`define RUN_TEST_INTR_MODEM_V

localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTICR   = 10'h011;
localparam [15:0] M_RI=16'h0001, M_CTS=16'h0002, M_DCD=16'h0004, M_DSR=16'h0008;
localparam [15:0] M_MS = M_RI|M_CTS|M_DCD|M_DSR;

task run_test;
  reg [15:0] ris;
begin
  $display("\n[TC] Modem status — RI/CTS/DCD/DSR");
  apb_write(OFF_UARTIMSC, M_MS);

`ifndef USE_RTL
  tb_modem_toggle(4'b1111);            // DUMMY: toggle tất cả
`endif

  apb_read(OFF_UARTRIS, ris);
  CHECK_EQ("RI set",  ris & M_RI , M_RI );
  CHECK_EQ("CTS set", ris & M_CTS, M_CTS);
  CHECK_EQ("DCD set", ris & M_DCD, M_DCD);
  CHECK_EQ("DSR set", ris & M_DSR, M_DSR);

  apb_write(OFF_UARTICR, M_MS);
  apb_read(OFF_UARTRIS, ris); CHECK_EQ("All modem cleared", ris & M_MS, 16'h0);
end
endtask
`endif

