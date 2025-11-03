`ifndef RUN_TEST_INTR_COMBINED_V
`define RUN_TEST_INTR_COMBINED_V

localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;
localparam [15:0] M_RI=16'h0001, M_CTS=16'h0002, M_DCD=16'h0004, M_DSR=16'h0008;
localparam [15:0] M_RX=16'h0010, M_TX=16'h0020, M_RT=16'h0040;
localparam [15:0] M_FE=16'h0080, M_PE=16'h0100, M_BE=16'h0200, M_OE=16'h0400;
localparam [15:0] M_MS = M_RI|M_CTS|M_DCD|M_DSR;
localparam [15:0] M_ERR= M_FE|M_PE|M_BE|M_OE;

task run_test;
  reg [15:0] mis;
  reg [15:0] allm;
begin
  $display("\n[TC] Combined UARTINTR (OR of MIS)");
  allm = M_RX|M_TX|M_RT|M_MS|M_ERR;
  apb_write(OFF_UARTIMSC, allm);

`ifndef USE_RTL
  tb_rx_push(1);
  tb_tx_consume(1);
  tb_rx_timeout();
  tb_make_error("FE");
  tb_modem_toggle(4'b0001);
`endif

  apb_read(OFF_UARTMIS, mis);
  if (mis==16'h0000) begin
    $display("[%0t] [FAIL] Combined MIS is 0", $time); fail_cnt=fail_cnt+1;
  end else begin
    $display("[%0t] [PASS] Combined MIS non-zero: 0x%04h", $time, mis); pass_cnt=pass_cnt+1;
  end

  apb_write(OFF_UARTICR, allm); // clear all
end
endtask
`endif

