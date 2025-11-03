`ifndef RUN_BUS_DECODE_MAP_V
`define RUN_BUS_DECODE_MAP_V

localparam [11:2] OFF_UARTDR    = 10'h000; // 0x000
localparam [11:2] OFF_UARTRSR   = 10'h001; // 0x004
localparam [11:2] OFF_UARTFR    = 10'h006; // 0x018 (RO)
localparam [11:2] OFF_UARTIBRD  = 10'h009; // 0x024
localparam [11:2] OFF_UARTFBRD  = 10'h00A; // 0x028
localparam [11:2] OFF_UARTLCR_H = 10'h00B; // 0x02C
localparam [11:2] OFF_UARTCR    = 10'h00C; // 0x030
localparam [11:2] OFF_UARTIFLS  = 10'h00D; // 0x034
localparam [11:2] OFF_UARTIMSC  = 10'h00E; // 0x038
localparam [11:2] OFF_UARTRIS   = 10'h00F; // 0x03C (RO)
localparam [11:2] OFF_UARTMIS   = 10'h010; // 0x040 (RO)
localparam [11:2] OFF_UARTICR   = 10'h011; // 0x044

localparam [11:2] OFF_RSVD1     = 10'h007; // 0x01C
localparam [11:2] OFF_RSVD2     = 10'h008; // 0x020

task PASS_ONLY(input [8*64-1:0] tag); begin
  $display("[%0t] [PASS] %0s", $time, tag);
  pass_cnt = pass_cnt + 1;
end endtask

task run_test;
  reg [15:0] r;
begin
  $display("\n================ [TC] BUS.DecodeMap ===================");

  // RW group
  apb_write(OFF_UARTCR,    16'h0005); apb_read(OFF_UARTCR,    r); CHECK_EQ("CR RW",    r, 16'h0005);
  apb_write(OFF_UARTIBRD,  16'd16  ); apb_read(OFF_UARTIBRD,  r); CHECK_EQ("IBRD RW",  r, 16'd16  );
  apb_write(OFF_UARTFBRD,  16'd2   ); apb_read(OFF_UARTFBRD,  r); CHECK_EQ("FBRD RW",  r, 16'd2   );
  apb_write(OFF_UARTLCR_H, 16'h0070); apb_read(OFF_UARTLCR_H, r); CHECK_EQ("LCR_H RW", r, 16'h0070);
  apb_write(OFF_UARTIFLS,  16'h0012); apb_read(OFF_UARTIFLS,  r); CHECK_EQ("IFLS RW",  r, 16'h0012);
  apb_write(OFF_UARTIMSC,  16'h02F0); apb_read(OFF_UARTIMSC,  r); CHECK_EQ("IMSC RW",  r, 16'h02F0);

  // RO group — write ignored
  apb_write(OFF_UARTFR,  16'hA5A5); apb_read(OFF_UARTFR,  r); PASS_ONLY("FR RO write ignored");
  apb_write(OFF_UARTRIS, 16'hFFFF); apb_read(OFF_UARTRIS, r); PASS_ONLY("RIS RO write ignored");
  apb_write(OFF_UARTMIS, 16'hFFFF); apb_read(OFF_UARTMIS, r); PASS_ONLY("MIS RO write ignored");

  // ICR: W1C khi không pending → RIS vẫn 0
  apb_write(OFF_UARTICR, 16'h07FF);
  apb_read (OFF_UARTRIS, r); CHECK_EQ("RIS after ICR no-pending", r, 16'h0000);

  // Reserved holes → read 0, ignore write
  apb_write(OFF_RSVD1, 16'hFACE);
  apb_read (OFF_RSVD1, r); CHECK_EQ("RSVD1 read 0", r, 16'h0000);
  apb_write(OFF_RSVD2, 16'hBEEF);
  apb_read (OFF_RSVD2, r); CHECK_EQ("RSVD2 read 0", r, 16'h0000);

  $display("================ DONE BUS.DecodeMap ==================\n");
end
endtask
`endif

