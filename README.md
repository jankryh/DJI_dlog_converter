# DJI Avata 2 D-Log Video Processor

🚁 **Professional batch video processing tool for DJI Avata 2 D-Log footage**

Convert your DJI Avata 2 D-Log videos to Rec.709 color space using hardware acceleration, parallel processing, and custom LUT files. Features real-time progress tracking, ETA calculation, and multiple quality presets with intelligent multi-core utilization.

## ✨ Features

- 🎬 **Batch Processing** - Process multiple videos automatically
- 🚀 **Parallel Processing** - Multi-core utilization with auto-detection (2-4x speedup)
- ⚡ **Hardware Acceleration** - Uses macOS VideoToolbox for optimal performance
- 📊 **Real-time Progress** - Visual progress bar with ETA and encoding speed
- 🎯 **Quality Presets** - High, Medium, Low quality options
- ⏱️ **Time Tracking** - Individual file and total processing time with speedup metrics
- 🛡️ **Error Handling** - Robust error handling with graceful recovery
- 🎨 **Color Output** - Beautiful colored terminal output
- 🔄 **Resume Support** - Skips already processed files
- 🧠 **Smart Job Management** - Intelligent queue management and resource allocation
- 📱 **macOS Optimized** - Built for macOS with bash 3.2 compatibility

## 🎯 Sample Output

### Sequential Mode (PARALLEL_JOBS=1)
```bash
ℹ️  🚀 DJI Avata 2 D-Log Processor (Optimized) - Parallel Edition
ℹ️  Zdrojová složka: /Users/user/Movies/DJI/source
ℹ️  Výstupní složka: /Users/user/Movies/DJI/final
ℹ️  LUT soubor: /Users/user/Movies/DJI/Avata2.cube
ℹ️  Kvalita: high
ℹ️  Paralelní úlohy: 1
ℹ️  Nalezeno 3 souborů k zpracování
ℹ️  🔄 Sekvenční zpracování (1 úloha najednou)

ℹ️  📁 Soubor 1/3
ℹ️  🎞️ Zpracovávám: DJI_20250613194533_0001_D.mp4 – délka: 123s (kvalita: high)
🔄 [####################-----------]  68% filename.mp4 | 1.2x | ETA: 02:34

✅ Hotovo: DJI_20250613194533_0001_D.mp4
ℹ️  Velikost: 156M | Čas: 08:23

🏁 Zpracování dokončeno!
✅ Úspěšně zpracováno: 3
⏱️  Celkový čas: 25:47
```

### Parallel Mode (PARALLEL_JOBS>1)
```bash
ℹ️  🚀 DJI Avata 2 D-Log Processor (Optimized) - Parallel Edition
ℹ️  Zdrojová složka: /Users/user/Movies/DJI/source
ℹ️  Výstupní složka: /Users/user/Movies/DJI/final
ℹ️  LUT soubor: /Users/user/Movies/DJI/Avata2.cube
ℹ️  Kvalita: high
ℹ️  Paralelní úlohy: 4
ℹ️  Nalezeno 8 souborů k zpracování
ℹ️  🚀 Paralelní zpracování (4 úloh současně)

ℹ️  🚀 Spouštím úlohu #1: DJI_20250613194533_0001_D.mp4
ℹ️  🚀 Spouštím úlohu #2: DJI_20250613194834_0002_D.MP4
ℹ️  🚀 Spouštím úlohu #3: DJI_20250709155901_0003_D.mp4
📊 Stav: 2/8 dokončeno | 3 běží | 2 úspěšných | 0 chyb
✅ Dokončeno: DJI_20250613194533_0001_D.mp4
ℹ️  🚀 Spouštím úlohu #4: DJI_20250615120045_0004_D.mp4
ℹ️  ⏳ Čekám na dokončení všech úloh...

🏁 Zpracování dokončeno!
✅ Úspěšně zpracováno: 8
⏱️  Celkový čas: 12:30
ℹ️  🚀 Zrychlení: ~3.2x díky paralelizaci
```

## 📋 Requirements

- **macOS** (tested on macOS Sonoma/Ventura)
- **FFmpeg** with VideoToolbox support
- **Bash** 3.2+ (default macOS bash)
- **DJI Avata 2 LUT file** (`.cube` format)

### Install FFmpeg

```bash
# Using Homebrew
brew install ffmpeg

# Verify VideoToolbox support
ffmpeg -encoders | grep videotoolbox
```

## 🚀 Quick Start

1. **Clone or download** the script
2. **Make it executable**:
   ```bash
   chmod +x avata2_dlog_optimized.sh
   ```
3. **Prepare your files**:
   - Source videos in `/path/to/source/`
   - LUT file (e.g., `Avata2.cube`)
4. **Run the processor**:
   ```bash
   ./avata2_dlog_optimized.sh
   ```

## 📖 Usage

### Basic Usage

```bash
# Use default paths
./avata2_dlog_optimized.sh

# Custom source and output directories
./avata2_dlog_optimized.sh /path/to/source /path/to/output

# Custom source, output, and LUT file
./avata2_dlog_optimized.sh /path/to/source /path/to/output /path/to/lut.cube
```

### Quality Presets

Control encoding quality using environment variables:

```bash
# High quality (default) - 15Mbps, best for archival
QUALITY_PRESET=high ./avata2_dlog_optimized.sh

# Medium quality - 10Mbps, balanced size/quality
QUALITY_PRESET=medium ./avata2_dlog_optimized.sh

# Low quality - 6Mbps, smaller files for quick sharing
QUALITY_PRESET=low ./avata2_dlog_optimized.sh
```

### Parallel Processing

Control how many videos process simultaneously:

```bash
# Auto-detect CPU cores (default, recommended)
./avata2_dlog_optimized.sh

# Use 4 parallel jobs (good for 8+ core systems)
PARALLEL_JOBS=4 ./avata2_dlog_optimized.sh

# Use 2 parallel jobs (good for 4-6 core systems)
PARALLEL_JOBS=2 ./avata2_dlog_optimized.sh

# Sequential processing (original behavior, single core)
PARALLEL_JOBS=1 ./avata2_dlog_optimized.sh

# Combined with quality settings
PARALLEL_JOBS=3 QUALITY_PRESET=medium ./avata2_dlog_optimized.sh
```

### Help

```bash
./avata2_dlog_optimized.sh --help
```

## ⚙️ Configuration

### Default Paths

The script uses these default paths (edit the script to change):

```bash
SOURCE_DIR="/Users/onimalu/Movies/DJI/source"
FINAL_DIR="/Users/onimalu/Movies/DJI/final"
LUT_FILE="/Users/onimalu/Movies/DJI/Avata2.cube"
```

### Quality Settings

| Preset | Bitrate | Max Rate | Buffer | Use Case |
|--------|---------|----------|---------|----------|
| **High** | 15M | 18M | 30M | Archive/editing |
| **Medium** | 10M | 12M | 20M | General use |
| **Low** | 6M | 8M | 12M | Web/mobile |

### Environment Variables

```bash
QUALITY_PRESET    # Quality: high, medium, low (default: high)
PARALLEL_JOBS     # Number of parallel jobs (default: auto-detect CPU cores)
```

| Variable | Options | Default | Description |
|----------|---------|---------|-------------|
| `QUALITY_PRESET` | high, medium, low | high | Video encoding quality |
| `PARALLEL_JOBS` | 1, 2, 3, 4+ | auto-detect | Simultaneous video processing jobs |

### Parallel Processing Recommendations

| System Type | Recommended PARALLEL_JOBS | Reason |
|-------------|---------------------------|---------|
| **M1/M2 MacBook Air** | 2-3 | Balance performance vs. thermal throttling |
| **M1/M2 MacBook Pro** | 3-4 | Better cooling, can handle more load |
| **M1/M2 Mac Studio/Pro** | 4-6 | High-performance systems with excellent cooling |
| **Intel Mac (4-6 cores)** | 2-3 | Limited by CPU performance |
| **Intel Mac (8+ cores)** | 3-4 | Better multi-core performance |

## 🎬 Video Processing Details

### Hardware Acceleration

- **Primary**: h264_videotoolbox (macOS VideoToolbox)
- **Fallback**: libx264 (software encoding if hardware unavailable)
- **Auto-detection**: Script automatically detects available encoders

### Output Format

- **Container**: MP4
- **Video Codec**: H.264 (hardware accelerated)
- **Audio Codec**: Copy (no re-encoding)
- **Color Space**: Rec.709 (via LUT transformation)
- **Optimization**: Fast start enabled (`-movflags +faststart`)

### Progress Information

The real-time progress display shows:

- **Progress Bar**: Visual representation of completion
- **Percentage**: Exact completion percentage
- **Encoding Speed**: Real-time multiplier (e.g., `1.2x` = 20% faster than real-time)
- **ETA**: Estimated time to completion
- **File Info**: Current file being processed

## 📁 File Structure

```
DJI/
├── source/                 # Place your D-Log videos here
│   ├── DJI_20250613_0001_D.mp4
│   ├── DJI_20250613_0002_D.MP4
│   └── DJI_20250709_0003_D.mp4
├── final/                  # Processed videos appear here
├── Avata2.cube           # Your LUT file
└── avata2_dlog_optimized.sh   # The processor script
```

## 🐛 Troubleshooting

### Common Issues

**❌ "LUT file not found"**
```bash
# Solution: Check LUT file path
ls -la /path/to/your/Avata2.cube
```

**❌ "Unable to choose an output format"**
```bash
# Solution: Update to latest script version (includes -f mp4 fix)
```

**❌ "Hardware acceleration not available"**
```bash
# Check VideoToolbox support
ffmpeg -encoders | grep videotoolbox

# If not available, script automatically falls back to software encoding
```

**❌ "Command not found: ffmpeg"**
```bash
# Install FFmpeg
brew install ffmpeg
```

### Performance Tips

1. **Use SSD storage** for source and output directories
2. **Close other video applications** during processing
3. **Use appropriate quality preset** for your needs
4. **Ensure sufficient disk space** (processed files can be large)
5. **Optimize parallel jobs** for your system (2-4 jobs for most Macs)
6. **Monitor system temperature** during intensive parallel processing
7. **Use lower PARALLEL_JOBS** if system becomes unresponsive

### Parallel Processing Troubleshooting

**❌ "System becomes slow/unresponsive during parallel processing"**
```bash
# Solution: Reduce parallel jobs
PARALLEL_JOBS=2 ./avata2_dlog_optimized.sh
```

**❌ "Jobs are completing slower than expected"**
```bash
# Check if thermal throttling is occurring
# Solution: Reduce parallel jobs or improve cooling
PARALLEL_JOBS=1 ./avata2_dlog_optimized.sh
```

**❌ "Some jobs fail randomly in parallel mode"**
```bash
# Check system resources and logs
ls -la /tmp/dji_job_*.log
# Solution: Reduce parallel jobs or check available memory
```

**❌ "Auto-detected core count is wrong"**
```bash
# Check detected cores
sysctl -n hw.ncpu
# Manually set if needed
PARALLEL_JOBS=4 ./avata2_dlog_optimized.sh
```

### Script Interruption

- **Ctrl+C**: Gracefully stops processing and all parallel jobs
- **Temp files**: Automatically cleaned up
- **Background jobs**: All parallel processes terminated safely
- **Resume**: Re-run script to continue (skips completed files)
- **Log files**: Parallel job logs preserved for debugging (`/tmp/dji_job_*.log`)

## 📊 Performance Expectations

### Sequential Processing Speeds (M4 Mac Mini)

| Quality | Speed | Use Case |
|---------|-------|----------|
| **Low** | ~0.3-0.5x | Quick previews |
| **Medium** | ~0.2-0.4x | Daily use |
| **High** | ~0.1-0.3x | Archive quality |

*Single file processing speed varies based on video complexity, resolution, and system load*

### Parallel Processing Performance

| Files | Sequential Time | Parallel Time (4 jobs) | Speedup | 
|-------|----------------|------------------------|---------|
| 1 file | 10 minutes | 10 minutes | 1.0x |
| 4 files | 40 minutes | 12-15 minutes | ~3.0x |
| 8 files | 80 minutes | 22-28 minutes | ~3.2x |
| 12 files | 120 minutes | 32-40 minutes | ~3.5x |

**Key Performance Notes:**
- 🚀 **Best speedup**: 2-4 files per CPU core
- 🌡️ **Thermal considerations**: Performance may decrease on sustained loads (MacBook Air)
- 💾 **I/O bottleneck**: SSD storage recommended for optimal parallel performance
- 🔥 **System load**: Close other applications for maximum speed

### File Size Expectations

For 1-minute 4K DJI footage:

| Quality | Approximate Size |
|---------|-----------------|
| **Low** | ~45-60 MB |
| **Medium** | ~75-90 MB |
| **High** | ~110-140 MB |

## 🎯 Advanced Usage

### Batch Processing Multiple Directories

```bash
#!/bin/bash
for dir in /Users/onimalu/Movies/DJI/*/; do
    if [[ -d "$dir/source" ]]; then
        echo "Processing: $dir"
        PARALLEL_JOBS=3 QUALITY_PRESET=medium ./avata2_dlog_optimized.sh \
            "$dir/source" \
            "$dir/final" \
            "/Users/onimalu/Movies/DJI/Avata2.cube"
    fi
done
```

### Optimal Performance Configuration

```bash
#!/bin/bash
# Configuration for different scenarios

# For MacBook Air (thermal management)
PARALLEL_JOBS=2 QUALITY_PRESET=medium ./avata2_dlog_optimized.sh

# For MacBook Pro/Studio (maximum performance)
PARALLEL_JOBS=4 QUALITY_PRESET=high ./avata2_dlog_optimized.sh

# For processing while working (low system impact)
PARALLEL_JOBS=1 QUALITY_PRESET=medium ./avata2_dlog_optimized.sh

# For overnight batch processing (maximum quality)
PARALLEL_JOBS=3 QUALITY_PRESET=high ./avata2_dlog_optimized.sh
```

### Monitoring System Resources

```bash
# Monitor CPU/GPU usage during processing
sudo powermetrics -n 1 -f plist | grep -A5 -B5 "videotoolbox\|ffmpeg"

# Monitor active parallel jobs
ps aux | grep ffmpeg | grep -v grep

# Check system temperature (requires TG Pro or similar)
system_profiler SPHardwareDataType | grep -i temperature

# Monitor parallel job logs (when processing)
tail -f /tmp/dji_job_*.log

# Real-time resource monitoring
htop  # Install with: brew install htop
```

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests!

### Future Enhancements

- [x] ~~Parallel processing support~~ ✅ **COMPLETED** - Auto-detect cores, 2-4x speedup
- [ ] Multiple LUT support
- [ ] Web interface
- [ ] Progress persistence across restarts
- [ ] Auto-quality selection based on source
- [ ] Metadata preservation options
- [ ] GPU memory optimization for parallel processing
- [ ] Dynamic job scheduling based on system load
- [ ] Integration with macOS notifications

## 📄 License

This project is open source. Feel free to use and modify as needed.

## ⚠️ Disclaimer

This tool processes video files. Always keep backups of your original footage. Test with sample files before batch processing important content.

---

**Happy Flying! 🚁** 

*Optimized for DJI Avata 2 pilots who demand professional video quality*