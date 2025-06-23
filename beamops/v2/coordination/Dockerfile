# BeamOps V2 Coordination Service
FROM alpine:3.18

# Install required packages for coordination
RUN apk add --no-cache \
    bash \
    jq \
    curl \
    flock \
    openssl \
    coreutils

# Create coordination user
RUN addgroup -g 1000 coordination && \
    adduser -u 1000 -G coordination -s /bin/bash -D coordination

# Set up directories
RUN mkdir -p /coordination /scripts && \
    chown -R coordination:coordination /coordination /scripts

# Copy coordination scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Switch to coordination user
USER coordination

# Set working directory
WORKDIR /coordination

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /scripts/health-check.sh || exit 1

# Default command
CMD ["/scripts/coordination-daemon.sh"]