# DJI Avata 2 D-Log Video Processor

🚁 **Professional batch video processing tool for DJI Avata 2 D-Log footage**

Convert your DJI Avata 2 D-Log videos to Rec.709 color space using hardware acceleration and custom LUT files. Features real-time progress tracking, ETA calculation, and multiple quality presets.

## ✨ Features

- 🎬 **Batch Processing** - Process multiple videos automatically
- ⚡ **Hardware Acceleration** - Uses macOS VideoToolbox for optimal performance
- 📊 **Real-time Progress** - Visual progress bar with ETA and encoding speed
- 🎯 **Quality Presets** - High, Medium, Low quality options
- ⏱️ **Time Tracking** - Individual file and total processing time
- 🛡️ **Error Handling** - Robust error handling with graceful recovery
- 🎨 **Color Output** - Beautiful colored terminal output
- 🔄 **Resume Support** - Skips already processed files
- 📱 **macOS Optimized** - Built for macOS with bash 3.2 compatibility

## 🎯 Sample Output

```bash
ℹ️  🚀 DJI Avata 2 D-Log Processor (Optimized)
ℹ️  Zdrojová složka: /Users/user/Movies/DJI/source
ℹ️  Výstupní složka: /Users/user/Movies/DJI/final
ℹ️  LUT soubor: /Users/user/Movies/DJI/Avata2.cube
ℹ️  Kvalita: high
ℹ️  Nalezeno 3 souborů k zpracování

ℹ️  📁 Soubor 1/3
ℹ️  🎞️ Zpracovávám: DJI_20250613194533_0001_D.mp4 – délka: 123s (kvalita: high)
🔄 [####################-----------]  68% filename.mp4 | 1.2x | ETA: 02:34

✅ Hotovo: DJI_20250613194533_0001_D.mp4
ℹ️  Velikost: 156M | Čas: 08:23

🏁 Zpracování dokončeno!
✅ Úspěšně zpracováno: 3
⏱️  Celkový čas: 25:47
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
PARALLEL_JOBS     # Future: Number of parallel jobs (default: 1)
```

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

### Script Interruption

- **Ctrl+C**: Gracefully stops processing
- **Temp files**: Automatically cleaned up
- **Resume**: Re-run script to continue (skips completed files)

## 📊 Performance Expectations

### Encoding Speeds (M4 Mac Mini)

| Quality | Speed | Use Case |
|---------|-------|----------|
| **Low** | ~0.3-0.5x | Quick previews |
| **Medium** | ~0.2-0.4x | Daily use |
| **High** | ~0.1-0.3x | Archive quality |

*Speed varies based on video complexity, resolution, and system load*

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
        QUALITY_PRESET=medium ./avata2_dlog_optimized.sh \
            "$dir/source" \
            "$dir/final" \
            "/Users/onimalu/Movies/DJI/Avata2.cube"
    fi
done
```

### Monitoring System Resources

```bash
# Monitor CPU/GPU usage during processing
sudo powermetrics -n 1 -f plist | grep -A5 -B5 "videotoolbox\|ffmpeg"
```

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests!

### Future Enhancements

- [ ] Parallel processing support
- [ ] Multiple LUT support
- [ ] Web interface
- [ ] Progress persistence across restarts
- [ ] Auto-quality selection based on source
- [ ] Metadata preservation options

## 📄 License

This project is open source. Feel free to use and modify as needed.

## ⚠️ Disclaimer

This tool processes video files. Always keep backups of your original footage. Test with sample files before batch processing important content.

---

**Happy Flying! 🚁** 

*Optimized for DJI Avata 2 pilots who demand professional video quality*