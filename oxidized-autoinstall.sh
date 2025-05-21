SERVICE_FILE="/etc/systemd/system/oxidized.service"
WORKINGDIR="/etc/oxidized"

sudo add-apt-repository universe
sudo apt-get install ruby ruby-dev libsqlite3-dev libssl-dev pkg-config cmake libssh2-1-dev libicu-dev zlib1g-dev g++ libyaml-dev
sudo gem install oxidized
sudo gem install oxidized-script oxidized-web

sudo mkdir $WORKINGDIR

sudo tee "$WORKINGDIR/config" > /dev/null <<EOF
---
rest: 0.0.0.0:8888
username: user-here
password: password-here
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
  enable: password-here
EOF

sudo tee "$WORKINGDIR/devices.db" > /dev/null <<EOF
example-switch01:cisco:192.168.1.1
example-switch02:cisco:192.168.1.2
example-switch03:cisco:192.168.1.3
EOF

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
User=administrator
WorkingDirectory=$WORKINGDIR
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo chown $USER:$USER -R /etc/oxidized

#sudo systemctl start oxidized
#sudo systemctl daemon-reload
#sudo systemctl enable oxidized

echo -e "\e[32mInstallation complete, do the following to match your setup:
 1. Edit $WORKINGDIR/config to match the correct user/password, and enable password
 2. Edit $WORKINGDIR/devices.db to match the correct devices
 3. Use following commands to start, and enable the service, and reload the systemd daemon
    sudo systemctl start oxidized
    sudo systemctl daemon-reload
    sudo systemctl enable oxidized
 4. *Add SSL certificate with Apache or NGINX
\e[0m"
