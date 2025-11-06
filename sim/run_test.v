`ifndef RUN_TEST_INTR_COMBINED_V
`define RUN_TEST_INTR_COMBINED_V
localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;

localparam [15:0] M_RX = 16'h0010;
localparam [15:0] M_TX = 16'h0020;
localparam [15:0] M_RT = 16'h0040;
localparam [15:0] M_ERR= 16'h0780;

task run_test; reg [15:0] ris, mis;
begin
  $display("\n[TC] UARTINTR — Combined OR (via MIS) check");

  // Unmask multiple sources
  apb_write(OFF_UARTIMSC, M_RX | M_TX | M_RT | M_ERR);
  apb_write(OFF_UARTLCR_H, 16'h0010); // FEN=1

`ifdef TB_HAS_DUMMY
  // Create RX level and TX level events together
  tb_rx_pop(64); tb_rx_push(8);
  apb_write(OFF_UARTICR, M_TX); // clean
  integer k; for (k=0;k<16;k=k+1) apb_write(10'h000, k); // write DR fill TX
  tb_tx_consume(16); // drop to empty -> TXRIS

  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("Combined has RX", mis & M_RX, M_RX);
  CHECK_EQ("Combined has TX", mis & M_TX, M_TX);

  // Clear all and ensure MIS=0
  apb_write(OFF_UARTICR, M_RX|M_TX|M_RT|M_ERR);
  apb_read(OFF_UARTMIS, mis); CHECK_EQ("All cleared MIS=0", mis & (M_RX|M_TX|M_RT|M_ERR), 16'h0);
`else
  $display("[SKIP] RTL mode w/o stim; expect MIS=0.");
  apb_read(OFF_UARTMIS, mis); CHECK_EQ("MIS=0", mis & (M_RX|M_TX|M_RT|M_ERR), 16'h0);
`endif
end
endtask
`endif

