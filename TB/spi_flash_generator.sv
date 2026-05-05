class spi_flash_generator;
    mailbox #(spi_flash_transaction) gen2drv;
    mailbox #(spi_flash_transaction) exp2sb;

    function new(
        mailbox #(spi_flash_transaction) gen2drv,
        mailbox #(spi_flash_transaction) exp2sb
    );
        this.gen2drv = gen2drv;
        this.exp2sb  = exp2sb;
    endfunction

    task send(input spi_flash_transaction tr);
        $display("[GEN] %s", tr.sprint());
        gen2drv.put(tr.clone());
        exp2sb.put(tr.clone());
    endtask
task run();
   spi_flash_transaction tr;

   // Keep your directed tests (good for corner cases)

   tr = new(OP_READ_ID, 24'h000000, 16'd3, "read_jedec_id");
   send(tr);

   tr = new(OP_READ_STATUS, 24'h000000, 16'd1, "read_idle_status");
   send(tr);

   // -------------------------------
   // RANDOM TRAFFIC (THIS IS KEY)
   // -------------------------------

   repeat(1000) begin
      tr = new();

      assert(tr.randomize() with {
         op inside {OP_READ, OP_PAGE_PROGRAM, OP_SECTOR_ERASE, OP_READ_STATUS};
         addr inside {24'h000000, 24'h0000F0, 24'h000120, [24'h0:24'h00FFFF]};
         len inside {[1:32]};
      });

      send(tr);
   end

   // -------------------------------
   // KEEP YOUR CORNER TESTS
   // -------------------------------

   tr = new(OP_PAGE_PROGRAM, 24'h000120, 16'd16, "program_16_bytes");
   foreach (tr.tx_payload[i])
      tr.tx_payload.push_back(byte'(8'hA0 + i));
   send(tr);

   tr = new(OP_READ, 24'h000120, 16'd16, "read_programmed_bytes");
   send(tr);

   tr = new(OP_SECTOR_ERASE, 24'h000000, 16'd0, "erase_sector_zero");
   send(tr);

   tr = new(OP_READ, 24'h000120, 16'd16, "read_erased_bytes");
   send(tr);

   tr = new(OP_PAGE_PROGRAM, 24'h0000F0, 16'd17, "bad_crossing_page_program");
   send(tr);
// --------------------------------------------------
// COVERAGE IMPROVEMENT TESTS
// --------------------------------------------------

// FULL PAGE PROGRAM
tr = new(OP_PAGE_PROGRAM, 24'h000200, 16'd256, "full_page_program");

for (int i = 0; i < 256; i++)
   tr.tx_payload.push_back($urandom_range(0,255));

send(tr);

// TOO LARGE PROGRAM
tr = new(OP_PAGE_PROGRAM, 24'h000300, 16'd300, "too_large_program");

for (int i = 0; i < 300; i++)
   tr.tx_payload.push_back($urandom_range(0,255));

send(tr);

// ZERO LENGTH READ
tr = new(OP_READ, 24'h000100, 16'd0, "zero_length_read");
send(tr);

// ONE BYTE READ
tr = new(OP_READ, 24'h000101, 16'd1, "one_byte_read");
send(tr);

// MEDIUM LENGTH READ
tr = new(OP_READ, 24'h000120, 16'd100, "medium_read");
send(tr);

// LARGE ID READ
tr = new(OP_READ_ID, 24'h000000, 16'd32, "large_id_read");
send(tr);

// ILLEGAL PAGE PROGRAM
tr = new(OP_PAGE_PROGRAM, 24'h0000F8, 16'd32, "illegal_page_cross");

for (int i = 0; i < 32; i++)
   tr.tx_payload.push_back($urandom_range(0,255));

send(tr);

// RANDOM TRANSACTIONS
repeat(1000) begin

   tr = new();

   assert(tr.randomize());

   send(tr);

end
   gen2drv.put(null);
   exp2sb.put(null);

endtask
    /*task run();
        spi_flash_transaction tr;

        tr = new(OP_READ_ID, 24'h000000, 16'd3, "read_jedec_id");
        send(tr);

        tr = new(OP_READ_STATUS, 24'h000000, 16'd1, "read_idle_status");
        send(tr);

        tr = new(OP_PAGE_PROGRAM, 24'h000120, 16'd16, "program_16_bytes");
        for (int i = 0; i < 16; i++)
            tr.tx_payload.push_back(byte'(8'hA0 + i));
        send(tr);

        tr = new(OP_READ, 24'h000120, 16'd16, "read_programmed_bytes");
        send(tr);

        tr = new(OP_SECTOR_ERASE, 24'h000000, 16'd0, "erase_sector_zero");
        send(tr);

        tr = new(OP_READ, 24'h000120, 16'd16, "read_erased_bytes");
        send(tr);

        tr = new(OP_PAGE_PROGRAM, 24'h0000F0, 16'd17, "bad_crossing_page_program");
        send(tr);

        gen2drv.put(null);
        exp2sb.put(null);
    endtask*/
endclass
