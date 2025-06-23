# NuxtOps V3 Multi-Stage Dockerfile
# Production-ready Nuxt 3 application with full observability

# Stage 1: Dependencies
FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat python3 make g++
WORKDIR /app

# Copy package files
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

# Install dependencies based on lockfile
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "No lockfile found." && exit 1; \
  fi

# Stage 2: Builder
FROM node:20-alpine AS builder
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build arguments for environment configuration
ARG NUXT_PUBLIC_API_BASE
ARG NUXT_PUBLIC_SITE_URL
ARG NITRO_PRESET=node-server

ENV NUXT_PUBLIC_API_BASE=$NUXT_PUBLIC_API_BASE
ENV NUXT_PUBLIC_SITE_URL=$NUXT_PUBLIC_SITE_URL
ENV NITRO_PRESET=$NITRO_PRESET
ENV NODE_ENV=production

# Generate production build
RUN \
  if [ -f yarn.lock ]; then yarn build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then pnpm build; \
  fi

# Stage 3: Production
FROM node:20-alpine AS runner
RUN apk add --no-cache libc6-compat curl

# Add non-root user
RUN addgroup --system --gid 1001 nuxt && \
    adduser --system --uid 1001 nuxt

WORKDIR /app

# Production environment variables
ENV NODE_ENV=production
ENV NITRO_PORT=3000
ENV NITRO_HOST=0.0.0.0

# Copy necessary files
COPY --from=builder --chown=nuxt:nuxt /app/.output ./.output
COPY --from=builder --chown=nuxt:nuxt /app/package.json ./package.json

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Switch to non-root user
USER nuxt

# Expose ports
EXPOSE 3000

# Start the application
CMD ["node", ".output/server/index.mjs"]