package LoadStoreTypes;

typedef enum logic [2:0] {
    LOAD_BYTE                   = 3'b000,
    LOAD_BYTE_UNSIGNED          = 3'b001,
    LOAD_HALFWORD               = 3'b010,
    LOAD_HALFWORD_UNSIGNED      = 3'b011,
    LOAD_WORD                   = 3'b100,
    STORE_BYTE                  = 3'b101,
    STORE_HALFWORD              = 3'b110,
    STORE_WORD                  = 3'b111
} ls_type_t;

endpackage