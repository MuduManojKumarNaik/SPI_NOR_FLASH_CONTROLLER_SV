`timescale 1ns/1ps
`default_nettype none

// SPI NOR flash controller, SPI mode 0.
//
// Host command interface:
//   op = 0: READ          command 0x03, returns len bytes on rx_data/rx_valid
//   op = 1: PAGE PROGRAM  command 0x02, consumes len bytes from tx_data/tx_valid
//   op = 2: SECTOR ERASE  command 0x20, erases 4 KB sector containing addr
//   op = 3: READ STATUS   command 0x05, returns one byte
//   op = 4: READ ID       command 0x9F, returns len bytes, or 3 bytes when len is 0
//
// Notes:
//   - 24-bit addressing.
//   - PAGE PROGRAM length must be 1..256 bytes and must not cross a page.
//   - PAGE PROGRAM and SECTOR ERASE automatically send WRITE ENABLE first.
//   - PAGE PROGRAM and SECTOR ERASE automatically poll status[0] WIP until clear.
//   - SCLK frequency is clk / (2 * CLK_DIV).

module spi_flash_controller #(
    parameter integer CLK_DIV  = 4,
    parameter integer POLL_MAX = 1000000
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire [2:0]  op,
    input  wire [23:0] addr,
    input  wire [15:0] len,

    output wire        cmd_ready,
    output reg         busy,
    output reg         done,
    output reg         error,

    input  wire [7:0]  tx_data,
    input  wire        tx_valid,
    output wire        tx_ready,

    output reg  [7:0]  rx_data,
    output reg         rx_valid,
    input  wire        rx_ready,

    output reg  [7:0]  status,

    output reg         flash_cs_n,
    output reg         flash_sclk,
    output reg         flash_mosi,
    input  wire        flash_miso
);

    localparam [2:0] OP_READ         = 3'd0;
    localparam [2:0] OP_PAGE_PROGRAM = 3'd1;
    localparam [2:0] OP_SECTOR_ERASE = 3'd2;
    localparam [2:0] OP_READ_STATUS  = 3'd3;
    localparam [2:0] OP_READ_ID      = 3'd4;

    localparam [7:0] CMD_WRITE_ENABLE = 8'h06;
    localparam [7:0] CMD_READ         = 8'h03;
    localparam [7:0] CMD_PAGE_PROGRAM = 8'h02;
    localparam [7:0] CMD_SECTOR_ERASE = 8'h20;
    localparam [7:0] CMD_READ_STATUS  = 8'h05;
    localparam [7:0] CMD_READ_ID      = 8'h9F;

    localparam [1:0] DIR_NONE = 2'd0;
    localparam [1:0] DIR_RX   = 2'd1;
    localparam [1:0] DIR_TX   = 2'd2;

    localparam [4:0]
        ST_IDLE            = 5'd0,
        ST_WREN_CS_LOW     = 5'd1,
        ST_WREN_WAIT       = 5'd2,
        ST_WREN_CS_HIGH    = 5'd3,
        ST_CMD_CS_LOW      = 5'd4,
        ST_CMD_WAIT_OPCODE = 5'd5,
        ST_ADDR2_START     = 5'd6,
        ST_ADDR2_WAIT      = 5'd7,
        ST_ADDR1_START     = 5'd8,
        ST_ADDR1_WAIT      = 5'd9,
        ST_ADDR0_START     = 5'd10,
        ST_ADDR0_WAIT      = 5'd11,
        ST_AFTER_HEADER    = 5'd12,
        ST_RX_START        = 5'd13,
        ST_RX_WAIT         = 5'd14,
        ST_RX_HOLD         = 5'd15,
        ST_TX_GET          = 5'd16,
        ST_TX_WAIT         = 5'd17,
        ST_CS_HIGH         = 5'd18,
        ST_POLL_GAP        = 5'd19,
        ST_POLL_CS_LOW     = 5'd20,
        ST_POLL_CMD_WAIT   = 5'd21,
        ST_POLL_RX_WAIT    = 5'd22,
        ST_POLL_CHECK      = 5'd23;

    reg [4:0]  state;
    reg [2:0]  op_r;
    reg [23:0] addr_r;
    reg [15:0] byte_count;
    reg [7:0]  opcode_r;
    reg        use_addr;
    reg [1:0]  data_dir;
    reg        poll_after;
    reg [31:0] poll_count;

    assign cmd_ready = (state == ST_IDLE);
    assign tx_ready  = (state == ST_TX_GET);

    wire [16:0] page_end;
    wire        page_program_bad;

    assign page_end = {9'd0, addr[7:0]} + {1'b0, len};
    assign page_program_bad =
        (len == 16'd0) ||
        (len > 16'd256) ||
        (page_end > 17'd256);

    // ---------------------------------------------------------------------
    // Single-byte SPI master engine, mode 0.
    // ---------------------------------------------------------------------

    reg        spi_start;
    reg        spi_busy;
    reg        spi_done;
    reg [7:0]  spi_tx_byte;
    reg [7:0]  spi_rx_byte;

    reg [7:0]  tx_shift;
    reg [7:0]  rx_shift;
    reg [2:0]  bit_cnt;
    reg [31:0] div_cnt;
    reg        spi_phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_busy    <= 1'b0;
            spi_done    <= 1'b0;
            spi_rx_byte <= 8'd0;
            tx_shift    <= 8'd0;
            rx_shift    <= 8'd0;
            bit_cnt     <= 3'd0;
            div_cnt     <= 32'd0;
            spi_phase   <= 1'b0;
            flash_sclk  <= 1'b0;
            flash_mosi  <= 1'b0;
        end else begin
            spi_done <= 1'b0;

            if (spi_start && !spi_busy) begin
                spi_busy    <= 1'b1;
                tx_shift    <= spi_tx_byte;
                rx_shift    <= 8'd0;
                bit_cnt     <= 3'd7;
                div_cnt     <= 32'd0;
                spi_phase   <= 1'b0;
                flash_sclk  <= 1'b0;
                flash_mosi  <= spi_tx_byte[7];
            end else if (spi_busy) begin
                if (div_cnt == CLK_DIV - 1) begin
                    div_cnt <= 32'd0;

                    if (spi_phase == 1'b0) begin
                        flash_sclk        <= 1'b1;
                        rx_shift[bit_cnt] <= flash_miso;
                        if (bit_cnt == 3'd0)
                            spi_rx_byte <= {rx_shift[7:1], flash_miso};
                        spi_phase         <= 1'b1;
                    end else begin
                        flash_sclk <= 1'b0;
                        spi_phase  <= 1'b0;

                        if (bit_cnt == 3'd0) begin
                            spi_busy    <= 1'b0;
                            spi_done    <= 1'b1;
                            flash_mosi  <= 1'b0;
                        end else begin
                            bit_cnt    <= bit_cnt - 3'd1;
                            flash_mosi <= tx_shift[bit_cnt - 3'd1];
                        end
                    end
                end else begin
                    div_cnt <= div_cnt + 32'd1;
                end
            end else begin
                flash_sclk <= 1'b0;
                flash_mosi <= 1'b0;
                div_cnt    <= 32'd0;
                spi_phase  <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------------------
    // Flash command controller.
    // ---------------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            op_r        <= 3'd0;
            addr_r      <= 24'd0;
            byte_count  <= 16'd0;
            opcode_r    <= 8'd0;
            use_addr    <= 1'b0;
            data_dir    <= DIR_NONE;
            poll_after  <= 1'b0;
            poll_count  <= 32'd0;

            spi_start   <= 1'b0;
            spi_tx_byte <= 8'd0;

            busy        <= 1'b0;
            done        <= 1'b0;
            error       <= 1'b0;
            rx_data     <= 8'd0;
            rx_valid    <= 1'b0;
            status      <= 8'd0;

            flash_cs_n  <= 1'b1;
        end else begin
            spi_start <= 1'b0;
            done      <= 1'b0;

            case (state)
                ST_IDLE: begin
                    flash_cs_n <= 1'b1;
                    busy       <= 1'b0;
                    rx_valid   <= 1'b0;

                    if (start) begin
                        busy       <= 1'b1;
                        error      <= 1'b0;
                        op_r       <= op;
                        addr_r     <= addr;
                        poll_count <= 32'd0;

                        case (op)
                            OP_READ: begin
                                if (len == 16'd0) begin
                                    busy  <= 1'b0;
                                    done  <= 1'b1;
                                    error <= 1'b1;
                                    state <= ST_IDLE;
                                end else begin
                                    opcode_r   <= CMD_READ;
                                    byte_count <= len;
                                    use_addr   <= 1'b1;
                                    data_dir   <= DIR_RX;
                                    poll_after <= 1'b0;
                                    state      <= ST_CMD_CS_LOW;
                                end
                            end

                            OP_PAGE_PROGRAM: begin
                                if (page_program_bad) begin
                                    busy  <= 1'b0;
                                    done  <= 1'b1;
                                    error <= 1'b1;
                                    state <= ST_IDLE;
                                end else begin
                                    opcode_r   <= CMD_PAGE_PROGRAM;
                                    byte_count <= len;
                                    use_addr   <= 1'b1;
                                    data_dir   <= DIR_TX;
                                    poll_after <= 1'b1;
                                    state      <= ST_WREN_CS_LOW;
                                end
                            end

                            OP_SECTOR_ERASE: begin
                                opcode_r   <= CMD_SECTOR_ERASE;
                                byte_count <= 16'd0;
                                use_addr   <= 1'b1;
                                data_dir   <= DIR_NONE;
                                poll_after <= 1'b1;
                                state      <= ST_WREN_CS_LOW;
                            end

                            OP_READ_STATUS: begin
                                opcode_r   <= CMD_READ_STATUS;
                                byte_count <= 16'd1;
                                use_addr   <= 1'b0;
                                data_dir   <= DIR_RX;
                                poll_after <= 1'b0;
                                state      <= ST_CMD_CS_LOW;
                            end

                            OP_READ_ID: begin
                                opcode_r   <= CMD_READ_ID;
                                byte_count <= (len == 16'd0) ? 16'd3 : len;
                                use_addr   <= 1'b0;
                                data_dir   <= DIR_RX;
                                poll_after <= 1'b0;
                                state      <= ST_CMD_CS_LOW;
                            end

                            default: begin
                                busy  <= 1'b0;
                                done  <= 1'b1;
                                error <= 1'b1;
                                state <= ST_IDLE;
                            end
                        endcase
                    end
                end

                ST_WREN_CS_LOW: begin
                    flash_cs_n  <= 1'b0;
                    spi_tx_byte <= CMD_WRITE_ENABLE;
                    spi_start   <= 1'b1;
                    state       <= ST_WREN_WAIT;
                end

                ST_WREN_WAIT: begin
                    if (spi_done) begin
                        flash_cs_n <= 1'b1;
                        state      <= ST_WREN_CS_HIGH;
                    end
                end

                ST_WREN_CS_HIGH: begin
                    state <= ST_CMD_CS_LOW;
                end

                ST_CMD_CS_LOW: begin
                    flash_cs_n  <= 1'b0;
                    spi_tx_byte <= opcode_r;
                    spi_start   <= 1'b1;
                    state       <= ST_CMD_WAIT_OPCODE;
                end

                ST_CMD_WAIT_OPCODE: begin
                    if (spi_done) begin
                        if (use_addr)
                            state <= ST_ADDR2_START;
                        else
                            state <= ST_AFTER_HEADER;
                    end
                end

                ST_ADDR2_START: begin
                    spi_tx_byte <= addr_r[23:16];
                    spi_start   <= 1'b1;
                    state       <= ST_ADDR2_WAIT;
                end

                ST_ADDR2_WAIT: begin
                    if (spi_done)
                        state <= ST_ADDR1_START;
                end

                ST_ADDR1_START: begin
                    spi_tx_byte <= addr_r[15:8];
                    spi_start   <= 1'b1;
                    state       <= ST_ADDR1_WAIT;
                end

                ST_ADDR1_WAIT: begin
                    if (spi_done)
                        state <= ST_ADDR0_START;
                end

                ST_ADDR0_START: begin
                    spi_tx_byte <= addr_r[7:0];
                    spi_start   <= 1'b1;
                    state       <= ST_ADDR0_WAIT;
                end

                ST_ADDR0_WAIT: begin
                    if (spi_done)
                        state <= ST_AFTER_HEADER;
                end

                ST_AFTER_HEADER: begin
                    if (data_dir == DIR_RX)
                        state <= ST_RX_START;
                    else if (data_dir == DIR_TX)
                        state <= ST_TX_GET;
                    else
                        state <= ST_CS_HIGH;
                end

                ST_RX_START: begin
                    if (byte_count == 16'd0) begin
                        state <= ST_CS_HIGH;
                    end else begin
                        spi_tx_byte <= 8'h00;
                        spi_start   <= 1'b1;
                        state       <= ST_RX_WAIT;
                    end
                end

                ST_RX_WAIT: begin
                    if (spi_done) begin
                        rx_data    <= spi_rx_byte;
                        rx_valid   <= 1'b1;
                        byte_count <= byte_count - 16'd1;

                        if (op_r == OP_READ_STATUS)
                            status <= spi_rx_byte;

                        state <= ST_RX_HOLD;
                    end
                end

                ST_RX_HOLD: begin
                    if (rx_ready) begin
                        rx_valid <= 1'b0;
                        state    <= ST_RX_START;
                    end
                end

                ST_TX_GET: begin
                    if (byte_count == 16'd0) begin
                        state <= ST_CS_HIGH;
                    end else if (tx_valid) begin
                        spi_tx_byte <= tx_data;
                        spi_start   <= 1'b1;
                        byte_count  <= byte_count - 16'd1;
                        state       <= ST_TX_WAIT;
                    end
                end

                ST_TX_WAIT: begin
                    if (spi_done)
                        state <= ST_TX_GET;
                end

                ST_CS_HIGH: begin
                    flash_cs_n <= 1'b1;

                    if (poll_after) begin
                        state <= ST_POLL_GAP;
                    end else begin
                        busy  <= 1'b0;
                        done  <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                ST_POLL_GAP: begin
                    state <= ST_POLL_CS_LOW;
                end

                ST_POLL_CS_LOW: begin
                    flash_cs_n  <= 1'b0;
                    spi_tx_byte <= CMD_READ_STATUS;
                    spi_start   <= 1'b1;
                    state       <= ST_POLL_CMD_WAIT;
                end

                ST_POLL_CMD_WAIT: begin
                    if (spi_done) begin
                        spi_tx_byte <= 8'h00;
                        spi_start   <= 1'b1;
                        state       <= ST_POLL_RX_WAIT;
                    end
                end

                ST_POLL_RX_WAIT: begin
                    if (spi_done) begin
                        status     <= spi_rx_byte;
                        flash_cs_n <= 1'b1;
                        state      <= ST_POLL_CHECK;
                    end
                end

                ST_POLL_CHECK: begin
                    if (status[0] == 1'b0) begin
                        busy       <= 1'b0;
                        done       <= 1'b1;
                        poll_after <= 1'b0;
                        state      <= ST_IDLE;
                    end else if (poll_count >= POLL_MAX) begin
                        busy       <= 1'b0;
                        done       <= 1'b1;
                        error      <= 1'b1;
                        poll_after <= 1'b0;
                        state      <= ST_IDLE;
                    end else begin
                        poll_count <= poll_count + 32'd1;
                        state      <= ST_POLL_GAP;
                    end
                end

                default: begin
                    flash_cs_n <= 1'b1;
                    busy       <= 1'b0;
                    done       <= 1'b1;
                    error      <= 1'b1;
                    state      <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
