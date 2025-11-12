# Quick Start Guide

Get the Telegram Audio Transcription Pipeline running in 5 minutes.

## Prerequisites

- Docker & Docker Compose installed
- Telegram Bot Token
- DigitalOcean Spaces (or S3) credentials
- Replicate API token

## Setup

### 1. Get API Keys

**Telegram Bot**
1. Message [@BotFather](https://t.me/botfather)
2. Create bot: `/newbot`
3. Copy token: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

**DigitalOcean Spaces**
1. Login to DigitalOcean
2. Navigate to API → Spaces Keys
3. Generate new key pair
4. Note: Key, Secret, Bucket name, Region, Endpoint

**Replicate**
1. Sign up at [replicate.com](https://replicate.com)
2. Go to Account Settings → API Tokens
3. Copy token: `r8_...`

### 2. Configure Environment

```bash
# Copy example file
cp .env.example .env

# Edit .env with your credentials
nano .env   # or use any text editor
```

Required values:
```env
TELEGRAM_BOT_TOKEN=your_bot_token
DO_SPACES_KEY=your_key
DO_SPACES_SECRET=your_secret
DO_SPACES_BUCKET=your-bucket
REPLICATE_API_TOKEN=your_token
```

### 3. Run Setup Script

```bash
./setup.sh
```

This will:
- Build Docker images with FFmpeg
- Start n8n and PostgreSQL
- Verify all services are running

### 4. Import Workflow

1. Open http://localhost:5678
2. Login: `admin` / `changeme`
3. Click **Workflows** → **Import from File**
4. Select `workflow.json`
5. Click **Import**

### 5. Configure Credentials

#### DigitalOcean Spaces

1. Go to **Credentials** → **Add Credential**
2. Search for "AWS"
3. Fill in:
   - **Name**: DigitalOcean Spaces
   - **Access Key ID**: Your Spaces key
   - **Secret Access Key**: Your Spaces secret
   - **Region**: e.g., `nyc3`
   - Enable **Custom Endpoints**
   - **S3 Endpoint**: e.g., `nyc3.digitaloceanspaces.com`
4. Save

#### Replicate API

1. Go to **Credentials** → **Add Credential**
2. Search for "HTTP Header Auth"
3. Fill in:
   - **Name**: Replicate API
   - **Header Name**: `Authorization`
   - **Header Value**: `Token YOUR_REPLICATE_TOKEN`
4. Save

### 6. Update Webhook URLs

For **production** (with public domain):

1. In workflow, find these nodes:
   - "To Replicate"
   - "Chat-GPT Formatting"
2. Replace `http://localhost:5678` with your domain:
   - `https://yourdomain.com/webhook/replicate-webh111`
   - `https://yourdomain.com/webhook/Repl-chatgpt`

For **testing** (with ngrok):

```bash
# Install ngrok
brew install ngrok  # macOS
# or download from ngrok.com

# Create tunnel
ngrok http 5678

# Use the HTTPS URL in webhook nodes
# Example: https://abc123.ngrok.io/webhook/replicate-webh111
```

### 7. Activate Workflow

1. Open the imported workflow
2. Click the **Active** toggle in top-right
3. Workflow is now live!

## Testing

### Send Test Audio

1. Send audio/video to your Telegram bot
2. Bot processes and replies with transcript
3. Check execution in n8n: **Executions** tab

### Troubleshoot

View logs:
```bash
docker-compose logs -f n8n
```

Check service status:
```bash
docker-compose ps
```

Restart services:
```bash
docker-compose restart
```

## Manual Method (No Setup Script)

```bash
# Build and start
docker-compose build
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

Then follow steps 4-7 above.

## Next Steps

- Read full [README.md](README.md) for:
  - Detailed configuration options
  - Model customization
  - Performance tuning
  - Production deployment
  - Troubleshooting guide

- Customize workflow:
  - Different Whisper models
  - Custom GPT prompts
  - Audio quality settings
  - Alternative storage providers

## Common Issues

**n8n won't start**
```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

**Credentials not working**
- Double-check .env values
- Restart n8n: `docker-compose restart n8n`
- Verify credentials in n8n UI

**Webhook not receiving**
- Ensure n8n is publicly accessible
- Use ngrok for local testing
- Check webhook URLs match your domain

**FFmpeg errors**
- Rebuild image: `docker-compose build --no-cache n8n`
- Check file permissions on /tmp
- Verify file paths in Code node

## Production Checklist

Before going live:

- [ ] Change default n8n password
- [ ] Set up HTTPS with SSL certificate
- [ ] Configure proper firewall rules
- [ ] Set up monitoring and alerts
- [ ] Enable automatic backups
- [ ] Configure S3 lifecycle rules
- [ ] Test with actual Telegram users
- [ ] Set up webhook authentication
- [ ] Document your configuration
- [ ] Plan for scaling (if needed)

## Support

- **n8n**: [docs.n8n.io](https://docs.n8n.io)
- **Replicate**: [replicate.com/docs](https://replicate.com/docs)
- **Issues**: Check workflow executions in n8n UI

Happy transcribing! 🎙️✨