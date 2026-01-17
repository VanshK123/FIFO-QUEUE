# Installation Guide

## Required Tools

### 1. Icarus Verilog (iverilog) - Verilog Simulator

```bash
sudo apt update
sudo apt install iverilog -y
```

Verify installation:
```bash
iverilog -v
```

### 2. GTKWave - Waveform Viewer

```bash
sudo apt install gtkwave -y
```

Verify installation:
```bash
gtkwave --version
```

### 3. Python 3 and matplotlib (for analysis scripts)

```bash
sudo apt install python3 python3-pip -y
pip3 install matplotlib numpy
```

Verify installation:
```bash
python3 --version
python3 -c "import matplotlib; print('matplotlib OK')"
```

## Quick Install (All at Once)

```bash
sudo apt update
sudo apt install -y iverilog gtkwave python3 python3-pip
pip3 install matplotlib numpy
```

## Running the Simulations

After installation, run:

```bash
cd /home/vansh/Desktop/Study/Project/FIFO/sim
make test
```

Or run individual tests:

```bash
# Synchronous FIFO
make sync

# Asynchronous FIFO
make async

# View waveforms
make wave_sync
make wave_async
```

## Troubleshooting

### If iverilog is not found:
Check if it's installed:
```bash
which iverilog
dpkg -l | grep iverilog
```

### If make fails:
Check the error message and ensure all source files exist:
```bash
ls -la ../rtl/
ls -la ../tb/
```

### If Python scripts fail:
Install dependencies:
```bash
pip3 install --user matplotlib numpy
```
