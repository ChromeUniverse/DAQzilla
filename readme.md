# DAQzilla 🦖

A monster all-in-one modular IP core for FPGA-based Data Acquisition (DAQ), built in SystemVerilog. Designed with automotive-grade applications in mind: think racecar telemetry, low-latency data logging, real-time sensor streaming, etc.

**DAQzilla** absolutely devours data and eats complexity for breakfast, bringing everything under one roof:

- A custom **SPI master** for high-precision ADC interfacing
- A pluggable **DSP pipeline** for real-time filtering and signal conditioning
- A lightweight, fully custom **CAN 2.0A controller** for transmitting calibrated sensor readings

Originally inspired by the Izze Racing [SGAMP-V2](https://www.izzeracing.com/products/ewExternalFiles/Izze_Racing_SGAMP_V2_Datasheet.pdf) strain gauge amplifier and my experience as Data Acquisition lead for [Carnegie Mellon Racing](https://www.carnegiemellonracing.org/team) in Formula SAE. The name was inspired by the ["Godzilla" Nissan GT-R ](https://www.youtube.com/watch?v=wmvwj_BqDNI) and the ["Rexy" Porsche 911 GT3-R](https://www.youtube.com/watch?v=CUI5EOyBW04&pp=ygUMcmV4eSBwb3JzY2hl).

### 🛠️ Software

- [Synopsys VCS + DVE](https://www.synopsys.com/tools/simulation/vcs.html) for simulation/waveform analysis
- [Xilinx Vivado](https://www.xilinx.com/products/design-tools/vivado.html) for synthesis

### 🔌 Hardware

- [Real Digital Boolean Board](https://real.digital/boolean/) (Spartan-7 FPGA)
- [INA333](https://www.ti.com/product/INA333) instrumentation amplifier
- [ADS1256](https://www.ti.com/lit/ds/symlink/ads1256.pdf) 24-bit delta-sigma ADC
- [SN65HVD230](https://www.ti.com/product/SN65HVD230) CAN transceiver evaluation board
- [CANable](https://canable.io/) USB-to-CAN adapter for PC-side interfacing
