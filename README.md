# o3utl

This is a command execution helper tool that simplifies media encoding and other command-line workflows. You can register commands as reusable tasks in advance and execute them through an command-line interface. Tasks can be customized by editing tasks.ini to fit your specific needs.

## Requirements

### System Requirements
- Windows 10/11
- PowerShell
- NVIDIA RTX40,50+ (for all of default presets)

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

## Built-in Tasks

### General Encoding with FFmpeg
- `FFmpeg-HEVC-Proxy` - HEVC proxy for preview (vbr)
- `FFmpeg-HEVC-LT` - High quality HEVC (constqp)
- `FFmpeg-HEVC-XQ` - Extra high quality HEVC (constqp)
- `FFmpeg-H264-Proxy` - H.264 proxy for preview (vbr)
- `FFmpeg-H264-LT` - High quality H.264 (constqp)  **Recommended for most cases**
- `FFmpeg-H264-LT_from_MMD-rgb` - High quality H.264 (constqp)  **For MMD users, converts RGB to YUV preserving original colors**
- `FFmpeg-H264-XQ` - Extra high quality H.264 (constqp)
- `FFmpeg-HEVC-1440p-LT` - HEVC 1440p (bitrate)
- `FFmpeg-HEVC-1440p-XQ` - HEVC 1440p high quality (bitrate)
- `FFmpeg-H264-1440p-LT` - H.264 1440p (bitrate)
- `FFmpeg-H264-1440p-XQ` - H.264 1440p high quality (bitrate)
- `FFmpeg-H264-ultra` - Ultra high quality H.264 (constqp)
- `FFmpeg-AV1-720p` - AV1 720p (constqp)

### Platform Optimized Encoding with FFmpeg
- `FFmpeg-Iwara-2160p60fps` - H.264 4K 60fps for Iwara
- `FFmpeg-Iwara-2160p30fps` - H.264 4K 30fps for Iwara
- `FFmpeg-Iwara-1440p60fps` - H.264 1440p 60fps for Iwara
- `FFmpeg-Iwara-1440p30fps` - H.264 1440p 30fps for Iwara
- `FFmpeg-Iwara-1080p60fps` - H.264 1080p 60fps for Iwara
- `FFmpeg-Iwara-1080p24fps` - H.264 1080p 24fps for Iwara
- `FFmpeg-Iwara-720p60fps` - H.264 720p 60fps for Iwara
- `FFmpeg-Iwara-720p30fps` - H.264 720p 30fps for Iwara
- `FFmpeg-for-X` - H.264 720p 5000k-25000kbps AAC 128k for X
