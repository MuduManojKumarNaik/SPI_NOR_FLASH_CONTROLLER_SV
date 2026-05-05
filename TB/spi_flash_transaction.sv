/*typedef enum {
   OP_READ,
   OP_PAGE_PROGRAM,
   OP_SECTOR_ERASE,
   OP_RESET,
   OP_READ_STATUS,
   OP_READ_ID
} spi_op_e;*/
class spi_flash_transaction;
    //spi_op_e      op;
    //bit [23:0]    addr;
    //bit [15:0]    len;
rand spi_op_e   op;
rand bit [23:0] addr;
rand bit [15:0] len;    
byte unsigned tx_payload[$];
    byte unsigned rx_payload[$];
    bit           error;
    bit [7:0]     status_at_done;
    string        name;
constraint op_c {
   op inside {
      OP_READ,
      OP_PAGE_PROGRAM,
      OP_SECTOR_ERASE,
      OP_READ_STATUS,
      OP_READ_ID
   };
}

constraint addr_c {
   addr inside {
      24'h000000,
      24'h0000F0,
      24'h000120,
      [24'h000000:24'h00FFFF]
   };
}

constraint len_c {
   len inside {[1:32]};
}

    function new(
        input spi_op_e   op   = OP_READ,
        input bit [23:0] addr = 24'd0,
        input bit [15:0] len  = 16'd0,
        input string     name = ""
    );
        this.op             = op;
        this.addr           = addr;
        this.len            = len;
        this.error          = 1'b0;
        this.status_at_done = 8'd0;
        this.name           = name;
    endfunction

    function spi_flash_transaction clone();
        spi_flash_transaction c;
        c = new(op, addr, len, name);
        c.error          = error;
        c.status_at_done = status_at_done;
        foreach (tx_payload[i])
            c.tx_payload.push_back(tx_payload[i]);
        foreach (rx_payload[i])
            c.rx_payload.push_back(rx_payload[i]);
        return c;
    endfunction

    function bit is_page_program_bad();
        return page_program_bad(addr, len);
    endfunction

    function int unsigned expected_rx_count();
        case (op)
            OP_READ:        return (len == 16'd0) ? 0 : len;
            OP_READ_STATUS: return 1;
            OP_READ_ID:     return (len == 16'd0) ? 3 : len;
            default:        return 0;
        endcase
    endfunction

    function byte unsigned tx_byte_at(input int unsigned index);
        if (index < tx_payload.size())
            return tx_payload[index];
        return 8'h00;
    endfunction

    function string op_name();
        case (op)
            OP_READ:         return "READ";
            OP_PAGE_PROGRAM: return "PAGE_PROGRAM";
            OP_SECTOR_ERASE: return "SECTOR_ERASE";
            OP_READ_STATUS:  return "READ_STATUS";
            OP_READ_ID:      return "READ_ID";
            default:         return "UNKNOWN";
        endcase
    endfunction

    function string sprint();
        return $sformatf("%s addr=0x%06h len=%0d name=%s", op_name(), addr, len, name);
    endfunction
endclass
