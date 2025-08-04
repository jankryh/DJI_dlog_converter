# DJI Video Processor Configuration Guide

🔧 **Comprehensive configuration file support for the DJI Avata 2 D-Log Video Processor**

## 🚀 Quick Start

1. **Copy the sample configuration:**
   ```bash
   cp dji-config.yml ~/.dji-processor/config.yml
   ```

2. **Edit your settings:**
   ```bash
   nano ~/.dji-processor/config.yml
   ```

3. **Run the processor:**
   ```bash
   ./avata2_dlog_optimized.sh
   ```

## 📁 Configuration File Locations

The processor looks for configuration files in this order:

1. **Current directory:** `./dji-config.yml`
2. **User home:** `~/.dji-processor/config.yml`
3. **Custom location:** Set `CONFIG_FILE` environment variable

```bash
# Use custom config file
CONFIG_FILE=/path/to/my-config.yml ./avata2_dlog_optimized.sh
```

## ⚙️ Configuration Sections

### 🎯 Essential Settings

```yaml
# Core paths and settings
source_directory: "/Users/username/Movies/DJI/source"
output_directory: "/Users/username/Movies/DJI/final"
lut_file: "/Users/username/Movies/DJI/Avata2.cube"
quality_preset: "high"           # high, medium, low
parallel_jobs: "auto"            # auto, 1-8, or specific number
```

### 💾 Backup & Organization

```yaml
# Automatic backup of original files
auto_backup: true
backup_directory: "/Users/username/Movies/DJI/backup"

# Organize output files by date
organize_by_date: true
date_format: "%Y-%m-%d"          # 2025-01-15 format

# Skip files that already exist
skip_existing: true
```

### 🎬 Video Processing

```yaml
# Force specific encoder
force_encoder: "h264_videotoolbox"  # auto, h264_videotoolbox, libx264

# Custom FFmpeg arguments for advanced users
custom_ffmpeg_args: "-preset slow -tune film"

# Metadata handling
preserve_metadata: true
preserve_timestamps: true
add_processing_metadata: false
```

### 📏 File Filtering

```yaml
# File size constraints
min_file_size: 10                # Minimum size in MB
max_file_size: 0                 # Maximum size in GB (0 = no limit)

# Supported file extensions
file_extensions:
  - "mp4"
  - "MP4"
  - "mov"
  - "MOV"
```

### 🔔 Notifications & Monitoring

```yaml
# macOS notifications and sounds
macos_notifications: true
completion_sound: true

# Logging options
verbose_logging: false
log_file: ""                     # Path to log file (empty = no logging)
keep_job_logs: false            # Keep individual job logs for debugging
```

### ⚡ Performance Tuning

```yaml
# System resource management
max_cpu_usage: 90               # Percentage (1-100)
thermal_protection: true       # Pause if system gets hot
```

## 📋 Example Configurations

### 🏠 Home User (Basic)

```yaml
source_directory: "/Users/john/Movies/DJI/source"
output_directory: "/Users/john/Movies/DJI/final"
lut_file: "/Users/john/Movies/DJI/Avata2.cube"
quality_preset: "medium"
parallel_jobs: "auto"
skip_existing: true
preserve_timestamps: true
macos_notifications: true
```

### 🎬 Professional (Advanced)

```yaml
source_directory: "/Volumes/WorkDrive/DJI/RAW"
output_directory: "/Volumes/WorkDrive/DJI/Processed"
lut_file: "/Volumes/WorkDrive/DJI/Professional-LUT.cube"
quality_preset: "high"
parallel_jobs: 4
auto_backup: true
backup_directory: "/Volumes/BackupDrive/DJI/Originals"
organize_by_date: true
date_format: "%Y-%m-%d"
preserve_metadata: true
add_processing_metadata: true
force_encoder: "h264_videotoolbox"
custom_ffmpeg_args: "-preset slow -tune film"
verbose_logging: true
log_file: "/Volumes/WorkDrive/DJI/processing.log"
min_file_size: 50
thermal_protection: true
```

### 💨 Lightweight (Quick Processing)

```yaml
source_directory: "/Users/sarah/Downloads"
output_directory: "/Users/sarah/Videos/DJI"
lut_file: "/Users/sarah/Videos/Avata2.cube"
quality_preset: "low"
parallel_jobs: 2
skip_existing: true
auto_backup: false
organize_by_date: false
preserve_metadata: false
preserve_timestamps: true
max_file_size: 3
macos_notifications: true
completion_sound: false
max_cpu_usage: 70
```

## 🔄 Command Line Overrides

Configuration file settings can be overridden:

```bash
# Override paths
./avata2_dlog_optimized.sh /custom/source /custom/output

# Override quality
QUALITY_PRESET=medium ./avata2_dlog_optimized.sh

# Override parallel jobs
PARALLEL_JOBS=4 ./avata2_dlog_optimized.sh

# Combine overrides
QUALITY_PRESET=high PARALLEL_JOBS=6 ./avata2_dlog_optimized.sh /my/source
```

## 🎯 Configuration Priority

Settings are applied in this order (highest priority first):

1. **Command line arguments**
2. **Environment variables**
3. **Configuration file**
4. **Built-in defaults**

## 🛠️ Advanced Features

### 📝 Verbose Logging

Enable detailed logging to see what the processor is doing:

```yaml
verbose_logging: true
log_file: "/path/to/processing.log"
keep_job_logs: true
```

This will show:
- Configuration details
- File filtering decisions
- Encoder choices
- Performance metrics

### 🔔 System Integration

#### macOS Notifications
```yaml
macos_notifications: true       # Show notification when complete
completion_sound: true          # Play sound when done
```

#### Thermal Management
```yaml
thermal_protection: true       # Monitor system temperature
max_cpu_usage: 85              # Limit CPU usage to prevent overheating
```

### 📊 File Organization

Automatically organize processed files by date:

```yaml
organize_by_date: true
date_format: "%Y-%m-%d"        # Creates folders like "2025-01-15"
# Other formats:
# "%Y/%m" = "2025/01"
# "%Y-%m-%d_%H%M" = "2025-01-15_1430"
```

## 🐛 Troubleshooting

### Configuration Not Loading
```bash
# Check if config file exists
ls -la ./dji-config.yml
ls -la ~/.dji-processor/config.yml

# Test with verbose logging
echo "verbose_logging: true" > test-config.yml
CONFIG_FILE=test-config.yml ./avata2_dlog_optimized.sh
```

### Invalid Settings
- Check YAML syntax (spaces, not tabs)
- Verify file paths exist
- Ensure numeric values are not quoted
- Check boolean values: `true`/`false` (lowercase)

### Performance Issues
```yaml
# Reduce system load
parallel_jobs: 2
max_cpu_usage: 70
thermal_protection: true

# Skip large files
max_file_size: 5
```

## 📚 Reference

### File Extensions
```yaml
file_extensions:
  - "mp4"      # Standard MP4
  - "MP4"      # Uppercase
  - "mov"      # QuickTime
  - "MOV"      # Uppercase QuickTime
  - "m4v"      # iTunes video (if supported)
```

### Date Formats
| Format | Output | Description |
|--------|---------|-------------|
| `%Y-%m-%d` | 2025-01-15 | ISO date format |
| `%Y/%m/%d` | 2025/01/15 | Folder hierarchy |
| `%Y-%m` | 2025-01 | Month folders |
| `%B_%Y` | January_2025 | Month name |

### Quality Presets
| Preset | Bitrate | Best For |
|--------|---------|----------|
| `high` | 15 Mbps | Archive, editing |
| `medium` | 10 Mbps | General use |
| `low` | 6 Mbps | Web, mobile |

---

**🎥 Happy Processing!** 

*For more help, run: `./avata2_dlog_optimized.sh --help`*