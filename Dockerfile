FROM eclipse-temurin:25-jdk

RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    iproute2 \
    gosu \
    libsecret-1-0 \
    gnome-keyring \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1001 hytale && \
    useradd -m -u 1001 -g hytale -s /bin/bash hytale

WORKDIR /data

ENV HYTALE_PATCHLINE="release"
ENV UPDATE_ON_BOOT="false"
ENV SERVER_PORT="5520"
ENV JAVA_MS="2G"
ENV JAVA_MX="4G"
ENV TERM=xterm

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 5520/udp

ENTRYPOINT ["docker-entrypoint.sh"]
