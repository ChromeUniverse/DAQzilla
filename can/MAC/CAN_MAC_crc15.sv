// `default_nettype none

// ==========================================================================
// CRC Generation Unit - Linear Feedback Shift Register implementation
// (c) Kay Gorontzi, GHSi.de, distributed under the terms of LGPL
// ==========================================================================


module CRC_Unit(
  input logic BITVAL, BITSTRB, CLEAR,
  output logic [14:0] CRC
);
   logic inv;
   
   assign inv = BITVAL ^ CRC[14];                   // XOR required?
   
   always @(posedge BITSTRB or posedge CLEAR) begin
      if (CLEAR) begin
         CRC = 0;                                  // Init before calculation
         end
      else begin
         CRC[14] = CRC[13] ^ inv;
         CRC[13] = CRC[12];
         CRC[12] = CRC[11];
         CRC[11] = CRC[10];
         CRC[10] = CRC[9] ^ inv;
         CRC[9] = CRC[8];
         CRC[8] = CRC[7] ^ inv;
         CRC[7] = CRC[6] ^ inv;
         CRC[6] = CRC[5];
         CRC[5] = CRC[4];
         CRC[4] = CRC[3] ^ inv;
         CRC[3] = CRC[2] ^ inv;
         CRC[2] = CRC[1];
         CRC[1] = CRC[0];
         CRC[0] = inv;
         end
      end
   
endmodule