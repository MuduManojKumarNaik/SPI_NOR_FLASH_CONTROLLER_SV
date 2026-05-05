class spi_flash_test;
    virtual spi_flash_if vif;
    spi_flash_env env;

    function new(virtual spi_flash_if vif);
        this.vif = vif;
        env = new(vif);
    endfunction

    task run();
        env.build();
        env.run();
    endtask
endclass
