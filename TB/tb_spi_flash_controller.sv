`timescale 1ns/1ps
`default_nettype none

module tb_spi_flash_controller;
    import spi_flash_tb_pkg::*;

    bit clk;
    spi_flash_if tb_if(clk);
    spi_flash_test test;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    spi_flash_controller #(
        .CLK_DIV(2),
        .POLL_MAX(100)
    ) dut (
        .clk(tb_if.clk),
        .rst_n(tb_if.rst_n),
        .start(tb_if.start),
        .op(tb_if.op),
        .addr(tb_if.addr),
        .len(tb_if.len),
        .cmd_ready(tb_if.cmd_ready),
        .busy(tb_if.busy),
        .done(tb_if.done),
        .error(tb_if.error),
        .tx_data(tb_if.tx_data),
        .tx_valid(tb_if.tx_valid),
        .tx_ready(tb_if.tx_ready),
        .rx_data(tb_if.rx_data),
        .rx_valid(tb_if.rx_valid),
        .rx_ready(tb_if.rx_ready),
        .status(tb_if.status),
        .flash_cs_n(tb_if.flash_cs_n),
        .flash_sclk(tb_if.flash_sclk),
        .flash_mosi(tb_if.flash_mosi),
        .flash_miso(tb_if.flash_miso)
    );

    spi_flash_model #(
        .MEM_BYTES(MEM_BYTES),
        .SECTOR_SIZE(SECTOR_SIZE),
        .ID0(8'hEF),
        .ID1(8'h40),
        .ID2(8'h18)
    ) flash (
        .cs_n(tb_if.flash_cs_n),
        .sclk(tb_if.flash_sclk),
        .mosi(tb_if.flash_mosi),
        .miso(tb_if.flash_miso)
    );

    spi_flash_assertions #(
        .MAX_COMMAND_LATENCY(200000)
    ) assertions (
        .vif(tb_if)
    );

    initial begin
        $dumpfile("spi_flash_controller_tb.vcd");
        $dumpvars(0, tb_spi_flash_controller);

        test = new(tb_if);
        test.run();

        #100;
        $finish;
    end
endmodule

`default_nettype wire
