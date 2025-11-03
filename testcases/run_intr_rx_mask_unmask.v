`ifndef RUN_TEST_INTR_RX_MASK_V
`define RUN_TEST_INTR_RX_MASK_V

localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;
localparam [15:0] M_RX = 16'h0010;

task run_test;
  reg [15:0] ris, mis;
begin
  $display("\n[TC] RX interrupt — Mask/Unmask");
  apb_write(OFF_UARTLCR_H, 16'h0000);   // FEN=0

  apb_write(OFF_UARTIMSC, 16'h0000);    // mask off

`ifndef USE_RTL
  tb_rx_push(1);                        // DUMMY: set RAW
`endif

  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RIS=1", ris & M_RX, M_RX);
  CHECK_EQ("MIS=0 when masked", mis & M_RX, 16'h0);

  apb_write(OFF_UARTIMSC, M_RX);        // unmask
  apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("MIS reflects RIS when unmasked", mis & M_RX, M_RX);

  apb_write(OFF_UARTICR, M_RX);         // clear
end
endtask
`endif

