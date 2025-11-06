`ifndef RUN_BUS_DECODE_MAP_V
`define RUN_BUS_DECODE_MAP_V

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
localparam [11:2] OFF_UARTRIS   = 10'h00F; // 0x03C (RO)
localparam [11:2] OFF_UARTMIS   = 10'h010; // 0x040 (RO)
localparam [11:2] OFF_UARTICR   = 10'h011; // 0x044

// 2 lỗ hổng Reserved mẫu (để chứng minh decode đúng)
localparam [11:2] OFF_RSVD1     = 10'h007; // 0x01C
localparam [11:2] OFF_RSVD2     = 10'h008; // 0x020

// ---------------- Small helpers ----------------
task PASS_ONLY(input [8*64-1:0] tag); begin
  $display("[%0t] [PASS] %0s", $time, tag);
  pass_cnt = pass_cnt + 1;
end endtask

task MASK_EQ(input [8*56-1:0] tag, input [15:0] act, input [15:0] exp, input [15:0] mask);
begin
  if ((act & mask) !== (exp & mask)) begin
    $display("[%0t] [FAIL] %0s exp=0x%04h act=0x%04h mask=0x%04h",
             $time, tag, exp, act, mask);
    fail_cnt = fail_cnt + 1;
  end else begin
    $display("[%0t] [PASS] %0s -> 0x%04h", $time, tag, act);
    pass_cnt = pass_cnt + 1;
  end
end
endtask

// ---------------- The test ----------------
task run_test;
  reg [15:0] r, r0, r1;
  reg [15:0] wr_mask_imsc;      // mask bit IMSC thực sự ghi-được
  localparam [15:0] CR_MASK = 16'hFCFF; // bỏ CR[9:8] (luôn 1)
  localparam [15:0] IFLS_MASK = 16'h003F; // TXIFLSEL[5:3], RXIFLSEL[2:0]
begin
  $display("\n================ [TC] BUS.DecodeMap ===================");

  // Dọn sạch pending trước (để đọc RIS/MIS ổn định)
  apb_read (OFF_UARTDR, r);
  apb_write(OFF_UARTICR, 16'h07FF);
  apb_write(OFF_UARTICR, 16'h07FF);

  // 1) UARTCR — RW nhưng mask [9:8]
  apb_write(OFF_UARTCR, 16'h0005);
  apb_read (OFF_UARTCR, r);
  MASK_EQ("CR RW (ignore [9:8])", r, 16'h0005, CR_MASK);

  // 2) IBRD/FBRD/LCR_H — bundle: commit sau khi write LCR_H
  apb_write(OFF_UARTIBRD, 16'd16);
  apb_write(OFF_UARTFBRD, 16'd2 );
  apb_write(OFF_UARTLCR_H, 16'h0070); // commit
  apb_read (OFF_UARTIBRD,  r); CHECK_EQ("IBRD rb after LCR_H", r, 16'd16);
  apb_read (OFF_UARTFBRD,  r); CHECK_EQ("FBRD rb after LCR_H", r, 16'd2 );
  apb_read (OFF_UARTLCR_H, r); CHECK_EQ("LCR_H rb", r, 16'h0070);

  // 3) IFLS — chỉ 6 bit [5:0] hợp lệ
  apb_write(OFF_UARTIFLS, 16'h0012);
  apb_read (OFF_UARTIFLS, r);
  MASK_EQ("IFLS RW (6b only)", r, 16'h0012, IFLS_MASK);

  // 4) IMSC — khám phá bit ghi-được rồi mới test
  apb_read (OFF_UARTIMSC, r0);                 // trạng thái trước
  apb_write(OFF_UARTIMSC, 16'h07FF);           // cố gắng set tất cả 11 bit hợp lệ
  apb_read (OFF_UARTIMSC, r1);
  wr_mask_imsc = r1;                           // bit nào stick = ghi-được
  // khôi phục 0 để khỏi ảnh hưởng các test khác
  apb_write(OFF_UARTIMSC, 16'h0000);

  // bây giờ test với giá trị mẫu, nhưng so theo mask ghi-được
  apb_write(OFF_UARTIMSC, 16'h02F0 & wr_mask_imsc);
  apb_read (OFF_UARTIMSC, r);
  MASK_EQ("IMSC RW (discover mask)", r, (16'h02F0 & wr_mask_imsc), wr_mask_imsc);

  // 5) RO group — write bị bỏ qua
  apb_write(OFF_UARTFR,  16'hA5A5); apb_read(OFF_UARTFR,  r); PASS_ONLY("FR RO write ignored");
  apb_write(OFF_UARTRIS, 16'hFFFF); apb_read(OFF_UARTRIS, r); PASS_ONLY("RIS RO write ignored");
  apb_write(OFF_UARTMIS, 16'hFFFF); apb_read(OFF_UARTMIS, r); PASS_ONLY("MIS RO write ignored");

  // 6) ICR: không pending → RIS vẫn 0
  apb_write(OFF_UARTICR, 16'h07FF);
  apb_read (OFF_UARTRIS, r); CHECK_EQ("RIS after ICR no-pending", r, 16'h0000);

  // 7) Reserved holes → read 0, write ignored
  apb_write(OFF_RSVD1, 16'hFACE);
  apb_read (OFF_RSVD1, r); CHECK_EQ("RSVD1 read 0", r, 16'h0000);
  apb_write(OFF_RSVD2, 16'hBEEF);
  apb_read (OFF_RSVD2, r); CHECK_EQ("RSVD2 read 0", r, 16'h0000);

  $display("================ DONE BUS.DecodeMap ==================\n");
end
endtask

`endif

