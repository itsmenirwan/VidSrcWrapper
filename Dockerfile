# ---- Build stage: install deps and build all packages ----
FROM node:22-alpine AS builder
WORKDIR /app

# Copy manifest files first for better Docker layer caching
COPY package*.json ./
COPY packages ./packages

# Install dependencies for all workspaces
RUN npm install --workspaces --include-workspace-root

# FIX: Manually install the rollup binary for Alpine (musl)
# This prevents the "Cannot find module '@rollup/rollup-linux-x64-musl'" error
RUN npm install @rollup/rollup-linux-x64-musl

# Copy source and build
COPY . .
RUN npm run build

# ---- Runtime stage: Node + Nginx in a single container ----
FROM node:22-alpine AS runtime
WORKDIR /app

# Install Nginx (Alpine uses apk)
RUN apk add --no-cache nginx && mkdir -p /run/nginx

# Copy built app and node_modules from builder
# We only need the production files to keep the image small
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/packages /app/packages
COPY --from=builder /app/package.json /app/package.json

# Copy Nginx config and entrypoint script
# Ensure these files exist in your local repository root
COPY nginx.conf /etc/nginx/nginx.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# The Node server usually listens on 8080 (check your app code)
# Nginx will act as the reverse proxy on port 80
ENV PORT=8080
EXPOSE 80

# Use the entrypoint script to start both Nginx and Node
CMD ["/docker-entrypoint.sh"]
