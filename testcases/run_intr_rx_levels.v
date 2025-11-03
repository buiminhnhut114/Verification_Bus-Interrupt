`ifndef RUN_TEST_INTR_RX_LEVELS_V
`define RUN_TEST_INTR_RX_LEVELS_V

localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIFLS  = 10'h00D;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;
localparam [15:0] M_RX = 16'h0010;

task run_test;
  reg [15:0] ris, mis;
  reg [2:0] lvl [0:4];
  integer i;
begin
  $display("\n[TC] RX interrupt — FIFO level transition");
  lvl[0]=3'b000; lvl[1]=3'b001; lvl[2]=3'b010; lvl[3]=3'b011; lvl[4]=3'b100;

  apb_write(OFF_UARTLCR_H, 16'h0010);    // FEN=1
  apb_write(OFF_UARTIMSC,  M_RX);

  for (i=0;i<5;i=i+1) begin
    apb_write(OFF_UARTIFLS, {3'b000, lvl[i]}); // TXIFLSEL keep=0, RXIFLSEL=lvl[i]
`ifndef USE_RTL
    tb_rx_pop(16); tb_rx_push(1);       // dưới ngưỡng
    apb_write(OFF_UARTICR, M_RX);
    apb_read(OFF_UARTRIS, ris);
    CHECK_EQ($sformatf("Below level (idx=%0d)",i), ris & M_RX, 16'h0);

    tb_rx_push(8);                      // vượt ngưỡng -> transition
`endif
    apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
    CHECK_EQ($sformatf("RXRIS set at transition (idx=%0d)",i), ris & M_RX, M_RX);
    CHECK_EQ($sformatf("RXMIS set (idx=%0d)",i),               mis & M_RX, M_RX);
    apb_write(OFF_UARTICR, M_RX);
  end
end
endtask
`endif

