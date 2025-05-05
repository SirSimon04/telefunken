# Use a base image with Flutter SDK
# Use a specific, more recent Flutter version tag
FROM cirrusci/flutter:3.22.0 as builder

# Set the working directory
WORKDIR /app

# Copy pubspec files first to leverage Docker cache
COPY pubspec.* ./

# Get Flutter dependencies
# Keep -v for now to see verbose output if it still fails
RUN flutter pub get -v

# Copy the rest of the application code
COPY . .

# Build the web application
# Use --release for optimized output
RUN flutter build web --release

# --- Serve stage ---
# Use a lightweight image for serving the static files
FROM node:slim as server

# Install a simple static file server
RUN npm install -g serve

# Set the working directory
WORKDIR /app

# Copy the built web app from the builder stage
COPY --from=builder /app/build/web ./

# Expose the port the server will listen on
EXPOSE 80

# Command to run the static file server
CMD ["serve", "-s", ".", "-l", "80", "-H", "0.0.0.0"]
