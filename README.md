# DJI Avata 2 D-Log Video Processor

🚁 **Professional batch video processing tool for DJI Avata 2 D-Log footage**

Convert your DJI Avata 2 D-Log videos to Rec.709 color space using hardware acceleration, parallel processing, and custom LUT files. Features real-time progress tracking, ETA calculation, and multiple quality presets with intelligent multi-core utilization.

🌍 **Fully internationalized** - All interface messages in English for global accessibility

⚙️ **Comprehensive configuration system** - YAML-based configuration files for professional workflows

## ✨ Features

### 🎬 Core Processing
- **Batch Processing** - Process multiple videos automatically
- **Parallel Processing** - Multi-core utilization with auto-detection (2-4x speedup)
- **Hardware Acceleration** - Uses macOS VideoToolbox for optimal performance
- **Quality Presets** - High, Medium, Low quality options with custom settings

### ⚙️ Configuration System
- **YAML Configuration Files** - Professional workflow management
- **Multiple Config Locations** - Project-specific or user-global settings
- **Command Line Overrides** - Flexible setting precedence system
- **Auto Backup** - Automatic backup of original files before processing
- **Smart File Organization** - Date-based folder structure with custom formats

### 📊 Monitoring & Progress
- **Real-time Progress** - Visual progress bar with ETA and encoding speed
- **Time Tracking** - Individual file and total processing time with speedup metrics
- **macOS Notifications** - System alerts when processing completes
- **Verbose Logging** - Detailed logs with configurable file output
- **Performance Metrics** - Parallelization speedup calculations

### 🛡️ System Protection & Management
- **Error Handling** - Robust error handling with graceful recovery
- **Thermal Protection** - Monitor system temperature and adjust load
- **CPU Usage Control** - Configurable system resource limits
- **Smart Job Management** - Intelligent queue management and resource allocation
- **Resume Support** - Skips already processed files

### 🎯 Advanced Features
- **File Size Filtering** - Process only files within specified size ranges
- **Metadata Preservation** - Maintain original file metadata and timestamps
- **Custom FFmpeg Arguments** - Advanced encoding options for professionals
- **Multiple File Formats** - Configurable support for MP4, MOV, and more
- **Encoder Selection** - Force specific encoders or auto-detection

### 🌍 User Experience
- **Internationalized** - Clean English interface for global users
- **Color Output** - Beautiful colored terminal output
- **Comprehensive Help** - Detailed documentation and examples
- **macOS Optimized** - Built for macOS with bash 3.2 compatibility

## 🎯 Sample Output

### Sequential Mode (PARALLEL_JOBS=1)
```bash
ℹ️  📄 Loading configuration from: ./dji-config.yml
ℹ️  🚀 DJI Avata 2 D-Log Processor (Optimized) - Parallel Edition
ℹ️  Source directory: /Users/user/Movies/DJI/source
ℹ️  Output directory: /Users/user/Movies/DJI/final
ℹ️  LUT file: /Users/user/Movies/DJI/Avata2.cube
ℹ️  Quality: high
ℹ️  Parallel jobs: 1
ℹ️  💾 Auto backup enabled: /Users/user/Movies/DJI/backup
ℹ️  Found 3 files to process
ℹ️  🔄 Sequential processing (1 job at a time)

ℹ️  📁 File 1/3
ℹ️  🎞️ Processing: DJI_20250613194533_0001_D.mp4 – duration: 123s (quality: high)
🔄 [####################-----------]  68% filename.mp4 | 1.2x | ETA: 02:34

✅ Completed: DJI_20250613194533_0001_D.mp4
ℹ️  Size: 156M | Time: 08:23

🏁 Processing completed!
✅ Successfully processed: 3
⏱️  Total time: 25:47
```

### Parallel Mode (PARALLEL_JOBS>1)
```bash
ℹ️  📄 Loading configuration from: ~/.dji-processor/config.yml
ℹ️  🚀 DJI Avata 2 D-Log Processor (Optimized) - Parallel Edition
ℹ️  Source directory: /Users/user/Movies/DJI/source
ℹ️  Output directory: /Users/user/Movies/DJI/final
ℹ️  LUT file: /Users/user/Movies/DJI/Avata2.cube
ℹ️  Quality: high
ℹ️  Parallel jobs: 4
ℹ️  Found 8 files to process
ℹ️  🚀 Parallel processing (4 jobs simultaneously)

ℹ️  🚀 Starting job #1: DJI_20250613194533_0001_D.mp4
ℹ️  🚀 Starting job #2: DJI_20250613194834_0002_D.MP4
ℹ️  🚀 Starting job #3: DJI_20250709155901_0003_D.mp4
📊 Status: 2/8 completed | 3 running | 2 successful | 0 errors
✅ Completed: DJI_20250613194533_0001_D.mp4
ℹ️  🚀 Starting job #4: DJI_20250615120045_0004_D.mp4
ℹ️  ⏳ Waiting for all jobs to complete...

🏁 Processing completed!
✅ Successfully processed: 8
⏱️  Total time: 12:30
ℹ️  🚀 Speedup: ~3.2x thanks to parallelization
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
3. **Set up configuration** (recommended):
   ```bash
   # Copy sample configuration
   cp dji-config.yml ~/.dji-processor/config.yml
   
   # Edit your settings
   nano ~/.dji-processor/config.yml
   ```
4. **Prepare your files**:
   - Source videos in your configured source directory
   - LUT file (e.g., `Avata2.cube`)
5. **Run the processor**:
   ```bash
   ./avata2_dlog_optimized.sh
   ```

## ⚙️ Configuration System

### 📁 Configuration File Locations

The processor automatically looks for configuration files in this order:

1. **Current directory**: `./dji-config.yml`
2. **User home**: `~/.dji-processor/config.yml`
3. **Custom location**: `CONFIG_FILE=/path/to/config.yml`

### 🎯 Basic Configuration

Create a basic configuration file:

```yaml
# Essential settings
source_directory: "/Users/username/Movies/DJI/source"
output_directory: "/Users/username/Movies/DJI/final"
lut_file: "/Users/username/Movies/DJI/Avata2.cube"
quality_preset: "high"
parallel_jobs: "auto"

# Convenience features
skip_existing: true
preserve_timestamps: true
macos_notifications: true
```

### 🏢 Professional Configuration

For professional workflows:

```yaml
# Professional video production setup
source_directory: "/Volumes/WorkDrive/DJI/RAW"
output_directory: "/Volumes/WorkDrive/DJI/Processed"
lut_file: "/Volumes/WorkDrive/DJI/Professional-LUT.cube"

# Quality and performance
quality_preset: "high"
parallel_jobs: 4
force_encoder: "h264_videotoolbox"
custom_ffmpeg_args: "-preset slow -tune film"

# Workflow management
auto_backup: true
backup_directory: "/Volumes/BackupDrive/DJI/Originals"
organize_by_date: true
date_format: "%Y-%m-%d"

# Metadata and logging
preserve_metadata: true
add_processing_metadata: true
verbose_logging: true
log_file: "/Volumes/WorkDrive/DJI/processing.log"

# File filtering
min_file_size: 50
file_extensions:
  - "mp4"
  - "MP4"
  - "mov"
  - "MOV"
```

### 🎮 Configuration Override Examples

Configuration files can be overridden by command line arguments:

```bash
# Use config file as-is
./avata2_dlog_optimized.sh

# Override quality setting
QUALITY_PRESET=medium ./avata2_dlog_optimized.sh

# Override paths from config
./avata2_dlog_optimized.sh /custom/source /custom/output

# Use custom config file
CONFIG_FILE=./project-config.yml ./avata2_dlog_optimized.sh

# Multiple overrides
PARALLEL_JOBS=6 QUALITY_PRESET=high ./avata2_dlog_optimized.sh
```

## 📖 Usage

### Recommended: Configuration File Approach

```bash
# 1. Set up your configuration (one time)
cp dji-config.yml ~/.dji-processor/config.yml
nano ~/.dji-processor/config.yml

# 2. Run with your saved settings
./avata2_dlog_optimized.sh

# 3. Override specific settings when needed
QUALITY_PRESET=medium ./avata2_dlog_optimized.sh
```

### Traditional: Command Line Arguments

```bash
# Use built-in defaults
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
CONFIG_FILE       # Path to configuration file (default: ./dji-config.yml)
QUALITY_PRESET    # Quality: high, medium, low (default: high)
PARALLEL_JOBS     # Number of parallel jobs (default: auto-detect CPU cores)
```

| Variable | Options | Default | Description |
|----------|---------|---------|-------------|
| `CONFIG_FILE` | /path/to/config.yml | ./dji-config.yml | Configuration file location |
| `QUALITY_PRESET` | high, medium, low | high | Video encoding quality |
| `PARALLEL_JOBS` | 1, 2, 3, 4+ | auto-detect | Simultaneous video processing jobs |

**Configuration Priority:** Command line args > Environment variables > Config file > Built-in defaults

### Parallel Processing Recommendations

| System Type | Recommended PARALLEL_JOBS | Reason |
|-------------|---------------------------|---------|
| **M1/M2 MacBook Air** | 2-3 | Balance performance vs. thermal throttling |
| **M1/M2 MacBook Pro** | 3-4 | Better cooling, can handle more load |
| **M1/M2 Mac Studio/Pro** | 4-6 | High-performance systems with excellent cooling |
| **Intel Mac (4-6 cores)** | 2-3 | Limited by CPU performance |
| **Intel Mac (8+ cores)** | 3-4 | Better multi-core performance |

## 🔧 Advanced Configuration Features

### 💾 Automatic Backup System

Protect your original files with automatic backup:

```yaml
auto_backup: true
backup_directory: "/Users/username/Movies/DJI/backup"
```

When enabled, the processor creates a backup copy of each original file before processing.

### 📅 Smart File Organization

Automatically organize processed files by date:

```yaml
organize_by_date: true
date_format: "%Y-%m-%d"        # Creates folders like "2025-01-15"
```

Other date format options:
- `%Y/%m` = "2025/01" (year/month folders)
- `%Y-%m-%d_%H%M` = "2025-01-15_1430" (with time)
- `%B_%Y` = "January_2025" (month name)

### 📊 File Size Filtering

Process only files within specific size ranges:

```yaml
min_file_size: 10              # Skip files smaller than 10MB
max_file_size: 5               # Skip files larger than 5GB (0 = no limit)
```

This helps filter out corrupted files (too small) or avoid processing very large files.

### 🎯 Custom FFmpeg Arguments

Add professional encoding options:

```yaml
custom_ffmpeg_args: "-preset slow -tune film -crf 18"
force_encoder: "h264_videotoolbox"
```

For advanced users who need specific encoding parameters.

### 🔔 Notifications & Monitoring

Stay informed of processing status:

```yaml
macos_notifications: true      # System notifications when complete
completion_sound: true         # Play sound when finished
verbose_logging: true          # Detailed logging output
log_file: "/path/to/processing.log"  # Save logs to file
keep_job_logs: true           # Keep individual job logs for debugging
```

### 🛡️ System Protection

Prevent system overload during intensive processing:

```yaml
max_cpu_usage: 85             # Limit CPU usage to 85%
thermal_protection: true      # Monitor system temperature
```

The processor will automatically reduce load if your system gets too hot.

### 📋 Multiple File Format Support

Configure which file types to process:

```yaml
file_extensions:
  - "mp4"
  - "MP4"
  - "mov"
  - "MOV"
  - "m4v"
```

### 🏷️ Metadata Management

Control how metadata is handled:

```yaml
preserve_metadata: true        # Keep original metadata
preserve_timestamps: true     # Maintain file dates
add_processing_metadata: true  # Add processing information
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
│   └── 2025-01-15/         # Date-organized output (if enabled)
├── backup/                 # Auto backup of originals (if enabled)
├── Avata2.cube           # Your LUT file
├── dji-config.yml         # Configuration file (project-specific)
├── avata2_dlog_optimized.sh   # The processor script
├── CONFIG.md              # Configuration documentation
└── examples/              # Sample configuration files
    ├── basic-config.yml
    ├── professional-config.yml
    └── lightweight-config.yml

# User home directory
~/.dji-processor/
└── config.yml             # User-global configuration
```

## 🐛 Troubleshooting

### Configuration Issues

**❌ "Configuration file not loading"**
```bash
# Check if config file exists in expected locations
ls -la ./dji-config.yml
ls -la ~/.dji-processor/config.yml

# Test with custom config file
CONFIG_FILE=/path/to/my-config.yml ./avata2_dlog_optimized.sh

# Enable verbose logging to see what's happening
echo "verbose_logging: true" > test-config.yml
CONFIG_FILE=test-config.yml ./avata2_dlog_optimized.sh
```

**❌ "Invalid YAML syntax"**
```bash
# Check YAML formatting (spaces, not tabs)
# Verify quotes and colons
# Common issues:
#   - Using tabs instead of spaces
#   - Missing quotes around paths with spaces
#   - Incorrect boolean values (use true/false, not True/False)
```

**❌ "Settings not taking effect"**
```bash
# Check configuration priority:
# Command line > Environment variables > Config file > Defaults

# Test with verbose logging to see loaded settings
echo "verbose_logging: true" >> ~/.dji-processor/config.yml
./avata2_dlog_optimized.sh
```

### Common Issues

**❌ "LUT file not found"**
```bash
# Solution: Check LUT file path in config
cat ~/.dji-processor/config.yml | grep lut_file
ls -la /path/to/your/Avata2.cube
```

**❌ "Source directory not found"**
```bash
# Solution: Verify source directory in config
cat ~/.dji-processor/config.yml | grep source_directory
ls -la /path/to/your/source/directory
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
# Or force software encoding in config:
echo "force_encoder: libx264" >> ~/.dji-processor/config.yml
```

**❌ "Command not found: ffmpeg"**
```bash
# Install FFmpeg
brew install ffmpeg
```

**❌ "Auto backup failing"**
```bash
# Check backup directory permissions
ls -la /path/to/backup/directory
mkdir -p /path/to/backup/directory

# Or disable auto backup temporarily
echo "auto_backup: false" >> ~/.dji-processor/config.yml
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

### Recent Updates

- [x] ~~Parallel processing support~~ ✅ **COMPLETED** - Auto-detect cores, 2-4x speedup
- [x] ~~English internationalization~~ ✅ **COMPLETED** - All interface messages translated
- [x] ~~Configuration file system~~ ✅ **COMPLETED** - YAML-based professional workflow support

### Future Enhancements

- [ ] Multiple LUT support
- [ ] Web interface
- [ ] Progress persistence across restarts
- [ ] Auto-quality selection based on source
- [ ] GPU memory optimization for parallel processing
- [ ] Dynamic job scheduling based on system load
- [ ] Additional language support (localization framework)
- [ ] Configuration file validation and schema
- [ ] Template system for common workflows
- [ ] Integration with video editing software

## 📄 License

This project is open source. Feel free to use and modify as needed.

## ⚠️ Disclaimer

This tool processes video files. Always keep backups of your original footage. Test with sample files before batch processing important content.

## 🌍 Language & Internationalization

The script interface is fully in English, making it accessible to users worldwide. All status messages, error messages, and help text are provided in clear, professional English for maximum usability across different regions.

## 📚 Additional Documentation

- **[CONFIG.md](CONFIG.md)** - Comprehensive configuration file documentation
- **[examples/](examples/)** - Sample configuration files for different use cases
- **Built-in Help** - Run `./avata2_dlog_optimized.sh --help` for quick reference

## 🎯 Configuration Quick Reference

```bash
# Essential configuration locations
./dji-config.yml                    # Project-specific config
~/.dji-processor/config.yml        # User-global config
CONFIG_FILE=/path/to/config.yml     # Custom config location

# Sample configurations
examples/basic-config.yml           # Simple home user setup
examples/professional-config.yml    # Advanced professional workflow
examples/lightweight-config.yml     # Minimal system impact setup

# Priority order
Command line > Environment vars > Config file > Built-in defaults
```

---

**Happy Flying! 🚁** 

*Optimized for DJI Avata 2 pilots worldwide who demand professional video quality*

*Now with enterprise-grade configuration management for professional workflows*