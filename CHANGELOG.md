# Changelog

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
