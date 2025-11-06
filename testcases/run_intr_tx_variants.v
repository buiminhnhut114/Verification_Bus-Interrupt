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

// TXIFLSEL in [5:3]
function [15:0] set_tx_lvl(input [2:0] enc, input [15:0] cur);
  set_tx_lvl = {cur[15:6], enc, cur[2:0]};
endfunction

task run_test; reg [15:0] ifls, ris, mis; integer i; reg [2:0] enc[0:4];
begin
  $display("\n[TC] UARTTXINTR — bypass & FIFO levels");

  enc[0]=3'b000; enc[1]=3'b001; enc[2]=3'b010; enc[3]=3'b011; enc[4]=3'b100;

  // --- Case 1: FEN=0 (bypass) ---
  apb_write(OFF_UARTLCR_H, 16'h0000);
  apb_write(OFF_UARTIMSC , M_TX);

`ifdef TB_HAS_DUMMY
  // Write some bytes to TX, then consume to empty -> TXRIS=1
  apb_write(OFF_UARTDR, 16'h005A);
  tb_tx_consume(1);  // empty -> set
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("TXRIS=1 (bypass)", ris & M_TX, M_TX);
  CHECK_EQ("TXMIS=1 (bypass)", mis & M_TX, M_TX);
  apb_write(OFF_UARTICR, M_TX);
`else
  $display("[SKIP] RTL mode w/o TX BFM; expect no TX interrupt.");
  apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
  CHECK_EQ("No TXRIS", ris & M_TX, 16'h0);
  CHECK_EQ("No TXMIS", mis & M_TX, 16'h0);
`endif

  // --- Case 2: FEN=1 (levels) ---
  apb_write(OFF_UARTLCR_H, 16'h0010); // FEN=1
  apb_write(OFF_UARTIMSC , M_TX);

`ifdef TB_HAS_DUMMY
  for (i=0;i<5;i=i+1) begin
    apb_read (OFF_UARTIFLS, ifls);
    ifls = set_tx_lvl(enc[i], ifls);
    apb_write(OFF_UARTIFLS, ifls);
    apb_write(OFF_UARTICR, M_TX);

    // Fill fifo then consume down across threshold
    integer k;
    for (k=0;k<16;k=k+1) apb_write(OFF_UARTDR, k);
    tb_tx_consume(12); // drop counts to cross threshold

    apb_read(OFF_UARTRIS, ris); apb_read(OFF_UARTMIS, mis);
    CHECK_EQ("TXRIS=1 at threshold", ris & M_TX, M_TX);
    CHECK_EQ("TXMIS=1 at threshold", mis & M_TX, M_TX);

    apb_write(OFF_UARTICR, M_TX);
  end
`endif
end
endtask
`endif

