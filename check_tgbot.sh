#!/bin/bash

echo "=== Проверка Telegram Bot API ==="
echo ""

# Проверка переменных окружения
echo "1. Проверка .env файла:"
if [ -f .env ]; then
    echo "✅ .env файл существует"
    
    # Проверка обязательных переменных
    for var in TELEGRAM_BOT_TOKEN TELEGRAM_API_ID TELEGRAM_API_HASH; do
        if grep -q "^${var}=" .env; then
            value=$(grep "^${var}=" .env | cut -d '=' -f2)
            if [ -n "$value" ] && [ "$value" != "your_"* ] && [ "$value" != "123456"* ] && [ "$value" != "012345"* ]; then
                echo "✅ $var установлен"
            else
                echo "❌ $var не установлен или имеет значение по умолчанию"
            fi
        else
            echo "❌ $var отсутствует в .env"
        fi
    done
else
    echo "❌ .env файл не найден"
    exit 1
fi

echo ""
echo "2. Проверка статуса контейнера tg-bot-api:"
docker compose ps tg-bot-api

echo ""
echo "3. Логи tg-bot-api (последние 50 строк):"
docker compose logs --tail=50 tg-bot-api

echo ""
echo "4. Проверка healthcheck:"
docker inspect tg-bot-api 2>/dev/null | grep -A 10 "Health"

echo ""
echo "5. Попытка подключения к Bot API:"
BOT_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" .env | cut -d '=' -f2)
echo "Проверяем: http://127.0.0.1:8081/bot${BOT_TOKEN}/getMe"
curl -s "http://127.0.0.1:8081/bot${BOT_TOKEN}/getMe" | jq . 2>/dev/null || curl -s "http://127.0.0.1:8081/bot${BOT_TOKEN}/getMe"

echo ""
echo "=== Конец проверки ==="