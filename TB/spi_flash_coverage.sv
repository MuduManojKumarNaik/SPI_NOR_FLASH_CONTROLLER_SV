class spi_flash_coverage;
    mailbox #(spi_flash_transaction) mon2cov;

    spi_op_e     cov_op;
    bit [23:0]   cov_addr;
    bit [15:0]   cov_len;
    bit          cov_error;
    bit          cov_page_bad;
    int unsigned cov_rx_count;
    int unsigned cov_tx_count;

    int unsigned total_samples;
    int unsigned op_hits[5];
    int unsigned len_hits[6];
    int unsigned addr_hits[4];
    int unsigned error_hits[2];
    int unsigned page_bad_hits[2];
    int unsigned rx_count_hits[4];
    int unsigned tx_count_hits[3];
    int unsigned op_x_error_hits[10];
    int unsigned op_x_len_hits[30];

    covergroup cg_command;
        option.per_instance = 1;

        op_cp: coverpoint cov_op {
            bins read         = {OP_READ};
            bins page_program = {OP_PAGE_PROGRAM};
            bins sector_erase = {OP_SECTOR_ERASE};
            bins read_status  = {OP_READ_STATUS};
            bins read_id      = {OP_READ_ID};
        }

        len_cp: coverpoint cov_len {
            bins zero      = {16'd0};
            bins one       = {16'd1};
            bins small_len = {[16'd2:16'd16]};
            bins med_len   = {[16'd17:16'd255]};
            bins full_page = {16'd256};
            bins too_large = {[16'd257:16'hFFFF]};
        }

        addr_lsb_cp: coverpoint cov_addr[7:0] {
            bins page_start = {8'h00};
            bins low        = {[8'h01:8'h3F]};
            bins middle     = {[8'h40:8'hBF]};
            bins near_end   = {[8'hC0:8'hFF]};
        }

        error_cp: coverpoint cov_error {
            bins no_error = {1'b0};
            bins error_seen = {1'b1};
        }

        page_bad_cp: coverpoint cov_page_bad {
            bins legal_page_program   = {1'b0};
            bins illegal_page_program = {1'b1};
        }

        rx_count_cp: coverpoint cov_rx_count {
            bins none = {0};
            bins one  = {1};
            bins few  = {[2:16]};
            bins many = {[17:256]};
        }

        tx_count_cp: coverpoint cov_tx_count {
            bins none = {0};
            bins few  = {[1:16]};
            bins many = {[17:256]};
        }

        op_x_error: cross op_cp, error_cp;
        op_x_len:   cross op_cp, len_cp;
    endgroup

    function new(mailbox #(spi_flash_transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg_command = new();
        total_samples = 0;
    endfunction

    function int unsigned op_index(input spi_op_e op);
        case (op)
            OP_READ:         return 0;
            OP_PAGE_PROGRAM: return 1;
            OP_SECTOR_ERASE: return 2;
            OP_READ_STATUS:  return 3;
            OP_READ_ID:      return 4;
            default:         return 0;
        endcase
    endfunction

    function string op_bin_name(input int unsigned index);
        case (index)
            0: return "read";
            1: return "page_program";
            2: return "sector_erase";
            3: return "read_status";
            4: return "read_id";
            default: return "unknown";
        endcase
    endfunction

    function int unsigned len_index(input bit [15:0] len);
        if (len == 16'd0)
            return 0;
        if (len == 16'd1)
            return 1;
        if ((len >= 16'd2) && (len <= 16'd16))
            return 2;
        if ((len >= 16'd17) && (len <= 16'd255))
            return 3;
        if (len == 16'd256)
            return 4;
        return 5;
    endfunction

    function string len_bin_name(input int unsigned index);
        case (index)
            0: return "zero";
            1: return "one";
            2: return "small_len";
            3: return "med_len";
            4: return "full_page";
            5: return "too_large";
            default: return "unknown";
        endcase
    endfunction

    function int unsigned addr_index(input bit [7:0] addr_lsb);
        if (addr_lsb == 8'h00)
            return 0;
        if ((addr_lsb >= 8'h01) && (addr_lsb <= 8'h3F))
            return 1;
        if ((addr_lsb >= 8'h40) && (addr_lsb <= 8'hBF))
            return 2;
        return 3;
    endfunction

    function string addr_bin_name(input int unsigned index);
        case (index)
            0: return "page_start";
            1: return "low";
            2: return "middle";
            3: return "near_end";
            default: return "unknown";
        endcase
    endfunction

    function int unsigned rx_count_index(input int unsigned count);
        if (count == 0)
            return 0;
        if (count == 1)
            return 1;
        if ((count >= 2) && (count <= 16))
            return 2;
        return 3;
    endfunction

    function string rx_count_bin_name(input int unsigned index);
        case (index)
            0: return "none";
            1: return "one";
            2: return "few";
            3: return "many";
            default: return "unknown";
        endcase
    endfunction

    function int unsigned tx_count_index(input int unsigned count);
        if (count == 0)
            return 0;
        if ((count >= 1) && (count <= 16))
            return 1;
        return 2;
    endfunction

    function string tx_count_bin_name(input int unsigned index);
        case (index)
            0: return "none";
            1: return "few";
            2: return "many";
            default: return "unknown";
        endcase
    endfunction

    function real cover_pct(input int unsigned covered_bins, input int unsigned total_bins);
        if (total_bins == 0)
            return 0.0;
        return (100.0 * covered_bins) / total_bins;
    endfunction

    function real hit_pct(input int unsigned hits);
        if (total_samples == 0)
            return 0.0;
        return (100.0 * hits) / total_samples;
    endfunction

    task print_line();
        $display("[RPT] +------------------------------------------------------------------------------+");
    endtask

    task print_section(input string title);
        $display("");
        print_line();
        $display("[RPT] | %-76s |", title);
        print_line();
    endtask

    task print_summary_row(input string item, input string value);
        $display("[RPT] | %-28s : %-45s |", item, value);
    endtask

    task print_cp_table_header();
        $display("[COV] | %s | %s | %s |",
                 "Coverpoint/Cross        ",
                 "Covered Bins  ",
                 "Coverage  ");
        $display("[COV] |--------------------------|----------------|------------|");
    endtask

    task print_cp_row(input string cp_name, input int unsigned covered_bins, input int unsigned total_bins);
        string covered_text;
        covered_text = $sformatf("%0d/%0d", covered_bins, total_bins);
        $display("[COV] | %-24s | %-14s | %6.2f%%    |",
                 cp_name, covered_text, cover_pct(covered_bins, total_bins));
    endtask

    task print_bin_table_header(input string section_name);
        print_section(section_name);
        $display("[COV] | %s | %s | %s | %s |",
                 "Bin                                   ",
                 "Hits  ",
                 "Sample %  ",
                 "Bin Cov ");
        $display("[COV] |----------------------------------------|--------|------------|----------|");
    endtask

    task print_bin(input string bin_name, input int unsigned hits);
        $display("[COV] | %-38s | %-6d | %6.2f%%    | %6.2f%%  |",
                 bin_name,
                 hits,
                 hit_pct(hits),
                 (hits > 0) ? 100.0 : 0.0);
    endtask

    function void sample(input spi_flash_transaction tr);
        int unsigned op_i;
        int unsigned len_i;
        int unsigned addr_i;
        int unsigned err_i;
        int unsigned page_i;
        int unsigned rx_i;
        int unsigned tx_i;

        cov_op       = tr.op;
        cov_addr     = tr.addr;
        cov_len      = tr.len;
        cov_error    = tr.error;
        cov_page_bad = ((tr.op == OP_PAGE_PROGRAM) && tr.is_page_program_bad());
        cov_rx_count = tr.rx_payload.size();
        cov_tx_count = tr.tx_payload.size();

        op_i   = op_index(tr.op);
        len_i  = len_index(tr.len);
        addr_i = addr_index(tr.addr[7:0]);
        err_i  = tr.error ? 1 : 0;
        page_i = cov_page_bad ? 1 : 0;
        rx_i   = rx_count_index(cov_rx_count);
        tx_i   = tx_count_index(cov_tx_count);

        total_samples++;
        op_hits[op_i]++;
        len_hits[len_i]++;
        addr_hits[addr_i]++;
        error_hits[err_i]++;
        page_bad_hits[page_i]++;
        rx_count_hits[rx_i]++;
        tx_count_hits[tx_i]++;
        op_x_error_hits[(op_i * 2) + err_i]++;
        op_x_len_hits[(op_i * 6) + len_i]++;

        cg_command.sample();
    endfunction

    task report(input int unsigned scoreboard_errors);
        int unsigned covered;
        int unsigned cross_index;

        $display("");
        $display("[RPT] ================================================================================");
        $display("[RPT]                  SPI FLASH CONTROLLER VERIFICATION REPORT");
        $display("[RPT] ================================================================================");
        if (scoreboard_errors == 0)
            print_summary_row("Result", "PASS");
        else
            print_summary_row("Result", "FAIL");
        print_summary_row("Scoreboard errors", $sformatf("%0d", scoreboard_errors));
        print_summary_row("Sampled transactions", $sformatf("%0d", total_samples));
        print_summary_row("Functional coverage", $sformatf("%0.2f%%", cg_command.get_coverage()));

        print_section("COVERAGE SUMMARY");
        print_cp_table_header();

        covered = 0;
        for (int unsigned i = 0; i < 5; i++)
            if (op_hits[i] > 0)
                covered++;
        print_cp_row("op_cp", covered, 5);

        covered = 0;
        for (int unsigned i = 0; i < 6; i++)
            if (len_hits[i] > 0)
                covered++;
        print_cp_row("len_cp", covered, 6);

        covered = 0;
        for (int unsigned i = 0; i < 4; i++)
            if (addr_hits[i] > 0)
                covered++;
        print_cp_row("addr_lsb_cp", covered, 4);

        covered = 0;
        for (int unsigned i = 0; i < 2; i++)
            if (error_hits[i] > 0)
                covered++;
        print_cp_row("error_cp", covered, 2);

        covered = 0;
        for (int unsigned i = 0; i < 2; i++)
            if (page_bad_hits[i] > 0)
                covered++;
        print_cp_row("page_bad_cp", covered, 2);

        covered = 0;
        for (int unsigned i = 0; i < 4; i++)
            if (rx_count_hits[i] > 0)
                covered++;
        print_cp_row("rx_count_cp", covered, 4);

        covered = 0;
        for (int unsigned i = 0; i < 3; i++)
            if (tx_count_hits[i] > 0)
                covered++;
        print_cp_row("tx_count_cp", covered, 3);

        covered = 0;
        for (int unsigned i = 0; i < 10; i++)
            if (op_x_error_hits[i] > 0)
                covered++;
        print_cp_row("op_x_error", covered, 10);

        covered = 0;
        for (int unsigned i = 0; i < 30; i++)
            if (op_x_len_hits[i] > 0)
                covered++;
        print_cp_row("op_x_len", covered, 30);

        print_bin_table_header("op_cp BIN DETAILS");
        for (int unsigned i = 0; i < 5; i++)
            print_bin(op_bin_name(i), op_hits[i]);

        print_bin_table_header("len_cp BIN DETAILS");
        for (int unsigned i = 0; i < 6; i++)
            print_bin(len_bin_name(i), len_hits[i]);

        print_bin_table_header("addr_lsb_cp BIN DETAILS");
        for (int unsigned i = 0; i < 4; i++)
            print_bin(addr_bin_name(i), addr_hits[i]);

        print_bin_table_header("error_cp BIN DETAILS");
        print_bin("no_error", error_hits[0]);
        print_bin("error_seen", error_hits[1]);

        print_bin_table_header("page_bad_cp BIN DETAILS");
        print_bin("legal_page_program", page_bad_hits[0]);
        print_bin("illegal_page_program", page_bad_hits[1]);

        print_bin_table_header("rx_count_cp BIN DETAILS");
        for (int unsigned i = 0; i < 4; i++)
            print_bin(rx_count_bin_name(i), rx_count_hits[i]);

        print_bin_table_header("tx_count_cp BIN DETAILS");
        for (int unsigned i = 0; i < 3; i++)
            print_bin(tx_count_bin_name(i), tx_count_hits[i]);

        print_bin_table_header("op_x_error CROSS BIN DETAILS");
        for (int unsigned op_i = 0; op_i < 5; op_i++) begin
            print_bin($sformatf("%s x no_error", op_bin_name(op_i)),
                      op_x_error_hits[(op_i * 2) + 0]);
            print_bin($sformatf("%s x error_seen", op_bin_name(op_i)),
                      op_x_error_hits[(op_i * 2) + 1]);
        end

        print_bin_table_header("op_x_len CROSS BIN DETAILS");
        for (int unsigned op_i = 0; op_i < 5; op_i++) begin
            for (int unsigned len_i = 0; len_i < 6; len_i++) begin
                cross_index = (op_i * 6) + len_i;
                print_bin($sformatf("%s x %s", op_bin_name(op_i), len_bin_name(len_i)),
                          op_x_len_hits[cross_index]);
            end
        end

        $display("");
        $display("[RPT] ================================================================================");
        $display("[RPT]                         END OF VERIFICATION REPORT");
        $display("[RPT] ================================================================================");
        $display("");
    endtask

    task run();
        spi_flash_transaction tr;

        forever begin
            mon2cov.get(tr);
            if (tr != null)
                sample(tr);
        end
    endtask
endclass
