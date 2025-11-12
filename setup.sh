#!/bin/bash

# Telegram Audio Transcription Pipeline - Setup Script
# This script helps you set up the n8n workflow environment

set -e

echo "======================================"
echo "n8n Telegram Transcription Setup"
echo "======================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "   Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env file created"
    echo ""
    echo "⚠️  IMPORTANT: Edit .env file and add your credentials:"
    echo "   - TELEGRAM_BOT_TOKEN"
    echo "   - DO_SPACES_KEY and DO_SPACES_SECRET"
    echo "   - REPLICATE_API_TOKEN"
    echo ""
    echo "Run this script again after configuring .env"
    exit 0
fi

echo "✅ .env file exists"
echo ""

# Validate required environment variables
source .env

MISSING_VARS=""

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ "$TELEGRAM_BOT_TOKEN" = "123456789:ABCdefGHIjklMNOpqrsTUVwxyz" ]; then
    MISSING_VARS="$MISSING_VARS\n  - TELEGRAM_BOT_TOKEN"
fi

if [ -z "$TELEGRAM_API_ID" ] || [ "$TELEGRAM_API_ID" = "your_api_id" ]; then
    MISSING_VARS="$MISSING_VARS\n  - TELEGRAM_API_ID"
fi

if [ -z "$TELEGRAM_API_HASH" ] || [ "$TELEGRAM_API_HASH" = "your_api_hash" ]; then
    MISSING_VARS="$MISSING_VARS\n  - TELEGRAM_API_HASH"
fi

if [ -z "$DO_SPACES_KEY" ] || [ "$DO_SPACES_KEY" = "your_spaces_access_key" ]; then
    MISSING_VARS="$MISSING_VARS\n  - DO_SPACES_KEY"
fi

if [ -z "$DO_SPACES_SECRET" ] || [ "$DO_SPACES_SECRET" = "your_spaces_secret_key" ]; then
    MISSING_VARS="$MISSING_VARS\n  - DO_SPACES_SECRET"
fi

if [ -z "$REPLICATE_API_TOKEN" ] || [ "$REPLICATE_API_TOKEN" = "r8_your_replicate_api_token_here" ]; then
    MISSING_VARS="$MISSING_VARS\n  - REPLICATE_API_TOKEN"
fi

if [ -n "$MISSING_VARS" ]; then
    echo "❌ Missing required environment variables in .env:"
    echo -e "$MISSING_VARS"
    echo ""
    echo "Please edit .env file and add the missing values"
    exit 1
fi

echo "✅ All required environment variables are set"
echo ""

# Build n8n-ffmpeg image
echo "🔨 Building n8n-ffmpeg Docker image..."
docker build -t n8n-ffmpeg -f Dockerfile.n8n .

echo ""
echo "🔨 Building remaining Docker images..."
docker-compose build --no-cache

echo ""
echo "🚀 Starting services..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if services are running
if docker-compose ps | grep -q "n8n.*Up"; then
    echo "✅ n8n is running"
else
    echo "❌ n8n failed to start. Check logs with: docker-compose logs n8n"
    exit 1
fi

if docker-compose ps | grep -q "postgres.*Up"; then
    echo "✅ PostgreSQL is running"
else
    echo "❌ PostgreSQL failed to start. Check logs with: docker-compose logs postgres"
    exit 1
fi

echo ""
echo "======================================"
echo "✅ Setup Complete!"
echo "======================================"
echo ""
echo "📍 n8n is now running at: http://localhost:5678"
echo "🔐 Default credentials: admin / changeme"
echo ""
echo "Next steps:"
echo "1. Open http://localhost:5678 in your browser"
echo "2. Login with the default credentials"
echo "3. Import workflow.json (Workflow menu → Import from File)"
echo "4. Configure credentials in n8n:"
echo "   - DigitalOcean Spaces (AWS S3 credential type)"
echo "   - Replicate API (HTTP Header Auth)"
echo "5. Update webhook URLs with your public domain"
echo "6. Activate the workflow"
echo ""
echo "📚 For detailed instructions, see README.md"
echo ""
echo "Useful commands:"
echo "  - View logs: docker-compose logs -f n8n"
echo "  - Stop services: docker-compose down"
echo "  - Restart services: docker-compose restart"
echo ""