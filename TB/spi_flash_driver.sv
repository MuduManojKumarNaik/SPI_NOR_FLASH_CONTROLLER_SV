class spi_flash_driver;
    virtual spi_flash_if vif;
    mailbox #(spi_flash_transaction) gen2drv;
    int unsigned timeout_cycles;

    function new(
        virtual spi_flash_if vif,
        mailbox #(spi_flash_transaction) gen2drv,
        input int unsigned timeout_cycles = 200000
    );
        this.vif            = vif;
        this.gen2drv        = gen2drv;
        this.timeout_cycles = timeout_cycles;
    endfunction

    task reset_dut();
        vif.rst_n    <= 1'b0;
        vif.start    <= 1'b0;
        vif.op       <= OP_READ;
        vif.addr     <= 24'd0;
        vif.len      <= 16'd0;
        vif.tx_data  <= 8'd0;
        vif.tx_valid <= 1'b0;
        vif.rx_ready <= 1'b0;

        repeat (6) @(posedge vif.clk);
        vif.rst_n <= 1'b1;
        repeat (3) @(posedge vif.clk);
    endtask

    task start_command(input spi_flash_transaction tr);
        @(posedge vif.clk);
        while (vif.cmd_ready !== 1'b1)
            @(posedge vif.clk);

        vif.op    <= tr.op;
        vif.addr  <= tr.addr;
        vif.len   <= tr.len;
        vif.start <= 1'b1;

        @(posedge vif.clk);
        vif.start <= 1'b0;
    endtask

    task wait_done(input spi_flash_transaction tr);
        for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
            @(posedge vif.clk);
            if (vif.done === 1'b1)
                return;
        end

        $fatal(1, "[DRV] Timeout waiting for done on %s", tr.sprint());
    endtask

    task send_program_data(input spi_flash_transaction tr);
        int unsigned count;
        count = tr.len;

        for (int unsigned i = 0; i < count; i++) begin
            @(posedge vif.clk);
            while (vif.tx_ready !== 1'b1)
                @(posedge vif.clk);

            vif.tx_data  <= tr.tx_byte_at(i);
            vif.tx_valid <= 1'b1;

            @(posedge vif.clk);
            vif.tx_valid <= 1'b0;
        end
    endtask

    task accept_rx_data(input spi_flash_transaction tr);
        int unsigned count;
        count = tr.expected_rx_count();

        for (int unsigned i = 0; i < count; i++) begin
            @(posedge vif.clk);
            while (vif.rx_valid !== 1'b1)
                @(posedge vif.clk);

            vif.rx_ready <= 1'b1;
            @(posedge vif.clk);
            vif.rx_ready <= 1'b0;
        end
    endtask

    task drive_one(input spi_flash_transaction tr);
        $display("[DRV] Driving %s", tr.sprint());
        start_command(tr);

        fork
            begin
                if ((tr.op == OP_PAGE_PROGRAM) && !tr.is_page_program_bad())
                    send_program_data(tr);
            end
            begin
                if (tr.expected_rx_count() != 0)
                    accept_rx_data(tr);
            end
            begin
                wait_done(tr);
            end
        join

        vif.tx_valid <= 1'b0;
        vif.rx_ready <= 1'b0;
    endtask

    task run();
        spi_flash_transaction tr;

        forever begin
            gen2drv.get(tr);
            if (tr == null)
                break;
            drive_one(tr);
        end
    endtask
endclass
