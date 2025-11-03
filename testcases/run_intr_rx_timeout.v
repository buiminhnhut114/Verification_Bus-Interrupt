`ifndef RUN_TEST_INTR_RX_TIMEOUT_V
`define RUN_TEST_INTR_RX_TIMEOUT_V

localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTICR   = 10'h011;
localparam [15:0] M_RT = 16'h0040;

task run_test;
  reg [15:0] ris;
begin
  $display("\n[TC] RX timeout (32-bit) + negative case");
  apb_write(OFF_UARTLCR_H, 16'h0010);   // FEN=1
  apb_write(OFF_UARTIMSC,  M_RT);

`ifndef USE_RTL
  tb_rx_pop(16); tb_rx_push(2);
  tb_rx_timeout();                      // DUMMY: idle 32-bit
`endif

  apb_read(OFF_UARTRIS, ris); CHECK_EQ("RTRIS set", ris & M_RT, M_RT);
  apb_write(OFF_UARTICR, M_RT);

`ifndef USE_RTL
  tb_rx_pop(16); tb_rx_timeout();       // rỗng trước -> không set
`endif

  apb_read(OFF_UARTRIS, ris); CHECK_EQ("RTRIS stays 0 (negative)", ris & M_RT, 16'h0);
end
endtask
`endif

