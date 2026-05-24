# Build webhook. Based on from https://github.com/almir/docker-webhook
FROM golang:alpine3.23 AS build-webhook

# Install dependencies
WORKDIR /go/src/github.com/adnanh/webhook
ENV WEBHOOK_VERSION=2.8.3
RUN apk add --update -t build-deps curl libc-dev gcc libgcc

# Download and build webhook
RUN curl -L --silent -o webhook.tar.gz https://github.com/adnanh/webhook/archive/${WEBHOOK_VERSION}.tar.gz && \
    tar -xzf webhook.tar.gz --strip 1
RUN go mod download
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /usr/local/bin/webhook

# Base
FROM alpine:3.23 AS base

# Install common dependencies
RUN apk add --no-cache \
    curl \
    jq
# curl: Useful for callbacks, calling other webhooks.
# jq: Useful to work with json, on various docker outputs.

# Optional: Install AWS CLI
ARG AWS_ENABLED=false
RUN if [ "$AWS_ENABLED" = "true" ]; then apk add --no-cache aws-cli; fi

# Create non root user
RUN adduser -D webhook && \
    mkdir -p /opt/webhook/scripts && \
    chown -R webhook:webhook /opt/webhook

# Webhook
FROM base AS webhook

# Install webhook dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata

# Copy built webhook
COPY --from=build-webhook /usr/local/bin/webhook /usr/local/bin/webhook

WORKDIR     /etc/webhook
VOLUME      ["/etc/webhook"]
EXPOSE      9000
USER        webhook
ENTRYPOINT  ["/usr/local/bin/webhook"]
