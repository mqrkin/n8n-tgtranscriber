# Установка и настройка на Ubuntu Server

Подробная пошаговая инструкция для развертывания Telegram Audio Transcription Pipeline на Ubuntu сервере.

> ⚠️ **ВАЖНО**: Этот setup использует **локальный Telegram Bot API сервер** (tg-bot-api), что **снимает ограничение в 20MB** на размер файлов. Вы можете обрабатывать видео и аудио любого размера!

## 📋 Содержание

1. [Подготовка сервера](#1-подготовка-сервера)
2. [Установка Docker](#2-установка-docker)
3. [Получение API ключей](#3-получение-api-ключей)
4. [Установка проекта](#4-установка-проекта)
5. [Настройка окружения](#5-настройка-окружения)
6. [Создание директорий](#6-создание-директорий)
7. [Сборка образов](#7-сборка-образов)
8. [Запуск сервисов](#8-запуск-сервисов)
9. [Настройка n8n](#9-настройка-n8n)
10. [Проверка работы](#10-проверка-работы)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Подготовка сервера

### Обновление системы

```bash
# Обновить список пакетов
sudo apt update

# Обновить установленные пакеты
sudo apt upgrade -y

# Установить необходимые утилиты
sudo apt install -y curl wget git nano htop
```

### Проверка версии Ubuntu

```bash
lsb_release -a
# Рекомендуется: Ubuntu 20.04 LTS или выше
```

---

## 2. Установка Docker

### Вариант A: Быстрая установка (рекомендуется)

```bash
# Установить Docker одной командой
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавить текущего пользователя в группу docker
sudo usermod -aG docker $USER

# Применить изменения группы (или перелогиниться)
newgrp docker

# Проверить установку
docker --version
```

### Вариант B: Ручная установка

```bash
# Удалить старые версии (если есть)
sudo apt remove docker docker-engine docker.io containerd runc

# Установить зависимости
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Добавить официальный GPG ключ Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Добавить репозиторий Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установить Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Добавить пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# Проверить
docker --version
```

### Установка Docker Compose

```bash
# Установить Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Сделать исполняемым
sudo chmod +x /usr/local/bin/docker-compose

# Проверить версию
docker-compose --version
```

### Тест Docker

```bash
# Запустить тестовый контейнер
docker run hello-world

# Если всё работает, увидите сообщение "Hello from Docker!"
```

---

## 3. Получение API ключей

### 3.1 Telegram Bot Token

1. Откройте Telegram и найдите [@BotFather](https://t.me/botfather)
2. Отправьте команду `/newbot`
3. Следуйте инструкциям (название бота, username)
4. **Сохраните токен**: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

### 3.2 Telegram API ID и Hash (для локального Bot API)

> **🚀 ЗАЧЕМ НУЖНО**: Локальный Telegram Bot API сервер позволяет:
> - ✅ **Снять ограничение 20MB** на размер файлов (официальный API лимит)
> - ✅ Обрабатывать видео и аудио **любого размера** (1GB+)
> - ✅ Быстрее загружать файлы (прямой доступ к кешу)
> - ✅ Больше контроля и стабильности
>
> **Без локального API** официальный Telegram Bot API имеет **жесткий лимит 20MB**. С локальным сервером это ограничение полностью снимается!

**Способ 1: Через my.telegram.org**

1. Перейдите на [my.telegram.org/auth](https://my.telegram.org/auth)
2. Войдите с вашим номером телефона
3. Перейдите в "API development tools"
4. Создайте новое приложение (любое название)
5. **Сохраните**:
   - `api_id` (например: 12345678)
   - `api_hash` (например: 0123456789abcdef0123456789abcdef)

**Способ 2: Через telethon (если нет веб-доступа)**

```bash
# На локальном компьютере (не на сервере)
pip install telethon
python3 -c "from telethon import TelegramClient; import asyncio; asyncio.run(TelegramClient('temp', input('api_id: '), input('api_hash: ')).start())"
```

### 3.3 DigitalOcean Spaces (S3-хранилище)

1. Войдите в [DigitalOcean](https://cloud.digitalocean.com)
2. Перейдите в "Spaces" → "Manage Keys"
3. Нажмите "Generate New Key"
4. **Сохраните**:
   - Access Key ID (например: DO00ABCDEFGH12345678)
   - Secret Access Key (например: abc123def456...)

5. Создайте Bucket (Space):
   - Перейдите в "Spaces" → "Create Space"
   - Выберите регион (например: NYC3)
   - Название bucket (например: transcriptions-bucket)
   - **Сохраните**: название bucket и endpoint (например: nyc3.digitaloceanspaces.com)

### 3.4 Replicate API Token

1. Зарегистрируйтесь на [replicate.com](https://replicate.com)
2. Перейдите в [Account Settings](https://replicate.com/account/api-tokens)
3. Создайте новый API token
4. **Сохраните токен**: `r8_...` (начинается с r8_)

---

## 4. Установка проекта

### Создание рабочей директории

```bash
# Перейти в домашнюю директорию
cd ~

# Создать директорию для проекта
mkdir -p telegram-transcription
cd telegram-transcription
```

### Скачивание файлов проекта

**Вариант A: Если проект в Git**

```bash
git clone <URL_РЕПОЗИТОРИЯ> .
```

**Вариант B: Загрузка файлов вручную**

Скопируйте все файлы на сервер через SCP, SFTP или любой другой способ:

```bash
# С локального компьютера:
scp -r /path/to/files/* user@server-ip:~/telegram-transcription/
```

**Вариант C: Создание файлов вручную на сервере**

```bash
# Создать все необходимые файлы
touch docker-compose.yaml
touch Dockerfile.n8n
touch .env
touch workflow.json

# Затем скопировать содержимое каждого файла
```

### Проверка файлов

```bash
# Должны быть следующие файлы:
ls -la

# Основные файлы:
# - docker-compose.yaml
# - Dockerfile.n8n
# - workflow.json
# - .env.example
# - setup.sh (опционально)
```

---

## 5. Настройка окружения

### Создание .env файла

```bash
# Скопировать шаблон
cp .env.example .env

# Открыть для редактирования
nano .env
```

### Заполнение .env файла

Вставьте ваши реальные значения:

```env
# Telegram Bot Configuration (ОБЯЗАТЕЛЬНО)
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_API_ID=12345678
TELEGRAM_API_HASH=0123456789abcdef0123456789abcdef

# n8n Authentication (ОБЯЗАТЕЛЬНО - измените пароль!)
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=ваш_сильный_пароль_123

# n8n URLs (если используете домен, измените)
WEBHOOK_URL=http://your-server-ip:5678/
N8N_EDITOR_BASE_URL=http://your-server-ip:5678

# PostgreSQL (можно оставить по умолчанию)
POSTGRES_USER=n8n
POSTGRES_PASSWORD=n8n_secure_password_456
POSTGRES_DB=n8n

# DigitalOcean Spaces (ОБЯЗАТЕЛЬНО)
DO_SPACES_KEY=DO00ABCDEFGH12345678
DO_SPACES_SECRET=your_secret_key_here
DO_SPACES_BUCKET=transcriptions-bucket
DO_SPACES_ENDPOINT=nyc3.digitaloceanspaces.com
DO_SPACES_REGION=nyc3

# CDN (опционально)
DO_CDN_DOMAIN=

# Replicate API (ОБЯЗАТЕЛЬНО)
REPLICATE_API_TOKEN=r8_ваш_токен_здесь

# OpenAI (опционально)
OPENAI_API_KEY=
```

**Сохранение в nano:**
- Нажмите `Ctrl+X`
- Нажмите `Y` (Yes)
- Нажмите `Enter`

### Проверка .env файла

```bash
# Убедиться что файл создан и содержит ваши данные
cat .env | grep -v "^#" | grep -v "^$"

# ВАЖНО: не публикуйте этот файл!
```

---

## 6. Создание директорий

### Создание директории для Telegram Bot API

```bash
# Создать директорию для кэша Telegram Bot API
sudo mkdir -p /opt/tg-bot-api

# Дать права текущему пользователю
sudo chown -R $USER:$USER /opt/tg-bot-api

# Проверить
ls -la /opt/ | grep tg-bot-api
```

### Проверка /tmp

```bash
# Убедиться что /tmp существует и доступен для записи
ls -la / | grep tmp

# Права должны быть: drwxrwxrwt
```

---

## 7. Сборка образов

### Сборка n8n-ffmpeg образа

```bash
# Перейти в директорию проекта
cd ~/telegram-transcription

# Собрать образ n8n с FFmpeg (это займёт 5-10 минут)
docker build -t n8n-ffmpeg -f Dockerfile.n8n .

# Проверить что образ создан
docker images | grep n8n-ffmpeg
```

**Вывод должен быть:**
```
n8n-ffmpeg    latest    abc123def456    2 minutes ago    XXX MB
```

### Проверка сборки

```bash
# Тестовый запуск контейнера
docker run --rm n8n-ffmpeg ffmpeg -version

# Должна вывестись версия FFmpeg
```

---

## 8. Запуск сервисов

### Запуск через docker-compose

```bash
# Убедиться что находимся в директории проекта
cd ~/telegram-transcription

# Запустить все сервисы
docker-compose up -d

# Флаг -d запускает в фоновом режиме (detached)
```

**Процесс запуска:**
```
Creating network "telegram-transcription_app-net" ... done
Creating volume "telegram-transcription_postgres_data" ... done
Creating volume "telegram-transcription_n8n_data" ... done
Creating tg-bot-api ... done
Creating postgres ... done
Creating n8n ... done
```

### Проверка статуса сервисов

```bash
# Посмотреть статус всех контейнеров
docker-compose ps

# Все должны быть "Up" и "healthy"
```

**Ожидаемый вывод:**
```
Name                Command               State            Ports
------------------------------------------------------------------------
tg-bot-api   /telegram-bot-api ...        Up (healthy)   127.0.0.1:8081->8081/tcp
postgres     docker-entrypoint.sh ...     Up (healthy)   5432/tcp
n8n          docker-entrypoint.sh ...     Up             0.0.0.0:5678->5678/tcp
```

### Просмотр логов

```bash
# Логи всех сервисов
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs -f n8n
docker-compose logs -f tg-bot-api
docker-compose logs -f postgres

# Последние 50 строк
docker-compose logs --tail=50 n8n

# Выход из просмотра логов: Ctrl+C
```

### Проверка healthcheck

```bash
# Проверить что все сервисы healthy
docker-compose ps

# Или более подробно
docker inspect tg-bot-api | grep -A 5 "Health"
```

---

## 9. Настройка n8n

### 9.1 Доступ к веб-интерфейсу

1. **Откройте браузер** и перейдите по адресу:
   ```
   http://ВАШ_IP_СЕРВЕРА:5678
   ```

2. **Войдите** используя credentials из .env файла:
   - Username: `admin`
   - Password: ваш пароль из `N8N_BASIC_AUTH_PASSWORD`

### 9.2 Импорт workflow

1. В n8n нажмите **"Workflows"** в левом меню
2. Нажмите кнопку **"..."** → **"Import from File"**
3. Выберите файл `workflow.json` (загрузите с сервера или скопируйте содержимое)
4. Нажмите **"Import"**

**Если импортируете через копирование JSON:**
1. На сервере: `cat ~/telegram-transcription/workflow.json`
2. Скопируйте весь JSON
3. В n8n: "Import from URL or File" → вставьте JSON

### 9.3 Настройка Credentials

#### Credential 1: DigitalOcean Spaces (AWS S3)

1. В n8n перейдите в **"Credentials"** → **"Add Credential"**
2. Найдите и выберите **"AWS"** (не "AWS S3", а просто "AWS")
3. Заполните:
   - **Credential name**: `DigitalOcean Spaces`
   - **Access Key ID**: ваш `DO_SPACES_KEY`
   - **Secret Access Key**: ваш `DO_SPACES_SECRET`
   - **Region**: `nyc3` (или ваш регион)
   - **Custom Endpoints**: ✅ Включить (toggle on)
   - **S3 Endpoint**: `nyc3.digitaloceanspaces.com` (или ваш endpoint)
   - **Force Path Style**: ✅ Включить
4. Нажмите **"Save"**

#### Credential 2: Replicate API (HTTP Header Auth)

1. В n8n: **"Credentials"** → **"Add Credential"**
2. Найдите и выберите **"HTTP Header Auth"**
3. Заполните:
   - **Credential name**: `Replicate API`
   - **Name**: `Authorization`
   - **Value**: `Token ВАШ_REPLICATE_TOKEN`
     
     Например: `Token r8_abc123def456...`
4. Нажмите **"Save"**

### 9.4 Обновление URL в workflow

Откройте импортированный workflow и обновите webhook URLs:

#### Узел "To Replicate"

1. Найдите узел **"To Replicate"**
2. В параметрах найдите `webhook` URL
3. Замените `http://localhost:5678` на `http://ВАШ_IP:5678`
   
   Например: `http://95.142.47.123:5678/webhook/replicate-webh111`

#### Узел "Chat-GPT Formatting"

1. Найдите узел **"Chat-GPT Formatting"**
2. В параметрах найдите `webhook` URL
3. Замените `http://localhost:5678` на `http://ВАШ_IP:5678`
   
   Например: `http://95.142.47.123:5678/webhook/Repl-chatgpt`

### 9.5 Активация workflow

1. Убедитесь что все credentials настроены
2. В правом верхнем углу переключите **"Active"** в положение ON
3. Workflow должен показывать зелёный статус "Active"

---

## 10. Проверка работы

### 10.1 Проверка Telegram Bot API

```bash
# На сервере выполните
curl "http://127.0.0.1:8081/bot$(grep TELEGRAM_BOT_TOKEN .env | cut -d '=' -f2)/getMe"

# Должен вернуть JSON с информацией о боте
```

### 10.2 Проверка n8n API

```bash
# Проверить что n8n отвечает
curl http://localhost:5678

# Должна вернуться HTML страница
```

### 10.3 Тестовая отправка в Telegram

1. Откройте Telegram
2. Найдите вашего бота по username
3. Отправьте `/start`
4. Отправьте аудио или видео файл (можно голосовое сообщение)

### 10.4 Мониторинг выполнения

1. В n8n перейдите в **"Executions"**
2. Вы должны увидеть новое выполнение
3. Кликните на него чтобы увидеть детали
4. Проверьте что каждый узел выполнился успешно

**Ожидаемое время:**
- Webhook получен: ~0.1с
- FFmpeg обработка: 5-15с
- S3 загрузка: 2-5с
- Replicate транскрипция: 30-120с
- GPT форматирование: 5-15с
- Ответ в Telegram: 0.5с

---

## 11. Troubleshooting

### Проблема: tg-bot-api не становится healthy

**Проверка:**
```bash
docker-compose logs tg-bot-api
```

**Возможные причины:**
1. Неверный TELEGRAM_BOT_TOKEN
2. Неверный TELEGRAM_API_ID или TELEGRAM_API_HASH
3. Бот не зарегистрирован с этим API ID

**Решение:**
```bash
# Проверить переменные окружения
docker-compose exec tg-bot-api env | grep TELEGRAM

# Проверить вручную
docker-compose exec tg-bot-api wget -qO- "http://127.0.0.1:8081/bot$TELEGRAM_BOT_TOKEN/getMe"

# Пересоздать контейнер
docker-compose down
docker-compose up -d
```

### Проблема: n8n не может подключиться к tg-bot-api

**Проверка:**
```bash
# Проверить что оба контейнера в одной сети
docker network inspect telegram-transcription_app-net

# Проверить DNS резолвинг
docker-compose exec n8n ping -c 3 tg-bot-api

# Проверить доступность API
docker-compose exec n8n wget -qO- "http://tg-bot-api:8081/bot$TELEGRAM_BOT_TOKEN/getMe"
```

**Решение:**
```bash
# Пересоздать сеть
docker-compose down
docker network prune -f
docker-compose up -d
```

### Проблема: FFmpeg ошибка "No such file or directory"

**Проверка:**
```bash
# Проверить права на /opt/tg-bot-api
ls -la /opt/tg-bot-api

# Проверить что n8n может читать файлы
docker-compose exec n8n ls -la /opt/tg-bot-api
```

**Решение:**
```bash
# Дать правильные права
sudo chown -R $USER:$USER /opt/tg-bot-api
sudo chmod -R 755 /opt/tg-bot-api

# Перезапустить n8n
docker-compose restart n8n
```

### Проблема: S3 upload fails

**Проверка:**
```bash
# Проверить credentials в n8n UI
# Проверить что bucket существует в DigitalOcean
# Проверить endpoint и region
```

**Тест вручную:**
```bash
# Проверить что bucket доступен
curl -I https://YOUR_BUCKET.nyc3.digitaloceanspaces.com/
```

### Проблема: Replicate webhook не приходит

**Причины:**
1. n8n не доступен из интернета (нужен публичный IP)
2. Неверный webhook URL в workflow
3. Firewall блокирует порт 5678

**Решение:**
```bash
# Проверить firewall
sudo ufw status

# Открыть порт 5678
sudo ufw allow 5678/tcp

# Проверить что n8n доступен снаружи
curl http://ВАШ_ПУБЛИЧНЫЙ_IP:5678
```

### Проблема: Высокое использование ресурсов

**Проверка:**
```bash
# Посмотреть использование ресурсов
docker stats

# Посмотреть логи на ошибки
docker-compose logs --tail=100
```

**Оптимизация:**
```bash
# Очистить старые логи
docker-compose logs --no-log-prefix > /dev/null 2>&1

# Ограничить память для сервисов
# Отредактировать docker-compose.yaml и добавить:
# deploy:
#   resources:
#     limits:
#       memory: 512M
```

### Просмотр всех логов

```bash
# Сохранить все логи в файл
docker-compose logs > ~/logs.txt

# Посмотреть последние ошибки
docker-compose logs | grep -i error

# Мониторинг в реальном времени
docker-compose logs -f --tail=50
```

---

## 12. Полезные команды

### Управление сервисами

```bash
# Остановить все сервисы
docker-compose down

# Остановить и удалить volumes (ОСТОРОЖНО: удалит данные!)
docker-compose down -v

# Перезапустить конкретный сервис
docker-compose restart n8n

# Обновить образ и перезапустить
docker-compose pull
docker-compose up -d

# Пересобрать образ n8n-ffmpeg
docker build -t n8n-ffmpeg -f Dockerfile.n8n . --no-cache
docker-compose up -d --force-recreate n8n
```

### Backup и восстановление

```bash
# Backup PostgreSQL
docker-compose exec postgres pg_dump -U n8n n8n > backup_$(date +%Y%m%d).sql

# Восстановление PostgreSQL
docker-compose exec -T postgres psql -U n8n n8n < backup_20250112.sql

# Backup n8n workflows (экспорт из UI)
# Workflows → ... → Export

# Backup .env и конфигурации
tar -czf config_backup_$(date +%Y%m%d).tar.gz .env docker-compose.yaml Dockerfile.n8n

# Backup Telegram cache
sudo tar -czf tg-cache_backup_$(date +%Y%m%d).tar.gz /opt/tg-bot-api
```

### Мониторинг

```bash
# Статус контейнеров
docker-compose ps

# Использование ресурсов
docker stats

# Дисковое пространство
df -h
docker system df

# Очистка неиспользуемых образов
docker system prune -a
```

### Обновление проекта

```bash
# Если используется Git
cd ~/telegram-transcription
git pull

# Пересобрать образы
docker build -t n8n-ffmpeg -f Dockerfile.n8n . --no-cache
docker-compose build --no-cache

# Перезапустить с новыми образами
docker-compose up -d --force-recreate
```

---

## 13. Production рекомендации

### Безопасность

1. **Смените пароли**
   ```bash
   nano .env
   # Измените N8N_BASIC_AUTH_PASSWORD
   # Измените POSTGRES_PASSWORD
   ```

2. **Настройте firewall**
   ```bash
   sudo ufw enable
   sudo ufw allow 22/tcp   # SSH
   sudo ufw allow 5678/tcp # n8n
   # НЕ открывать 8081 - только localhost!
   ```

3. **Настройте SSL/TLS** (nginx + Let's Encrypt)
   ```bash
   sudo apt install nginx certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

4. **Регулярные обновления**
   ```bash
   # Добавить в crontab
   crontab -e
   # Добавить: 0 3 * * 0 cd ~/telegram-transcription && docker-compose pull && docker-compose up -d
   ```

### Мониторинг

1. **Автоматические логи**
   ```bash
   # Создать скрипт для ротации логов
   nano ~/log-rotation.sh
   ```
   
   ```bash
   #!/bin/bash
   cd ~/telegram-transcription
   docker-compose logs --since 24h > ~/logs/n8n_$(date +%Y%m%d).log
   find ~/logs/ -name "*.log" -mtime +7 -delete
   ```
   
   ```bash
   chmod +x ~/log-rotation.sh
   crontab -e
   # Добавить: 0 0 * * * ~/log-rotation.sh
   ```

2. **Healthcheck script**
   ```bash
   nano ~/healthcheck.sh
   ```
   
   ```bash
   #!/bin/bash
   if ! docker-compose ps | grep -q "Up (healthy)"; then
       echo "Service unhealthy, restarting..."
       cd ~/telegram-transcription
       docker-compose restart
   fi
   ```

### Backup автоматизация

```bash
nano ~/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR=~/backups
DATE=$(date +%Y%m%d)

mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T postgres pg_dump -U n8n n8n > $BACKUP_DIR/db_$DATE.sql

# Backup config
tar -czf $BACKUP_DIR/config_$DATE.tar.gz -C ~/telegram-transcription .env docker-compose.yaml

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
```

```bash
chmod +x ~/backup.sh
crontab -e
# Добавить: 0 2 * * * ~/backup.sh
```

---

## 14. Итоговый checklist

После завершения всех шагов, убедитесь что:

### ✅ Система
- [ ] Ubuntu обновлена
- [ ] Docker установлен и работает
- [ ] Docker Compose установлен
- [ ] Пользователь в группе docker

### ✅ API ключи получены
- [ ] TELEGRAM_BOT_TOKEN
- [ ] TELEGRAM_API_ID
- [ ] TELEGRAM_API_HASH
- [ ] DO_SPACES_KEY и DO_SPACES_SECRET
- [ ] REPLICATE_API_TOKEN

### ✅ Проект настроен
- [ ] Файлы проекта скопированы
- [ ] .env файл создан и заполнен
- [ ] /opt/tg-bot-api директория создана
- [ ] n8n-ffmpeg образ собран

### ✅ Сервисы запущены
- [ ] docker-compose up успешно выполнен
- [ ] Все контейнеры в статусе "Up (healthy)"
- [ ] Логи не показывают критических ошибок

### ✅ n8n настроен
- [ ] Доступ к веб-интерфейсу
- [ ] Workflow импортирован
- [ ] Credentials настроены (Spaces, Replicate)
- [ ] Webhook URLs обновлены
- [ ] Workflow активирован

### ✅ Тестирование
- [ ] Бот отвечает в Telegram
- [ ] Аудио/видео обрабатывается
- [ ] Транскрипция приходит пользователю
- [ ] Executions в n8n показывают успех

---

## 15. Контакты и поддержка

Если возникли проблемы:

1. **Проверьте логи**: `docker-compose logs -f`
2. **Проверьте статус**: `docker-compose ps`
3. **Проверьте executions** в n8n UI
4. **Используйте troubleshooting** из раздела 11

**Полезные ссылки:**
- n8n документация: https://docs.n8n.io
- Docker документация: https://docs.docker.com
- Replicate документация: https://replicate.com/docs
- Telegram Bot API: https://core.telegram.org/bots/api

---

**Успешной установки! 🚀**