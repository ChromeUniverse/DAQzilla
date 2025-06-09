// `default_nettype none

// implements a binary to decimal converter
// one-hot encoded output
module Decoder
  #(parameter WIDTH = 8)
  (output logic [WIDTH-1:0] D,
   input  logic en,
   input  logic [($clog2(WIDTH))-1:0] I);

   always_comb begin
     D = 'b0;
     if (en)
       D[I] = 1'b1;
   end

endmodule: Decoder

// shifts a parameterized input by a 2-bit value
// synchronized to a clok
module BarrelShiftRegister
  #(parameter WIDTH = 8)
  (input  logic [1:0] by,
   input  logic en, load, clock,
   input  logic [WIDTH-1:0] D,
   output logic [WIDTH-1:0] Q);

   logic [WIDTH-1:0] temp;

   always_ff @(posedge clock) begin
     if (load)
       temp <= D;
     else if (en)
       temp <= (temp << by);
   end

   assign Q = temp;

endmodule: BarrelShiftRegister


// implements a Multiplexer with a parameterized input
module Multiplexer
  #(parameter WIDTH = 8)
  (output logic Y,
   input  logic [WIDTH-1:0] I, 
   input  logic [($clog2(WIDTH)) - 1:0] S);

    assign Y = I[S];

endmodule: Multiplexer


// implements a 2-to-1 Mux with parameterized inputs
module Mux2to1
  #(parameter WIDTH = 8)
  (output logic [WIDTH-1:0] Y,
   input  logic [WIDTH-1:0] I0, I1, 
   input  logic S);

  // tertiary conditional
  assign Y = S ? I1 : I0;

endmodule: Mux2to1


// compares the values of two parameterized inputs
module MagComp
  #(parameter WIDTH = 8)
  (output logic AltB, AeqB, AgtB,
   input  logic [WIDTH-1:0] A, B);

  assign AltB = (A < B);
  assign AeqB = (A == B);
  assign AgtB = (A > B);

endmodule: MagComp


// compares the values of two parameterized inputs
// different from MagComp, only checks for equality
module Comparator
  #(parameter WIDTH = 8)
  (output logic AeqB,
   input  logic [WIDTH-1:0] A, B);

  assign AeqB = (A == B);

endmodule: Comparator


// adds two parameterized inputs together
module Adder
  #(parameter WIDTH = 8)
  (output logic cout,
   output logic [WIDTH-1:0] sum,
   input logic cin,
   input logic [WIDTH-1:0] A, B);

  assign {cout, sum} = A + B + cin;

endmodule: Adder


// subtracts two parameterized inputs
module Subtracter
  #(parameter WIDTH = 8)
  (input  logic bin,
   input  logic [WIDTH-1:0] A, B,
   output logic bout,
   output logic [WIDTH-1:0] diff);

   assign {bout, diff} = A - B - bin;


endmodule : Subtracter


// a flip flop with 2 asynchronous inputs
// only for 1 bit data inputs
module DFlipFlop
  (input  logic D, preset_L, reset_L,
   input  logic clock,
   output logic Q);

   always_ff @(posedge clock, negedge preset_L, negedge reset_L) begin
     if (~reset_L & ~preset_L) 
       Q <= 1'bx;
     else if (~reset_L)
       Q <= 0;
     else if (~preset_L)
       Q <= 1'b1;
     else
       Q <= D;
   end

endmodule : DFlipFlop


// stores a parameterized input
module Register
  #(parameter WIDTH = 8)
  (input  logic [(WIDTH - 1):0] D,
   input  logic clock, en, clear,
   output logic [(WIDTH - 1):0] Q);

   always_ff @(posedge clock) begin
     if (en)
       Q <= D;
     else if (clear)
       Q <= '0;
   end

endmodule : Register


// can decrement or increment a parameterized input
module Counter
  #(parameter WIDTH = 8)
  (input  logic en, clear, load, up,
   input  logic [WIDTH-1:0] D,
   input  logic clock,
   output logic [WIDTH-1:0] Q);

   logic [WIDTH-1:0] temp;

   always_ff @(posedge clock) begin
     if (clear)
       temp <= '0;
     else if (load)
       temp <= D;
     else if (en & up)
       temp <= (Q + 1);
     else if (en & ~up)
       temp <= (Q - 1);
    end

    assign Q = temp;
    
endmodule : Counter


// serial in parallel out shift register
// for parameterized output
// logically shifts left or right
module ShiftRegisterSIPO
  #(parameter WIDTH = 8)
  (input  logic en, left, serial, clock,
   output logic [WIDTH-1:0] Q);

   always_ff @(posedge clock) begin
     if (en & left) 
        Q <= {Q[WIDTH-2:0], serial}; // Shift left
     else if (en & ~left)
        Q <= {serial, Q[WIDTH-1:1]}; // Shift right
    end

endmodule : ShiftRegisterSIPO


// parallel in parallel out shift register
// for parameterized input and output
// logically shifts left or right
module ShiftRegisterPIPO
  #(parameter WIDTH = 8)
  (input  logic en, left, load, clock,
   input  logic [WIDTH-1:0] D,
   output logic [WIDTH-1:0] Q);

   always_ff @(posedge clock) begin
     if (load)
       Q = D;
     else if (en & left)
       Q <= (Q << 1);
     else if (en & ~left)
       Q <= (Q >> 1);
   end

endmodule : ShiftRegisterPIPO


// controls metastability issues
// feeds an input through a DFlipFlop twice
module Synchronizer
  (input  logic async, clock,
   output logic sync);

   logic temp;

   DFlipFlop f1(.D(async), .Q(temp), .clock(clock),
                .preset_L(1'b1), .reset_L(1'b1)),
             f2(.D(temp), .Q(sync), .clock(clock),
                .preset_L(1'b1), .reset_L(1'b1));

endmodule : Synchronizer


// controls access to a shared wire/bus
module BusDriver
  #(parameter WIDTH = 8)
  (input  logic en, 
   input  logic [WIDTH-1:0] data,
   output logic [WIDTH-1:0] buff,
   inout  tri [WIDTH-1:0] bus);

   assign bus = (en) ? data : 'bz;
   assign buff = bus;
endmodule : BusDriver


// stores a number of words
// combination read, sequential write
module Memory
  #(parameter AW = 4,
              DW = 8,
              W = 2 ** AW)
  (input logic re, we, clock,
   input logic [AW-1:0] addr,
   inout tri [DW-1:0] data);

   logic [DW-1:0] M[W];
   logic [DW-1:0] rData;

   assign data = (re) ? rData : 'bz;

   always_ff @(posedge clock) begin
     if (we)
       M[addr] <= data;
   end

   always_comb
     rData = M[addr];

endmodule : Memory