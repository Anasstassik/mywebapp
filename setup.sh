#!/bin/bash

# Зупиняємо скрипт, якщо десь виникне помилка
set -e

echo "Починаємо встановлення та налаштування сервера..."

# 1. Встановлення необхідних пакетів (Node.js, Nginx, PostgreSQL)
echo "Встановлюємо Nginx, PostgreSQL та залежності..."
apt-get update
apt-get install -y curl sudo nginx postgresql postgresql-contrib

echo "Встановлюємо Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs

# 2. Створення користувачів за вимогами методички
echo "Налаштовуємо користувачів системи..."

# Користувач student (адміністративні права)
if ! id -u student > /dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo student
    echo "student:student123" | chpasswd
fi

# Користувач teacher (адміністративні права, зміна пароля при першому вході)
if ! id -u teacher > /dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo teacher
    echo "teacher:12345678" | chpasswd
    chage -d 0 teacher
fi

# Користувач app (системний користувач, від якого запускається застосунок)
if ! id -u app > /dev/null 2>&1; then
    useradd -r -s /bin/false app
fi

# Користувач operator (обмежений доступ, зміна пароля при першому вході)
if ! id -u operator > /dev/null 2>&1; then
    # Розумна перевірка на існування групи operator (щоб уникнути помилки)
    if getent group operator > /dev/null; then
        useradd -m -s /bin/bash -g operator operator
    else
        useradd -m -s /bin/bash operator
    fi
    echo "operator:12345678" | chpasswd
    chage -d 0 operator
fi

# Налаштовуємо жорсткі права для operator через sudoers
cat <<EOF > /etc/sudoers.d/operator
operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp, /bin/systemctl stop mywebapp, /bin/systemctl restart mywebapp, /bin/systemctl status mywebapp, /bin/systemctl reload nginx
EOF
chmod 0440 /etc/sudoers.d/operator

# 3. Налаштування бази даних PostgreSQL
echo "Налаштовуємо базу даних..."
sudo -u postgres psql -c "CREATE USER dbuser WITH PASSWORD 'dbpassword';" || true
sudo -u postgres psql -c "CREATE DATABASE notes_db OWNER dbuser;" || true

# 4. Налаштування застосунку mywebapp
APP_DIR="/opt/mywebapp"
echo "Копіюємо файли застосунку в $APP_DIR..."

mkdir -p $APP_DIR
# Копіюємо всі файли з поточної папки
cp -r ./* $APP_DIR/
cd $APP_DIR

# НОВИЙ ФІКС: Примусово створюємо правильний .env для сервера, щоб перебити будь-який кеш
echo 'DATABASE_URL="postgresql://dbuser:dbpassword@localhost:5432/notes_db"' > .env

echo "Встановлюємо залежності Node.js..."
npm install

echo "Застосовуємо міграції бази даних Prisma..."
export DATABASE_URL="postgresql://dbuser:dbpassword@localhost:5432/notes_db"
npx prisma generate
npx prisma migrate deploy

# Передаємо права на папку службовому користувачу app
chown -R app:app $APP_DIR

# 5. Налаштування Systemd сервісу
echo "Створюємо системний сервіс..."
cat <<EOF > /etc/systemd/system/mywebapp.service
[Unit]
Description=My Web App (Notes Service)
After=network.target postgresql.service

[Service]
Environment=PORT=5000
Environment=DATABASE_URL="postgresql://dbuser:dbpassword@localhost:5432/notes_db"
Type=simple
User=app
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node server.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mywebapp
systemctl restart mywebapp

# 6. Налаштування Nginx (Reverse Proxy)
echo "Налаштовуємо Nginx (Reverse Proxy на 80 порт)..."
cat <<EOF > /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Вмикаємо конфіг і видаляємо дефолтний
ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# 7. Фінальний штрих (створення файлу gradebook з номером варіанту)
if [ -d "/home/student" ]; then
    echo "9" > /home/student/gradebook
    chown student:student /home/student/gradebook
fi

echo "Встановлення успішно завершено! Застосунок працює та доступний."