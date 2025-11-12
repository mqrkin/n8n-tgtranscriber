# Project Structure

## File Organization

```
telegram-transcription/
├── docker-compose.yaml          # Docker orchestration (n8n + PostgreSQL)
├── Dockerfile.n8n               # Custom n8n image with FFmpeg
├── workflow.json                # n8n workflow definition (import this)
│
├── README.md                    # Complete documentation (START HERE)
├── QUICKSTART.md                # 5-minute setup guide
├── WORKFLOW_DIAGRAM.md          # Visual architecture diagrams
├── PROJECT_STRUCTURE.md         # This file
│
├── .env.example                 # Environment template (copy to .env)
├── .env                         # Your credentials (git-ignored)
├── .gitignore                   # Security-focused ignore rules
│
├── setup.sh                     # Automated setup script (executable)
│
└── volumes/ (created by Docker)
    ├── n8n_data/                # n8n workflows and settings
    ├── postgres_data/           # PostgreSQL database
    └── tg_cache/                # Telegram file cache
```

## File Descriptions

### Core Infrastructure Files

#### [`docker-compose.yaml`](docker-compose.yaml)
**Purpose**: Orchestrates all services  
**Contains**:
- PostgreSQL database configuration
- n8n service with custom Dockerfile
- Environment variable mapping
- Volume mounts
- Network configuration
- Optional Telegram Bot API service

**Usage**:
```bash
docker-compose up -d        # Start services
docker-compose logs -f n8n  # View logs
docker-compose down         # Stop services
```

#### [`Dockerfile.n8n`](Dockerfile.n8n)
**Purpose**: Custom n8n image with FFmpeg  
**Installs**:
- FFmpeg (audio/video processing)
- Python 3 (for potential extensions)
- Additional tools (curl, bash)

**Build command**:
```bash
docker-compose build --no-cache n8n
```

#### [`workflow.json`](workflow.json)
**Purpose**: n8n workflow definition  
**Contains**:
- 14 nodes (webhooks, HTTP requests, code, FFmpeg)
- Node connections and data flow
- Node configurations (some require credential IDs)
- Workflow settings

**Import path**: n8n UI → Workflows → Import from File

### Documentation Files

#### [`README.md`](README.md) ⭐ START HERE
**Purpose**: Complete project documentation (461 lines)  
**Sections**:
- Architecture overview
- Feature descriptions
- Prerequisites and quick start
- Detailed setup instructions
- Configuration options (Replicate models, FFmpeg settings, storage)
- Troubleshooting guide
- Advanced setup (self-hosted Telegram Bot API, SSL, scaling)
- Maintenance and monitoring
- Performance optimization
- Cost estimation
- Security considerations

**Best for**: Understanding the complete system

#### [`QUICKSTART.md`](QUICKSTART.md)
**Purpose**: Rapid deployment guide (217 lines)  
**Sections**:
- API key acquisition steps
- Environment configuration
- Setup script usage
- Workflow import
- Credential configuration
- Testing procedures
- Common issues

**Best for**: Getting started in 5 minutes

#### [`WORKFLOW_DIAGRAM.md`](WORKFLOW_DIAGRAM.md)
**Purpose**: Visual architecture (378 lines)  
**Contains**:
- ASCII art workflow diagram
- Node-by-node breakdown table
- Data flow examples (JSON payloads)
- Timing breakdown
- Error handling strategy
- Scalability analysis
- Monitoring points

**Best for**: Understanding how data flows through the system

#### [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md)
**Purpose**: This file - project navigation guide  
**Best for**: Finding the right documentation

### Configuration Files

#### [`.env.example`](.env.example)
**Purpose**: Environment variable template  
**Contains placeholders for**:
- Telegram Bot Token
- DigitalOcean Spaces credentials
- Replicate API token
- Optional: OpenAI, Telegram Bot API server

**Usage**:
```bash
cp .env.example .env
nano .env  # Add your credentials
```

#### [`.env`](.env)
**Purpose**: Your actual credentials (git-ignored)  
**Security**: Never commit this file!

#### [`.gitignore`](.gitignore)
**Purpose**: Prevent committing sensitive data  
**Ignores**:
- `.env` file
- Docker volumes
- Temporary files
- Logs
- OS files

### Automation Scripts

#### [`setup.sh`](setup.sh)
**Purpose**: Automated setup and validation (124 lines)  
**Features**:
- Checks Docker installation
- Creates `.env` from template
- Validates required environment variables
- Builds Docker images
- Starts services
- Verifies service health
- Displays next steps

**Usage**:
```bash
chmod +x setup.sh  # Make executable (already done)
./setup.sh         # Run setup
```

**When to use**: First-time setup or after changes to .env

## Workflow Components

### Nodes in workflow.json

| ID | Name | Type | Purpose |
|----|------|------|---------|
| `webhook-puzzlebot` | Webhook Puzzlebot | webhook | Receives file notifications |
| `telegram-get-fileid` | Telegram Get FileID | httpRequest | Retrieves file metadata |
| `code-build-paths` | Code | code | Generates file paths |
| `ffmpeg-extract` | ffmpeg | executeCommand | Extracts audio |
| `read-mp3` | Read/Write Files from Disk1 | readWriteFile | Reads MP3 file |
| `merge-file-metadata` | Merge | merge | Combines data |
| `spaces-upload` | Spaces (S3) Upload | awsS3 | Uploads to cloud |
| `merge-upload-info` | Merge1 | merge | Combines upload data |
| `build-url` | Build DO URL | code | Constructs public URL |
| `to-replicate` | To Replicate | httpRequest | Sends to STT |
| `webhook-replicate` | Replicate-webh | webhook | Receives transcript |
| `chatgpt-formatting` | Chat-GPT Formatting | httpRequest | Formats text |
| `webhook-chatgpt` | Repl-chatgpt | webhook | Receives formatted text |
| `send-to-telegram` | Send to Telegram | httpRequest | Sends reply |

### Required Credentials in n8n

After importing workflow, configure these in n8n UI:

1. **DigitalOcean Spaces** (ID: "1")
   - Type: AWS S3
   - Contains: Access keys, endpoint, region

2. **Replicate API** (ID: "2")
   - Type: HTTP Header Auth
   - Contains: Authorization token

## Data Persistence

### Docker Volumes

Created automatically by Docker Compose:

```
telegram-transcription_postgres_data
├── PostgreSQL database files
└── Persistent across restarts

telegram-transcription_n8n_data
├── n8n workflows and executions
├── User credentials
└── Settings

telegram-transcription_tg_cache
├── Telegram file cache (if using local Bot API)
└── Shared with telegram-bot-api service
```

### Temporary Files

Created during workflow execution:

```
/tmp/
├── audio_in_<user_id>_<timestamp>      # Original file copy
├── audio_out_<user_id>_<timestamp>.mp3 # Converted MP3
└── Automatically cleaned up
```

### Cloud Storage

Files uploaded to DigitalOcean Spaces (or S3):

```
your-bucket-name/
└── transcriptions/
    └── <user_id>/
        ├── <timestamp1>.mp3
        ├── <timestamp2>.mp3
        └── ...
```

**Note**: Set up lifecycle rules to auto-delete old files

## Development Workflow

### 1. Initial Setup
```bash
git clone <repo>
cd telegram-transcription
cp .env.example .env
# Edit .env with your credentials
./setup.sh
```

### 2. Import Workflow
- Open http://localhost:5678
- Import workflow.json
- Configure credentials
- Update webhook URLs

### 3. Testing
```bash
# Send test message to Telegram bot
# Monitor execution in n8n UI
docker-compose logs -f n8n
```

### 4. Customization
```bash
# Modify workflow in n8n UI
# Export updated workflow:
# n8n UI → Workflow → Download
# Replace workflow.json
```

### 5. Production Deployment
```bash
# Update environment for production
nano docker-compose.yaml  # Change passwords, add SSL
nano .env                 # Set production URLs

# Deploy with SSL (using Caddy/nginx)
# See README.md "Custom Domain with SSL"
```

## Maintenance Tasks

### Daily
- Monitor executions in n8n UI
- Check disk usage: `df -h`
- Review error logs: `docker-compose logs --tail=100 n8n`

### Weekly
- Clean temp files: `docker-compose exec n8n find /tmp -name "audio_*" -mtime +7 -delete`
- Review Spaces storage usage
- Check cost analytics in Replicate dashboard

### Monthly
- Backup workflow: Export from n8n UI
- Backup database: `docker-compose exec postgres pg_dump -U n8n n8n > backup.sql`
- Update n8n: `docker-compose pull && docker-compose up -d`
- Review and optimize performance

### Quarterly
- Rotate API tokens
- Review security settings
- Optimize S3 lifecycle rules
- Update documentation

## Troubleshooting Guide

### Where to Look

**Service won't start**
1. Check: `docker-compose ps`
2. Logs: `docker-compose logs <service_name>`
3. Fix: Review .env and docker-compose.yaml

**Workflow fails**
1. Check: n8n UI → Executions tab
2. Click failed execution for details
3. Common issues:
   - Missing credentials
   - Wrong webhook URLs
   - File path problems
   - FFmpeg errors

**FFmpeg issues**
1. Test in container: `docker-compose exec n8n ffmpeg -version`
2. Rebuild if needed: `docker-compose build --no-cache n8n`
3. Check file permissions: `/tmp` and `/data/tg-cache`

**Webhook not receiving**
1. Check n8n is publicly accessible
2. Use ngrok for testing: `ngrok http 5678`
3. Verify webhook URLs in workflow nodes
4. Check firewall rules

### Log Locations

```
# n8n logs
docker-compose logs -f n8n

# PostgreSQL logs
docker-compose logs -f postgres

# All logs
docker-compose logs -f

# Export logs to file
docker-compose logs > logs.txt
```

## Quick Reference

### Essential Commands

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# Rebuild
docker-compose build --no-cache

# View logs
docker-compose logs -f n8n

# Access n8n shell
docker-compose exec n8n sh

# Clean everything (CAUTION: deletes data)
docker-compose down -v
```

### Important URLs

- **n8n UI**: http://localhost:5678
- **Webhook endpoints**: http://localhost:5678/webhook/*
- **n8n docs**: https://docs.n8n.io
- **Replicate docs**: https://replicate.com/docs

### Default Credentials

- **n8n**: admin / changeme (CHANGE THIS!)
- **PostgreSQL**: n8n / n8n (internal use only)

## Contributing

To contribute improvements:

1. Fork the repository
2. Make changes
3. Test thoroughly
4. Update documentation
5. Submit pull request

Key areas for contribution:
- Additional AI models
- Performance optimizations
- Error handling improvements
- Cost optimization
- Monitoring and alerting
- Multi-language support

## License

MIT License - free to use and modify.

## Support

- **Issues**: Check workflow executions in n8n UI first
- **Documentation**: README.md for details, QUICKSTART.md for speed
- **n8n Help**: https://community.n8n.io
- **Replicate Help**: https://replicate.com/docs

---

**Next Steps**: Read [`README.md`](README.md) for complete setup instructions or [`QUICKSTART.md`](QUICKSTART.md) for rapid deployment.