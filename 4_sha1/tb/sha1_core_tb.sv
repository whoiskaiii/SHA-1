module sha1_core_tb();

parameter CLK_CYC   = 2.5,
          MAX_TEST  = 100;

reg           clk;
reg           rst_n;
reg           din_vld; //For each message block, it is valid for 16T.
reg   [31:0]  din; //Message block is 16 * 32-bit.
reg           use_prec_cv; //1: Use the result of sha1 calculation in the previous message block.
                           //0: Do not use.
wire          busy;
wire          dout_vld; //A valid indication lasts for 1T.
wire  [159:0] dout; //sha1 calculation result.
wire  [159:0] dout_buf; 

integer i,  t_cnt;
integer fp_din, fp_dout;

reg [7:0]   b0, b1, b2, b3;
reg [159:0] expected_result;


//Generate clk.
initial begin
  #0;
  clk = 0;
  forever #(CLK_CYC)  clk = ~clk;
end

//Generate rst_n.
initial begin
  rst_n = 0;
  repeat(10) @(posedge clk)
  #1;
  rst_n = 1;
end

assign #1 dout_buf  = dout;

initial begin
  din_vld         = 1'b0;
  din             = 'd0;
  use_prec_cv     = 1'b0;
  //b0              = 'd0;
  //b1              = 'd0;
  //b2              = 'd0;
  //b3              = 'd0;
  //expected_result = 'd0;
  
  fp_din  = $fopen("../cmodel/sha1/sha_in.bin", "rb");
  fp_dout = $fopen("../cmodel/sha1/sha_out.bin", "rb");

  if(fp_din==0) begin
    $display("Sim Erro: File ../cmodel/sha1/sha_in.bin doesn't exist.");
    $finish();
  end

  if(fp_dout==0) begin
    $display("Sim Erro: File ../cmodel/sha1/sha_out.bin doesn't exist.");
    $finish();
  end

  @(posedge clk);
  @(posedge rst_n);
  repeat(5) @(posedge clk);

  //Start the function test of sha ------------------------------
  for(t_cnt=0; t_cnt<MAX_TEST; t_cnt=t_cnt+1) begin
    #1;
    //Load 16 * 32-bit message block for 16T.
    for(i=0; i<16; i=i+1) begin
      b0  = $fgetc(fp_din);
      b1  = $fgetc(fp_din);
      b2  = $fgetc(fp_din);
      b3  = $fgetc(fp_din);
      din = {b0, b1, b2, b3};

      din_vld = 1'b1;
      @(posedge clk);
      #1;
    end

    din_vld = 1'b0;
    @(posedge clk); #1;

    //Wait for the calculation to finish.
    @(posedge dout_vld);
    @(posedge clk);

    //Compare the calculated results.
    for(i=0; i<5; i=i+1) begin
      b0              = $fgetc(fp_dout);
      b1              = $fgetc(fp_dout);
      b2              = $fgetc(fp_dout);
      b3              = $fgetc(fp_dout);
      expected_result = (expected_result << 32) | {b3, b2, b1, b0};
    end

    if(expected_result !== dout_buf) begin
      #1;
      $display("SHA1 fail at test: %d.\n", t_cnt);
      $stop();
    end
  end
  $display("SHA1 test pass!\n");
  $stop();
end

sha1_core u_sha1_core(
  .clk          (clk),
  .rst_n        (rst_n),
  .din_vld      (din_vld),
  .din          (din),
  .use_prec_cv  (use_prec_cv),
  .busy         (busy),
  .dout_vld     (dout_vld),
  .dout         (dout)
);

endmodule
