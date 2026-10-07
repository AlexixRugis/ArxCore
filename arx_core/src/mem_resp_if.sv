import LoadStoreTypes::*;

interface mem_resp_if #(
    parameter int unsigned XLEN = 32
);

  logic valid;
  logic ready;
  logic [XLEN-1:0] data;

  modport master(input ready, output valid, data);
  modport slave(input valid, data, output ready);

endinterface
