`timescale 1ns/1ps

package spi_flash_tb_pkg;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned MEM_BYTES   = 65536;
    localparam int unsigned SECTOR_SIZE = 4096;

    typedef enum bit [2:0] {
        OP_READ         = 3'd0,
        OP_PAGE_PROGRAM = 3'd1,
        OP_SECTOR_ERASE = 3'd2,
        OP_READ_STATUS  = 3'd3,
        OP_READ_ID      = 3'd4
    } spi_op_e;

    function automatic byte unsigned jedec_id_byte(input int unsigned index);
        case (index)
            0: jedec_id_byte = 8'hEF;
            1: jedec_id_byte = 8'h40;
            2: jedec_id_byte = 8'h18;
            default: jedec_id_byte = 8'h00;
        endcase
    endfunction

    function automatic bit page_program_bad(input bit [23:0] addr, input bit [15:0] len);
        bit [16:0] page_end;
        begin
            page_end = {9'd0, addr[7:0]} + {1'b0, len};
            page_program_bad = (len == 16'd0) || (len > 16'd256) || (page_end > 17'd256);
        end
    endfunction

    `include "spi_flash_transaction.sv"
    `include "spi_flash_generator.sv"
    `include "spi_flash_driver.sv"
    `include "spi_flash_monitor.sv"
    `include "spi_flash_scoreboard.sv"
    `include "spi_flash_coverage.sv"
    `include "spi_flash_env.sv"
    `include "spi_flash_test.sv"
endpackage
