#!/bin/bash
# Instala Node.js, clona el repo y deja la FibonacciApp corriendo con forever.
# Se ejecuta dentro de la VM (az vm run-command lo corre como root).
set -e

REPO=https://github.com/AndySzs/ARSW_LOAD-BALANCING_AZURE.git
APP_DIR=/opt/ARSW_LOAD-BALANCING_AZURE

# Swap de 1 GB: la B1ls solo tiene 0,5 GiB de RAM y npm install puede quedarse sin memoria
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

# Node.js 20 LTS
if ! command -v node >/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs git
fi

# Aplicación
rm -rf "$APP_DIR"
git clone "$REPO" "$APP_DIR"
cd "$APP_DIR/FibonacciApp"
npm install --omit=dev

# forever + arranque automático tras reinicio (p. ej. al cambiar el tamaño de la VM)
npm install -g forever
forever stopall || true
forever start "$APP_DIR/FibonacciApp/FibonacciApp.js"
(crontab -l 2>/dev/null | grep -v forever; echo "@reboot $(command -v forever) start $APP_DIR/FibonacciApp/FibonacciApp.js") | crontab -

sleep 2
curl -s http://localhost:3000/fibonacci/6
