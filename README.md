# o3utl

This is a command execution helper tool that simplifies media encoding and other command-line workflows. You can register commands as reusable tasks in advance and execute them through an command-line interface. Tasks can be customized by editing tasks.ini to fit your specific needs.

## Requirements

### System Requirements
- Windows 10/11
- PowerShell
- NVIDIA RTX40,50+ (for most of default presets)

### Essential for default tasks
- **FFmpeg**
  - Download FFmpeg from: https://www.gyan.dev/ffmpeg/builds/
  - Create a `bin` folder inside the `o3utl` directory
  - Extract and copy `ffmpeg.exe` to the `o3utl/bin/`
  - All default presets run bin/ffmpeg.exe. If you want to use your own ffmpeg, modify the commands written in tasks.ini
  - File structure:
    ```
    o3utl/
    ├── bin/
    │   └── ffmpeg.exe
    ├── src/
    │   └── core.ps1
    ├── o3utl.bat
    └── tasks.ini
    ```

## Usage

1. **Basic Usage**
   
   Drop input file onto o3utl.bat

2. **Command Line**
   ```batch
   o3utl.bat "input_path" [task_name]
   ```

3. **Interactive Mode**
   - When no profile is specified, available tasks are listed
   - Select multiple tasks with comma-separated numbers (e.g., `1,3,5`)

## Write Tasks

Edit `tasks.ini` to add your own tasks:

```ini
[Task-Name]
cmd = your_command "{INPUT}" output_options
```

Example:
```ini
[Custom-Encode]
cmd = bin\ffmpeg.exe -i "{INPUT}" -crf 23 "{INPUT_BASE}_task1.mp4"
```

- `{INPUT}` is replaced with your file path
- `{INPUT_BASE}` is replaced with your input filename without extension

## Built-in Tasks

### General Encoding

#### AV1
- `FFmpeg_SVTAV1` - AV1 10-bit (CRF-based)  
  Modern codec with excellent compression efficiency, though less compatible than H.264

- `FFmpeg_AOMAV1_mst` - AV1 10-bit mastering quality (CRF-based)  
  libaom-av1 encoder with high-quality settings optimized for mastering

#### H.264/AVC
- `FFmpeg_MPEG-4-AVC_Proxy` - H.264 lightweight proxy (VBR)  
  Fast preview encoding for editing workflows

- `FFmpeg_MPEG-4-AVC` - H.264 standard quality (constQP)  
  Recommended general-purpose preset for most use cases

- `FFmpeg_MPEG-4-AVC_from_MMD_rgb` - H.264 with RGB color preservation (constQP)  
  Specialized preset for MMD content, maintains accurate color conversion from RGB to YUV

- `FFmpeg_MPEG-4-AVC_XQ` - H.264 extra quality (constQP)  
  Higher quality encoding with lower QP values

- `FFmpeg_MPEG-4-AVC_ultra` - H.264 ultra quality (constQP)  
  Maximum quality preset with minimal compression

- `FFmpeg_MPEG-4-AVC_1440p_LT` - H.264 1440p standard bitrate  
  Downscaled output with moderate bitrate allocation

- `FFmpeg_MPEG-4-AVC_1440p_HQ` - H.264 1440p high bitrate  
  Downscaled output with higher bitrate allocation

#### H.265/HEVC
- `FFmpeg_HEVC_Proxy` - H.265 lightweight proxy (VBR)  
  Efficient preview encoding with improved compression over H.264

- `FFmpeg_HEVC` - H.265 standard quality (constQP)  
  Better compression efficiency than H.264 at similar quality levels

- `FFmpeg_HEVC_XQ` - H.265 extra quality (constQP)  
  Higher quality with enhanced detail preservation

- `FFmpeg_HEVC_1440p_LT` - H.265 1440p standard bitrate  
  Efficient 1440p encoding with moderate file sizes

- `FFmpeg_HEVC_1440p_HQ` - H.265 1440p high bitrate  
  Higher bitrate 1440p encoding with enhanced quality

### Platform-Optimized Encoding

#### Iwara Platform Presets
- `FFmpeg_Iwara_2160p60fps` - H.264 4K 60fps  
  Optimized for Iwara's 4K high framerate tier

- `FFmpeg_Iwara_2160p30fps` - H.264 4K 30fps  
  Optimized for Iwara's 4K standard framerate tier

- `FFmpeg_Iwara_1440p60fps` - H.264 1440p 60fps  
  Balanced quality and file size for smooth playback

- `FFmpeg_Iwara_1440p30fps` - H.264 1440p 30fps  
  Standard 1440p encoding for efficient streaming

- `FFmpeg_Iwara_1080p60fps` - H.264 1080p 60fps  
  High framerate Full HD preset

- `FFmpeg_Iwara_1080p24fps` - H.264 1080p 24fps  
  Cinematic framerate Full HD preset

- `FFmpeg_Iwara_720p60fps` - H.264 720p 60fps  
  Smooth motion HD preset

- `FFmpeg_Iwara_720p30fps` - H.264 720p 30fps  
  Standard HD streaming preset

#### Social Media Presets
- `FFmpeg_for_X` - H.264 720p for X/Twitter  
  5-25 Mbps VBR encoding optimized for Twitter's requirements

- `FFmpeg_AV1_720p_webm` - WebM AV1 720p  
  For Iwara's image category uploads (WebM format enables video posting in image sections)

- `FFmpeg_AV1_1440p_webm` - WebM AV1 1440p  
  Higher resolution WebM output with AV1 compression
