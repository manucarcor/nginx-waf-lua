#!/bin/sh
# Genera un fichero de overrides para ModSecurity/OWASP CRS a partir de las
# variables de entorno del contenedor (ver tabla en README): nivel de
# paranoia y umbrales de anomalía de tráfico entrante/saliente.
#
# Se ejecuta al arrancar el contenedor (docker-entrypoint.sh) y cada 5
# minutos vía cron (assets/cron/nginx-cron), igual que tor.script para la
# lista de nodos Tor. Como con tor.script, el fichero generado solo surte
# efecto tras un (re)arranque de nginx: este script no hace `nginx -s reload`.
set -eu

BLOCKING_PARANOIA="${BLOCKING_PARANOIA:-1}"
ANOMALY_INBOUND="${ANOMALY_INBOUND:-5}"
ANOMALY_OUTBOUND="${ANOMALY_OUTBOUND:-4}"

OUT=/etc/modsecurity.d/owasp-crs/tx-overrides.conf

cat > "$OUT" <<EOF
SecAction \\
    "id:900000,\\
    phase:1,\\
    pass,\\
    t:none,\\
    nolog,\\
    tag:'OWASP_CRS',\\
    setvar:tx.blocking_paranoia_level=${BLOCKING_PARANOIA}"

SecAction \\
    "id:900110,\\
    phase:1,\\
    pass,\\
    t:none,\\
    nolog,\\
    tag:'OWASP_CRS',\\
    setvar:tx.inbound_anomaly_score_threshold=${ANOMALY_INBOUND},\\
    setvar:tx.outbound_anomaly_score_threshold=${ANOMALY_OUTBOUND}"
EOF
