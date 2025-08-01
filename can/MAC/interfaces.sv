// --------------------------------
// Data frames
// --------------------------------

interface MA_data_request_if (
    input logic clock
);
  logic        valid;  // LLC -> MAC: asserts when request is valid
  logic        ready;  // MAC -> LLC: asserts when MAC is ready to accept

  logic [10:0] identifier;
  logic [ 3:0] dlc;
  logic [63:0] data_payload;  // up to 8 bytes

  modport MAC(input valid, identifier, dlc, data_payload, output ready);
  modport LLC(output valid, identifier, dlc, data_payload, input ready);
endinterface


interface MA_data_indication_if (
    input logic clock
);
  logic        valid;
  logic        ready;
  logic [10:0] identifier;
  logic [ 3:0] dlc;
  logic [63:0] data_payload;

  modport MAC(output valid, identifier, dlc, data_payload, input ready);
  modport LLC(input valid, identifier, dlc, data_payload, output ready);
endinterface


interface MA_data_confirm_if (
    input logic clock
);
  logic        valid;
  logic        ready;
  logic [10:0] identifier;
  typedef enum logic [0:0] {
    Success,
    No_Success
  } tx_status_t;
  tx_status_t status;

  modport MAC(output valid, identifier, status, input ready);
  modport LLC(input valid, identifier, status, output ready);
endinterface

// --------------------------------
// Remote frames
// --------------------------------

interface MA_remote_request_if (
    input logic clock
);
  logic        valid;
  logic        ready;
  logic [10:0] identifier;
  logic [ 3:0] dlc;

  modport LLC(output valid, identifier, dlc, input ready);
  modport MAC(input valid, identifier, dlc, output ready);
endinterface


interface MA_remote_indication_if (
    input logic clock
);
  logic        valid;
  logic        ready;
  logic [10:0] identifier;
  logic [ 3:0] dlc;

  modport MAC(output valid, identifier, dlc, input ready);
  modport LLC(input valid, identifier, dlc, output ready);
endinterface


interface MA_remote_confirm_if (
    input logic clock
);
  logic        valid;
  logic        ready;
  logic [10:0] identifier;
  typedef enum logic [0:0] {
    Success,
    No_Success
  } tx_status_t;
  tx_status_t status;

  modport MAC(output valid, identifier, status, input ready);
  modport LLC(input valid, identifier, status, output ready);
endinterface

// --------------------------------
// Overload frames
// --------------------------------

interface MA_ovld_request_if (
    input logic clock
);
  logic valid;
  logic ready;

  modport LLC(output valid, input ready);
  modport MAC(input valid, output ready);
endinterface


interface MA_ovld_indication_if (
    input logic clock
);
  logic valid;
  logic ready;

  modport MAC(output valid, input ready);
  modport LLC(input valid, output ready);
endinterface


interface MA_ovld_confirm_if (
    input logic clock
);
  logic valid;
  logic ready;
  typedef enum logic [0:0] {
    Success,
    No_Success
  } tx_status_t;
  tx_status_t status;

  modport MAC(output valid, status, input ready);
  modport LLC(input valid, status, output ready);
endinterface
