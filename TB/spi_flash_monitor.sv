class spi_flash_monitor;
    virtual spi_flash_if vif;
    mailbox #(spi_flash_transaction) mon2sb;
    mailbox #(spi_flash_transaction) mon2cov;

    function new(
        virtual spi_flash_if vif,
        mailbox #(spi_flash_transaction) mon2sb,
        mailbox #(spi_flash_transaction) mon2cov
    );
        this.vif     = vif;
        this.mon2sb  = mon2sb;
        this.mon2cov = mon2cov;
    endfunction

    task run();
        spi_flash_transaction tr;
        tr = null;

        forever begin
            @(posedge vif.clk);

            if (!vif.rst_n) begin
                tr = null;
            end else begin
                if (vif.start && vif.cmd_ready) begin
                    tr = new(spi_op_e'(vif.op), vif.addr, vif.len, "observed");
                    $display("[MON] Accepted %s", tr.sprint());
                end

                if (tr != null) begin
                    if (vif.tx_valid && vif.tx_ready)
                        tr.tx_payload.push_back(vif.tx_data);

                    if (vif.rx_valid && vif.rx_ready)
                        tr.rx_payload.push_back(vif.rx_data);

                    if (vif.done) begin
                        tr.error          = vif.error;
                        tr.status_at_done = vif.status;
                        $display("[MON] Completed %s error=%0b rx=%0d tx=%0d",
                                 tr.sprint(), tr.error, tr.rx_payload.size(), tr.tx_payload.size());
                        mon2sb.put(tr.clone());
                        mon2cov.put(tr.clone());
                        tr = null;
                    end
                end
            end
        end
    endtask
endclass
