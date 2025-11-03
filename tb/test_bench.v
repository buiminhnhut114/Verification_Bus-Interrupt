`timescale 1ns/1ps
`default_nettype none

module test_bench;

  //================ Clocks & Resets ================
  reg PCLK, UARTCLK;
  initial begin PCLK=0;      forever #5  PCLK=~PCLK;   end   // 100 MHz
  initial begin UARTCLK=0;   forever #7  UARTCLK=~UARTCLK; end // ~71.43 MHz

  reg PRESETn, nUARTRST;

  //================ APB ============================
  reg         PSEL, PENABLE, PWRITE;
  reg  [11:2] PADDR;                 // word-aligned
  reg  [15:0] PWDATA;
  wire [15:0] PRDATA;

  // Pads / On-chip
  reg  nUARTCTS, nUARTDCD, nUARTDSR, nUARTRI; // active LOW
  reg  UARTRXD, SIRIN;
  reg  SCANENABLE, SCANINPCLK, SCANINUCLK;
  reg  UARTTXDMACLR, UARTRXDMACLR;

  wire UARTMSINTR, UARTRXINTR, UARTTXINTR, UARTRTINTR, UARTEINTR, UARTINTR;
  wire UARTTXD, nSIROUT, nUARTOut2, nUARTOut1, nUARTRTS, nUARTDTR;
  wire SCANOUTPCLK, SCANOUTUCLK;
  wire UARTTXDMASREQ, UARTTXDMABREQ, UARTRXDMASREQ, UARTRXDMABREQ;

  //================ PASS/FAIL =======================
  integer pass_cnt, fail_cnt;
  initial begin pass_cnt=0; fail_cnt=0; end

  //================ APB BFM =========================
  task apb_reset; begin
    PSEL=0; PENABLE=0; PWRITE=0; PADDR={10{1'b0}}; PWDATA=16'h0000;
  end endtask

  task apb_write(input [11:2] addr_w, input [15:0] wdata); begin
    @(posedge PCLK);
    PSEL   <= 1; PENABLE <= 0; PWRITE <= 1;
    PADDR  <= addr_w; PWDATA <= wdata;               // SETUP
    @(posedge PCLK) PENABLE <= 1;                    // ENABLE
    @(posedge PCLK) begin PSEL<=0; PENABLE<=0; PWRITE<=0; end
  end endtask

  task apb_read(input [11:2] addr_w, output [15:0] rdata); begin
    @(posedge PCLK);
    PSEL   <= 1; PENABLE <= 0; PWRITE <= 0;
    PADDR  <= addr_w;                                 // SETUP
    @(posedge PCLK) PENABLE <= 1;                     // ENABLE
    @(posedge PCLK) begin rdata = PRDATA; PSEL<=0; PENABLE<=0; end
  end endtask

  task CHECK_EQ(input [8*96-1:0] tag, input [15:0] act, input [15:0] exp); begin
    if (act !== exp) begin
      $display("[%0t] [FAIL] %0s exp=0x%04h act=0x%04h", $time, tag, exp, act);
      fail_cnt = fail_cnt + 1;
    end else begin
      $display("[%0t] [PASS] %0s = 0x%04h", $time, tag, act);
      pass_cnt = pass_cnt + 1;
    end
  end endtask

  //================ Global init =====================
  initial begin
    PRESETn=0; nUARTRST=0;
    nUARTCTS=1; nUARTDCD=1; nUARTDSR=1; nUARTRI=1;
    UARTRXD=1; SIRIN=1;
    SCANENABLE=0; SCANINPCLK=0; SCANINUCLK=0;
    UARTTXDMACLR=0; UARTRXDMACLR=0;
    apb_reset();

    repeat(8) @(posedge PCLK);
    PRESETn=1;
    repeat(4) @(posedge UARTCLK);
    nUARTRST=1;
  end

  //================ UART RX line BFM ===============
  integer UARTCLK_HZ = 71428571;                 // ~1/14ns
  function integer bit_time_ns(input integer baud); real t; begin t=1e9/baud; bit_time_ns=$rtoi(t); end endfunction

  // parity_mode: 0=none, 1=even, 2=odd ; two_stop: 0/1
  task uart_rx_send_byte(input [7:0] data, input integer baud, input [1:0] parity_mode, input bit two_stop, input bit force_bad_parity);
    integer bt, i; bit p;
  begin
    bt = bit_time_ns(baud);
    UARTRXD <= 1'b0; #bt;
    for (i=0;i<8;i=i+1) begin UARTRXD <= data[i]; #bt; end
    if (parity_mode!=0) begin
      p = ^data; if (parity_mode==1) p = ~p; // even: invert odd
      if (force_bad_parity) p = ~p;
      UARTRXD <= p; #bt;
    end
    UARTRXD <= 1'b1; #bt; if (two_stop) begin UARTRXD <= 1'b1; #bt; end
  end endtask

  task uart_rx_send_byte_framing_error(input [7:0] data, input integer baud);
    integer bt, i; begin
      bt = bit_time_ns(baud);
      UARTRXD <= 1'b0; #bt;
      for (i=0;i<8;i=i+1) begin UARTRXD <= data[i]; #bt; end
      UARTRXD <= 1'b0; #bt; // bad stop -> FE
      UARTRXD <= 1'b1; #bt;
    end
  endtask

  task uart_rx_send_break(input integer nbits_low, input integer baud);
    integer bt; begin bt=bit_time_ns(baud); UARTRXD<=1'b0; #(nbits_low*bt); UARTRXD<=1'b1; #bt; end
  endtask

  //================= Instantiate RTL =================
  Uart uut
  (
    .PCLK          ( PCLK          ),
    .UARTCLK       ( UARTCLK       ),
    .PRESETn       ( PRESETn       ),
    .nUARTRST      ( nUARTRST      ),

    .PSEL          ( PSEL          ),
    .PENABLE       ( PENABLE       ),
    .PWRITE        ( PWRITE        ),
    .PADDR         ( PADDR         ),
    .PWDATA        ( PWDATA        ),
    .PRDATA        ( PRDATA        ),

    .nUARTCTS      ( nUARTCTS      ),
    .nUARTDCD      ( nUARTDCD      ),
    .nUARTDSR      ( nUARTDSR      ),
    .nUARTRI       ( nUARTRI       ),

    .UARTRXD       ( UARTRXD       ),
    .SIRIN         ( SIRIN         ),

    .SCANENABLE    ( SCANENABLE    ),
    .SCANINPCLK    ( SCANINPCLK    ),
    .SCANINUCLK    ( SCANINUCLK    ),

    .UARTTXDMACLR  ( UARTTXDMACLR  ),
    .UARTRXDMACLR  ( UARTRXDMACLR  ),

    .UARTMSINTR    ( UARTMSINTR    ),
    .UARTRXINTR    ( UARTRXINTR    ),
    .UARTTXINTR    ( UARTTXINTR    ),
    .UARTRTINTR    ( UARTRTINTR    ),
    .UARTEINTR     ( UARTEINTR     ),
    .UARTINTR      ( UARTINTR      ),

    .UARTTXD       ( UARTTXD       ),
    .nSIROUT       ( nSIROUT       ),
    .nUARTOut2     ( nUARTOut2     ),
    .nUARTOut1     ( nUARTOut1     ),
    .nUARTRTS      ( nUARTRTS      ),
    .nUARTDTR      ( nUARTDTR      ),

    .SCANOUTPCLK   ( SCANOUTPCLK   ),
    .SCANOUTUCLK   ( SCANOUTUCLK   ),

    .UARTTXDMASREQ ( UARTTXDMASREQ ),
    .UARTTXDMABREQ ( UARTTXDMABREQ ),
    .UARTRXDMASREQ ( UARTRXDMASREQ ),
    .UARTRXDMABREQ ( UARTRXDMABREQ )
  );

  initial begin
    run_test();   // (định nghĩa trong run_test.v)
    $display("\n==================== SUMMARY ====================");
    $display("PASS = %0d, FAIL = %0d", pass_cnt, fail_cnt);
    $display("=================================================\n");
    if (fail_cnt != 0) $fatal(1, "Some tests FAILED");
    $finish;
  end

  `include "run_test.v"

endmodule
`default_nettype wire

