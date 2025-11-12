# Telegram Audio Transcription Pipeline

A complete n8n workflow that processes Telegram audio/video files, extracts audio, uploads to S3-compatible storage, transcribes using Replicate's Whisper model, formats the transcription with GPT, and sends the result back to the user via Telegram.

## Architecture Overview

```
Telegram Bot → Webhook → File Retrieval → FFmpeg Audio Extraction
    ↓
S3/Spaces Upload → Public URL Generation
    ↓
Replicate STT (Whisper) → GPT Formatting
    ↓
Telegram Message Reply
```

## Features

- **Audio/Video Processing**: Automatic extraction of audio from video files using FFmpeg
- **Cloud Storage**: Upload processed audio to DigitalOcean Spaces (S3-compatible)
- **Speech-to-Text**: High-quality transcription using Replicate's Whisper model
- **Text Formatting**: AI-powered cleanup and formatting using GPT models
- **Telegram Integration**: Seamless user experience with automatic replies
- **Docker Support**: Complete containerized setup with n8n and PostgreSQL

## Prerequisites

- Docker and Docker Compose installed
- Telegram Bot Token (from [@BotFather](https://t.me/botfather))
- DigitalOcean Spaces or S3-compatible storage account
- Replicate API account and token
- (Optional) Local Telegram Bot API server for large file support

## Quick Start

### 1. Clone and Setup Environment

```bash
# Create project directory
mkdir telegram-transcription && cd telegram-transcription

# Copy workflow files (docker-compose.yaml, Dockerfile.n8n, workflow.json)
# Copy this README.md and .env.example
cp .env.example .env
```

### 2. Configure Environment Variables

Edit `.env` file with your credentials:

```bash
# Required: Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
TELEGRAM_API_URL=https://api.telegram.org  # or your local bot API URL

# Required: DigitalOcean Spaces / S3 Configuration
DO_SPACES_KEY=your_spaces_access_key
DO_SPACES_SECRET=your_spaces_secret_key
DO_SPACES_BUCKET=your-bucket-name
DO_SPACES_ENDPOINT=nyc3.digitaloceanspaces.com
DO_SPACES_REGION=nyc3
DO_CDN_DOMAIN=  # Optional: your CDN domain if using one

# Required: Replicate API
REPLICATE_API_TOKEN=your_replicate_api_token

# Optional: OpenAI (if using via Replicate)
OPENAI_API_KEY=your_openai_key_if_needed

# Optional: Local Telegram Bot API
TELEGRAM_API_ID=your_api_id
TELEGRAM_API_HASH=your_api_hash
```

### 3. Start Services

```bash
# Build and start all services
docker-compose up -d

# Check logs
docker-compose logs -f n8n

# Access n8n UI at http://localhost:5678
# Default credentials: admin / changeme
```

### 4. Import Workflow

1. Open n8n at http://localhost:5678
2. Login with credentials (admin / changeme)
3. Click "Import from File"
4. Select `workflow.json`
5. Activate the workflow

### 5. Configure Credentials

#### DigitalOcean Spaces Credentials

1. In n8n, go to **Credentials** menu
2. Click **Add Credential** → **AWS**
3. Name: "DigitalOcean Spaces"
4. Configure:
   - **Access Key ID**: Your Spaces access key
   - **Secret Access Key**: Your Spaces secret key
   - **Region**: Your region (e.g., nyc3)
   - **Custom Endpoints**: Enable
   - **S3 Endpoint**: Your Spaces endpoint (e.g., nyc3.digitaloceanspaces.com)

#### Replicate API Credentials

1. In n8n, go to **Credentials** menu
2. Click **Add Credential** → **HTTP Header Auth**
3. Name: "Replicate API"
4. Configure:
   - **Name**: `Authorization`
   - **Value**: `Token YOUR_REPLICATE_API_TOKEN`

### 6. Configure Webhook URL

1. In the workflow, update webhook nodes with your public URL:
   - Replace `http://localhost:5678` with your public domain
   - Or use a tunneling service like ngrok for testing

2. Set up webhook in your Telegram bot via Puzzlebot or similar proxy service

## Workflow Details

### Node Breakdown

| Node | Type | Purpose |
|------|------|---------|
| **Webhook Puzzlebot** | Webhook | Receives Telegram file notifications |
| **Telegram Get FileID** | HTTP Request | Retrieves file metadata from Telegram API |
| **Code** | Code | Builds file paths and generates unique identifiers |
| **ffmpeg** | Execute Command | Extracts audio as mono 16kHz MP3 |
| **Read/Write Files from Disk1** | Read/Write File | Reads generated MP3 file |
| **Merge** | Merge | Combines file data with metadata |
| **Spaces (S3) Upload** | AWS S3 | Uploads MP3 to cloud storage with public ACL |
| **Merge1** | Merge | Combines upload response with metadata |
| **Build DO URL** | Code | Constructs public URL for audio file |
| **To Replicate** | HTTP Request | Sends audio to Replicate Whisper STT |
| **Replicate-webh** | Webhook | Receives transcription result |
| **Chat-GPT Formatting** | HTTP Request | Formats transcript via GPT model |
| **Repl-chatgpt** | Webhook | Receives formatted text |
| **Send to Telegram** | HTTP Request | Sends final result to user |

### File Processing Flow

1. **Input**: User sends audio/video to Telegram bot
2. **Proxy**: Puzzlebot forwards file metadata to n8n webhook
3. **Download**: n8n retrieves file from Telegram Bot API cache
4. **Extract**: FFmpeg converts to mono 16kHz 64kbps MP3
5. **Upload**: MP3 uploaded to DigitalOcean Spaces with public access
6. **Transcribe**: Replicate Whisper processes audio URL
7. **Format**: GPT model cleans and formats the transcript
8. **Reply**: Formatted text sent back to user

## Configuration Options

### Replicate Models

The workflow uses two Replicate models:

#### Speech-to-Text Model (Whisper)
```javascript
// Default model version in workflow
"stt_model_version": "b9fd8a4dcae7b1f199b32d9c8953b2e187a1cf8e23ee04707b3f8c743b8a2e78"

// Popular alternatives:
// Whisper Large V3: "4d50797290df275329f202e48c76360b3f22b08d28c196cbc54600319435f8d2"
```

#### GPT Formatting Model
```javascript
// Configure in Chat-GPT Formatting node
"gpt_model_version": "your-preferred-gpt-model-version"

// System prompt (customizable):
"You are a transcription editor. Your task: 
1) Keep the original language. 
2) Fix punctuation, grammar, and structure. 
3) Remove filler words (um, uh, like). 
4) Output ONLY the cleaned text in a single block."
```

### FFmpeg Audio Settings

Default configuration in the workflow:

```bash
ffmpeg -i {input} -vn -ar 16000 -ac 1 -b:a 64k -f mp3 {output}
```

- `-vn`: No video (strip video track)
- `-ar 16000`: 16kHz sample rate (optimal for speech)
- `-ac 1`: Mono audio (single channel)
- `-b:a 64k`: 64kbps bitrate (good quality/size balance)

Adjust in the **ffmpeg** node based on your needs.

### Storage Configuration

The workflow supports any S3-compatible storage:

**DigitalOcean Spaces** (Recommended)
```env
DO_SPACES_ENDPOINT=nyc3.digitaloceanspaces.com
DO_SPACES_REGION=nyc3
```

**AWS S3**
```env
DO_SPACES_ENDPOINT=s3.amazonaws.com
DO_SPACES_REGION=us-east-1
```

**Other S3-compatible** (Wasabi, Backblaze B2, MinIO)
```env
DO_SPACES_ENDPOINT=your-s3-endpoint.com
DO_SPACES_REGION=your-region
```

## Troubleshooting

### Common Issues

#### 1. FFmpeg Not Found
```bash
# Check if ffmpeg is installed in container
docker-compose exec n8n ffmpeg -version

# Rebuild if needed
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

#### 2. Telegram File Not Found
- Verify `TELEGRAM_API_URL` is correct
- Check if bot has access to file cache
- Ensure file_path in webhook payload is correct

#### 3. S3 Upload Fails
- Verify Spaces/S3 credentials in n8n
- Check bucket name and region
- Ensure bucket allows public-read ACL
- Verify endpoint URL format

#### 4. Replicate Webhook Not Receiving
- Confirm n8n is publicly accessible
- Check webhook URLs in To Replicate and Chat-GPT Formatting nodes
- Use ngrok for local testing: `ngrok http 5678`

#### 5. Transcript Not Sent to Telegram
- Verify `TELEGRAM_BOT_TOKEN` is correct
- Check user_id is properly passed through workflow
- Review Telegram API response in execution logs

### Debug Mode

Enable verbose execution logging:

```yaml
# In docker-compose.yaml, add:
environment:
  - N8N_LOG_LEVEL=debug
  - EXECUTIONS_DATA_SAVE_ON_ERROR=all
  - EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
```

View logs in n8n UI under **Executions** tab.

## Advanced Setup

### Local Telegram Bot API Server

For handling large files (>20MB), run your own Telegram Bot API:

1. Uncomment `telegram-bot-api` service in `docker-compose.yaml`
2. Set your API credentials:
   ```env
   TELEGRAM_API_ID=your_api_id
   TELEGRAM_API_HASH=your_api_hash
   ```
3. Update workflow Telegram nodes to use `http://telegram-bot-api:8081`

### Custom Domain with SSL

1. Set up reverse proxy (nginx/Caddy)
2. Configure SSL certificate
3. Update environment:
   ```env
   N8N_PROTOCOL=https
   WEBHOOK_URL=https://yourdomain.com/
   N8N_EDITOR_BASE_URL=https://yourdomain.com
   ```

### Scaling for Production

```yaml
# In docker-compose.yaml:
services:
  n8n:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '2'
          memory: 4G
    environment:
      - EXECUTIONS_PROCESS=main
      - N8N_METRICS=true
```

## Maintenance

### Backup Workflow

```bash
# Export from n8n UI or backup workflow.json
cp workflow.json workflow.backup.json

# Backup database
docker-compose exec postgres pg_dump -U n8n n8n > backup.sql
```

### Update n8n

```bash
# Pull latest image
docker-compose pull n8n

# Restart with new image
docker-compose up -d n8n
```

### Clean Temp Files

```bash
# Clean /tmp directory periodically
docker-compose exec n8n find /tmp -name "audio_*" -mtime +1 -delete

# Or add cron job in Dockerfile
```

### Monitor Storage Usage

```bash
# Check Spaces/S3 bucket size
# Set up lifecycle rules to delete old transcriptions
# Example: Delete files older than 30 days
```

## Performance Optimization

### Audio Processing
- Reduce sample rate to 8kHz for faster processing (lower quality)
- Increase bitrate to 128kbps for better quality (larger files)
- Use GPU-accelerated ffmpeg for faster conversion

### Replicate Optimization
- Use smaller Whisper models for faster transcription
- Configure `temperature` in STT for better accuracy
- Batch multiple requests for high volume

### Storage Optimization
- Enable CDN for faster audio delivery
- Use lifecycle rules to auto-delete old files
- Compress audio more aggressively (32kbps)

## Cost Estimation

**Per 1000 transcriptions**:
- Replicate Whisper: ~$0.60-$2.00 (depends on model and audio length)
- GPT formatting: ~$0.10-$0.50 (depends on transcript length)
- DigitalOcean Spaces: ~$0.02 (storage + bandwidth)
- Total: **~$0.72-$2.52** per 1000 messages

## Security Considerations

1. **Change default credentials** in docker-compose.yaml
2. **Use strong passwords** for n8n and PostgreSQL
3. **Enable HTTPS** in production
4. **Restrict webhook access** with authentication
5. **Set up firewall rules** for container network
6. **Rotate API tokens** regularly
7. **Use environment variables** for all secrets

## Contributing

Improvements welcome! Areas for contribution:
- Additional language models for formatting
- Support for more audio formats
- Batch processing for multiple files
- User preference storage (language, model choice)
- Cost tracking and analytics
- Rate limiting and queue management

## License

MIT License - feel free to modify and use for your projects.

## Support

For issues and questions:
- n8n Documentation: https://docs.n8n.io
- Replicate Documentation: https://replicate.com/docs
- Telegram Bot API: https://core.telegram.org/bots/api

## Acknowledgments

- n8n - Workflow automation platform
- Replicate - AI model hosting
- OpenAI Whisper - Speech recognition model
- FFmpeg - Audio/video processing
- Telegram - Bot platform