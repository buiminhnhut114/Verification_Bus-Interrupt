`ifndef RUN_BUS_BACK2BACK_V
`define RUN_BUS_BACK2BACK_V

localparam [11:2] OFF_UARTCR = 10'h00C; // 0x030
localparam [11:2] OFF_UARTFR = 10'h006; // 0x018
localparam [11:2] OFF_UARTDR = 10'h000; // 0x000

task run_test;
  reg [15:0] r;
begin
  $display("\n================ [TC] BUS.Back-to-Back ================");

  // Chuỗi 1: W@CR -> R@FR -> W@DR -> R@CR
  apb_write(OFF_UARTCR, 16'h0003);
  apb_read (OFF_UARTFR, r); // chỉ log
  $display("[%0t] [INFO] FR during back2back = 0x%04h", $time, r);
  apb_write(OFF_UARTDR, 16'h005A);
  apb_read (OFF_UARTCR, r); CHECK_EQ("Back2Back CR rb", r, 16'h0003);

  // Chuỗi 2: toggles nhanh CR
  apb_write(OFF_UARTCR, 16'h0001);
  apb_write(OFF_UARTCR, 16'h0000);
  apb_read (OFF_UARTCR, r); CHECK_EQ("CR rb after rapid toggles", r, 16'h0000);

  $display("================ DONE BUS.Back-to-Back ================\n");
end
endtask
`endif

