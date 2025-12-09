# AI Accelerator Support - Orion Sentinel NetSec

This document describes AI accelerator support for the Orion Sentinel NetSec Node, including hardware requirements, driver installation, and configuration.

## Overview

The Orion Sentinel AI services can leverage hardware acceleration to improve inference performance and reduce CPU load. The system supports multiple AI accelerators with a focus on Raspberry Pi 5 compatibility.

## Supported Accelerators

### 1. Hailo AI Hat (Recommended for Raspberry Pi 5)

**Hardware**:
- Hailo-8 AI Kit for Raspberry Pi 5
- Hailo-8L AI Hat (M.2 form factor)
- Performance: ~13 TOPS (Tera Operations Per Second)

**Compatibility**:
- Raspberry Pi 5 (8GB RAM recommended)
- Raspberry Pi OS 64-bit (Bookworm or later)

**Device Path**: `/dev/hailo0`

---

### 2. Google Coral TPU

**Hardware**:
- Coral USB Accelerator
- Coral M.2 Accelerator
- Performance: 4 TOPS

**Compatibility**:
- Any system with USB 3.0 or M.2 slot
- Works with x86_64 and ARM64

**Device Path**: `/dev/apex_0`

---

### 3. Intel Neural Compute Stick

**Hardware**:
- Intel Movidius Neural Compute Stick 2
- Performance: 1 TOPS

**Compatibility**:
- Any system with USB port

**Device Path**: `/dev/myriad0` (or similar)

---

## Installation

### Hailo AI Hat on Raspberry Pi 5

#### Prerequisites

1. **Raspberry Pi OS 64-bit** (Bookworm or later)
2. **Kernel 6.1+** (check with `uname -r`)
3. **Internet connection** for package installation

#### Step 1: Install Hailo Drivers

```bash
# Update system
sudo apt update
sudo apt upgrade -y

# Install Hailo software stack
sudo apt install hailo-all

# The hailo-all package includes:
# - Kernel driver (hailo_pci)
# - Runtime libraries
# - Python bindings
# - Example models
```

#### Step 2: Verify Installation

```bash
# Check if Hailo device is detected
ls -la /dev/hailo*

# Expected output:
# crw-rw---- 1 root video 511, 0 Dec  9 10:00 /dev/hailo0

# Check driver is loaded
lsmod | grep hailo

# Expected output:
# hailo_pci              65536  0
```

#### Step 3: Test Device

```bash
# Install Hailo test utilities
pip3 install hailort

# Run basic test
hailortcli fw-control identify

# Expected output should show Hailo-8 device info
```

#### Step 4: Configure Permissions

Add your user to the `video` group for device access:

```bash
sudo usermod -aG video $USER
newgrp video
```

#### Step 5: Verify in Docker

Test that Docker containers can access the device:

```bash
docker run --rm --device=/dev/hailo0:/dev/hailo0 ubuntu:22.04 ls -la /dev/hailo0
```

---

### Google Coral TPU on Raspberry Pi

#### Step 1: Install Edge TPU Runtime

```bash
# Add Edge TPU repository
echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | \
  sudo tee /etc/apt/sources.list.d/coral-edgetpu.list

# Add Google package signing key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
  sudo apt-key add -

# Update and install
sudo apt update
sudo apt install libedgetpu1-std
```

#### Step 2: Install Python Library

```bash
pip3 install pycoral tflite-runtime
```

#### Step 3: Verify Device

```bash
ls -la /dev/apex_0

# Should show device
```

---

## Configuration in Orion Sentinel

### Hailo Configuration

The main `compose.yml` file is pre-configured to support Hailo devices. No changes needed if using default setup.

**Automatic Device Mapping**:
The AI services automatically detect and use `/dev/hailo0` if present.

**Manual Configuration** (if needed):

Edit `compose.yml` and add device mapping to AI services:

```yaml
soar:
  # ... existing config ...
  devices:
    - /dev/hailo0:/dev/hailo0
  # ... rest of config ...
```

Repeat for `inventory`, `change-monitor`, `health-score` services as needed.

---

### Model Format & Conversion

AI models must be converted to accelerator-specific formats:

#### Hailo Models (HEF Format)

Hailo requires models in **HEF** (Hailo Executable Format).

**Convert ONNX to HEF**:

```bash
# Install Hailo Dataflow Compiler (on development machine)
pip3 install hailo_sdk

# Convert model
hailo compiler compile \
  --hw-arch hailo8 \
  model.onnx \
  --output-dir ./compiled/

# This produces model.hef
```

**Place Model in Container**:

```bash
# Copy to AI models directory
cp model.hef stacks/ai/models/

# Model will be available at /app/models/model.hef in container
```

---

#### TFLite Models (Coral TPU)

Coral TPU uses **TFLite** models with Edge TPU delegation.

**Convert to Edge TPU TFLite**:

```bash
# Install Edge TPU Compiler
curl https://coral.ai/software/ -o edgetpu_compiler
sudo apt install ./edgetpu_compiler

# Convert model
edgetpu_compiler model.tflite

# Produces model_edgetpu.tflite
```

---

## Model Directory Structure

Place your models in `stacks/ai/models/`:

```
stacks/ai/models/
├── README.md                     # Model documentation
├── device_anomaly.hef            # Hailo model for device anomaly detection
├── domain_risk.hef               # Hailo model for domain risk scoring
├── device_anomaly_edgetpu.tflite # Coral TPU alternative
└── domain_risk_edgetpu.tflite    # Coral TPU alternative
```

---

## Performance Tuning

### Hailo Performance Settings

**Batch Size**: Adjust in AI service code
```python
# In your inference code
BATCH_SIZE = 8  # Hailo performs best with batch sizes 4-16
```

**Multi-Stream Processing**:
```python
# Hailo supports multiple streams
NUM_STREAMS = 4  # Parallel inference streams
```

**Power Mode** (on Pi 5):
```bash
# Set performance governor for max speed
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

---

### Memory Optimization

For Raspberry Pi with limited RAM:

1. **Reduce Batch Size**: Smaller batches = less memory
2. **Limit Concurrent Streams**: Fewer parallel operations
3. **Increase Swap** (if needed):
   ```bash
   sudo dphys-swapfile swapoff
   sudo nano /etc/dphys-swapfile
   # Set CONF_SWAPSIZE=2048
   sudo dphys-swapfile setup
   sudo dphys-swapfile swapon
   ```

---

## Fallback to CPU Inference

If no accelerator is detected, Orion Sentinel AI services **automatically fall back to CPU inference**.

**Performance Impact**:
- Hailo: ~10-20x slower on CPU
- Inference latency: 100ms → 1-2 seconds
- Still functional, but may struggle with high event rates

**When to Use CPU-Only**:
- Development and testing
- Low-traffic networks (<100 events/minute)
- Budget-constrained deployments

---

## Troubleshooting

### Device Not Found

**Symptom**: `/dev/hailo0` does not exist

**Solutions**:
1. Check hardware connection: `lspci | grep Hailo` or `lsusb`
2. Verify driver loaded: `lsmod | grep hailo`
3. Check kernel logs: `dmesg | grep -i hailo`
4. Reinstall driver: `sudo apt reinstall hailo-all`

---

### Permission Denied

**Symptom**: Docker cannot access `/dev/hailo0`

**Solutions**:
1. Check device permissions: `ls -la /dev/hailo0`
2. Add user to video group: `sudo usermod -aG video $USER`
3. Restart Docker: `sudo systemctl restart docker`
4. Verify in container: `docker run --rm --device=/dev/hailo0 ubuntu ls -la /dev/hailo0`

---

### Poor Performance

**Symptom**: Inference is slow even with accelerator

**Solutions**:
1. Check model is using accelerator (not CPU fallback)
2. Verify batch size is optimal (4-16 for Hailo)
3. Monitor system resources: `htop`, `iostat`
4. Check for thermal throttling: `vcgencmd measure_temp` (Pi 5)
5. Ensure adequate cooling (heatsink/fan on AI Hat)

---

### Model Loading Errors

**Symptom**: AI service fails to load model

**Solutions**:
1. Verify model format matches accelerator (HEF for Hailo, TFLite for Coral)
2. Check model path in container: `docker exec orion-inventory ls /app/models/`
3. Validate model file is not corrupted: `file model.hef`
4. Review service logs: `docker logs orion-inventory`

---

## Advanced: Custom Accelerator Support

To add support for a different accelerator:

### 1. Update Compose File

Add device mapping:
```yaml
inventory:
  devices:
    - /dev/your-accelerator:/dev/your-accelerator
```

### 2. Update AI Service Code

Modify `stacks/ai/src/orion_ai/model_runner.py`:

```python
def detect_accelerator():
    """Detect available accelerator."""
    if os.path.exists("/dev/hailo0"):
        return "hailo"
    elif os.path.exists("/dev/apex_0"):
        return "coral"
    elif os.path.exists("/dev/your-accelerator"):
        return "custom"
    else:
        return "cpu"
```

### 3. Implement Inference

Add accelerator-specific inference code:

```python
def run_inference_custom(model_path, input_data):
    """Run inference on custom accelerator."""
    # Load model
    model = load_custom_model(model_path)
    # Run inference
    output = model.predict(input_data)
    return output
```

---

## Hardware Recommendations

### Raspberry Pi 5 (Recommended)

**Minimum**:
- Pi 5 with 4GB RAM
- Hailo AI Hat
- 32GB SD card (Class 10+)
- Official Pi 5 power supply (27W)

**Recommended**:
- Pi 5 with 8GB RAM
- Hailo-8 AI Kit
- 64GB SD card (or NVMe SSD)
- Active cooling (fan/heatsink)
- Official Pi 5 power supply

**Optimal**:
- Pi 5 with 8GB RAM
- Hailo-8L AI Hat
- 128GB NVMe SSD
- Argon ONE V3 case (active cooling)
- UPS for power backup

---

### x86_64 Mini PC (Alternative)

For non-Pi deployments:

**Example**: Intel N100 Mini PC
- Intel N100 CPU (4 cores)
- 8GB+ RAM
- 128GB+ SSD
- Google Coral USB Accelerator

---

## Future Enhancements

Planned accelerator support:

- [ ] NVIDIA Jetson (CUDA inference)
- [ ] AMD ROCm support
- [ ] Apple M-series Neural Engine
- [ ] Multi-accelerator load balancing
- [ ] Dynamic accelerator selection

---

## References

- [Hailo Documentation](https://hailo.ai/developer-zone/)
- [Google Coral Documentation](https://coral.ai/docs/)
- [Raspberry Pi 5 Specs](https://www.raspberrypi.com/products/raspberry-pi-5/)
- [ONNX Runtime](https://onnxruntime.ai/)
- [TensorFlow Lite](https://www.tensorflow.org/lite)

---

**Last Updated**: 2024-12-09  
**Tested On**: Raspberry Pi 5 (8GB) + Hailo-8 AI Hat
