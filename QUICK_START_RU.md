# Быстрый старт на Ubuntu

Краткая инструкция для быстрой установки. Подробная версия: [`UBUNTU_SETUP_RU.md`](UBUNTU_SETUP_RU.md)

> 🚀 **ВАЖНО**: Этот setup использует **локальный Telegram Bot API сервер**, что **снимает ограничение 20MB** на файлы. Вы можете обрабатывать видео и аудио **любого размера**!

## Предварительные требования

- Ubuntu 20.04+ сервер
- Доступ через SSH
- Sudo права

## Шаг 1: Установка Docker (5 минут)

```bash
# Обновить систему
sudo apt update && sudo apt upgrade -y

# Установить Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Установить Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Проверить
docker --version
docker-compose --version
```

## Шаг 2: Получить API ключи (10 минут)

### Telegram Bot
1. [@BotFather](https://t.me/botfather) → `/newbot`
2. Сохранить: `TELEGRAM_BOT_TOKEN`

### Telegram API ID (для локального Bot API - **снимает лимит 20MB!**)
1. [my.telegram.org/auth](https://my.telegram.org/auth)
2. API development tools → Create app
3. Сохранить: `api_id` и `api_hash`

> **Зачем нужно**: Локальный Bot API сервер позволяет обрабатывать файлы **любого размера** (официальный API имеет лимит 20MB)

### DigitalOcean Spaces
1. [cloud.digitalocean.com](https://cloud.digitalocean.com)
2. Spaces → Manage Keys → Generate
3. Создать Space (bucket)
4. Сохранить: key, secret, bucket name, endpoint

### Replicate
1. [replicate.com](https://replicate.com)
2. Account → API Tokens
3. Сохранить: токен (начинается с `r8_`)

## Шаг 3: Скачать проект

```bash
# Создать директорию
mkdir -p ~/telegram-transcription
cd ~/telegram-transcription

# Скачать файлы (git или scp)
# Или создать вручную все файлы
```

## Шаг 4: Настроить окружение

```bash
# Создать .env
cp .env.example .env
nano .env
```

**Заполнить обязательные поля:**
```env
TELEGRAM_BOT_TOKEN=ваш_токен
TELEGRAM_API_ID=ваш_id
TELEGRAM_API_HASH=ваш_hash

N8N_BASIC_AUTH_PASSWORD=сильный_пароль

DO_SPACES_KEY=ваш_ключ
DO_SPACES_SECRET=ваш_секрет
DO_SPACES_BUCKET=имя_bucket
DO_SPACES_ENDPOINT=nyc3.digitaloceanspaces.com
DO_SPACES_REGION=nyc3

REPLICATE_API_TOKEN=ваш_токен

# Если есть публичный IP, укажите:
WEBHOOK_URL=http://ваш_ip:5678/
N8N_EDITOR_BASE_URL=http://ваш_ip:5678
```

Сохранить: `Ctrl+X` → `Y` → `Enter`

## Шаг 5: Создать директории

```bash
# Директория для Telegram Bot API
sudo mkdir -p /opt/tg-bot-api
sudo chown -R $USER:$USER /opt/tg-bot-api
```

## Шаг 6: Собрать и запустить

```bash
# Собрать n8n образ с FFmpeg
docker build -t n8n-ffmpeg -f Dockerfile.n8n .

# Запустить все сервисы
docker-compose up -d

# Проверить статус (должны быть "Up (healthy)")
docker-compose ps

# Посмотреть логи
docker-compose logs -f
```

## Шаг 7: Настроить n8n

### 7.1 Открыть n8n
Браузер: `http://ВАШ_IP:5678`
- Login: `admin`
- Password: из `.env`

### 7.2 Импортировать workflow
1. Workflows → Import from File
2. Выбрать `workflow.json`

### 7.3 Настроить credentials

**DigitalOcean Spaces:**
- Credentials → Add → AWS
- Name: `DigitalOcean Spaces`
- Access Key ID: из .env
- Secret Access Key: из .env
- Region: `nyc3`
- Custom Endpoints: ✅ ON
- S3 Endpoint: `nyc3.digitaloceanspaces.com`
- Force Path Style: ✅ ON

**Replicate API:**
- Credentials → Add → HTTP Header Auth
- Name: `Replicate API`
- Header Name: `Authorization`
- Header Value: `Token ВАШ_REPLICATE_TOKEN`

### 7.4 Обновить URLs
В workflow найти узлы:
- "To Replicate"
- "Chat-GPT Formatting"

Заменить webhook URLs:
- `http://localhost:5678` → `http://ВАШ_IP:5678`

### 7.5 Активировать
Toggle "Active" в правом верхнем углу

## Шаг 8: Тестирование

1. Открыть Telegram → найти бота
2. Отправить `/start`
3. Отправить аудио/видео
4. Подождать 1-2 минуты
5. Получить транскрипцию

**Мониторинг:**
- n8n UI → Executions
- Сервер: `docker-compose logs -f n8n`

## Быстрая диагностика

```bash
# Проверить статус
docker-compose ps

# Проверить логи
docker-compose logs --tail=50 n8n

# Проверить Telegram Bot API
curl "http://127.0.0.1:8081/bot$(grep TELEGRAM_BOT_TOKEN .env | cut -d '=' -f2)/getMe"

# Перезапустить если проблемы
docker-compose restart

# Полный перезапуск
docker-compose down
docker-compose up -d
```

## Полезные команды

```bash
# Остановить
docker-compose down

# Просмотр логов
docker-compose logs -f [service_name]

# Перезапуск
docker-compose restart [service_name]

# Статус
docker-compose ps

# Использование ресурсов
docker stats
```

## Troubleshooting

### Проблема: "unhealthy" статус

```bash
# Посмотреть логи проблемного сервиса
docker-compose logs tg-bot-api
docker-compose logs postgres
docker-compose logs n8n

# Проверить .env
cat .env | grep -v "^#" | grep -v "^$"

# Пересоздать контейнеры
docker-compose down
docker-compose up -d --force-recreate
```

### Проблема: n8n не доступен

```bash
# Проверить firewall
sudo ufw status

# Открыть порт
sudo ufw allow 5678/tcp

# Проверить что n8n слушает
docker-compose exec n8n netstat -tulpn | grep 5678
```

### Проблема: FFmpeg ошибки

```bash
# Проверить права
ls -la /opt/tg-bot-api

# Дать права
sudo chown -R $USER:$USER /opt/tg-bot-api

# Проверить из контейнера
docker-compose exec n8n ls -la /opt/tg-bot-api
```

## Следующие шаги

1. **Безопасность:**
   - Сменить пароли в .env
   - Настроить firewall: `sudo ufw enable`
   - Настроить SSL (nginx + certbot)

2. **Мониторинг:**
   - Настроить логи
   - Создать backup скрипты
   - Мониторить использование ресурсов

3. **Оптимизация:**
   - Настроить автоочистку /tmp
   - Настроить lifecycle rules в Spaces
   - Оптимизировать модели Replicate

## Документация

- [`UBUNTU_SETUP_RU.md`](UBUNTU_SETUP_RU.md) - Полная инструкция
- [`README.md`](README.md) - Английская документация
- [`WORKFLOW_DIAGRAM.md`](WORKFLOW_DIAGRAM.md) - Архитектура
- [`MIGRATION_NOTES.md`](MIGRATION_NOTES.md) - Изменения в конфигурации

## Поддержка

- n8n: https://docs.n8n.io
- Docker: https://docs.docker.com
- Replicate: https://replicate.com/docs

**Успехов! 🚀**