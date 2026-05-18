/*
 * Copyright (c) 2024 Renaldas Zioma
 * based on the VGA examples by Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_28add11_latchup(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // X color bands shift register
  reg [63:0] xShiftReg;
  wire randBit;
  assign randBit = ((xShiftReg[63] ~^ xShiftReg[62]) ~^ xShiftReg[60]) ~^ xShiftReg[59]; // Tap placement from https://docs.amd.com/v/u/en-US/xapp052

  reg prevVsync;
  always @(posedge clk) begin
    if (~rst_n) begin
		// Fun magic number ;)
    xShiftReg <= 64'h6C6F766569743F00;
		prevVsync <= 0;
		counter <= 0;
		height <= 0;
    end else begin
		prevVsync <= vsync;
		if (vsync && !prevVsync) begin
      xShiftReg <= {xShiftReg[62:0], randBit};

		  // Cloud registers
		  counter <= counter + 1;

		  if (counter == 0) begin
		  	height <= xShiftReg[39:32]; // Arbitrary choice referencing my username
		  end
    end
    end
  end 

  // Cloud logic
  reg [7:0] height;
  reg [9:0] counter;
  // Centered coordinates (signed)
  wire signed [10:0] cx = ($signed({1'b0, pix_x}) - {1'b0, counter});
  wire signed [10:0] cy = ($signed({1'b0, pix_y}) - {3'b0, height});
  wire signed [11:0] scaled_cx = {cx[10], cx[10], cx[10:1]};; 
  wire signed [11:0] scaled_cy = {cy[10], cy}; // Sign-extend Y to match width

  // Absolute values (using the scaled coordinates now)
  wire [10:0] abs_x = scaled_cx[11] ? (~scaled_cx[10:0] + 1'b1) : scaled_cx[10:0];
  wire [10:0] abs_y = scaled_cy[11] ? (~scaled_cy[10:0] + 1'b1) : scaled_cy[10:0];

  // Distance approximation (max + min/2)
  wire [10:0] max_d = (abs_x > abs_y) ? abs_x : abs_y;
  wire [10:0] min_d = (abs_x < abs_y) ? abs_x : abs_y;
  wire [10:0] radius = max_d + {1'b0, min_d[9:1]};


  // Draw the actual cloud
  wire isInCloud = radius <= 40;


  wire [1:0] green;
  wire sky;

  assign green = xShiftReg[pix_x[9:4] -: 2];
  assign sky = pix_y <= (240 + {6'b0, pix_x[3:0]});

  assign {R, G, B} = video_active ? sky ? (isInCloud ? {2'b11, 2'b11, 2'b11} : {2'b10, 2'b10, 2'b11}) : 
  ((green == 2'b00) ? {2'b01, 2'b10, 2'b00} : {2'b00, green, 2'b00}) : 6'b0;

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

endmodule