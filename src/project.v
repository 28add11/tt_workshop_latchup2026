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
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
		// Fun magic number ;)
      xShiftReg <= 64'h6C6F766569743F00;
    end else begin
      xShiftReg <= {xShiftReg[62:0], randBit};
    end
  end 

  wire [1:0] green;
  assign green = xShiftReg[pix_x[9:4] -: 2];
  assign {R, G, B} = video_active ? (green == 2'b00) ? {2'b01, 2'b10, 2'b00} : {2'b00, green, 2'b00} : 6'b0;

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