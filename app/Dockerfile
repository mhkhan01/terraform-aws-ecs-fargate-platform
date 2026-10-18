# Hardened variant of the demo image: nginx-unprivileged runs as UID 101 and listens
# on 8080, so the task can use a non-root user and a read-only root filesystem
# (with /tmp mounted writable via the module's writable_paths).
FROM nginxinc/nginx-unprivileged:stable-alpine

COPY --chown=101:101 index.html /usr/share/nginx/html/index.html

USER 101
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
