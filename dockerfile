# === Stage 1: Build the Flutter web app ===
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Set working directory
WORKDIR /app

ARG CRASH_APP_ORIGIN=https://crash-pad-cold-dawn-1241.fly.dev
ARG SUPABASE_URL=
ARG SUPABASE_ANON_KEY=

# Copy all files into the container
COPY . .


# Enable web support (if not already enabled) and fetch dependencies
RUN flutter config --enable-web
RUN flutter pub get

# Build the Flutter web app in release mode
RUN flutter build web --release \
    --dart-define=CRASH_APP_ORIGIN=${CRASH_APP_ORIGIN} \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}


# === Stage 2: Serve the built app using Nginx ===
FROM nginx:alpine

# Remove default Nginx config and static files
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/default.conf

# Copy the compiled Flutter web build from the builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Create custom Nginx config that listens on 0.0.0.0:8080
RUN cat > /etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen 0.0.0.0:8080;
    listen [::]:8080;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Gzip compression
    gzip on;
    gzip_types text/plain text/css text/javascript application/javascript application/json;
    
    # Cache control
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Route all requests to index.html for Flutter routing
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Expose port 8080
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD nc -z 127.0.0.1 8080 || exit 1

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
