FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        mariadb-server mariadb-client libpcre3 libssl3 libmariadb3 libxml2 procps \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
