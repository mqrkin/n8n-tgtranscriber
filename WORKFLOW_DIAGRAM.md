# Workflow Architecture Diagram

## Visual Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    TELEGRAM AUDIO TRANSCRIPTION PIPELINE                         │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   Telegram   │  User sends audio/video
│     User     │  ────────────────────────────────┐
└──────────────┘                                  │
                                                  ▼
                                        ┌─────────────────┐
                                        │   Puzzlebot     │
                                        │   (Proxy)       │
                                        └────────┬────────┘
                                                 │ File metadata
                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                             STEP 1: FILE RETRIEVAL                              │
└────────────────────────────────────────────────────────────────────────────────┘
                                        ┌─────────────────┐
                                        │    Webhook      │
                                        │   Puzzlebot     │
                                        └────────┬────────┘
                                                 │ POST request
                                                 ▼
                                        ┌─────────────────┐
                                        │  Telegram Get   │
                                        │    FileID       │ → Calls Telegram Bot API
                                        └────────┬────────┘
                                                 │ file_path, user_id
                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                         STEP 2: PATH GENERATION                                 │
└────────────────────────────────────────────────────────────────────────────────┘
                                        ┌─────────────────┐
                                        │   Code Node     │
                                        │  (Build Paths)  │
                                        └────────┬────────┘
                                                 │
                                    ┌────────────┴────────────┐
                                    │ Output:                 │
                                    │ • absPath (cache)       │
                                    │ • inPath (/tmp/in)      │
                                    │ • outPath (/tmp/out)    │
                                    │ • objectKey (S3 key)    │
                                    └────────────┬────────────┘
                                                 │
                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                       STEP 3: AUDIO EXTRACTION                                  │
└────────────────────────────────────────────────────────────────────────────────┘
                                        ┌─────────────────┐
                                        │  FFmpeg Node    │
                                        │   (Execute)     │
                                        └────────┬────────┘
                                                 │
                                    ┌────────────┴────────────┐
                                    │ Convert to:             │
                                    │ • 16kHz sample rate     │
                                    │ • Mono (1 channel)      │
                                    │ • 64kbps MP3            │
                                    └────────────┬────────────┘
                                                 │
                                                 ▼
                                        ┌─────────────────┐
                                        │  Read File      │
                                        │   from Disk     │
                                        └────────┬────────┘
                                                 │ Binary MP3 data
                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                          STEP 4: CLOUD UPLOAD                                   │
└────────────────────────────────────────────────────────────────────────────────┘
                                        ┌─────────────────┐
                                        │  Merge Node     │
                                        │ (File + Meta)   │
                                        └────────┬────────┘
                                                 │
                                                 ▼
                                        ┌─────────────────┐
                                        │  S3/Spaces      │
                                        │    Upload       │ → ACL: public-read
                                        └────────┬────────┘
                                                 │ Upload success
                                                 ▼
                                        ┌─────────────────┐
                                        │  Merge Node     │
                                        │ (Upload + Meta) │
                                        └────────┬────────┘
                                                 │
                                                 ▼
                                        ┌─────────────────┐
                                        │  Build DO URL   │
                                        │   Code Node     │
                                        └────────┬────────┘
                                                 │
                                    ┌────────────┴────────────────┐
                                    │ Public URL:                 │
                                    │ https://bucket.endpoint/key │
                                    └────────────┬────────────────┘
                                                 │
                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                      STEP 5: SPEECH-TO-TEXT (REPLICATE)                        │
└────────────────────────────────────────────────────────────────────────────────┘
                                        ┌─────────────────┐
                                        │  To Replicate   │
                                        │  (HTTP POST)    │
                                        └────────┬────────┘
                                                 │
                                    ┌────────────┴────────────────┐
                                    │ Request to Replicate:       │
                                    │ • Model: Whisper           │
                                    │ • Input: audio_url         │
                                    │ • Webhook: /replicate-webh │
                                    └────────────┬────────────────┘
                                                 │
                                          [Async Processing]
                                        Replicate processes audio
                                          ⏰ 30-120 seconds
                                                 │
                                                 ▼
                                        ┌─────────────────┐
                                        │ Replicate-webh  │
                                        │   (Webhook)     │
                                        └────────┬────────┘
                                                 │ Raw transcription
                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                      STEP 6: TEXT FORMATTING (GPT)                             │
└────────────────────────────────────────────────────────────────────────────────┘
                                        ┌─────────────────┐
                                        │  Chat-GPT       │
                                        │  Formatting     │
                                        └────────┬────────┘
                                                 │
                                    ┌────────────┴────────────────┐
                                    │ GPT Processing:             │
                                    │ • Fix grammar               │
                                    │ • Remove fillers            │
                                    │ • Add punctuation           │
                                    │ • Keep original language    │
                                    └────────────┬────────────────┘
                                                 │
                                          [Async Processing]
                                        GPT processes text
                                          ⏰ 5-15 seconds
                                                 │
                                                 ▼
                                        ┌─────────────────┐
                                        │  Repl-chatgpt   │
                                        │   (Webhook)     │
                                        └────────┬────────┘
                                                 │ Formatted text
                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                        STEP 7: SEND TO USER                                     │
└────────────────────────────────────────────────────────────────────────────────┘
                                        ┌─────────────────┐
                                        │ Send to         │
                                        │   Telegram      │
                                        └────────┬────────┘
                                                 │ sendMessage API call
                                                 ▼
                                        ┌─────────────────┐
                                        │   Telegram      │
                                        │     User        │ ← Receives transcript
                                        └─────────────────┘

```

## Node Details

### Input Phase
| Node | Type | Purpose | Output |
|------|------|---------|--------|
| **Webhook Puzzlebot** | Webhook | Receives file notifications from Telegram proxy | `file_id`, `user_id` |
| **Telegram Get FileID** | HTTP Request | Retrieves file metadata from Telegram Bot API | `file_path`, complete file info |

### Processing Phase
| Node | Type | Purpose | Output |
|------|------|---------|--------|
| **Code** | JavaScript | Generates file paths and S3 key | `absPath`, `inPath`, `outPath`, `objectKey` |
| **ffmpeg** | Execute Command | Extracts audio as 16kHz mono MP3 | MP3 file in `/tmp` |
| **Read/Write Files from Disk1** | File I/O | Loads MP3 into n8n data stream | Binary MP3 data |

### Storage Phase
| Node | Type | Purpose | Output |
|------|------|---------|--------|
| **Merge** | Merge | Combines file data with metadata | Unified data object |
| **Spaces (S3) Upload** | AWS S3 | Uploads MP3 with public-read ACL | Upload confirmation |
| **Merge1** | Merge | Combines upload result with metadata | Complete upload info |
| **Build DO URL** | JavaScript | Constructs public audio URL | `audio_url` |

### AI Processing Phase
| Node | Type | Purpose | Output |
|------|------|---------|--------|
| **To Replicate** | HTTP Request | Initiates Whisper transcription | Prediction ID |
| **Replicate-webh** | Webhook | Receives transcription result | Raw transcript text |
| **Chat-GPT Formatting** | HTTP Request | Formats transcript with GPT | Prediction ID |
| **Repl-chatgpt** | Webhook | Receives formatted text | Clean transcript |

### Output Phase
| Node | Type | Purpose | Output |
|------|------|---------|--------|
| **Send to Telegram** | HTTP Request | Sends transcript to user | API response |

## Data Flow

### 1. Initial Webhook Payload
```json
{
  "file_id": "BAADAQADZwAD...",
  "user_id": 123456789
}
```

### 2. After File Info Retrieval
```json
{
  "file_path": "/var/lib/telegram-bot-api/documents/video_123.mp4",
  "file_size": 5242880,
  "user_id": 123456789
}
```

### 3. After Path Generation
```json
{
  "absPath": "/data/tg-cache/documents/video_123.mp4",
  "inPath": "/tmp/audio_in_123456789_1699999999",
  "outPath": "/tmp/audio_out_123456789_1699999999.mp3",
  "objectKey": "transcriptions/123456789/1699999999.mp3",
  "userId": 123456789
}
```

### 4. After S3 Upload
```json
{
  "audio_url": "https://bucket.nyc3.digitaloceanspaces.com/transcriptions/123456789/1699999999.mp3",
  "userId": 123456789
}
```

### 5. After Transcription
```json
{
  "transcription": "um so like today we're gonna uh discuss the uh quarterly results and stuff",
  "userId": 123456789
}
```

### 6. After Formatting
```json
{
  "formatted_text": "Today we're going to discuss the quarterly results.",
  "userId": 123456789
}
```

## Timing Breakdown

| Phase | Duration | Notes |
|-------|----------|-------|
| File Retrieval | 0.5-2s | Telegram API response |
| Audio Extraction | 2-10s | Depends on video length |
| S3 Upload | 1-5s | Depends on file size and network |
| STT (Whisper) | 30-120s | Async via Replicate webhook |
| GPT Formatting | 5-15s | Async via Replicate webhook |
| Telegram Reply | 0.5-1s | API call |
| **Total** | **39-153s** | Mostly async processing |

## Error Handling

The workflow includes implicit error handling:

- **FFmpeg failure**: Returns exit code, caught by n8n
- **S3 upload failure**: Returns error status, workflow stops
- **Replicate timeout**: 5-minute timeout, webhook never called
- **Telegram send failure**: Returns API error

For production, consider adding:
- Error notification nodes
- Retry logic for failed uploads
- Fallback mechanisms for Replicate failures
- User notification for long-running jobs

## Scalability Considerations

### Bottlenecks
1. **FFmpeg processing**: CPU-bound, synchronous
2. **S3 upload**: Network-bound, synchronous
3. **Replicate queue**: External service, can be slow during peak

### Solutions
- Use faster storage (NVMe SSD for `/tmp`)
- Implement queueing for high volume
- Add multiple n8n instances behind load balancer
- Use CDN for faster audio delivery to Replicate
- Consider self-hosting Whisper for lower latency

## Security Flow

```
User → Telegram Bot → Puzzlebot → n8n Webhook
                                     ↓
                              [Authentication]
                                     ↓
                         Environment Variables
                                     ↓
                    ┌────────────────┴────────────────┐
                    ↓                                  ↓
              S3 Credentials                    Replicate Token
        (public-read ACL only)              (webhook verification)
```

- All secrets stored in environment variables
- S3 files are public-read (required for Replicate)
- Webhook endpoints should be secured (add auth tokens)
- User data namespaced by `user_id` in S3

## Monitoring Points

Key metrics to track:

1. **Webhook response time** (should be <100ms)
2. **FFmpeg processing time** (alert if >30s)
3. **S3 upload success rate** (target 99.9%)
4. **Replicate callback time** (median ~60s)
5. **End-to-end latency** (from upload to reply)
6. **Storage usage** (MP3 files accumulate)
7. **Cost per transcription** (~$0.002-0.003)

Add monitoring with n8n's execution logs and external APM tools.