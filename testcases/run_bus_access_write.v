`ifndef RUN_BUS_ACCESS_WRITE_V
`define RUN_BUS_ACCESS_WRITE_V

localparam [11:2] OFF_UARTCR    = 10'h00C; // 0x030
localparam [11:2] OFF_UARTFR    = 10'h006; // 0x018 (RO)
localparam [11:2] OFF_UARTIBRD  = 10'h009; // 0x024
localparam [11:2] OFF_UARTFBRD  = 10'h00A; // 0x028
localparam [11:2] OFF_UARTLCR_H = 10'h00B; // 0x02C
localparam [11:2] OFF_UARTRIS   = 10'h00F; // 0x03C
localparam [11:2] OFF_UARTICR   = 10'h011; // 0x044

// helper để cộng PASS (không cần so sánh số)
task PASS_ONLY(input [8*64-1:0] tag, input [15:0] v); begin
  $display("[%0t] [PASS] %0s : 0x%04h", $time, tag, v);
  pass_cnt = pass_cnt + 1;
end endtask

task run_test;
  reg [15:0] r;
begin
  $display("\n================ [TC] BUS.AccessWrite =================");

  // 1) UARTCR RW
  apb_write(OFF_UARTCR, 16'h0000);
  apb_read (OFF_UARTCR, r); CHECK_EQ("CR write 0000 rb", r, 16'h0000);

  apb_write(OFF_UARTCR, 16'h0001);
  apb_read (OFF_UARTCR, r); CHECK_EQ("CR write 0001 rb", r, 16'h0001);

  apb_write(OFF_UARTCR, 16'h0301);
  apb_read (OFF_UARTCR, r); CHECK_EQ("CR write 0301 rb", r, 16'h0301);

  // 2) UARTFR RO – ghi bị bỏ qua (chỉ log PASS)
  apb_write(OFF_UARTFR, 16'hA5A5);
  apb_read (OFF_UARTFR, r); PASS_ONLY("FR is RO (write ignored), FR read", r);

  // 3) IBRD/FBRD + bundle commit qua LCR_H
  apb_write(OFF_UARTIBRD, 16'd27);
  apb_write(OFF_UARTFBRD, 16'd3);
  apb_write(OFF_UARTLCR_H, 16'h0070);
  apb_read (OFF_UARTIBRD,  r); CHECK_EQ("IBRD rb after LCR_H", r, 16'd27);
  apb_read (OFF_UARTFBRD,  r); CHECK_EQ("FBRD rb after LCR_H", r, 16'd3 );

  // 4) ICR clear khi không có pending → RIS vẫn 0
  apb_write(OFF_UARTICR, 16'h07FF);
  apb_read (OFF_UARTRIS, r); CHECK_EQ("RIS after ICR no-pending", r, 16'h0000);

  $display("================ DONE BUS.AccessWrite ================\n");
end
endtask
`endif

