# Migration Notes - Updated Configuration

> 🚀 **КЛЮЧЕВАЯ ОСОБЕННОСТЬ**: Этот setup использует **локальный Telegram Bot API сервер** (tg-bot-api), что **полностью снимает ограничение 20MB** на размер файлов. Вы можете обрабатывать видео и аудио **любого размера** (1GB+)!

## Changes Made to Match Your Working Setup

### 1. Docker Compose Structure

**Updated [`docker-compose.yaml`](docker-compose.yaml:1)** to match your production configuration:

#### Key Changes:
- ✅ **Telegram Bot API**: Now primary service with local-only binding
  ```yaml
  ports:
    - "127.0.0.1:8081:8081"  # Only accessible from localhost
  ```
- ✅ **Network**: Changed from `n8n_network` to `app-net`
- ✅ **Container names**: Explicitly set for all services
- ✅ **Volume mapping**: Using `/opt/tg-bot-api` for Telegram cache
- ✅ **Service dependencies**: n8n now depends on tg-bot-api health check
- ✅ **Image reference**: n8n uses pre-built `n8n-ffmpeg` image

#### Services Order:
1. `tg-bot-api` - Starts first with healthcheck
2. `postgres` - Database with healthcheck  
3. `n8n` - Waits for both services to be healthy

### 2. Environment Configuration

**Updated [`.env.example`](.env.example:1)** to include all required variables:

```env
# Now REQUIRED (was optional)
TELEGRAM_API_ID=your_api_id
TELEGRAM_API_HASH=your_api_hash

# Better organized with clear REQUIRED markers
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=changeme
```

### 3. Workflow File Paths

**Updated [`workflow.json`](workflow.json:39)** Code node:

```javascript
// OLD PATH
const absPath = `/data/tg-cache/${cleanPath}`;

// NEW PATH (matches your setup)
const absPath = `/opt/tg-bot-api/${cleanPath}`;
```

This ensures n8n reads from the same location where tg-bot-api stores files.

### 4. Setup Script Validation

**Updated [`setup.sh`](setup.sh:44)** to validate Telegram Bot API requirements:

- Now checks for `TELEGRAM_API_ID`
- Now checks for `TELEGRAM_API_HASH`
- Explicitly builds `n8n-ffmpeg` image before docker-compose

## Architecture Differences

### Your Production Setup vs Original

| Aspect | Original | Your Setup |
|--------|----------|------------|
| **Bot API** | Optional, commented out | Required, primary service |
| **Network** | n8n_network | app-net |
| **TG Cache** | /data/tg-cache | /opt/tg-bot-api |
| **Port Binding** | Public (8081) | Localhost only (127.0.0.1:8081) |
| **n8n Image** | Built on-the-fly | Pre-built (n8n-ffmpeg) |

## Deployment Instructions

### 1. Build n8n Image First

```bash
# Build the custom n8n image with FFmpeg
docker build -t n8n-ffmpeg -f Dockerfile.n8n .
```

### 2. Configure Environment

```bash
# Copy and edit .env
cp .env.example .env
nano .env

# REQUIRED variables:
# - TELEGRAM_BOT_TOKEN
# - TELEGRAM_API_ID (for local Bot API)
# - TELEGRAM_API_HASH (for local Bot API)
# - DO_SPACES_KEY, DO_SPACES_SECRET, DO_SPACES_BUCKET
# - REPLICATE_API_TOKEN
```

### 3. Create Required Directories

```bash
# Create directory for Telegram Bot API cache
sudo mkdir -p /opt/tg-bot-api
sudo chown -R $(id -u):$(id -g) /opt/tg-bot-api
```

### 4. Start Services

```bash
# Using provided setup script (recommended)
./setup.sh

# Or manually
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### 5. Verify Health Checks

```bash
# Telegram Bot API should be healthy first
docker-compose ps tg-bot-api

# Then postgres
docker-compose ps postgres

# Then n8n starts
docker-compose ps n8n
```

## Service Startup Order

```
1. tg-bot-api starts
   └─> Healthcheck: wget bot API getMe endpoint
       ⏱️ 20s start_period, check every 15s

2. postgres starts (independent)
   └─> Healthcheck: pg_isready
       ⏱️ Check every 10s

3. n8n starts ONLY when both are healthy
   └─> Connects to Telegram Bot API at http://tg-bot-api:8081
   └─> Connects to PostgreSQL at postgres:5432
```

## Network Configuration

### app-net Bridge Network

All services communicate through internal Docker network:

```
tg-bot-api:8081  ←→  n8n:5678
       ↓
   postgres:5432
```

**External Access:**
- n8n UI: `http://localhost:5678` (public)
- Telegram Bot API: `http://127.0.0.1:8081` (localhost only)
- PostgreSQL: Not exposed (internal only)

## Volume Mappings

```
Host                    → Container
/opt/tg-bot-api         → /var/lib/telegram-bot-api (tg-bot-api)
/opt/tg-bot-api         → /opt/tg-bot-api (n8n, read access)
/tmp                    → /tmp (n8n, temp audio files)
postgres_data (volume)  → /var/lib/postgresql/data
n8n_data (volume)       → /home/node/.n8n
```

## Security Considerations

### Improvements in Your Setup

1. **Telegram Bot API is localhost-only**
   - Not exposed to public internet
   - More secure than default 0.0.0.0:8081

2. **Shared volume for file access**
   - n8n reads directly from Bot API cache
   - No network transfer needed

3. **Using local Bot API**
   - No file size limits (official API has 20MB limit)
   - Faster file downloads
   - More reliable for large files

## Troubleshooting

### Common Issues with This Setup

#### 1. tg-bot-api Healthcheck Fails

```bash
# Check if Bot API is starting
docker-compose logs tg-bot-api

# Verify token is correct
curl "http://127.0.0.1:8081/bot${TELEGRAM_BOT_TOKEN}/getMe"

# Common causes:
# - Wrong TELEGRAM_BOT_TOKEN
# - Wrong TELEGRAM_API_ID or TELEGRAM_API_HASH
# - Bot not registered with this API ID/HASH pair
```

#### 2. n8n Can't Access Files

```bash
# Check volume permissions
ls -la /opt/tg-bot-api

# Verify n8n can read
docker-compose exec n8n ls -la /opt/tg-bot-api

# Fix permissions if needed
sudo chown -R $(id -u):$(id -g) /opt/tg-bot-api
```

#### 3. n8n Can't Connect to Bot API

```bash
# Test from n8n container
docker-compose exec n8n wget -qO- http://tg-bot-api:8081/bot${TELEGRAM_BOT_TOKEN}/getMe

# Should return JSON with bot info
```

## Testing the Setup

### 1. Verify Telegram Bot API

```bash
# From host (local only)
curl "http://127.0.0.1:8081/bot${TELEGRAM_BOT_TOKEN}/getMe"

# From n8n container
docker-compose exec n8n sh -c 'curl http://tg-bot-api:8081/bot$TELEGRAM_BOT_TOKEN/getMe'
```

### 2. Test File Upload

1. Send a video/audio to your Telegram bot
2. Check if file appears in `/opt/tg-bot-api/documents/` or `/opt/tg-bot-api/videos/`
3. Verify n8n workflow execution in UI

### 3. Monitor Service Health

```bash
# All services should show "healthy"
docker-compose ps

# View real-time logs
docker-compose logs -f tg-bot-api
docker-compose logs -f n8n
```

## Migration from Original Setup

If you had the original setup running:

```bash
# 1. Stop old services
docker-compose down

# 2. Build new n8n image
docker build -t n8n-ffmpeg -f Dockerfile.n8n .

# 3. Update .env with new required variables
nano .env  # Add TELEGRAM_API_ID and TELEGRAM_API_HASH

# 4. Create cache directory
sudo mkdir -p /opt/tg-bot-api
sudo chown -R $(id -u):$(id -g) /opt/tg-bot-api

# 5. Start with new config
docker-compose up -d

# 6. Re-import workflow.json if needed (path fix)
```

## Performance Notes

### Advantages of Local Bot API

- **No file size limits**: Process videos >20MB
- **Faster downloads**: Direct filesystem access
- **More reliable**: No network timeouts
- **Better privacy**: Files never leave your server

### Resource Usage

- **tg-bot-api**: ~50-100MB RAM, minimal CPU
- **n8n**: ~200-300MB RAM, CPU spikes during FFmpeg
- **postgres**: ~100-200MB RAM, minimal CPU

## Backup Considerations

### What to Backup

```bash
# 1. Telegram Bot API cache (if needed)
tar -czf tg-cache-backup.tar.gz /opt/tg-bot-api

# 2. n8n workflows and credentials
docker-compose exec n8n n8n export:workflow --all --output=/home/node/.n8n/backups/

# 3. PostgreSQL database
docker-compose exec postgres pg_dump -U n8n n8n > postgres-backup.sql

# 4. Environment configuration
cp .env .env.backup
```

## Production Recommendations

1. **Change default passwords** in .env immediately
2. **Set up SSL/TLS** with reverse proxy (nginx/Caddy)
3. **Configure firewall** to block port 5678 from public (use proxy)
4. **Enable HTTPS** in n8n configuration
5. **Set up monitoring** for service health
6. **Configure log rotation** for Docker logs
7. **Schedule regular backups** of database and workflows

## Next Steps

1. ✅ Configuration updated to match your setup
2. 📝 Read this migration guide
3. 🔧 Run `./setup.sh` to deploy
4. 🧪 Test with a sample audio file
5. 📊 Monitor execution logs in n8n UI

For complete documentation, see:
- [`README.md`](README.md:1) - Full project documentation
- [`QUICKSTART.md`](QUICKSTART.md:1) - Quick deployment guide
- [`WORKFLOW_DIAGRAM.md`](WORKFLOW_DIAGRAM.md:1) - Architecture details