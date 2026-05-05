# SPI NOR Flash Memory Controller using SystemVerilog

## Project Overview

This project focuses on the design and verification of an SPI NOR Flash Memory Controller using SystemVerilog. The controller enables communication between a host system and SPI NOR Flash memory through the Serial Peripheral Interface (SPI) protocol. A complete SystemVerilog-based verification environment was developed to validate controller functionality, protocol behavior, and data integrity.

The project supports major SPI NOR Flash operations including data read, page program, sector erase, status register read, and device identification. Functional verification was performed using directed and constrained-random test scenarios along with assertions, scoreboard checking, and functional coverage analysis.

Simulation and debugging were carried out using QuestaSim.

---

# Objectives

* Design an SPI NOR Flash Controller using SystemVerilog.
* Develop a reusable SystemVerilog verification environment.
* Verify SPI protocol functionality and flash memory operations.
* Perform constrained-random verification and functional coverage analysis.
* Validate data integrity using monitor and scoreboard architecture.
* Achieve high functional coverage using coverage-driven verification.

---

# Features Implemented

## SPI NOR Flash Operations

* Read Operation
* Page Program Operation
* Sector Erase Operation
* Read Status Register
* Read JEDEC Device ID
* Error and Boundary Condition Handling

## Verification Features

* Directed Testcases
* Constrained Random Verification
* Assertion-Based Verification
* Functional Coverage Collection
* Cross Coverage Analysis
* Scoreboard-Based Data Comparison
* Transaction-Level Verification
* Coverage-Driven Verification Methodology

---

# Design Architecture

The SPI NOR Flash Controller communicates with the flash memory model through SPI signals including:

* SCLK (Serial Clock)
* MOSI (Master Out Slave In)
* MISO (Master In Slave Out)
* CS_N (Chip Select)

The controller performs serial command transmission, address handling, data transfer, and flash memory operation sequencing.

---

# Verification Architecture

The verification environment was developed using SystemVerilog class-based architecture.

## Verification Components

### Transaction

Defines packet-level transaction data including:

* Operation type
* Address
* Data length
* Payload data
* Error information

### Generator

Generates directed and randomized SPI transactions.

### Driver

Drives generated transactions to the DUT through the SPI interface.

### Monitor

Captures DUT activity and converts signal-level behavior into transactions.

### Scoreboard

Compares expected and actual DUT outputs for functional correctness.

### Coverage

Collects functional coverage for operations, lengths, addresses, error cases, and cross-coverage bins.

### Assertions

Checks protocol correctness and design behavior using SystemVerilog Assertions (SVA).

### Environment

Connects all verification components and manages simulation flow.

### Test

Controls execution of the verification environment.

---

# Verification Strategy

The project uses both directed and constrained-random verification techniques.

## Directed Tests

Directed tests were implemented for:

* Read operations
* Page program operations
* Sector erase operations
* Status register reads
* JEDEC ID reads
* Illegal page crossing scenarios
* Full-page programming
* Invalid length conditions

## Constrained Random Verification

Randomized transactions were generated using:

* Random operation selection
* Random addresses
* Random transfer lengths
* Random payload generation

Constraints were applied to ensure valid and meaningful test scenarios.

---

# Functional Coverage

Functional coverage was implemented to measure verification completeness.

## Coverpoints

Coverage was collected for:

* SPI operations
* Address ranges
* Data lengths
* Error conditions
* RX/TX payload counts
* Illegal page program conditions

## Cross Coverage

Cross coverage was implemented between:

* Operation type and error conditions
* Operation type and transfer lengths

## Coverage Result

* Achieved Functional Coverage: **92.59%**

The achieved coverage demonstrates successful validation of major functional scenarios and protocol behaviors.

---

# Assertions

SystemVerilog Assertions (SVA) were used to verify:

* SPI timing behavior
* Protocol sequencing
* Command execution behavior
* Interface signal correctness

Assertion results successfully passed during simulation.

---

# Simulation Results

Simulation was performed using QuestaSim.

## Verification Outcome

* Functional Coverage Achieved: **92.59%**
* Assertions Passed Successfully
* Directed and Randomized Tests Executed
* Scoreboard Validation Completed
* Protocol Functionality Verified

---

# Tools and Technologies

| Tool / Technology        | Purpose                  |
| ------------------------ | ------------------------ |
| SystemVerilog            | Design and Verification  |
| QuestaSim                | Simulation and Debugging |
| Functional Coverage      | Coverage Analysis        |
| SystemVerilog Assertions | Protocol Verification    |

---

# Project Structure

```text
SPI_SV/
│
├── spi_flash_controller.sv
├── spi_flash_if.sv
├── spi_flash_model.sv
├── spi_flash_transaction.sv
├── spi_flash_generator.sv
├── spi_flash_driver.sv
├── spi_flash_monitor.sv
├── spi_flash_scoreboard.sv
├── spi_flash_coverage.sv
├── spi_flash_assertions.sv
├── spi_flash_env.sv
├── spi_flash_test.sv
├── spi_flash_tb_pkg.sv
├── tb_spi_flash_controller.sv
└── README.md
```

---

# Compile and Run Commands

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

## Run Simulation

```tcl
run -all
```

## Coverage Report

```tcl
coverage report -details
```

---

# Key Achievements

* Designed and verified an SPI NOR Flash Controller using SystemVerilog.
* Developed a reusable class-based verification environment.
* Implemented constrained-random verification methodology.
* Achieved **92.59% Functional Coverage**.
* Performed assertion-based verification and scoreboard validation.
* Verified corner cases, error scenarios, and protocol behavior.

---

# Resume Highlights

* Designed and verified an SPI NOR Flash Controller using SystemVerilog with read, page program, sector erase, and status register operations.

* Developed a reusable SystemVerilog verification environment including generator, driver, monitor, scoreboard, assertions, and functional coverage components.

* Implemented constrained-random verification, directed testcases, and assertion-based checks for protocol validation and corner-case testing.

* Achieved **92.59% Functional Coverage** through coverage-driven verification and cross-coverage analysis using QuestaSim.

---

# Future Enhancements

* Migration to UVM-based verification environment.
* Support for Quad SPI (QSPI).
* Advanced protocol timing verification.
* Regression automation scripting.
* Enhanced coverage closure techniques.

---

# Conclusion

This project successfully demonstrates the design and verification of an SPI NOR Flash Memory Controller using SystemVerilog. A complete verification environment was developed to validate functional correctness, protocol behavior, and data integrity through directed testing, constrained-random verification, assertions, scoreboard checking, and functional coverage analysis.

The project achieved strong functional verification results with 92.59% functional coverage and successful assertion validation in QuestaSim.
