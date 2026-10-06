interface mem_req_if
  import LoadStoreTypes::*;
#(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned XLEN = 32
);

  logic valid;
  logic ready;
  logic [ADDR_WIDTH-1:0] addr;
  ls_type_e op;
  logic [XLEN-1:0] write_data;

  modport master(input ready, output valid, addr, op, write_data);
  modport slave(input valid, addr, op, write_data, output ready);

endinterface
