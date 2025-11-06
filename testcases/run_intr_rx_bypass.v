`ifndef RUN_TEST_INTR_RX_BYPASS_V
`define RUN_TEST_INTR_RX_BYPASS_V
localparam [11:2] OFF_UARTDR    = 10'h000;
localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;

localparam [15:0] M_RX = 16'h0010;

task run_test; reg [15:0] ris, mis;
begin
  $display("\n[TC] UARTRXINTR — bypass (FEN=0)");

  // FEN=0 and unmask RX
  apb_write(OFF_UARTLCR_H, 16'h0000);
  apb_write(OFF_UARTIMSC , M_RX);

`ifdef TB_HAS_DUMMY
  // Inject 1 byte -> transition at single-location -> RXRIS=1
  tb_rx_push(1);
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RXRIS=1", ris & M_RX, M_RX);
  CHECK_EQ("RXMIS=1", mis & M_RX, M_RX);

  // Clear by ICR
  apb_write(OFF_UARTICR, M_RX);
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RXRIS=0 after ICR", ris & M_RX, 16'h0);
  CHECK_EQ("RXMIS=0 after ICR", mis & M_RX, 16'h0);
`else
  $display("[SKIP] RTL mode w/o RX BFM; expect no RX interrupt.");
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("No RXRIS", ris & M_RX, 16'h0);
  CHECK_EQ("No RXMIS", mis & M_RX, 16'h0);
`endif
end
endtask
`endif

