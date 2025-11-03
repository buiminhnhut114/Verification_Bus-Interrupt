`ifndef RUN_TEST_INTR_RX_BYPASS_V
`define RUN_TEST_INTR_RX_BYPASS_V

localparam [11:2] OFF_UARTDR    = 10'h000; // 0x000
localparam [11:2] OFF_UARTLCR_H = 10'h00B; // 0x02C
localparam [11:2] OFF_UARTIMSC  = 10'h00E; // 0x038
localparam [11:2] OFF_UARTRIS   = 10'h00F; // 0x03C
localparam [11:2] OFF_UARTMIS   = 10'h010; // 0x040
localparam [11:2] OFF_UARTICR   = 10'h011; // 0x044;
localparam [15:0] M_RX = 16'h0010;

task run_test;
  reg [15:0] ris, mis;
begin
  $display("\n[TC] RX interrupt — bypass (FEN=0)");
  apb_write(OFF_UARTLCR_H, 16'h0000);    // FEN=0
  apb_write(OFF_UARTIMSC,  M_RX);        // unmask RX

`ifndef USE_RTL
  tb_rx_push(1);                         // DUMMY: inject 1 byte -> RXRIS=1
`endif

  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RXRIS set (bypass)", ris & M_RX, M_RX);
  CHECK_EQ("RXMIS set (unmasked)", mis & M_RX, M_RX);

  apb_write(OFF_UARTICR, M_RX);          // clear
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RXRIS cleared", ris & M_RX, 16'h0);
  CHECK_EQ("RXMIS cleared", mis & M_RX, 16'h0);
end
endtask
`endif

