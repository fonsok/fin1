# Shared Dockerfile for FIN1 Node.js services
# Used by: parse-server, market-data, notification-service, analytics-service
#
# Build args:
#   SERVICE_PORT        – port the service listens on (required)
#   EXTRA_DIR           – additional directory to create under /app (default: logs)
#   HEALTHCHECK_START   – deprecated (Dockerfile HEALTHCHECK options require literal durations)

FROM node:18-alpine

ARG SERVICE_PORT
ARG EXTRA_DIR=logs
ARG HEALTHCHECK_START=5s

WORKDIR /app

RUN apk add --no-cache curl python3 make g++ && rm -rf /var/cache/apk/*

COPY package*.json ./
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi && npm cache clean --force

COPY . .

RUN mkdir -p /app/logs /app/${EXTRA_DIR}

RUN chown -R node:node /app
USER node

EXPOSE ${SERVICE_PORT}

# NOTE: Docker parses HEALTHCHECK option durations as literals during Dockerfile parsing.
# Variable substitution is not supported reliably here, so we use a fixed start period.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:${SERVICE_PORT}/health || exit 1

CMD ["npm", "start"]
