# Testbench - SPI NOR Flash Controller Verification

## Overview

This folder contains the complete SystemVerilog-based verification environment developed for verifying the SPI NOR Flash Controller.

The testbench architecture is built using a class-based verification methodology and includes constrained-random verification, assertions, functional coverage, scoreboard checking, and directed testcases.

The verification environment validates SPI protocol functionality, flash memory operations, data integrity, and corner-case scenarios.

---

# Testbench Components

| File Name | Description |
|---|---|
| `spi_flash_transaction.sv` | Defines transaction-level packet structure |
| `spi_flash_generator.sv` | Generates directed and randomized transactions |
| `spi_flash_driver.sv` | Drives transactions to the DUT |
| `spi_flash_monitor.sv` | Monitors DUT activity and collects transactions |
| `spi_flash_scoreboard.sv` | Compares expected and actual DUT outputs |
| `spi_flash_coverage.sv` | Functional coverage collection and analysis |
| `spi_flash_assertions.sv` | Assertion-based protocol verification |
| `spi_flash_env.sv` | Connects all verification components |
| `spi_flash_test.sv` | Controls test execution |
| `spi_flash_tb_pkg.sv` | Testbench package containing includes and utilities |
| `tb_spi_flash_controller.sv` | Top-level testbench module |

---

# Verification Features

- Constrained Random Verification
- Directed Testcases
- Functional Coverage Collection
- Cross Coverage Analysis
- Assertion-Based Verification
- Scoreboard Validation
- Protocol Checking
- Error Scenario Verification
- Boundary Condition Testing

---

# Functional Coverage

## Coverage Metrics

| Metric | Result |
|---|---|
| Functional Coverage | **92.59%** |
| Assertion Coverage | **100%** |
| Scoreboard Errors | **0** |
| Sampled Transactions | **2014** |

---

# Assertions

SystemVerilog Assertions (SVA) were implemented to verify:
- SPI protocol timing
- Command execution behavior
- Interface correctness
- Data transfer sequencing

All assertions passed successfully during simulation.

---

# Verification Flow

## Generator
Creates randomized and directed SPI transactions.

## Driver
Applies transactions to the DUT through the SPI interface.

## Monitor
Captures DUT responses and converts signal activity into transactions.

## Scoreboard
Performs expected vs actual data comparison.

## Coverage
Tracks functional verification completeness.

## Assertions
Checks protocol correctness during runtime.

---

# Test Scenarios

The following operations were verified:

- Read Operation
- Page Program Operation
- Sector Erase Operation
- Status Register Read
- JEDEC ID Read
- Illegal Page Crossing
- Full Page Program
- Invalid Length Conditions
- Randomized Transaction Sequences

---

# Simulation Tool

- QuestaSim

---

# Compile and Run

## Compile

```tcl
vlib work
vmap work work

vlog spi_flash_if.sv
vlog spi_flash_controller.sv
vlog spi_flash_model.sv
vlog spi_flash_tb_pkg.sv
vlog spi_flash_assertions.sv
vlog tb_spi_flash_controller.sv
```

## Simulate

```tcl
vsim -coverage tb_spi_flash_controller
```

## Run

```tcl
run -all
```

## Coverage Report

```tcl
coverage report -details
```

---

# Key Achievements

- Developed a reusable SystemVerilog verification environment.
- Implemented constrained-random verification methodology.
- Achieved **92.59% Functional Coverage**.
- Verified SPI NOR Flash operations and protocol behavior.
- Performed assertion-based protocol validation.
- Executed corner-case and boundary-condition testing.

---

# Author

**Manoj Kumar Naik Mudu**
