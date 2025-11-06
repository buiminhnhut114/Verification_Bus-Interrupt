`ifndef RUN_TEST_INTR_RX_MASK_UNMASK_V
`define RUN_TEST_INTR_RX_MASK_UNMASK_V
localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;

localparam [15:0] M_RX = 16'h0010;

task run_test; reg [15:0] ris, mis;
begin
  $display("\n[TC] UARTRXINTR — Mask/Unmask");

  apb_write(OFF_UARTLCR_H, 16'h0000); // FEN=0

  // MASK=0: RIS=1, MIS=0
  apb_write(OFF_UARTIMSC, 16'h0000);  // mask off
`ifdef TB_HAS_DUMMY
  tb_rx_push(1);
`endif
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RIS=1 after event",  ris & M_RX, M_RX);
  CHECK_EQ("MIS=0 when masked",  mis & M_RX, 16'h0);

  // MASK=1: MIS follows RIS
  apb_write(OFF_UARTIMSC, M_RX);
  apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("MIS=1 when unmasked", mis & M_RX, M_RX);

  // Clear
  apb_write(OFF_UARTICR, M_RX);
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RIS=0 after ICR", ris & M_RX, 16'h0);
  CHECK_EQ("MIS=0 after ICR", mis & M_RX, 16'h0);
end
endtask
`endif

