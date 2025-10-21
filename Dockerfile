ARG PG_VERSION=17

FROM postgres:${PG_VERSION}-alpine

ENV LOCALTIME_FILE="/tmp/localtime"

COPY scripts/*.sh /app/

COPY --from=ghcr.io/benjithatfoxguy/bclone /usr/local/bin/rclone /usr/bin/rclone

RUN mkdir -p /backup \
  && chmod +x /app/*.sh \
  && apk add --no-cache 7zip bash supercronic s-nail tzdata \
  && ln -sf "${LOCALTIME_FILE}" /etc/localtime

USER root

ENV XDG_CONFIG_HOME=/config

ENTRYPOINT ["/app/entrypoint.sh"]
