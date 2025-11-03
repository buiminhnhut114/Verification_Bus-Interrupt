`ifndef RUN_TEST_INTR_TX_VARIANTS_V
`define RUN_TEST_INTR_TX_VARIANTS_V

localparam [11:2] OFF_UARTDR    = 10'h000;
localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIFLS  = 10'h00D;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;
localparam [15:0] M_TX = 16'h0020;

task run_test;
  reg [15:0] ris, mis;
  integer k;
begin
  $display("\n[TC] TX interrupt — bypass & levels");

  // bypass
  apb_write(OFF_UARTLCR_H, 16'h0000);   // FEN=0
  apb_write(OFF_UARTIMSC,  M_TX);
  apb_write(OFF_UARTDR, 16'h005A);      // ghi 1 byte

`ifndef USE_RTL
  tb_tx_consume(1);                     // DUMMY: byte rời khỏi single-location
`endif

  apb_read(OFF_UARTRIS, ris); CHECK_EQ("TXRIS set (bypass)", ris & M_TX, M_TX);
  apb_write(OFF_UARTICR, M_TX);

  // FIFO level
  apb_write(OFF_UARTLCR_H, 16'h0010);   // FEN=1
  apb_write(OFF_UARTIFLS, {3'b010,3'b000}); // TXIFLSEL=1/2
  apb_write(OFF_UARTIMSC,  M_TX);

  for (k=0;k<12;k=k+1) apb_write(OFF_UARTDR, 16'h00AA); // đổ nhiều

`ifndef USE_RTL
  tb_tx_consume(5);                     // DUMMY: từ >level xuống <=level -> set
`endif

  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("TXRIS level transition", ris & M_TX, M_TX);
  CHECK_EQ("TXMIS level transition", mis & M_TX, M_TX);
  apb_write(OFF_UARTICR, M_TX);
end
endtask
`endif

