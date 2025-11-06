`ifndef RUN_TEST_INTR_RX_TIMEOUT_V
`define RUN_TEST_INTR_RX_TIMEOUT_V
localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;

localparam [15:0] M_RT = 16'h0040;

task run_test; reg [15:0] ris, mis;
begin
  $display("\n[TC] UARTRTINTR — Receive timeout");

  apb_write(OFF_UARTLCR_H, 16'h0010); // FEN=1
  apb_write(OFF_UARTIMSC , M_RT);

`ifdef TB_HAS_DUMMY
  // Put bytes in RX FIFO and then idle for a 32-bit period -> timeout
  tb_rx_pop(64);
  tb_rx_push(3);
  tb_rx_timeout();

  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RTRIS=1", ris & M_RT, M_RT);
  CHECK_EQ("RTMIS=1", mis & M_RT, M_RT);

  // Clear: read down to empty (pop) then ICR
  tb_rx_pop(64); apb_write(OFF_UARTICR, M_RT);
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("RTRIS=0", ris & M_RT, 16'h0);
  CHECK_EQ("RTMIS=0", mis & M_RT, 16'h0);
`else
  $display("[SKIP] RTL mode w/o RX BFM; expect no timeout.");
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("No RTRIS", ris & M_RT, 16'h0);
  CHECK_EQ("No RTMIS", mis & M_RT, 16'h0);
`endif
end
endtask
`endif

