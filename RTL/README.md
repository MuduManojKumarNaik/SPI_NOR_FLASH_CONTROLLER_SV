# RTL Design - SPI NOR Flash Controller

## Overview

This folder contains the RTL design files for the SPI NOR Flash Controller implemented using SystemVerilog. The controller is responsible for handling communication between the host system and SPI NOR Flash memory through the SPI protocol.

The RTL design supports major flash memory operations including read, page program, sector erase, status register read, and JEDEC ID read.

---

# RTL Files

| File Name | Description |
|---|---|
| `spi_flash_controller.sv` | Main SPI NOR Flash Controller design |
| `spi_flash_if.sv` | SPI interface signals and connectivity |
| `spi_flash_model.sv` | SPI NOR Flash behavioral memory model |

---

# Supported Operations

- Read Operation
- Page Program Operation
- Sector Erase Operation
- Read Status Register
- Read JEDEC ID

---

# Design Features

- SPI protocol implementation
- Serial data transfer handling
- Command decoding
- Address management
- Data read/write operations
- Flash memory interaction
- Status register handling

---

# Interface Signals

| Signal | Description |
|---|---|
| `sclk` | SPI serial clock |
| `mosi` | Master Out Slave In |
| `miso` | Master In Slave Out |
| `cs_n` | Active-low chip select |

---

# Tools Used

- SystemVerilog
- QuestaSim

---

# Design Verification

The RTL was verified using a SystemVerilog-based verification environment with:
- Constrained-random testing
- Assertions
- Functional coverage
- Scoreboard validation
- Directed testcases

---

# Author

**Manoj Kumar Naik Mudu**
