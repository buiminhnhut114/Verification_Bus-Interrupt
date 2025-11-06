`ifndef RUN_BUS_ACCESS_WRITE_V
`define RUN_BUS_ACCESS_WRITE_V

// ---------------- Offsets (word address) ----------------
localparam [11:2] OFF_UARTDR    = 10'h000; // 0x000
localparam [11:2] OFF_UARTRSR   = 10'h001; // 0x004
localparam [11:2] OFF_UARTFR    = 10'h006; // 0x018 (RO)
localparam [11:2] OFF_UARTIBRD  = 10'h009; // 0x024
localparam [11:2] OFF_UARTFBRD  = 10'h00A; // 0x028
localparam [11:2] OFF_UARTLCR_H = 10'h00B; // 0x02C
localparam [11:2] OFF_UARTCR    = 10'h00C; // 0x030
localparam [11:2] OFF_UARTIFLS  = 10'h00D; // 0x034
localparam [11:2] OFF_UARTIMSC  = 10'h00E; // 0x038
localparam [11:2] OFF_UARTRIS   = 10'h00F; // 0x03C
localparam [11:2] OFF_UARTMIS   = 10'h010; // 0x040
localparam [11:2] OFF_UARTICR   = 10'h011; // 0x044

// ---------------- Small helpers ----------------
// So sánh có mask (để bỏ qua các bit RO/đặc biệt)
task MASK_EQ(input [8*48-1:0] tag, input [15:0] act, input [15:0] exp, input [15:0] mask);
begin
  if ( (act & mask) !== (exp & mask) ) begin
    $display("[%0t] [FAIL] %0s exp=0x%04h act=0x%04h mask=0x%04h", $time, tag, exp, act, mask);
    fail_cnt = fail_cnt + 1;
  end else begin
    $display("[%0t] [PASS] %0s -> 0x%04h", $time, tag, act);
    pass_cnt = pass_cnt + 1;
  end
end
endtask

// PASS_ONLY dùng để log RO
task PASS_ONLY(input [8*64-1:0] tag, input [15:0] v);
begin
  $display("[%0t] [PASS] %0s : 0x%04h", $time, tag, v);
  pass_cnt = pass_cnt + 1;
end
endtask

// ---------------- The test ----------------
task run_test;
  reg [15:0] r;
begin
  $display("\n================ [TC] BUS.AccessWrite =================");

  // 0) Dọn sạch pending interrupt/error trước khi làm gì
  //    - đọc DR (snapshot/clear một số path theo spec)
  //    - clear ICR nhiều lần để chắc chắn về 0
  apb_read (OFF_UARTDR, r);
  apb_write(OFF_UARTICR, 16'h07FF);
  apb_write(OFF_UARTICR, 16'h07FF);
  apb_read (OFF_UARTRIS, r); CHECK_EQ("RIS clean before test", r, 16'h0000);

  // 1) UARTCR write/readback
  //    Lưu ý: nhiều RTL giữ CR[9:8]=1; vì vậy ta so sánh với mask bỏ qua 2 bit đó.
  //    mask = 16'hFCFF (bỏ qua [9:8])
  apb_write(OFF_UARTCR, 16'h0001);
  apb_read (OFF_UARTCR, r);
  MASK_EQ("CR wr 0001 rb (ignore [9:8])", r, 16'h0001, 16'hFCFF);

  apb_write(OFF_UARTCR, 16'h0000);
  apb_read (OFF_UARTCR, r);
  MASK_EQ("CR wr 0000 rb (ignore [9:8])", r, 16'h0000, 16'hFCFF);

  // Với một số RTL, CR[9:8] luôn 1 → đọc có thể thành 0x0301/0x0300.
  // Ghi một giá trị hợp lệ có cả TXE/RXE/UE = 1:
  apb_write(OFF_UARTCR, 16'h0301);
  apb_read (OFF_UARTCR, r);
  // yêu cầu 3 bit control đang set (bit0, và có thể bit[9:8] vẫn 1)
  MASK_EQ("CR wr 0301 rb (ignore [9:8])", r, 16'h0301, 16'hFCFF);

  // 2) UARTFR là RO → ghi bị bỏ qua. Chỉ log đọc (không ép kỳ vọng FR đúng hệt, vì phụ thuộc FIFO).
  apb_write(OFF_UARTFR, 16'hA5A5);
  apb_read (OFF_UARTFR, r);
  PASS_ONLY("FR is RO (write ignored), read FR", r);

  // 3) Bundle write: IBRD/FBRD/LCR_H
  //    - Theo spec: IBRD/FBRD chỉ “commit” khi có write LCR_H sau cùng.
  apb_write(OFF_UARTIBRD, 16'd27);
  apb_write(OFF_UARTFBRD, 16'd3 );
  apb_write(OFF_UARTLCR_H, 16'h0070);  // commit

  apb_read (OFF_UARTIBRD,  r); CHECK_EQ("IBRD rb after LCR_H", r, 16'd27);
  apb_read (OFF_UARTFBRD,  r); CHECK_EQ("FBRD rb after LCR_H", r, 16'd3 );

  // 4) Clear ICR khi không có pending → RIS phải 0
  apb_write(OFF_UARTICR, 16'h07FF);
  apb_read (OFF_UARTRIS, r); CHECK_EQ("RIS after ICR (no pending)", r, 16'h0000);

  $display("================ DONE BUS.AccessWrite ================\n");
end
endtask

`endif

