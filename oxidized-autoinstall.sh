SERVICE_FILE="/etc/systemd/system/oxidized.service"
CONFIG_PATH="/etc/oxidized/config"
WORKINGDIR="/etc/oxidized"
HOSTNAME=$(hostname)

sudo add-apt-repository universe
sudo apt-get install ruby ruby-dev libsqlite3-dev libssl-dev pkg-config cmake libssh2-1-dev libicu-dev zlib1g-dev g++ libyaml-dev -y
sudo gem install oxidized
sudo gem install oxidized-script oxidized-web

sudo mkdir $WORKINGDIR

echo "Enter your Oxidized username:"
read -r USERNAME

echo "Enter your Oxidized password:"
read -rs PASSWORD
echo

echo "Enter your Oxidized enable password:"
read -rs ENABLE_PASSWORD
echo

echo "Enter the FQDN or IP of this device:"e
read -rs FQDN
echo

sudo tee "$WORKINGDIR/config" > /dev/null <<EOF
---
rest: 0.0.0.0:8888
username: $USERNAME
password: $PASSWORD
model: ios
resolve_dns: true
interval: 3600
use_syslog: false
debug: false
run_once: false
threads: 30
use_max_threads: false
timeout: 20
retries: 3
prompt: !ruby/regexp /^([\w.@-]+[#>]\s?)$/
next_adds_job: false
pid: "$"
extensions:
  oxidized-web:
    load: true
crash:
  directory: "$WORKINGDIR/crashes"
  hostnames: false
stats:
  history_size: 10
input:
  default: ssh
  debug: false
  ssh:
    secure: false
  ftp:
    passive: true
  utf8_encoded: true
output:
  default: git
  git:
    user: Oxidized
    email: oxidized@localhost
    repo: "$WORKINGDIR/backup.git"
source:
  default: csv
  csv:
    file: "$WORKINGDIR/devices.db"
    delimiter: !ruby/regexp /:/
    map:
      name: 0
      model: 1
    gpg: false
model_map:
  cisco: ios
vars:
  enable: $ENABLE_PASSWORD
EOF

sudo tee "$WORKINGDIR/devices.db" > /dev/null <<EOF
router1:cisco:192.168.1.1
router2:cisco:192.168.1.2
EOF
echo "Oxidized devices written to /etc/oxidized/devices.db"

sudo git init $WORKINGDIR/backup.git
cd $WORKINGDIR/backup.git
sudo git config user.name "Oxidized"
sudo git config user.email "oxidized@localhost"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Oxidized Network Configuration Backup Service
After=network.target

[Service]
Environment=OXIDIZED_HOME=$WORKINGDIR
ExecStart=/usr/local/bin/oxidized
User=$USER
WorkingDirectory=$WORKINGDIR
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo chown $USER:$USER -R /etc/oxidized

sudo apt install apache2 -y

sudo systemctl daemon-reload
sudo systemctl enable oxidized

sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod ssl
sudo a2enmod rewrite

sudo rm /etc/apache2/sites-enabled/000-default.conf
sudo mkdir /etc/apache2/ssl

sudo tee "/etc/apache2/sites-available/oxidized.conf" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $HOSTNAME
    Redirect permanent / https://$FQDN/
</VirtualHost>

<VirtualHost *:443>
    ServerName $HOSTNAME

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/oxidized.crt
    SSLCertificateKeyFile /etc/apache2/ssl/oxidized.key

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:8888/
    ProxyPassReverse / http://127.0.0.1:8888/
</VirtualHost>
EOF

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/apache2/ssl/oxidized.key \
  -out /etc/apache2/ssl/oxidized.crt

sudo a2ensite oxidized.conf
sudo systemctl restart apache2

echo "Configure /etc/oxidized/devices.db, and proper SSL certificate"
