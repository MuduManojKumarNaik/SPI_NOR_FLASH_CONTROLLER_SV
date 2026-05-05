class spi_flash_env;
    virtual spi_flash_if vif;

    mailbox #(spi_flash_transaction) gen2drv;
    mailbox #(spi_flash_transaction) exp2sb;
    mailbox #(spi_flash_transaction) mon2sb;
    mailbox #(spi_flash_transaction) mon2cov;

    spi_flash_generator  gen;
    spi_flash_driver     drv;
    spi_flash_monitor    mon;
    spi_flash_scoreboard sb;
    spi_flash_coverage   cov;

    function new(virtual spi_flash_if vif);
        this.vif = vif;
    endfunction

    function void build();
        gen2drv = new();
        exp2sb  = new();
        mon2sb  = new();
        mon2cov = new();

        gen = new(gen2drv, exp2sb);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2sb, mon2cov);
        sb  = new(exp2sb, mon2sb);
        cov = new(mon2cov);
    endfunction

    task run();
        drv.reset_dut();

        fork
            gen.run();
            drv.run();
            mon.run();
            sb.run();
            cov.run();
        join_none

        wait (sb.finished == 1'b1);
        repeat (2) @(posedge vif.clk);
        cov.report(sb.errors);
        repeat (5) @(posedge vif.clk);
    endtask
endclass
