module sha1_core (
  input               clk,
  input               rst_n,
  input               din_vld, //For each message block, it is valid for 16T.
  input       [31:0]  din, //Message block is 16 * 32-bit.
  input               use_prec_cv, //1: Use the result of sha1 calculation in the previous message block.
                                   //0: Do not use.
  output  reg         busy,
  output  reg         dout_vld, //A valid indication lasts for 1T.
  output      [159:0] dout //sha1 calculation result.
  );

localparam  [31:0]  H0_INIT = 32'h67452301,
                    H1_INIT = 32'hefcdab89,
                    H2_INIT = 32'h98badcfe,
                    H3_INIT = 32'h10325476,
                    H4_INIT = 32'hc3d2e1f0;

//1. W[i] generation ------------------------------------------------------------------
reg       din_vld_d;
reg [6:0] cnt_w;
reg       w_busy;
reg [1:0] stage_cal; //t belong to 0~19 / 20~39 / 40~59 / 60~79.

reg   [31:0]  w_reg [0:15];
wire  [31:0]  w_nxt_xor;
wire  [31:0]  w_nxt;

assign  w_nxt_xor = w_reg[13] ^ w_reg[8] ^ w_reg[2] ^ w_reg[0];
assign  w_nxt     = {w_nxt_xor[30:0], w_nxt_xor[31]}; //Rotate left 1-bit.

always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    cnt_w <=  'd0;
  else if(w_busy || din_vld) begin //w_busy?
    if(cnt_w=='d79)
      cnt_w <=  'd0;
    else
      cnt_w <=  cnt_w + 1'b1;
  end
end

always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    w_busy  <=  1'b0;
  else if(din_vld)
    w_busy  <=  1'b1;
  else if(cnt_w=='d79)
    w_busy  <=  1'b0;
end

generate
  genvar  i;
  for(i=0; i<=15; i=i+1) begin: gen_w_reg
    always @(posedge clk) begin// or negedge rst_n)
      if(i==15) begin
        if(din_vld)
          w_reg[i]  <=  din;
        else if(w_busy)
          w_reg[i]  <=  w_nxt;
      end else begin
          w_reg[i]  <=  w_reg[i+1];
      end
    end
  end
endgenerate

//2. A/B/C/D/E update -----------------------------------------------------------------
reg           a_e_busy;
reg           a_e_busy_d;
reg   [31:0]  h0, h1, h2, h3, h4;
reg   [31:0]  a_reg;
reg   [31:0]  b_reg;
reg   [31:0]  c_reg;
reg   [31:0]  d_reg;
reg   [31:0]  e_reg;
reg   [31:0]  f_temp;
reg   [31:0]  k_temp;
wire  [31:0]  a_nxt;

assign  a_nxt = {a_reg[26:0], a_reg[31:27]} + f_temp + e_reg + w_reg[15] + k_temp;
assign  dout  = {h0, h1, h2, h3, h4};

//2.1 Calculate k_temp and f_temp -------------------------------
//Delay for Positive edge detection.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    din_vld_d <=  1'b0;
  else
    din_vld_d <=  din_vld;
end

//Calculate the current stage.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    stage_cal <=  'd0;
  else if(din_vld && ~din_vld_d) //Positive edge detection.
    stage_cal <=  'd0;
  else if((cnt_w=='d20) || (cnt_w=='d40) || (cnt_w=='d60))
    stage_cal <=  stage_cal + 1'b1;
end

//Calculate k_temp and f_temp.
always @(*) begin
  case(stage_cal)
    2'd0: begin
      k_temp  = 32'h5A827999;
      f_temp  = (b_reg & c_reg) | ((~b_reg) & d_reg);
    end
    2'd1: begin
      k_temp  = 32'h6ED9EBA1;
      f_temp  = b_reg ^ c_reg ^ d_reg;
    end
    2'd2: begin
      k_temp  = 32'h8F1BBCDC;
      f_temp  = (b_reg & c_reg) | (b_reg & d_reg) | (c_reg & d_reg);
    end
    2'd3: begin
      k_temp  = 32'hCA62C1D6;
      f_temp  = b_reg ^ c_reg ^ d_reg;
    end
  endcase
end

//2.2 Calculate a/b/c/d/e_reg -----------------------------------
always @(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    a_reg <=  H0_INIT;
    b_reg <=  H1_INIT;
    c_reg <=  H2_INIT;
    d_reg <=  H3_INIT;
    e_reg <=  H4_INIT;
  end else if(din_vld && (~din_vld_d)) begin //Positive edge detection.
    if(use_prec_cv) begin
      a_reg <=  h0;
      b_reg <=  h1;
      c_reg <=  h2;
      d_reg <=  h3;
      e_reg <=  h4;
    end else begin
      a_reg <=  H0_INIT;
      b_reg <=  H1_INIT;
      c_reg <=  H2_INIT;
      d_reg <=  H3_INIT;
      e_reg <=  H4_INIT;
    end
  end else if(a_e_busy) begin
    a_reg <=  a_nxt;
    b_reg <=  a_reg;
    c_reg <=  {b_reg[1:0], b_reg[31:2]}; //Rotate left by 30-bits.
    d_reg <=  c_reg;
    e_reg <=  d_reg;
  end
end

always @(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    a_e_busy    <=  1'b0;
    a_e_busy_d  <=  1'b0;
  end else begin
    a_e_busy    <=  w_busy | din_vld;
    a_e_busy_d  <=  a_e_busy;
  end
end

always @(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    h0  <=  H0_INIT;
    h1  <=  H1_INIT;
    h2  <=  H2_INIT;
    h3  <=  H3_INIT;
    h4  <=  H4_INIT;
  end else if(din_vld && (!din_vld_d)) begin //Positive edge detection.
    if(~use_prec_cv) begin
      h0  <=  H0_INIT;
      h1  <=  H1_INIT;
      h2  <=  H2_INIT;
      h3  <=  H3_INIT;
      h4  <=  H4_INIT;
    end
  end else if((!a_e_busy) && a_e_busy_d) begin //Negative edge detection.
    `ifdef _SHA_STAND_ALGORITHM_
      h0  <=  a_reg;
      h1  <=  b_reg;
      h2  <=  c_reg;
      h3  <=  d_reg;
      h4  <=  e_reg;
    `else
      h0  <=  h0 + a_reg;
      h1  <=  h1 + b_reg;
      h2  <=  h2 + c_reg;
      h3  <=  h3 + d_reg;
      h4  <=  h4 + e_reg;
    `endif
  end
end

always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    dout_vld  <=  1'b0;
  else if((!a_e_busy) && a_e_busy_d) //Negative edge detection.
    dout_vld  <=  1'b1;
  else
    dout_vld  <=  1'b0;
end

always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    busy  <=  1'b0;
  else if(din_vld && (!din_vld_d)) //Positive edge detection.
    busy  <=  1'b1;
  else if((!a_e_busy) && a_e_busy_d) //Negative edge detection.
    busy  <=  1'b0;
end

endmodule
