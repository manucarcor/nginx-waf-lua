#!/bin/sh -e
# Entrypoint del contenedor: sustituye variables de entorno en la configuración,
# arranca cron (reglas de Tor y logrotate) y finalmente ejecuta nginx.

export DNS_SERVER=${DNS_SERVER:-$(grep -i '^nameserver' /etc/resolv.conf|head -n1|cut -d ' ' -f2)}

ENV_VARIABLES=$(awk 'BEGIN{for(v in ENVIRON) print "$"v}')

# Nota: estas rutas coinciden con lo que copia el Dockerfile a /etc/nginx/conf/.
FILES="/etc/nginx/nginx.conf /etc/nginx/conf/default.conf /etc/modsecurity.d/modsecurity.conf"

for FILE in $FILES; do
    if [ -f "$FILE" ]; then
        envsubst "$ENV_VARIABLES" <"$FILE" | sponge "$FILE"
    fi
done

service cron start
# cron recogerá los ficheros de /etc/cron.d y /etc/cron.hourly
# se ejecutan una vez al arrancar: actualizar lista de Tor y activar reglas
sh /opt/scripts/tor.script
if [ -f /opt/modsecurity/activate-rules.sh ]; then
    sh /opt/modsecurity/activate-rules.sh || true
fi
exec "$@"
