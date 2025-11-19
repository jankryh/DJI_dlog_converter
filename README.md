# DJI D-Log Video Processor

A lightweight, high-performance shell script for applying LUTs to DJI D-Log video files using FFmpeg.

## Features

- <check> **Simple usage**: Just specify input file, output is auto-generated
- <zap> **Hardware acceleration**: Automatically detects and uses VideoToolbox (macOS), VAAPI (Linux), or NVENC
- <settings> **Quality presets**: Draft, Standard, High, Professional
- <film> **H.265 Support**: Option to use HEVC for better compression
- <database> **Metadata**: Preserves original video metadata (GPS, dates)
- <bar-chart-3> **Progress tracking**: Real-time progress bar with visual feedback
- <alert-circle> **Error handling**: Clear error messages with helpful suggestions
- <package> **Self-contained**: No external dependencies beyond FFmpeg

## Quick Start

```bash
# Make executable
chmod +x dji-processor

# Process a video (output will be video_processed.mp4)
./dji-processor video.mp4

# Specify output file
./dji-processor video.mp4 processed_video.mp4

# Use different quality and LUT
./dji-processor video.mp4 --quality high --lut ./custom.cube

# Use H.265 (HEVC) codec
./dji-processor video.mp4 --codec h265
```

## Installation

1. **Install FFmpeg**:
   ```bash
   # macOS
   brew install ffmpeg
   
   # Linux
   sudo apt-get install ffmpeg
   ```

2. **Download a LUT file** for your DJI drone (e.g., Avata2.cube)

3. **Run the script**:
   ```bash
   ./dji-processor your_video.mp4
   ```

## Usage

### Basic Usage
```bash
./dji-processor <input_file> [output_file] [options]
```

### Options
- `--lut FILE`: LUT file path (default: ./luts/Avata2.cube)
- `--quality SET`: Quality preset (draft, standard, high, professional)
- `--codec TYPE`: Video codec (h264, h265)
- `--dry-run`: Print command without executing
- `--help`: Show help message

### Examples
```bash
# Basic processing
./dji-processor video.mp4

# High quality with custom LUT
./dji-processor video.mp4 --quality high --lut ./luts/custom.cube

# Process multiple files
for file in *.mp4; do
    ./dji-processor "$file"
done
```

### Environment Variables
```bash
export LUT_FILE="./luts/Avata2.cube"    # Default LUT file
export QUALITY="standard"                # Default quality
export CODEC="h264"                      # Default codec
export OUTPUT_SUFFIX="_processed"        # Output file suffix
```

## Quality Presets

| Preset | Description | Use Case |
|--------|-------------|----------|
| `draft` | Fastest encoding, lower quality | Quick previews |
| `standard` | Balanced quality and speed | General use |
| `high` | Better quality, slower | Final output |
| `professional` | Best quality, slowest | Professional work |

## Hardware Acceleration

The script automatically detects and uses the best available hardware acceleration:

- **macOS**: VideoToolbox (h264_videotoolbox)
- **Linux**: VAAPI (h264_vaapi) or NVENC (h264_nvenc)
- **Fallback**: Software encoding (libx264)


## Troubleshooting

### Common Issues

1. **"LUT file not found"**
   ```bash
   # Download a LUT file for your DJI drone
   # Or specify with --lut option
   ./dji-processor video.mp4 --lut /path/to/your/lut.cube
   ```

2. **"Missing dependencies"**
   ```bash
   # Install FFmpeg
   brew install ffmpeg  # macOS
   sudo apt-get install ffmpeg  # Linux
   ```

3. **"Cannot read video duration"**
   - Check if the input file is a valid video
   - Ensure the file isn't corrupted
   - Try with a different video file

### Getting Help
```bash
./dji-processor --help
```

## License

This script is provided as-is for processing DJI D-Log videos. Use at your own risk.

## Contributing

This is a simplified version focused on core functionality. For feature requests or bug reports, please ensure they align with the goal of keeping the script simple and lightweight.
