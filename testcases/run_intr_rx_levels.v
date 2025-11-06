`ifndef RUN_TEST_INTR_RX_LEVELS_V
`define RUN_TEST_INTR_RX_LEVELS_V
localparam [11:2] OFF_UARTLCR_H = 10'h00B;
localparam [11:2] OFF_UARTIFLS  = 10'h00D;
localparam [11:2] OFF_UARTIMSC  = 10'h00E;
localparam [11:2] OFF_UARTRIS   = 10'h00F;
localparam [11:2] OFF_UARTMIS   = 10'h010;
localparam [11:2] OFF_UARTICR   = 10'h011;

localparam [15:0] M_RX = 16'h0010;

// IFLS helpers: RXIFLSEL in [2:0]
function [15:0] set_rx_lvl(input [2:0] enc, input [15:0] cur);
  set_rx_lvl = {cur[15:3], enc};
endfunction

task run_test; reg [15:0] ifls, ris, mis; integer i; reg [2:0] enc[0:4];
begin
  $display("\n[TC] UARTRXINTR — FIFO level transitions (FEN=1)");

  enc[0]=3'b000; enc[1]=3'b001; enc[2]=3'b010; enc[3]=3'b011; enc[4]=3'b100;

  // Enable FIFO & unmask RX
  apb_write(OFF_UARTLCR_H, 16'h0010);   // FEN=1
  apb_write(OFF_UARTIMSC , M_RX);

`ifdef TB_HAS_DUMMY
  // Sweep 5 levels: 1/8, 1/4, 1/2, 3/4, 7/8
  for (i=0; i<5; i=i+1) begin
    apb_read (OFF_UARTIFLS, ifls);
    ifls = set_rx_lvl(enc[i], ifls);
    apb_write(OFF_UARTIFLS, ifls);

    // push just below then cross the threshold
    tb_rx_pop(64);          // ensure empty
    tb_rx_push(1);          // < level
    apb_write(OFF_UARTICR, M_RX); // be safe clear
    tb_rx_push(16);         // should cross some level in dummy mapping

    apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
    CHECK_EQ("RXRIS=1 at threshold", ris & M_RX, M_RX);
    CHECK_EQ("RXMIS=1 at threshold", mis & M_RX, M_RX);

    // Clear by reading below level (pop) then ICR
    tb_rx_pop(16);
    apb_write(OFF_UARTICR, M_RX);
    apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
    CHECK_EQ("RX cleared", ris & M_RX, 16'h0);
    CHECK_EQ("RXMIS cleared", mis & M_RX, 16'h0);
  end
`else
  $display("[SKIP] RTL mode w/o RX BFM; expect no RX interrupt.");
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("No RXRIS", ris & M_RX, 16'h0);
  CHECK_EQ("No RXMIS", mis & M_RX, 16'h0);
`endif
end
endtask
`endif

