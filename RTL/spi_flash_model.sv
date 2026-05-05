`timescale 1ns/1ps
`default_nettype none

// Simple SPI NOR flash behavioral model for the testbench.
// Implements WREN, RDSR, READ ID, READ, PAGE PROGRAM, and SECTOR ERASE.
module spi_flash_model #(
    parameter integer MEM_BYTES   = 65536,
    parameter integer SECTOR_SIZE = 4096,
    parameter [7:0]   ID0         = 8'hEF,
    parameter [7:0]   ID1         = 8'h40,
    parameter [7:0]   ID2         = 8'h18
)(
    input  wire cs_n,
    input  wire sclk,
    input  wire mosi,
    output reg  miso
);

    localparam [7:0] CMD_WREN = 8'h06;
    localparam [7:0] CMD_RDSR = 8'h05;
    localparam [7:0] CMD_READ = 8'h03;
    localparam [7:0] CMD_PP   = 8'h02;
    localparam [7:0] CMD_SE   = 8'h20;
    localparam [7:0] CMD_RDID = 8'h9F;

    localparam [3:0]
        MODE_CMD         = 4'd0,
        MODE_RDSR        = 4'd1,
        MODE_RDID        = 4'd2,
        MODE_READ_ADDR   = 4'd3,
        MODE_READ_DATA   = 4'd4,
        MODE_PP_ADDR     = 4'd5,
        MODE_PP_DATA     = 4'd6,
        MODE_ERASE_ADDR  = 4'd7,
        MODE_ERASE_READY = 4'd8,
        MODE_IGNORE      = 4'd9;

    reg [7:0] memory [0:MEM_BYTES-1];
    reg [7:0] page_buffer [0:255];

    reg [3:0]  mode;
    reg [7:0]  in_shift;
    reg [2:0]  in_bit_count;
    reg [7:0]  out_shift;
    reg [2:0]  out_bit;
    reg        output_active;
    reg        skip_shift;
    reg [23:0] addr_shift;
    integer    addr_count;
    integer    read_ptr;
    integer    page_addr;
    integer    page_count;
    integer    erase_addr;
    integer    id_index;
    reg [7:0]  status_reg;
    integer    busy_reads;

    integer init_i;

    initial begin
        for (init_i = 0; init_i < MEM_BYTES; init_i = init_i + 1)
            memory[init_i] = 8'hFF;

        miso          = 1'b0;
        mode          = MODE_CMD;
        in_shift      = 8'd0;
        in_bit_count  = 3'd0;
        out_shift     = 8'd0;
        out_bit       = 3'd0;
        output_active = 1'b0;
        skip_shift    = 1'b0;
        addr_shift    = 24'd0;
        addr_count    = 0;
        read_ptr      = 0;
        page_addr     = 0;
        page_count    = 0;
        erase_addr    = 0;
        id_index      = 0;
        status_reg    = 8'd0;
        busy_reads    = 0;
    end

    function [7:0] id_byte;
        input integer index;
        begin
            case (index)
                0: id_byte = ID0;
                1: id_byte = ID1;
                2: id_byte = ID2;
                default: id_byte = 8'h00;
            endcase
        end
    endfunction

    task load_output_byte;
        input [7:0] data_in;
        begin
            out_shift     = data_in;
            miso          = data_in[7];
            out_bit       = 3'd6;
            output_active = 1'b1;
            skip_shift    = 1'b1;
        end
    endtask

    task get_status_byte;
        output [7:0] data_out;
        begin
            if (busy_reads > 0) begin
                status_reg[0] = 1'b1;
                busy_reads    = busy_reads - 1;
            end else begin
                status_reg[0] = 1'b0;
            end

            data_out = status_reg;
        end
    endtask

    task set_busy;
        input integer poll_count;
        begin
            busy_reads    = poll_count;
            status_reg[0] = 1'b1;
        end
    endtask

    task handle_byte;
        input [7:0] data_in;
        reg [7:0] st;
        begin
            case (mode)
                MODE_CMD: begin
                    addr_shift = 24'd0;
                    addr_count = 0;
                    page_count = 0;

                    case (data_in)
                        CMD_WREN: begin
                            status_reg[1] = 1'b1;
                            mode = MODE_IGNORE;
                        end

                        CMD_RDSR: begin
                            get_status_byte(st);
                            load_output_byte(st);
                            mode = MODE_RDSR;
                        end

                        CMD_RDID: begin
                            id_index = 0;
                            load_output_byte(id_byte(0));
                            mode = MODE_RDID;
                        end

                        CMD_READ: begin
                            mode = MODE_READ_ADDR;
                        end

                        CMD_PP: begin
                            mode = MODE_PP_ADDR;
                        end

                        CMD_SE: begin
                            mode = MODE_ERASE_ADDR;
                        end

                        default: begin
                            mode = MODE_IGNORE;
                        end
                    endcase
                end

                MODE_RDSR: begin
                    get_status_byte(st);
                    load_output_byte(st);
                end

                MODE_RDID: begin
                    id_index = id_index + 1;
                    load_output_byte(id_byte(id_index));
                end

                MODE_READ_ADDR: begin
                    addr_shift = {addr_shift[15:0], data_in};
                    addr_count = addr_count + 1;

                    if (addr_count == 3) begin
                        read_ptr = addr_shift % MEM_BYTES;
                        load_output_byte(memory[read_ptr]);
                        mode = MODE_READ_DATA;
                    end
                end

                MODE_READ_DATA: begin
                    read_ptr = (read_ptr + 1) % MEM_BYTES;
                    load_output_byte(memory[read_ptr]);
                end

                MODE_PP_ADDR: begin
                    addr_shift = {addr_shift[15:0], data_in};
                    addr_count = addr_count + 1;

                    if (addr_count == 3) begin
                        page_addr  = addr_shift % MEM_BYTES;
                        page_count = 0;
                        mode       = MODE_PP_DATA;
                    end
                end

                MODE_PP_DATA: begin
                    if (page_count < 256) begin
                        page_buffer[page_count] = data_in;
                        page_count = page_count + 1;
                    end
                end

                MODE_ERASE_ADDR: begin
                    addr_shift = {addr_shift[15:0], data_in};
                    addr_count = addr_count + 1;

                    if (addr_count == 3) begin
                        erase_addr = addr_shift % MEM_BYTES;
                        mode = MODE_ERASE_READY;
                    end
                end

                default: begin
                    mode = MODE_IGNORE;
                end
            endcase
        end
    endtask

    task finish_command;
        integer j;
        integer mem_index;
        integer sector_base;
        begin
            if ((mode == MODE_PP_DATA) && (page_count > 0)) begin
                if (status_reg[1]) begin
                    for (j = 0; j < page_count; j = j + 1) begin
                        mem_index = (page_addr + j) % MEM_BYTES;
                        memory[mem_index] = memory[mem_index] & page_buffer[j];
                    end

                    set_busy(3);
                end

                status_reg[1] = 1'b0;
            end else if (mode == MODE_ERASE_READY) begin
                if (status_reg[1]) begin
                    sector_base = (erase_addr / SECTOR_SIZE) * SECTOR_SIZE;

                    for (j = 0; j < SECTOR_SIZE; j = j + 1) begin
                        mem_index = sector_base + j;
                        if (mem_index < MEM_BYTES)
                            memory[mem_index] = 8'hFF;
                    end

                    set_busy(5);
                end

                status_reg[1] = 1'b0;
            end
        end
    endtask

    always @(negedge cs_n) begin
        mode          = MODE_CMD;
        in_shift      = 8'd0;
        in_bit_count  = 3'd0;
        output_active = 1'b0;
        skip_shift    = 1'b0;
        miso          = 1'b0;
    end

    always @(posedge cs_n) begin
        finish_command;
        output_active = 1'b0;
        skip_shift    = 1'b0;
        mode          = MODE_CMD;
        miso          = 1'b0;
    end

    always @(posedge sclk) begin
        if (!cs_n) begin
            in_shift = {in_shift[6:0], mosi};

            if (in_bit_count == 3'd7) begin
                handle_byte(in_shift);
                in_bit_count = 3'd0;
            end else begin
                in_bit_count = in_bit_count + 3'd1;
            end
        end
    end

    always @(negedge sclk) begin
        if (!cs_n && output_active) begin
            if (skip_shift) begin
                skip_shift = 1'b0;
            end else begin
                miso = out_shift[out_bit];

                if (out_bit != 3'd0)
                    out_bit = out_bit - 3'd1;
            end
        end
    end

endmodule

`default_nettype wire
