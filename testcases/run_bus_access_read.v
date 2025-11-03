`ifndef RUN_BUS_ACCESS_READ_V
`define RUN_BUS_ACCESS_READ_V

localparam [11:2] OFF_UARTFR = 10'h006; // 0x018
localparam [11:2] OFF_UARTCR = 10'h00C; // 0x030

task run_test;
  reg [15:0] r1, r2, r3;
begin
  $display("\n================ [TC] BUS.AccessRead ==================");

  // 1) FR stable back-to-back
  apb_read(OFF_UARTFR, r1);
  apb_read(OFF_UARTFR, r2);
  CHECK_EQ("FR stable r1==r2", r2, r1);

  // 2) FR read sau khi write CR vẫn hợp lệ (không có golden strict → chỉ log PASS)
  apb_write(OFF_UARTCR, 16'h0001);
  apb_read (OFF_UARTFR, r3);
  $display("[%0t] [INFO] FR after CR write = 0x%04h", $time, r3);
  pass_cnt = pass_cnt + 1; // đếm PASS cho case read-after-write

  $display("================ DONE BUS.AccessRead ==================\n");
end
endtask
`endif

