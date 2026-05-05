class spi_flash_scoreboard;
    mailbox #(spi_flash_transaction) exp2sb;
    mailbox #(spi_flash_transaction) mon2sb;
    byte unsigned exp_mem [0:MEM_BYTES-1];
    int unsigned errors;
    bit finished;

    function new(
        mailbox #(spi_flash_transaction) exp2sb,
        mailbox #(spi_flash_transaction) mon2sb
    );
        this.exp2sb  = exp2sb;
        this.mon2sb  = mon2sb;
        this.errors  = 0;
        this.finished = 1'b0;
        foreach (exp_mem[i])
            exp_mem[i] = 8'hFF;
    endfunction

    function void fail(input string msg);
        $display("[SB][ERROR] %s", msg);
        errors++;
    endfunction

    function void expect_error(input spi_flash_transaction obs, input bit exp_error, input string label);
        if (obs.error !== exp_error)
            fail($sformatf("%s error=%0b expected=%0b", label, obs.error, exp_error));
    endfunction

    function void expect_rx_size(input spi_flash_transaction obs, input int unsigned exp_size, input string label);
        if (obs.rx_payload.size() != exp_size)
            fail($sformatf("%s rx_payload size=%0d expected=%0d", label, obs.rx_payload.size(), exp_size));
    endfunction

    function void check_header(input spi_flash_transaction exp, input spi_flash_transaction obs);
        if (obs.op !== exp.op)
            fail($sformatf("Observed op %s expected %s", obs.op_name(), exp.op_name()));
        if (obs.addr !== exp.addr)
            fail($sformatf("%s addr=0x%06h expected=0x%06h", exp.name, obs.addr, exp.addr));
        if (obs.len !== exp.len)
            fail($sformatf("%s len=%0d expected=%0d", exp.name, obs.len, exp.len));
    endfunction

    function void check_read_id(input spi_flash_transaction exp, input spi_flash_transaction obs);
        int unsigned n;
        byte unsigned exp_byte;

        n = (exp.len == 16'd0) ? 3 : exp.len;
        expect_error(obs, 1'b0, exp.name);
        expect_rx_size(obs, n, exp.name);

        for (int unsigned i = 0; (i < n) && (i < obs.rx_payload.size()); i++) begin
            exp_byte = jedec_id_byte(i);
            if (obs.rx_payload[i] !== exp_byte)
                fail($sformatf("%s byte[%0d]=0x%02h expected=0x%02h",
                               exp.name, i, obs.rx_payload[i], exp_byte));
        end
    endfunction

    function void check_read_status(input spi_flash_transaction exp, input spi_flash_transaction obs);
        expect_error(obs, 1'b0, exp.name);
        expect_rx_size(obs, 1, exp.name);

        if (obs.rx_payload.size() > 0) begin
            if (obs.rx_payload[0][1:0] !== 2'b00)
                fail($sformatf("%s status[1:0]=%b expected=00", exp.name, obs.rx_payload[0][1:0]));
        end
    endfunction

    function void check_page_program(input spi_flash_transaction exp, input spi_flash_transaction obs);
        int unsigned mem_index;

        if (exp.is_page_program_bad()) begin
            expect_error(obs, 1'b1, exp.name);
            return;
        end

        expect_error(obs, 1'b0, exp.name);

        if (obs.tx_payload.size() != exp.len)
            fail($sformatf("%s tx_payload size=%0d expected=%0d", exp.name, obs.tx_payload.size(), exp.len));

        for (int unsigned i = 0; i < exp.len; i++) begin
            if ((i < obs.tx_payload.size()) && (obs.tx_payload[i] !== exp.tx_byte_at(i))) begin
                fail($sformatf("%s tx_payload[%0d]=0x%02h expected=0x%02h",
                               exp.name, i, obs.tx_payload[i], exp.tx_byte_at(i)));
            end

            mem_index = (exp.addr + i) % MEM_BYTES;
            exp_mem[mem_index] = exp_mem[mem_index] & exp.tx_byte_at(i);
        end
    endfunction

    function void check_sector_erase(input spi_flash_transaction exp, input spi_flash_transaction obs);
        int unsigned sector_base;
        int unsigned mem_index;

        expect_error(obs, 1'b0, exp.name);
        sector_base = (exp.addr / SECTOR_SIZE) * SECTOR_SIZE;

        for (int unsigned i = 0; i < SECTOR_SIZE; i++) begin
            mem_index = sector_base + i;
            if (mem_index < MEM_BYTES)
                exp_mem[mem_index] = 8'hFF;
        end
    endfunction

    function void check_read(input spi_flash_transaction exp, input spi_flash_transaction obs);
        int unsigned mem_index;
        byte unsigned exp_byte;

        if (exp.len == 16'd0) begin
            expect_error(obs, 1'b1, exp.name);
            return;
        end

        expect_error(obs, 1'b0, exp.name);
        expect_rx_size(obs, exp.len, exp.name);

        for (int unsigned i = 0; (i < exp.len) && (i < obs.rx_payload.size()); i++) begin
            mem_index = (exp.addr + i) % MEM_BYTES;
            exp_byte  = exp_mem[mem_index];
            if (obs.rx_payload[i] !== exp_byte) begin
                fail($sformatf("%s rx_payload[%0d]=0x%02h expected=0x%02h",
                               exp.name, i, obs.rx_payload[i], exp_byte));
            end
        end
    endfunction

    function void check_one(input spi_flash_transaction exp, input spi_flash_transaction obs);
        check_header(exp, obs);

        case (exp.op)
            OP_READ:         check_read(exp, obs);
            OP_PAGE_PROGRAM: check_page_program(exp, obs);
            OP_SECTOR_ERASE: check_sector_erase(exp, obs);
            OP_READ_STATUS:  check_read_status(exp, obs);
            OP_READ_ID:      check_read_id(exp, obs);
            default:         expect_error(obs, 1'b1, exp.name);
        endcase
    endfunction

    task run();
        spi_flash_transaction exp;
        spi_flash_transaction obs;

        forever begin
            exp2sb.get(exp);
            if (exp == null)
                break;

            mon2sb.get(obs);
            check_one(exp, obs);
        end

        finished = 1'b1;

        if (errors == 0)
            $display("[SB] TEST PASSED");
        else
            $display("[SB] TEST FAILED: %0d error(s)", errors);
    endtask
endclass
