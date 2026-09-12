# Guía de pruebas de gRPC

## Resumen
Este directorio contiene una configuración de pruebas para validar el soporte
de gRPC en el contenedor `nginx-waf-lua`.

## Soporte de gRPC
La compilación de Nginx incluye soporte HTTP/2 (`--with-http_v2_module`),
necesario para hacer proxy de gRPC.

## Entorno de pruebas

### Servicios
- **nginx**: contenedor principal con la configuración de proxy gRPC.
- **grpc-test-server**: servidor gRPC de prueba muy simple (basado en Go/busybox).
- **jaeger**: backend de trazas de OpenTelemetry.

### Puertos
- `80`: HTTP (redirige a HTTPS).
- `443`: HTTPS.
- `9443`: gRPC sobre HTTPS/HTTP2.
- `50051`: servidor gRPC de backend, en directo.
- `16686`: UI de Jaeger.

## Ejecutar las pruebas

### Prueba rápida
```bash
./test-grpc.sh
```

### Prueba manual
```bash
# Levantar el entorno
docker-compose up -d

# Comprobar soporte HTTP/2
curl -k --http2 -I https://localhost:443

# Probar gRPC con grpcurl (instálalo aparte)
grpcurl -insecure localhost:9443 grpc.health.v1.Health/Check

# Parar y limpiar
docker-compose down
```

## Ficheros de configuración

### Configuración del servidor gRPC
- `configs/conf.d/grpc_server.conf`: configuración de proxy gRPC.
- Puerto: 9443 (HTTPS/HTTP2).
- Backend: `grpc-test-server:50051`.

### Características
- ✅ Soporte HTTP/2 para gRPC
- ✅ Terminación TLS
- ✅ Protección WAF con ModSecurity
- ✅ Balanceo de carga
- ✅ Health checks
- ✅ Manejo de errores con códigos de estado gRPC
- ✅ Integración de trazas con OpenTelemetry

### Aspectos de seguridad
- Filtrado de user-agent
- Bloqueo de IPs de salida de Tor
- Validación de content-type
- Límite de tasa (vía ModSecurity)

## Solución de problemas

### Problemas habituales
1. **"HTTP/2 not supported"**: comprueba que nginx está compilado con `--with-http_v2_module`.
2. **"gRPC connection failed"**: comprueba que el servidor de backend está escuchando en el puerto 50051.
3. **"SSL certificate errors"**: en el entorno de pruebas se usan certificados autofirmados (genéralos con `../scripts/generar-certificados-dev.sh` antes de levantar el compose).

### Comandos de depuración
```bash
# Comprobar la configuración de nginx
docker-compose exec nginx nginx -t

# Comprobar los módulos cargados
docker-compose exec nginx nginx -V

# Ver logs
docker-compose logs nginx
docker-compose logs grpc-test-server

# Comprobar conectividad con el backend
docker-compose exec nginx telnet grpc-test-server 50051
```

## Ejemplo de cliente gRPC (Python)

```python
import grpc
import ssl

# Contexto SSL para certificados autofirmados (solo en desarrollo)
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

# Conectar contra el proxy gRPC
credentials = grpc.ssl_channel_credentials(ssl_context)
channel = grpc.secure_channel('localhost:9443', credentials)

# Aquí irían tus llamadas al cliente gRPC
```

## Prueba de rendimiento

### Prueba de carga básica
```bash
# Instalar grpcurl primero
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

# Prueba de carga sencilla
for i in {1..100}; do
  grpcurl -insecure localhost:9443 grpc.health.v1.Health/Check
done
```
