`timescale 1ns/1ps
`default_nettype none

module spi_flash_assertions #(
    parameter int unsigned MAX_COMMAND_LATENCY = 200000
)(
    spi_flash_if vif
);
    timeunit 1ns;
    timeprecision 1ps;

    localparam [2:0] OP_READ         = 3'd0;
    localparam [2:0] OP_PAGE_PROGRAM = 3'd1;

    function automatic bit page_program_bad(input bit [23:0] addr, input bit [15:0] len);
        bit [16:0] page_end;
        begin
            page_end = {9'd0, addr[7:0]} + {1'b0, len};
            page_program_bad = (len == 16'd0) || (len > 16'd256) || (page_end > 17'd256);
        end
    endfunction

    logic       prev_done;
    logic       prev_rx_valid;
    logic       prev_rx_ready;
    logic [7:0] prev_rx_data;
    logic       prev_tx_valid;
    logic       prev_tx_ready;
    logic [7:0] prev_tx_data;

    logic       command_active;
    int unsigned command_age;

    logic expect_zero_read_error;
    logic expect_bad_pp_error;

    always @(posedge vif.flash_sclk) begin
        if (vif.rst_n && vif.flash_cs_n)
            $error("flash_sclk toggled while chip select was inactive");
    end

    always @(posedge vif.clk or negedge vif.rst_n) begin
        if (!vif.rst_n) begin
            prev_done              <= 1'b0;
            prev_rx_valid          <= 1'b0;
            prev_rx_ready          <= 1'b0;
            prev_rx_data           <= 8'd0;
            prev_tx_valid          <= 1'b0;
            prev_tx_ready          <= 1'b0;
            prev_tx_data           <= 8'd0;
            command_active         <= 1'b0;
            command_age            <= 0;
            expect_zero_read_error <= 1'b0;
            expect_bad_pp_error    <= 1'b0;
        end else begin
            if (vif.start && !vif.cmd_ready)
                $error("start asserted while cmd_ready is low");

            if (prev_done && vif.done)
                $error("done must be a single-cycle pulse");

            if (vif.done && vif.busy)
                $error("busy must be low when done is asserted");

            if (vif.flash_cs_n && vif.flash_sclk)
                $error("flash_sclk must be low while chip select is high in SPI mode 0");

            if (prev_rx_valid && !prev_rx_ready) begin
                if (!vif.rx_valid || (vif.rx_data !== prev_rx_data))
                    $error("rx_valid/rx_data changed before rx_ready");
            end

            if (prev_tx_valid && !prev_tx_ready) begin
                if (!vif.tx_valid || (vif.tx_data !== prev_tx_data))
                    $error("tx_valid/tx_data changed before tx_ready");
            end

            if (expect_zero_read_error) begin
                if (!(vif.done && vif.error && !vif.busy))
                    $error("zero-length READ did not report an immediate error");
            end

            if (expect_bad_pp_error) begin
                if (!(vif.done && vif.error && !vif.busy))
                    $error("invalid PAGE PROGRAM did not report an immediate error");
            end

            if (vif.start && vif.cmd_ready) begin
                command_active <= 1'b1;
                command_age    <= 0;
            end else if (command_active && vif.done) begin
                command_active <= 1'b0;
                command_age    <= 0;
            end else if (command_active) begin
                if (command_age >= MAX_COMMAND_LATENCY) begin
                    $error("command did not finish within MAX_COMMAND_LATENCY");
                    command_active <= 1'b0;
                end else begin
                    command_age <= command_age + 1;
                end
            end

            expect_zero_read_error <= vif.start && vif.cmd_ready &&
                                      (vif.op == OP_READ) &&
                                      (vif.len == 16'd0);

            expect_bad_pp_error <= vif.start && vif.cmd_ready &&
                                   (vif.op == OP_PAGE_PROGRAM) &&
                                   page_program_bad(vif.addr, vif.len);

            prev_done     <= vif.done;
            prev_rx_valid <= vif.rx_valid;
            prev_rx_ready <= vif.rx_ready;
            prev_rx_data  <= vif.rx_data;
            prev_tx_valid <= vif.tx_valid;
            prev_tx_ready <= vif.tx_ready;
            prev_tx_data  <= vif.tx_data;
        end
    end
endmodule

`default_nettype wire
