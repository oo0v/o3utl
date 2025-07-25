# o3utl

This is a very simple Utility tool. You can register commands as tasks in advance and select them from the CUI to encode media in order. Tasks can be added or modified by editing tasks.ini.

## Setup

### FFmpeg Installation
1. Download FFmpeg (gyan build) from: https://www.gyan.dev/ffmpeg/builds/
2. Extract the downloaded archive
3. Copy `ffmpeg.exe` to the `o3utl/bin/`
4. The file structure should look like:
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

3. **Command Line**
   ```batch
   o3utl.bat "input_path" [task_name]
   ```

4. **Interactive Mode**
   - When no profile is specified, available tasks are listed
   - Select multiple tasks with comma-separated numbers (e.g., `1,3,5`)

## Built-in Presets

### General Encoding
- `FFmpeg-HEVC-Proxy` - HEVC proxy for preview (vbr)
- `FFmpeg-HEVC-LT` - High quality HEVC (constqp)
- `FFmpeg-HEVC-XQ` - Extra high quality HEVC (constqp)
- `FFmpeg-H264-Proxy` - H.264 proxy for preview (vbr)
- `FFmpeg-H264-LT` - High quality H.264 (constqp) **[Recommended for most cases]**
- `FFmpeg-H264-XQ` - Extra high quality H.264 (constqp)
- `FFmpeg-HEVC-1440p-LT` - HEVC 1440p (bitrate)
- `FFmpeg-HEVC-1440p-XQ` - HEVC 1440p high quality (bitrate)
- `FFmpeg-H264-1440p-LT` - H.264 1440p (bitrate)
- `FFmpeg-H264-1440p-XQ` - H.264 1440p high quality (bitrate)
- `FFmpeg-H264-ultra` - Ultra high quality H.264 (constqp)
- `FFmpeg-AV1-720p` - AV1 720p (constqp)

### Platform Optimized
- `FFmpeg-Iwara-2160p60fps` - H.264 4K 60fps for Iwara
- `FFmpeg-Iwara-2160p30fps` - H.264 4K 30fps for Iwara
- `FFmpeg-Iwara-1440p60fps` - H.264 1440p 60fps for Iwara
- `FFmpeg-Iwara-1440p30fps` - H.264 1440p 30fps for Iwara
- `FFmpeg-Iwara-1080p60fps` - H.264 1080p 60fps for Iwara
- `FFmpeg-Iwara-1080p24fps` - H.264 1080p 24fps for Iwara
- `FFmpeg-Iwara-720p60fps` - H.264 720p 60fps for Iwara
- `FFmpeg-Iwara-720p30fps` - H.264 720p 30fps for Iwara
- `FFmpeg-for-X` - H.264 1080p 30fps for X (Twitter)

## Requirements

### Essential
- **FFmpeg**
  - Download FFmpeg and place `ffmpeg.exe` in the `o3utl/bin/` directory
  - All default presets run bin/ffmpeg.exe. If you want to use your own ffmpeg, modify the commands written in tasks.ini

### System Requirements
- Windows 10/11
- PowerShell
- NVIDIA RTX40,50+ (for all default presets)
