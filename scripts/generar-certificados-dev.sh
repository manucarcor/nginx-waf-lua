#!/usr/bin/env bash
# Genera certificados TLS autofirmados SOLO para desarrollo/pruebas locales.
#
# Por qué existe este script: la versión original de este proyecto llevaba un
# certificado y una clave privada de ejemplo commiteados en el repositorio.
# Aunque ese par en concreto no era sensible (era el típico "Default Company
# Ltd" que genera OpenSSL de fábrica), commitear claves privadas —reales o de
# juguete— es una mala práctica que conviene no repetir ni siquiera en una
# demo. Este script las genera bajo demanda y quedan ignoradas por git.
#
# Uso:
#   bash scripts/generar-certificados-dev.sh
set -euo pipefail

DESTINOS=(
  "assets/nginx/ssl"
  "test/configs/certs"
)

for DIR in "${DESTINOS[@]}"; do
  mkdir -p "$DIR"
  if [ -f "$DIR/server.crt" ] && [ -f "$DIR/server.key" ]; then
    echo "Ya existen certificados en $DIR, no se regeneran (bórralos si quieres uno nuevo)."
    continue
  fi
  openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "$DIR/server.key" \
    -out "$DIR/server.crt" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=Demo/OU=Portfolio/CN=localhost"
  echo "Certificado autofirmado generado en $DIR (válido 365 días, solo para uso local)."
done
