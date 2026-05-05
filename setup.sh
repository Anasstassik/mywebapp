#!/bin/bash

set -e

apt-get update
apt-get install -y curl dirmngr apt-transport-https lsb-release ca-certificates
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs postgresql postgresql-contrib nginx sudo git

useradd -m -s /bin/bash -G sudo student

useradd -m -s /bin/bash -G sudo teacher
echo "teacher:12345678" | chpasswd
chage -d 0 teacher

useradd -r -s /bin/false app

useradd -m -s /bin/bash operator
echo "operator:12345678" | chpasswd
chage -d 0 operator

cat <<EOF > /etc/sudoers.d/operator
operator ALL=(ALL) /bin/systemctl start mywebapp.service
operator ALL=(ALL) /bin/systemctl stop mywebapp.service
operator ALL=(ALL) /bin/systemctl restart mywebapp.service
operator ALL=(ALL) /bin/systemctl status mywebapp.service
operator ALL=(ALL) /usr/sbin/nginx -s reload
operator ALL=(ALL) /bin/systemctl reload nginx
EOF
chmod 0440 /etc/sudoers.d/operator

echo "9" > /home/student/gradebook
chown student:student /home/student/gradebook

su - postgres -c "psql -c \"CREATE USER postgres WITH PASSWORD '12345';\""
su - postgres -c "psql -c \"ALTER USER postgres WITH SUPERUSER;\""
su - postgres -c "psql -c \"CREATE DATABASE notesdb OWNER postgres;\""

passwd -l ubuntu || true
passwd -l root || true

mkdir -p /opt/mywebapp
chown -R app:app /opt/mywebapp

mkdir -p /etc/mywebapp
cat <<EOF > /etc/mywebapp/config.json
{
  "port": 5000,
  "database_url": "postgresql://postgres:12345@localhost:5432/notesdb"
}
EOF
chown -R app:app /etc/mywebapp

cat <<EOF > /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/mywebapp.access.log;
    error_log /var/log/nginx/mywebapp.error.log;

    location = / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /notes {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location / {
        return 404;
    }
}
EOF

ln -s /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/ || true
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

cat <<EOF > /etc/systemd/system/mywebapp.socket
[Unit]
Description=MyWebApp Socket

[Socket]
ListenStream=5000
NoDelay=true

[Install]
WantedBy=sockets.target
EOF

cat <<EOF > /etc/systemd/system/mywebapp.service
[Unit]
Description=MyWebApp Notes Service
After=network.target postgresql.service
Requires=postgresql.service mywebapp.socket

[Service]
Type=simple
User=app
Group=app
WorkingDirectory=/opt/mywebapp
Environment="DATABASE_URL=postgresql://postgres:12345@localhost:5432/notesdb"
Environment="PORT=5000"
ExecStartPre=/usr/bin/npx prisma migrate deploy
ExecStart=/usr/bin/node server.js
NonBlocking=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl disable mywebapp.service || true
systemctl stop mywebapp.service || true
systemctl enable mywebapp.socket
systemctl start mywebapp.socket

cp -r ./* /opt/mywebapp/
cd /opt/mywebapp
npm install
chown -R app:app /opt/mywebapp
systemctl restart mywebapp.socket