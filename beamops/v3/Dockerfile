# BEAMOPS v3 Multi-Stage Docker Build
# Following Engineering Elixir Applications Chapter 3 patterns
# Final stage: 06_multi_stage (production-ready)

ARG EX_VSN=1.16.0
ARG OTP_VSN=26.2.1
ARG DEB_VSN=bullseye-20231009-slim
ARG BUILDER_IMG="hexpm/elixir:${EX_VSN}-erlang-${OTP_VSN}-debian-${DEB_VSN}"
ARG RUNNER_IMG="debian:${DEB_VSN}"

#######################################
# Builder Stage - Compile Application
#######################################
FROM ${BUILDER_IMG} AS builder

# Prepare build directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Create config directory
RUN mkdir config

# Copy compile-time config files before we compile dependencies
# This ensures any relevant config change will trigger dependencies to be re-compiled
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application source
COPY priv priv
COPY lib lib

# Copy and compile assets (if any)
# COPY assets assets
# RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Copy release configuration
COPY rel rel
RUN mix release

#######################################
# Runner Stage - Minimal Runtime Image
#######################################
FROM ${RUNNER_IMG} AS runner

# Install runtime dependencies
RUN apt-get update -y \
  && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

# Create app directory and user
WORKDIR "/app"
RUN groupadd --system --gid 1001 beamops && \
    useradd --system --uid 1001 --group beamops --home /app beamops && \
    chown beamops:beamops /app

# Set the runtime environment
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder \
     --chown=beamops:beamops /app/_build/${MIX_ENV}/rel/beamops ./

# Switch to non-root user
USER beamops

# Expose ports
EXPOSE 4000 9568

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Runtime configuration
ENV PHX_HOST="0.0.0.0"
ENV PHX_PORT="4000"
ENV PROMEX_PORT="9568"

# Labels for container management
LABEL org.opencontainers.image.title="BEAMOPS v3"
LABEL org.opencontainers.image.description="Enterprise AI Agent Coordination Infrastructure"
LABEL org.opencontainers.image.vendor="BEAMOPS"
LABEL org.opencontainers.image.version="3.0.0"
LABEL org.opencontainers.image.source="https://github.com/ai-self-sustaining-system"
LABEL org.opencontainers.image.documentation="https://github.com/ai-self-sustaining-system/blob/main/beamops/v3/README.md"

# Start the application
CMD ["/app/bin/server"]