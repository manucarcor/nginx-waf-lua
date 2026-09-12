# Changelog

## [1.1.0-demo] - 2026-09-12
### Arreglado
* **El WAF nunca se activaba.** El módulo ModSecurity se cargaba y
  `SecRuleEngine On` estaba puesto, pero faltaban `modsecurity on;` /
  `modsecurity_rules_file` en el `location /` de `default.conf`: todo el
  tráfico (incluidos SQLi/XSS) pasaba sin inspección. Añadidas las
  directivas que lo activan.
* **`/opt/modsecurity/activate-rules.sh` no existía**, pese a que el
  entrypoint y el cron lo invocaban (silenciado con `|| true`). Las
  variables `BLOCKING_PARANOIA`, `ANOMALY_INBOUND` y `ANOMALY_OUTBOUND` del
  README no tenían ningún efecto real. Reconstruido siguiendo el mismo
  patrón que `tor.script`: genera `owasp-crs/tx-overrides.conf` a partir de
  las variables de entorno, incluido desde `modsecurity.conf`.

### Quitado
* **`MODSEC_DEFAULT_PHASE1_ACTION` / `MODSEC_DEFAULT_PHASE2_ACTION`**
  estaban documentadas en el README sin estar cableadas a nada. Se intentó
  cablearlas como `SecDefaultAction` en `modsecurity.conf`, pero el propio
  OWASP CRS ya define su `SecDefaultAction` (`phase:1/2,log,auditlog,pass`)
  en `crs-setup.conf` — es lo que hace posible el sistema de scoring de
  anomalías. ModSecurity no permite dos `SecDefaultAction` en la misma fase
  y directamente aborta el arranque de nginx si lo intentas (`nginx: [emerg]
  ... SecDefaultActions can only be placed once per phase`). Quitadas del
  README y de `test/docker-compose.yaml`; para ajustar cuándo bloquea el WAF
  se usa `BLOCKING_PARANOIA` / `ANOMALY_INBOUND` / `ANOMALY_OUTBOUND`.

### Añadido
* `.gitignore` — los certificados TLS de desarrollo generados por
  `scripts/generar-certificados-dev.sh` no estaban excluidos de git pese a
  que la documentación decía que sí.
* `.github/workflows/build.yml` — compila la imagen y ejecuta un smoke test
  (tráfico normal -> 200, SQLi/XSS -> 403) en cada push/PR a `main`. Hace
  real lo que ya decía este changelog sobre mover el CI a GitHub Actions.
* README: sección para verificar que el WAF bloquea de verdad (no solo que
  el proxy funciona), aviso del tiempo/CPU que lleva el primer build, y
  nota sobre la limitación de recarga en caliente de `activate-rules.sh` y
  `tor.script`.

### Cambiado
* Versiones de las dependencias compiladas actualizadas a las últimas
  disponibles: NGINX 1.29.7 → 1.31.5, LuaJIT2 → v2.1-20260824,
  ModSecurity → v3.0.16, ngx_devel_kit → v0.3.4, OWASP CRS → v4.29.0,
  lua-resty-core → v0.1.32 (ModSecurity-nginx v1.0.4 y lua-resty-lrucache
  v0.15 ya estaban al día). `lua-nginx-module` se quedó en **v0.10.29**
  (no en la v0.10.31 más reciente): `lua-resty-core` v0.1.32 comprueba en
  tiempo de arranque que `ngx_lua_version` sea **exactamente** `10029`
  (`~=`, no `<`), así que emparejarlo con v0.10.31 hace que nginx aborte
  con "ngx_http_lua_module 0.10.29 required" nada más arrancar — estos dos
  componentes de OpenResty hay que versionarlos juntos, no cada uno a su
  "última" tag por separado. Build completo verificado tras la
  actualización; el salto a ModSecurity v3.0.16 obligó a dos ajustes más:
  - `git submodule update --init --recursive` en vez de `init && update`:
    v3.0.16 depende de Mbed TLS como submódulo anidado, que no se
    descargaba con el comando anterior (`configure` fallaba con "Mbed TLS
    was not found").
  - Añadidas `libpcre2-dev` (build) y `libpcre2-8-0` (runtime): v3.0.16
    requiere PCRE2 en tiempo de compilación y solo teníamos PCRE1
    (`libpcre3-dev`), así que `pcre2.h` no existía y la compilación
    abortaba.
* Eliminadas `OTEL_NGINX_VERSION` y `MODSECURITY_DOCKER_VERSION` del
  Dockerfile: eran variables sin uso real (el módulo OTel siempre se
  compila desde la rama por defecto del repo, sin `-b`).

## [1.0.0-demo] - 2026-09-12
### Cambiado
* Versión pública/didáctica adaptada de un proyecto real: se ha eliminado
  toda referencia a la empresa y al cliente originales (dominios, registros
  Docker, librería compartida de Jenkins), se han quitado los certificados
  TLS que venían commiteados (ver `scripts/generar-certificados-dev.sh`), y
  se ha corregido el rango de IPs permitido en `/metrics/nginx`
  (`172.0.0.0/8` era más amplio de lo pretendido; ahora son solo rangos
  privados RFC1918).
* Backend de ejemplo (`docker-compose.yml`) apuntando a un contenedor
  `whoami` en vez de a un dominio público real, para poder probar la demo
  sin depender de servicios de terceros.
* CI movido de un Jenkinsfile con librería compartida interna a GitHub
  Actions (se conserva un Jenkinsfile genérico como referencia).
