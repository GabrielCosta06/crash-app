# === Stage 1: Build the Flutter web app ===
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Set working directory
WORKDIR /app

# Copy all files into the container
COPY . .


# Enable web support (if not already enabled) and fetch dependencies
RUN flutter config --enable-web
RUN flutter pub get

# Build the Flutter web app in release mode
RUN flutter build web --release


# === Stage 2: Serve the built app using Nginx ===
FROM nginx:alpine

# (Optional) Remove the default Nginx static files
RUN rm -rf /usr/share/nginx/html/*

# Copy the compiled Flutter web build from the builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose port 80 to serve the app
EXPOSE 8080

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
