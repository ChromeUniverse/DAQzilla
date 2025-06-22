// `default_nettype none

module ChipInterface(
  input wire [15:0] SW,
  input wire [3:0] BTN,
  input wire CLOCK_100,
  output wire [15:0] LD,
  output wire [3:0] D1_AN, D2_AN,  // Hex displays
  output wire [7:0] D1_SEG, D2_SEG,  // Also, hex displays

  // ADS1256 SPI interface
  input wire ADS1256_DOUT,  // MISO
  input wire ADS1256_DRDY,  
  output wire ADS1256_SCLK,
  output wire ADS1256_DIN,  // MOSI
  output wire ADS1256_CS
); 

  // board I/O
  wire reset, clock, start, done;
  assign reset = BTN[0];
  assign clock = CLOCK_100;
  assign start = BTN[1];
  assign done = LD[0];

  // SPI interface (PMOD)
  wire MOSI, MISO, SCLK, CS_L;
  assign MOSI = ADS1256_DIN;
  assign MISO = ADS1256_DOUT;
  assign CS_L = ADS1256_CS;
  assign SCLK = ADS1256_SCLK;

  // ADS1256 status signals
  wire DRDY_L;
  assign DRDY_L = ADS1256_DRDY;
  assign LD[15] = ADS1256_DRDY;

  // hardcoding TX buffer with RDATA (01h)
  logic [7:0] tx_buffer;
  assign tx_buffer = 8'h01;

  spi_mode_t mode;
  assign mode = SPI_TX_RX;

  logic [23:0] rx_buffer;

  spi spi_core (
    .reset_i(reset),
    .clock_i(clock),
    .start_i(start),
    .tx_buffer_i(tx_buffer),
    .MISO_i(MISO),
    .MOSI_o(MOSI),
    .CS_L_o(CS_L),
    .SCLK_o(SCLK),
    .rx_buffer_o(rx_buffer),
    .done_o(done),
    .spi_mode_i(mode),
    .DRDY_L_i(DRDY_L)
  );

  // 7-segment displays
  logic [7:0] blank;
  assign blank = 8'b1100_0000;

  logic [3:0] BCD0, BCD1, BCD2, BCD3,
              BCD4, BCD5, BCD6, BCD7;

  assign BCD0 = rx_buffer[3:0];
  assign BCD1 = rx_buffer[7:4];
  assign BCD2 = rx_buffer[11:8];
  assign BCD3 = rx_buffer[15:12];
  assign BCD4 = rx_buffer[19:16];
  assign BCD5 = rx_buffer[23:20];

  logic [6:0] HEX7, HEX6, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0;

  SevenSegmentDisplay display(
    // bcd inputs
    .BCD0(BCD0),
    .BCD1(BCD1),
    .BCD2(BCD2),
    .BCD3(BCD3),
    .BCD4(BCD4),
    .BCD5(BCD5),
    .BCD6(BCD6),
    .BCD7(BCD7),

    // blank displays
    .blank(blank),

    // hex signals
    .HEX0(HEX0),
    .HEX1(HEX1),
    .HEX2(HEX2),
    .HEX3(HEX3),
    .HEX4(HEX4),
    .HEX5(HEX5),
    .HEX6(HEX6),
    .HEX7(HEX7)
  );

  SSegDisplayDriver ssd (.dpoints(8'b0), .reset(1'b0), .clk(CLOCK_100), .*);

endmodule: ChipInterface


module BCDtoSevenSegment(
  input logic [3:0] bcd,
  output logic [6:0] segment
);

  // segment 0: ~1, ~4, ~b, ~d
  assign segment[0] = 
    (bcd == 4'd1) | (bcd == 4'd4) | (bcd == 4'hB) | (bcd == 4'hD) 
    ? 1'b0 
    : 1'b1;

  // segment 1: ~5, ~6, ~b, ~c, ~e, ~f
  assign segment[1] = 
    (bcd == 4'd5) | (bcd == 4'd6) | (bcd == 4'hB) 
    | (bcd == 4'hC) | (bcd == 4'hC) | (bcd == 4'hF) 
    ? 1'b0 
    : 1'b1;
  
  // segment 2: ~2, ~c, ~e, ~f
  assign segment[2] = 
    (bcd == 4'd2) | (bcd == 4'hC) | (bcd == 4'hE) 
    | (bcd == 4'hF)
    ? 0 
    : 1;

  // segment 3: ~1, ~4, ~7, ~a, ~f
  assign segment[3] = 
    (bcd == 4'd1) | (bcd == 4'd4) | (bcd == 4'd7) 
    | (bcd == 4'hA) | (bcd == 4'hF) 
    ? 1'b0 
    : 1'b1;
  
  // segment 4: 0, 2, 6, 8, a, b, c, d, e, f
  assign segment[4] = 
    (bcd == 4'd0) | (bcd == 4'd2) | (bcd == 4'd6) | (bcd == 4'd8) 
    | (bcd == 4'hA) | (bcd == 4'hB) | (bcd == 4'hC) | (bcd == 4'hD)
    | (bcd == 4'hE) | (bcd == 4'hF)
    ? 1'b1 
    : 1'b0;

  // segment 5: ~1, ~2, ~3, ~7, ~d
  assign segment[5] = 
    (bcd == 4'd1) | (bcd == 4'd2) | (bcd == 4'd3) | (bcd == 4'd7) 
    | (bcd == 4'hD) 
    ? 1'b0 
    : 1'b1;
  
  // segment 6: ~0, ~1, ~7, ~c
  assign segment[6] = 
    (bcd == 4'd0) | (bcd == 4'd1) | (bcd == 4'd7) | (bcd == 4'hC) 
    ? 1'b0 
    : 1'b1;


endmodule: BCDtoSevenSegment


module SevenSegmentDisplay(
  input   logic [3:0] BCD7, BCD6, BCD5, BCD4, 
                      BCD3, BCD2, BCD1, BCD0,
  input   logic [7:0] blank,
  output  logic [6:0] HEX7, HEX6, HEX5, HEX4, 
                      HEX3, HEX2, HEX1, HEX0
);

  // segment bits outputted by BCD to 7 Segment converter
  // before ANDing with blank signals or inverting
  logic [6:0] PRE_HEX7, PRE_HEX6, PRE_HEX5, PRE_HEX4, 
              PRE_HEX3, PRE_HEX2, PRE_HEX1, PRE_HEX0;

  BCDtoSevenSegment display0(.bcd(BCD0), .segment(PRE_HEX0));
  assign HEX0 = blank[0] ? 7'b111_1111 : ~PRE_HEX0;
  
  BCDtoSevenSegment display1(.bcd(BCD1), .segment(PRE_HEX1));
  assign HEX1 = blank[1] ? 7'b111_1111 : ~PRE_HEX1;
  
  BCDtoSevenSegment display2(.bcd(BCD2), .segment(PRE_HEX2));
  assign HEX2 = blank[2] ? 7'b111_1111 : ~PRE_HEX2;
  
  BCDtoSevenSegment display3(.bcd(BCD3), .segment(PRE_HEX3));
  assign HEX3 = blank[3] ? 7'b111_1111 : ~PRE_HEX3;
  
  BCDtoSevenSegment display4(.bcd(BCD4), .segment(PRE_HEX4));
  assign HEX4 = blank[4] ? 7'b111_1111 : ~PRE_HEX4;
  
  BCDtoSevenSegment display5(.bcd(BCD5), .segment(PRE_HEX5));
  assign HEX5 = blank[5] ? 7'b111_1111 : ~PRE_HEX5;
  
  BCDtoSevenSegment display6(.bcd(BCD6), .segment(PRE_HEX6));
  assign HEX6 = blank[6] ? 7'b111_1111 : ~PRE_HEX6;
  
  BCDtoSevenSegment display7(.bcd(BCD7), .segment(PRE_HEX7));
  assign HEX7 = blank[7] ? 7'b111_1111 : ~PRE_HEX7;
  

endmodule: SevenSegmentDisplay