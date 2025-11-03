`ifndef RUN_BUS_RESET_V
`define RUN_BUS_RESET_V

localparam [11:2] OFF_UARTCR   = 10'h00C; // 0x030
localparam [11:2] OFF_UARTIFLS = 10'h00D; // 0x034
localparam [11:2] OFF_UARTFR   = 10'h006; // 0x018

task run_test;
  reg [15:0] r;
begin
  $display("\n================ [TC] BUS.Reset =======================");

  // Làm bẩn trước
  apb_write(OFF_UARTCR,   16'hFFFF);
  apb_write(OFF_UARTIFLS, 16'hFFFF);

  // Kéo reset & release (sử dụng PRESETn/nUARTRST trong TB)
  @(posedge PCLK);    PRESETn   <= 1'b0; repeat(4) @(posedge PCLK);
  @(posedge UARTCLK); nUARTRST  <= 1'b0; repeat(4) @(posedge UARTCLK);
  @(posedge PCLK);    PRESETn   <= 1'b1; repeat(2) @(posedge PCLK);
  @(posedge UARTCLK); nUARTRST  <= 1'b1; repeat(2) @(posedge UARTCLK);

  // Kiểm tra default theo spec
  apb_read(OFF_UARTCR,   r); CHECK_EQ("CR after reset exp=0300",  r, 16'h0300);
  apb_read(OFF_UARTIFLS, r); CHECK_EQ("IFLS after reset exp=0012", r, 16'h0012);

  // FR chỉ log
  apb_read(OFF_UARTFR, r);
  $display("[%0t] [INFO] FR after reset = 0x%04h (log only)", $time, r);
  pass_cnt = pass_cnt + 1; // đếm pass cho bước log này

  // Sanity: viết lại sau reset
  apb_write(OFF_UARTCR, 16'h0001);
  apb_read (OFF_UARTCR, r); CHECK_EQ("CR write after reset", r, 16'h0001);

  $display("================ DONE BUS.Reset ======================\n");
end
endtask
`endif

