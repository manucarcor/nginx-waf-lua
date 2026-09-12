# ============================
# Etapa 1: Compilación
# ============================
FROM debian:12.11-slim AS build

# Versiones / variables
ENV VERSION=1.31.5 \
    LUAJIT_VERSION=v2.1-20260824 \
    MODSECURITY_VERSION=v3.0.16 \
    MODSECURITY_NGINX_VERSION=v1.0.4 \
    NGXDEVELKIT_VERSION=0.3.4 \
    NGXLUA_VERSION=0.10.29 \
    OWASPCRS_VERSION=4.29.0 \
    LUA_RESTY_CORE=0.1.32 \
    LUAJIT_LIB=/usr/local/lib \
    LUAJIT_INC=/usr/local/include/luajit-2.1 \
    LD_LIBRARY_PATH=/usr/local/lib \
    RESTY_LRUCACHE_VERSION=0.15

# Dependencias de build
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential autoconf automake curl ca-certificates bash git \
    libpcre3-dev libpcre2-dev libssl-dev libffi-dev libtool pkg-config zlib1g-dev wget \
    moreutils cmake libc-ares-dev libre2-dev libyajl-dev libyajl2 yajl-tools && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src

# LuaJIT
RUN git clone --depth 1 -b ${LUAJIT_VERSION} https://github.com/openresty/luajit2.git /src/luajit2 && \
    cd /src/luajit2 && make -j"$(nproc)" && make install

# ModSecurity (lib) + conector nginx
RUN git clone --depth 1 -b ${MODSECURITY_NGINX_VERSION} https://github.com/owasp-modsecurity/ModSecurity-nginx.git /src/ModSecurity-nginx && \
    git clone --depth 1 -b ${MODSECURITY_VERSION} https://github.com/owasp-modsecurity/ModSecurity.git /src/ModSecurity && \
    cd /src/ModSecurity && git submodule update --init --recursive && \
    ./build.sh && ./configure --with-yajl="/usr" && \
    make -j"$(nproc)" && make install

# Nginx + módulos de OpenResty
RUN wget -qO - https://nginx.org/download/nginx-${VERSION}.tar.gz | tar xzf - && \
    wget -qO - https://github.com/openresty/lua-nginx-module/archive/v${NGXLUA_VERSION}.tar.gz | tar xzf - && \
    wget -qO - https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v${NGXDEVELKIT_VERSION}.tar.gz | tar xzf -

# OpenTelemetry módulo NGINX
RUN git clone --depth 1 https://github.com/nginxinc/nginx-otel.git /src/nginx-otel && \
    if [ -f /src/nginx-otel/config ]; then sed -i 's/NGX_OTEL_FETCH_DEPS=OFF/NGX_OTEL_FETCH_DEPS=ON/g' /src/nginx-otel/config || true; fi

# Compilación de NGINX (con gRPC vía HTTP/2)
RUN cd /src/nginx-${VERSION} && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_stub_status_module \
        --with-http_gzip_static_module \
        --with-threads \
        --with-compat \
        --with-stream \
        --with-debug \
        --add-module=/src/ngx_devel_kit-${NGXDEVELKIT_VERSION} \
        --add-module=/src/lua-nginx-module-${NGXLUA_VERSION} \
        --add-dynamic-module=/src/ModSecurity-nginx \
        --add-dynamic-module=/src/nginx-otel && \
    make -j"$(nproc)" && \
    make install && \
    make -j"$(nproc)" modules && \
    mkdir -p /etc/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules && \
    cp objs/ngx_otel_module.so /etc/nginx/modules && \
    /usr/sbin/nginx -V 2>&1 | tee /tmp/nginx-build.txt && \
    /usr/sbin/nginx -V 2>&1 | grep -q -- '--with-http_v2_module'

# Lua-resty-core
RUN wget -qO - https://github.com/openresty/lua-resty-core/archive/refs/tags/v${LUA_RESTY_CORE}.tar.gz | tar xzf - -C /src && \
    cd /src/lua-resty-core-${LUA_RESTY_CORE} && \
    make install LUA_LIB_DIR=/usr/local/share/lua/5.1

# Lua-resty-lrucache
RUN wget -qO - https://github.com/openresty/lua-resty-lrucache/archive/v${RESTY_LRUCACHE_VERSION}.tar.gz | tar xzf - -C /src && \
    cd /src/lua-resty-lrucache-${RESTY_LRUCACHE_VERSION} && \
    make install LUA_LIB_DIR=/usr/local/share/lua/5.1

# OWASP CRS
RUN wget -qO - https://github.com/coreruleset/coreruleset/archive/v${OWASPCRS_VERSION}.tar.gz | tar xzf - && \
    mkdir -p /etc/modsecurity.d/owasp-crs && \
    cp -r /src/coreruleset-${OWASPCRS_VERSION}/* /etc/modsecurity.d/owasp-crs/ && \
    cp /etc/modsecurity.d/owasp-crs/crs-setup.conf.example /etc/modsecurity.d/owasp-crs/crs-setup.conf

# ============================
# Etapa 2: Runtime
# ============================
FROM debian:12.11-slim

# Paquetes mínimos runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates bash curl moreutils cron gettext logrotate \
    libpcre3 libpcre2-8-0 libc-ares2 libre2-9 libyajl2 libssl3 zlib1g && \
    rm -rf /var/lib/apt/lists/*

# Variables de entorno finales
ENV USER=nginx \
    LD_LIBRARY_PATH=/usr/local/lib:/opt/modsecurity/src/.libs \
    ANOMALY_INBOUND=5 \
    ANOMALY_OUTBOUND=4 \
    BLOCKING_PARANOIA=1 \
    OPENSSL_VERSION=1.1.1w \
    PORT=80

# Copias desde build
COPY --from=build /etc/nginx/ /etc/nginx/
COPY --from=build /usr/sbin/nginx /usr/sbin/
COPY --from=build /usr/local/lib/libluajit-5.1.so.2 /usr/local/lib/
COPY --from=build /usr/local/share/lua/5.1/resty/ /usr/local/share/lua/5.1/resty/
COPY --from=build /src/ModSecurity/src/.libs/libmodsecurity.so* /opt/modsecurity/src/.libs/
COPY --from=build /etc/modsecurity.d/owasp-crs /etc/modsecurity.d/owasp-crs/
COPY --from=build /usr/lib/x86_64-linux-gnu/libyajl.so.2 /usr/lib/x86_64-linux-gnu/

# Configuración propia
COPY assets/nginx/nginx.conf /etc/nginx/
COPY assets/nginx/modsecurity.conf /etc/modsecurity.d/
COPY assets/nginx/conf/*.conf /etc/nginx/conf/
COPY assets/nginx/ssl /etc/nginx/ssl/
COPY assets/nginx/docker-entrypoint.sh /docker-entrypoint.sh
COPY assets/nginx/conf/tor.script /opt/scripts/tor.script
COPY assets/nginx/conf/useragent.filter /opt/scripts/
COPY assets/nginx/conf/unicode.mapping /etc/modsecurity.d/unicode.mapping
COPY assets/nginx/modsecurity/activate-rules.sh /opt/modsecurity/activate-rules.sh
COPY assets/nginx/modsecurity/tx-overrides.conf.default /etc/modsecurity.d/owasp-crs/tx-overrides.conf
COPY assets/cron /etc/cron.d/
COPY assets/nginx/cron.hourly/logrotate /etc/cron.hourly/logrotate

# Sistema / permisos
RUN ln -s /usr/lib/x86_64-linux-gnu/libyajl.so.2 /usr/lib/libyajl.so.2 && \
    ldconfig && \
    mkdir -p /var/log/nginx && \
    groupadd nginx && useradd -s /usr/sbin/nologin -g nginx -M nginx && \
    chmod +x /docker-entrypoint.sh && \
    chmod +x /opt/modsecurity/activate-rules.sh && \
    chmod +x /etc/cron.hourly/logrotate && \
    chown nginx:nginx /var/log/nginx && \
    if [ -d /etc/cron.d ]; then chmod 0644 /etc/cron.d/* || true; fi

EXPOSE 80 443

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
