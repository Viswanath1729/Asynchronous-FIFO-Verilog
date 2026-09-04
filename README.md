# Asynchronous FIFO on Basys 3 FPGA

## 📌 Project Overview

This project implements a **dual-clock Asynchronous FIFO (First-In-First-Out)** on the **Digilent Basys 3 FPGA board** using Verilog HDL.

The FIFO is designed to safely transfer data between two independent clock domains:

* **Write clock:** 100 MHz
* **Read clock:** 25 MHz
* **Data width:** 8 bits
* **FIFO depth:** 1024 entries

The project demonstrates important RTL and CDC concepts including **dual-clock FIFOs, Gray-code pointers, clock-domain synchronization, full/empty detection, button debouncing, clock division, and FPGA 7-segment display interfacing**.

---

## 🎯 Objectives

The main objectives of this project are:

* Understand the architecture of an asynchronous FIFO.
* Transfer data between independent clock domains.
* Implement Gray-code based read/write pointers.
* Synchronize pointer information between clock domains.
* Generate reliable `full` and `empty` status signals.
* Display the current FIFO occupancy on the Basys 3 seven-segment display.
* Support both manual and automatic FIFO operation.
* Gain practical experience with RTL design and FPGA implementation.

---

## 🏗️ Architecture

The design consists of three major modules:

```text
                 ┌─────────────────────────────┐
                 │        Basys 3 FPGA         │
                 │                             │
                 │        100 MHz Clock        │
                 │              │              │
                 │              ▼              │
                 │       Write Domain          │
                 │              │              │
                 │        Write Pointer        │
                 │              │              │
                 │              ▼              │
                 │       ┌────────────┐         │
                 │       │    FIFO    │         │
                 │       │   Memory   │         │
                 │       └────────────┘         │
                 │              ▲              │
                 │              │              │
                 │        Read Pointer         │
                 │              │              │
                 │              ▼              │
                 │        Read Domain           │
                 │         25 MHz Clock         │
                 │                             │
                 │      7-Segment Display      │
                 └─────────────────────────────┘
```

The write and read sides operate independently. Pointer information is transferred between the clock domains using **Gray-coded pointers and two-stage synchronizers**.

---

## ⚙️ Key Specifications

| Parameter       | Value                          |
| --------------- | ------------------------------ |
| FPGA Board      | Digilent Basys 3               |
| HDL             | Verilog                        |
| FIFO Type       | Asynchronous / Dual-Clock FIFO |
| Data Width      | 8 bits                         |
| FIFO Depth      | 1024                           |
| Write Clock     | 100 MHz                        |
| Read Clock      | 25 MHz                         |
| Memory          | Xilinx Block RAM               |
| Write Interface | Push button / Automatic        |
| Read Interface  | Push button / Automatic        |
| Status          | Full / Empty                   |
| Output          | 4-digit 7-segment display      |

---

## 🔄 Operating Modes

### Manual Mode

In manual mode:

* `BTNU` is used to generate a write request.
* `BTND` is used to generate a read request.
* The switches provide the data to be written into the FIFO.
* FIFO protection prevents writing when the FIFO is full or reading when it is empty.

### Automatic Mode

Automatic mode can be selected using `SW[0]`.

In this mode:

* Data is automatically generated and written into the FIFO.
* The generated data increments after every valid write.
* Read and write rates can be adjusted using switch selections.
* The FIFO occupancy changes depending on the difference between the write and read rates.

---

## 🧠 Important RTL Concepts Demonstrated

### 1. Dual Clock Domains

The FIFO uses independent clocks for writing and reading:

```text
Write Domain              Read Domain
100 MHz                   25 MHz
    │                         │
    ▼                         ▼
Write Pointer             Read Pointer
    │                         │
    └────── FIFO Memory ──────┘
```

This allows the FIFO to act as a buffer between logic operating at different clock frequencies.

---

### 2. Gray-Code Pointers

Binary pointers are converted into Gray code before being transferred between clock domains.

```verilog
wr_ptr_gray <= (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;
```

Gray code is useful for CDC pointer synchronization because only one bit changes between consecutive pointer values.

---

### 3. Pointer Synchronization

The Gray-coded pointers are passed through two flip-flop stages in the receiving clock domain:

```verilog
always @(posedge wr_clk)
    {rd_sync2, rd_sync1} <= {rd_sync1, rd_ptr_gray};

always @(posedge rd_clk)
    {wr_sync2, wr_sync1} <= {wr_sync1, wr_ptr_gray};
```

This reduces the risk of metastability propagating into the FIFO control logic.

---

### 4. Full and Empty Detection

The FIFO determines its state by comparing synchronized Gray-coded pointers.

```verilog
assign empty = (rd_ptr_gray == wr_sync2);
```

The full condition is detected by comparing the write pointer against the appropriately transformed synchronized read pointer.

---

### 5. FIFO Occupancy

The FIFO level is calculated by converting the synchronized read pointer back to binary and subtracting it from the write pointer.

```verilog
assign level_out = wr_ptr_bin - rd_ptr_sync_bin;
```

The resulting occupancy is displayed on the Basys 3 seven-segment display.

---

## 🖥️ FPGA Demonstration

The project uses the Basys 3 board's:

* 100 MHz onboard clock
* Push buttons
* 8 slide switches
* LEDs
* Four-digit seven-segment display

### LEDs

| LED       | Function       |
| --------- | -------------- |
| LED3      | FIFO Full      |
| LED2      | FIFO Empty     |
| LED1:LED0 | Operating Mode |

### Seven-Segment Display

The four-digit display shows the current FIFO occupancy.

For example:

```text
FIFO Level = 0256

┌────┬────┬────┬────┐
│  0 │  2 │  5 │  6 │
└────┴────┴────┴────┘
```

The FIFO level is converted to decimal using a binary-to-BCD conversion implemented with the **Double Dabble algorithm**.

---

## 🔘 Button Debouncing

Mechanical push buttons can produce multiple transitions when pressed.

A dedicated debouncer is therefore used before generating write and read pulses.

```text
Push Button
     │
     ▼
Synchronizer
     │
     ▼
Debouncer
     │
     ▼
Edge Detector
     │
     ▼
FIFO Read/Write Enable
```

This prevents a single button press from being interpreted as multiple FIFO operations.

---

## 📁 Project Structure

```text
async-fifo-basys3/
│
├── async_fifo_top.v
├── async_fifo.v
├── debouncer.v
├── constraints/
│   └── basys3.xdc
│
├── simulation/
│   └── testbench.v
│
└── README.md
```

> The exact file organization may vary depending on the Vivado project structure.

---

## 🛠️ Tools Used

* **Verilog HDL**
* **AMD/Xilinx Vivado**
* **Xilinx Block Memory Generator**
* **Digilent Basys 3**
* RTL Simulation
* FPGA Synthesis
* FPGA Implementation

---

## 🚀 Implementation Flow

1. Create a Vivado RTL project.
2. Select the **Basys 3 / Artix-7 FPGA** device.
3. Add the Verilog source files.
4. Generate the required clocking and block-memory IP.
5. Add the Basys 3 XDC constraints.
6. Run synthesis.
7. Run implementation.
8. Generate the bitstream.
9. Program the Basys 3 board.
10. Test manual and automatic FIFO operation.

---

## 📚 Concepts Learned

This project provides practical exposure to:

* RTL design
* Asynchronous FIFO architecture
* Clock-domain crossing (CDC)
* Gray-code counters
* Pointer synchronization
* Metastability mitigation
* FIFO full/empty logic
* Block RAM
* Clock generation
* Clock division
* Edge detection
* Button debouncing
* Binary-to-BCD conversion
* Seven-segment display multiplexing
* FPGA synthesis and implementation

---

## 🔬 Future Improvements

Possible improvements include:

* Add a complete SystemVerilog/UVM verification environment.
* Add assertions for FIFO safety properties.
* Add independent reset handling for each clock domain.
* Add programmable FIFO almost-full and almost-empty flags.
* Add configurable FIFO depth and data width.
* Add formal verification of the CDC logic.
* Add timing constraints for the asynchronous clock domains.
* Improve the FIFO implementation to follow a fully verified CDC FIFO methodology.
* Add simulation waveforms and hardware demonstration results.

---

## 📷 Hardware

**Target Board:** Digilent Basys 3

The design can be demonstrated by changing the FIFO write/read rates and observing the FIFO occupancy on the seven-segment display.

---

## 👨‍💻 Author

**G. Viswanath**

This project was developed as part of my FPGA/VLSI RTL design learning and focuses on practical implementation of asynchronous FIFO and clock-domain-crossing concepts.

---

## ⭐ Key Takeaway

This project demonstrates how data can be buffered and transferred reliably between two independent clock domains using an **asynchronous FIFO architecture**.

The project combines theoretical CDC concepts with an actual FPGA implementation, making it a practical example of **RTL design, memory interfacing, synchronization, and FPGA hardware development**.
