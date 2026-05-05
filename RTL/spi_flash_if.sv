`timescale 1ns/1ps
`default_nettype none

interface spi_flash_if(input wire clk);
    timeunit 1ns;
    timeprecision 1ps;

    logic        rst_n;
    logic        start;
    logic [2:0]  op;
    logic [23:0] addr;
    logic [15:0] len;

    logic        cmd_ready;
    logic        busy;
    logic        done;
    logic        error;

    logic [7:0]  tx_data;
    logic        tx_valid;
    logic        tx_ready;

    logic [7:0]  rx_data;
    logic        rx_valid;
    logic        rx_ready;

    logic [7:0]  status;

    logic        flash_cs_n;
    logic        flash_sclk;
    logic        flash_mosi;
    logic        flash_miso;

    modport dut (
        input  clk,
        input  rst_n,
        input  start,
        input  op,
        input  addr,
        input  len,
        output cmd_ready,
        output busy,
        output done,
        output error,
        input  tx_data,
        input  tx_valid,
        output tx_ready,
        output rx_data,
        output rx_valid,
        input  rx_ready,
        output status,
        output flash_cs_n,
        output flash_sclk,
        output flash_mosi,
        input  flash_miso
    );

    modport drv (
        input  clk,
        input  cmd_ready,
        input  busy,
        input  done,
        input  error,
        input  tx_ready,
        input  rx_data,
        input  rx_valid,
        input  status,
        output rst_n,
        output start,
        output op,
        output addr,
        output len,
        output tx_data,
        output tx_valid,
        output rx_ready
    );

    modport mon (
        input clk,
        input rst_n,
        input start,
        input op,
        input addr,
        input len,
        input cmd_ready,
        input busy,
        input done,
        input error,
        input tx_data,
        input tx_valid,
        input tx_ready,
        input rx_data,
        input rx_valid,
        input rx_ready,
        input status,
        input flash_cs_n,
        input flash_sclk,
        input flash_mosi,
        input flash_miso
    );
endinterface

`default_nettype wire
