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

RUN CACHE_BUST=$(date +%s) && \
    sed -i "s/main.dart.js/main.dart.js?v=${CACHE_BUST}/g" build/web/flutter_bootstrap.js

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
    
    # Flutter app shell and boot files must revalidate so users do not keep
    # running an old main.dart.js after a deploy.
    location = / {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /index.html =404;
    }

    location = /index.html {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /index.html =404;
    }

    location = /flutter_bootstrap.js {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /flutter_bootstrap.js =404;
    }

    location = /main.dart.js {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /main.dart.js =404;
    }

    location = /flutter.js {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /flutter.js =404;
    }

    location = /flutter_service_worker.js {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /flutter_service_worker.js =404;
    }

    location = /manifest.json {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /manifest.json =404;
    }

    location = /version.json {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        try_files /version.json =404;
    }

    # Static media and font assets are safe to cache aggressively.
    location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
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
