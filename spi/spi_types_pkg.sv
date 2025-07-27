package spi_types_pkg;
  typedef enum logic [2:0] {
    ROUTINE_NONE,       // 3'b000
    ROUTINE_CALIBRATE,  // 3'b001
    ROUTINE_READBACK,   // 3'b010
    ROUTINE_SINGLE,     // 3'b011
    ROUTINE_CONTINUOUS, // 3'b100
    ROUTINE_ILLEGAL     // 3'b101
  } routine_t;
endpackage