`timescale 1ns/1ps
`default_nettype none

module Uart
(
  input  wire        PCLK,
  input  wire        UARTCLK,
  input  wire        PRESETn,
  input  wire        nUARTRST,

  // APB
  input  wire        PSEL,
  input  wire        PENABLE,
  input  wire        PWRITE,
  input  wire [11:2] PADDR,     // word address
  input  wire [15:0] PWDATA,
  output reg  [15:0] PRDATA,

  // Pads / On-chip
  input  wire        nUARTCTS,
  input  wire        nUARTDCD,
  input  wire        nUARTDSR,
  input  wire        nUARTRI,

  input  wire        UARTRXD,
  input  wire        SIRIN,

  input  wire        SCANENABLE,
  input  wire        SCANINPCLK,
  input  wire        SCANINUCLK,

  input  wire        UARTTXDMACLR,
  input  wire        UARTRXDMACLR,

  output wire        UARTMSINTR,
  output wire        UARTRXINTR,
  output wire        UARTTXINTR,
  output wire        UARTRTINTR,
  output wire        UARTEINTR,
  output wire        UARTINTR,

  output reg         UARTTXD,
  output wire        nSIROUT,
  output wire        nUARTOut2,
  output wire        nUARTOut1,
  output wire        nUARTRTS,
  output wire        nUARTDTR,

  output wire        SCANOUTPCLK,
  output wire        SCANOUTUCLK,

  output wire        UARTTXDMASREQ,
  output wire        UARTTXDMABREQ,
  output wire        UARTRXDMASREQ,
  output wire        UARTRXDMABREQ
);

  // ---------------- Address map (word) ----------------
  localparam [9:0] A_UARTDR    = 10'h000; // 0x000
  localparam [9:0] A_UARTRSR   = 10'h001; // 0x004 (read), UARTECR (write)
  localparam [9:0] A_UARTFR    = 10'h006; // 0x018
  localparam [9:0] A_UARTIBRD  = 10'h009; // 0x024
  localparam [9:0] A_UARTFBRD  = 10'h00A; // 0x028
  localparam [9:0] A_UARTLCR_H = 10'h00B; // 0x02C
  localparam [9:0] A_UARTCR    = 10'h00C; // 0x030
  localparam [9:0] A_UARTIFLS  = 10'h00D; // 0x034
  localparam [9:0] A_UARTIMSC  = 10'h00E; // 0x038
  localparam [9:0] A_UARTRIS   = 10'h00F; // 0x03C
  localparam [9:0] A_UARTMIS   = 10'h010; // 0x040
  localparam [9:0] A_UARTICR   = 10'h011; // 0x044

  // RIS/MIS bit fields
  localparam INT_RI  = 0, INT_CTS = 1, INT_DCD = 2, INT_DSR = 3;
  localparam INT_RX  = 4, INT_TX  = 5, INT_RT  = 6, INT_FE  = 7, INT_PE  = 8, INT_BE  = 9, INT_OE = 10;

  // LCR_H
  localparam LCRH_BRK  = 0;
  localparam LCRH_PEN  = 1;
  localparam LCRH_EPS  = 2;
  localparam LCRH_STP2 = 3;
  localparam LCRH_FEN  = 4;

  // FR bits we drive: TXFE[7], RXFF[6], RXFE[4], BUSY[3], TXFF[5]
  // we only model TXFE, RXFE, BUSY, TXFF
  // --------------------------------------------------

  // Registers
  reg [15:0] r_DR, r_RSR, r_FR, r_IBRD, r_FBRD, r_LCR_H, r_CR, r_IFLS, r_IMSC;
  reg [15:0] r_RIS;  // raw
  wire[15:0] r_MIS = r_RIS & r_IMSC;

  // FIFO (logic depth)
  reg  [7:0] rx_mem [0:15];
  reg  [7:0] tx_mem [0:15];
  integer    rx_wr, rx_rd, rx_cnt;
  integer    tx_wr, tx_rd, tx_cnt;

  // Common helpers
  wire apb_wr = PSEL & PENABLE & PWRITE;
  wire apb_rd = PSEL & PENABLE & ~PWRITE;

  // Reset (async assert, sync deassert by clocks)
  wire arstn = PRESETn & nUARTRST;

  // RX/TX thresholds from IFLS
  function integer rx_thresh(input [2:0] enc);
    case (enc)
      3'b000: rx_thresh=2;  3'b001: rx_thresh=4;
      3'b010: rx_thresh=8;  3'b011: rx_thresh=12;
      default: rx_thresh=14;
    endcase
  endfunction
  function integer tx_thresh(input [2:0] enc);
    case (enc)
      3'b000: tx_thresh=2;  3'b001: tx_thresh=4;
      3'b010: tx_thresh=8;  3'b011: tx_thresh=12;
      default: tx_thresh=14;
    endcase
  endfunction

  // =========================
  // APB write side-effects
  // =========================
  always @(negedge arstn or posedge PCLK) begin
    if (!arstn) begin
      r_DR    <= 16'h0000;
      r_RSR   <= 16'h0000;
      r_FR    <= 16'h0090;     // TXFE=1 (bit7), RXFE=1 (bit4), BUSY=0
      r_IBRD  <= 16'h0000;
      r_FBRD  <= 16'h0000;
      r_LCR_H <= 16'h0000;
      r_CR    <= 16'h0300;     // bit9..8 = 1 theo spec
      r_IFLS  <= 16'h0012;     // reset trong spec
      r_IMSC  <= 16'h0000;
      r_RIS   <= 16'h0000;

      rx_wr<=0; rx_rd<=0; rx_cnt<=0;
      tx_wr<=0; tx_rd<=0; tx_cnt<=0;
    end else if (apb_wr) begin
      case (PADDR)
        A_UARTDR: begin
          r_DR <= {8'h00, PWDATA[7:0]};
          // push into TX FIFO
          if (tx_cnt<16) begin tx_mem[tx_wr] <= PWDATA[7:0]; tx_wr <= (tx_wr+1)&15; tx_cnt <= tx_cnt+1; end
        end
        A_UARTIBRD  : r_IBRD    <= PWDATA;
        A_UARTFBRD  : r_FBRD    <= PWDATA;
        A_UARTLCR_H : r_LCR_H   <= PWDATA;
        A_UARTCR    : r_CR      <= PWDATA;
        A_UARTIFLS  : r_IFLS    <= PWDATA;
        A_UARTIMSC  : r_IMSC    <= PWDATA;
        A_UARTICR   : begin
          // clear exactly targeted sources
          r_RIS[10:0] <= r_RIS[10:0] & ~PWDATA[10:0];
        end
        A_UARTRSR   : begin
          // UARTECR write semantics: clear error snapshot + RIS error group
          r_RSR[3:0]  <= r_RSR[3:0] & ~PWDATA[3:0];
          r_RIS[INT_OE:INT_FE] <= r_RIS[INT_OE:INT_FE] & ~PWDATA[3:0];
        end
        default: ;
      endcase
    end
  end

  // =========================
  // APB read mux
  // =========================
  always @(*) begin
    PRDATA = 16'h0000;
    case (PADDR)
      A_UARTDR    : PRDATA = {4'h0, r_RSR[3:0], r_DR[7:0]}; // data + error snapshot (typical PL011)
      A_UARTRSR   : PRDATA = {12'h0, r_RSR[3:0]};
      A_UARTFR    : PRDATA = r_FR;
      A_UARTIBRD  : PRDATA = r_IBRD;
      A_UARTFBRD  : PRDATA = r_FBRD;
      A_UARTLCR_H : PRDATA = r_LCR_H;
      A_UARTCR    : PRDATA = r_CR;
      A_UARTIFLS  : PRDATA = r_IFLS;
      A_UARTRIS   : PRDATA = r_RIS;
      A_UARTMIS   : PRDATA = r_MIS;
      default     : PRDATA = 16'h0000;
    endcase
  end

  // =========================
  // FR (flags)
  // =========================
  always @(*) begin
    r_FR[7] = (tx_cnt==0);      // TXFE
    r_FR[6] = (rx_cnt==16);     // RXFF (optional)
    r_FR[5] = (tx_cnt==16);     // TXFF (optional)
    r_FR[4] = (rx_cnt==0);      // RXFE
    r_FR[3] = 1'b0;             // BUSY ~ simplified
  end

  // =========================
  // TX drain + TXRIS
  // =========================
  reg [31:0] tx_timer;
  wire tx_enable = r_CR[0] & r_CR[8]; // UARTEN & TXE

  function integer uart_bit_time_cycles; // in UARTCLK cycles
    real div, bt;
    begin
      if (r_IBRD==0) uart_bit_time_cycles = 100; // fallback
      else begin
        div = r_IBRD + (r_FBRD/64.0);
        // 1 bit = 16*div UARTCLK cycles
        bt = 16.0*div;
        uart_bit_time_cycles = (bt<10.0)?10:$rtoi(bt);
      end
    end
  endfunction

  reg [31:0] tx_wait;
  always @(negedge arstn or posedge UARTCLK) begin
    if (!arstn) begin
      tx_wait <= 0; tx_timer <= 0; UARTTXD <= 1'b1;
    end else begin
      UARTTXD <= 1'b1; // simple idle-high line
      if (tx_enable && tx_cnt>0) begin
        if (tx_wait==0) tx_wait <= (10 * uart_bit_time_cycles()); // ~1 frame
        else begin
          tx_wait <= tx_wait - 1;
          if (tx_wait==1) begin
            // one byte "sent"
            tx_rd <= (tx_rd+1)&15; tx_cnt <= tx_cnt - 1;
            // TXRIS based on transition-through-level
            if (r_LCR_H[LCRH_FEN]) begin
              integer th; th = tx_thresh(r_IFLS[5:3]);
              if (tx_cnt > th && (tx_cnt-1) <= th) r_RIS[INT_TX] <= 1'b1;
            end else begin
              if ((tx_cnt-1)==0) r_RIS[INT_TX] <= 1'b1;
            end
          end
        end
      end else begin
        tx_wait <= 0;
      end
    end
  end

  // =========================
  // RX sampler/decoder + RTRIS (32 bits)
  // =========================
  wire rx_enable = r_CR[0] & r_CR[9]; // UARTEN & RXE

  reg        rx_prev;
  reg [31:0] rx_bt;      // bit time in cycles
  reg [31:0] rx_cntdown;
  reg [3:0]  rx_bitidx;
  reg [7:0]  rx_shift;
  reg        rx_parity_bit;
  reg        rx_sampling;
  reg [31:0] idle_timer; // for RT

  function [0:0] rx_even_parity(input [7:0] d); rx_even_parity = ~(^d); endfunction

  // RT timer
  always @(negedge arstn or posedge UARTCLK) begin
    if (!arstn) idle_timer <= 0;
    else if (!rx_enable)  idle_timer <= 0;
    else if (rx_cnt>0) begin
      if (idle_timer >= (32*uart_bit_time_cycles())) begin
        r_RIS[INT_RT] <= 1'b1;
        idle_timer <= 0;
      end else idle_timer <= idle_timer + 1;
    end else idle_timer <= 0;
  end

  // RX FSM (very small)
  always @(negedge arstn or posedge UARTCLK) begin
    if (!arstn) begin
      rx_prev <= 1'b1; rx_sampling<=1'b0; rx_cntdown<=0; rx_bitidx<=0; rx_shift<=0; rx_parity_bit<=0;
    end else begin
      rx_prev <= UARTRXD;

      // start detect
      if (rx_enable && !rx_sampling && rx_prev==1'b1 && UARTRXD==1'b0) begin
        rx_bt      <= uart_bit_time_cycles();
        rx_cntdown <= uart_bit_time_cycles() + (uart_bit_time_cycles()>>1); // 1.5 bit
        rx_bitidx  <= 0;
        rx_sampling<= 1'b1;
        idle_timer <= 0; // restart RT
      end else if (rx_sampling) begin
        if (rx_cntdown!=0) rx_cntdown <= rx_cntdown - 1;
        else begin
          // sample
          if (rx_bitidx < 8) begin
            rx_shift[rx_bitidx] <= UARTRXD;
            rx_bitidx <= rx_bitidx + 1;
            rx_cntdown <= rx_bt;
          end else if (r_LCR_H[LCRH_PEN] && rx_bitidx==8) begin
            rx_parity_bit <= UARTRXD;
            rx_bitidx <= rx_bitidx + 1;
            rx_cntdown <= rx_bt;
          end else begin
            // stop
            // Error checks
            // Framing error: stop must be HIGH
            if (UARTRXD==1'b0) r_RSR[0] <= 1'b1; // FE
            // Parity error
            if (r_LCR_H[LCRH_PEN]) begin
              reg exp;
              exp = r_LCR_H[LCRH_EPS] ? rx_even_parity(rx_shift) : ~rx_even_parity(rx_shift);
              if (rx_parity_bit !== exp) r_RSR[1] <= 1'b1; // PE
            end
            // Push RX FIFO
            if (rx_cnt<16) begin
              rx_mem[rx_wr] <= rx_shift; rx_wr <= (rx_wr+1)&15; rx_cnt <= rx_cnt+1;
            end else begin
              r_RSR[3] <= 1'b1; // OE
            end
            // Set RXRIS according to mode
            if (r_LCR_H[LCRH_FEN]==1'b0) begin
              r_RIS[INT_RX] <= 1'b1;
            end else begin
              integer th; th = rx_thresh(r_IFLS[2:0]);
              if (rx_cnt < th && (rx_cnt+1) >= th) r_RIS[INT_RX] <= 1'b1;
            end

            rx_sampling <= 1'b0;
            idle_timer  <= 0;
          end
        end
      end
    end
  end

  // BREAK detect: line low đủ dài
  reg [31:0] brk_cnt;
  always @(negedge arstn or posedge UARTCLK) begin
    if (!arstn) begin brk_cnt<=0; end
    else if (!rx_enable) brk_cnt<=0;
    else begin
      if (UARTRXD==1'b0) begin
        if (brk_cnt < (12*uart_bit_time_cycles())) brk_cnt <= brk_cnt + 1;
        else r_RIS[INT_BE] <= 1'b1;
      end else brk_cnt<=0;
    end
  end

  //==========================
  // Reading DR pops RX FIFO
  //==========================
  reg dr_pop_req;
  always @(negedge arstn or posedge PCLK) begin
    if (!arstn) dr_pop_req<=1'b0;
    else begin
      dr_pop_req <= 1'b0;
      if (apb_rd && PADDR==A_UARTDR) dr_pop_req <= 1'b1;
    end
  end
  always @(posedge UARTCLK) begin
    if (dr_pop_req && rx_cnt>0) begin
      r_DR[7:0] <= rx_mem[rx_rd];
      rx_rd <= (rx_rd+1)&15; rx_cnt <= rx_cnt-1;
      // Clear RT if became empty
    end
  end

  //==========================
  // Modem status interrupts
  //==========================
  reg cts_q, dcd_q, dsr_q, ri_q;
  always @(negedge arstn or posedge PCLK) begin
    if (!arstn) begin cts_q<=1; dcd_q<=1; dsr_q<=1; ri_q<=1; end
    else begin
      if (cts_q==1 && nUARTCTS==0) r_RIS[INT_CTS] <= 1'b1;
      if (dcd_q==1 && nUARTDCD==0) r_RIS[INT_DCD] <= 1'b1;
      if (dsr_q==1 && nUARTDSR==0) r_RIS[INT_DSR] <= 1'b1;
      if (ri_q ==1 && nUARTRI ==0) r_RIS[INT_RI ] <= 1'b1;
      cts_q<=nUARTCTS; dcd_q<=nUARTDCD; dsr_q<=nUARTDSR; ri_q<=nUARTRI;
    end
  end

  //==========================
  // Interrupt outputs
  //==========================
  assign UARTMSINTR = |r_MIS[3:0];
  assign UARTRXINTR =  r_MIS[INT_RX];
  assign UARTTXINTR =  r_MIS[INT_TX];
  assign UARTRTINTR =  r_MIS[INT_RT];
  assign UARTEINTR  = |r_MIS[INT_OE:INT_FE];
  assign UARTINTR   = |r_MIS[10:0];

  //==========================
  // Static/tie-off outputs
  //==========================
  assign nSIROUT        = 1'b1;
  assign nUARTOut1      = 1'b1;
  assign nUARTOut2      = 1'b1;
  assign nUARTRTS       = 1'b1;
  assign nUARTDTR       = 1'b1;
  assign SCANOUTPCLK    = 1'b0;
  assign SCANOUTUCLK    = 1'b0;
  assign UARTTXDMASREQ  = 1'b0;
  assign UARTTXDMABREQ  = 1'b0;
  assign UARTRXDMASREQ  = 1'b0;
  assign UARTRXDMABREQ  = 1'b0;

endmodule

`default_nettype wire

