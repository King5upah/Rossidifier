# Use the official Dart image
# https://hub.docker.com/_/dart
FROM dart:stable AS build

# Resolve package dependencies
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code and build it
COPY . .
# Ensure dependencies are fetched for all packages if needed
RUN dart pub get --offline
RUN dart compile exe bin/backend.dart -o bin/server

# Build minimal runtime image
FROM subfuzion/dart:slim
COPY --from=build /app/bin/server /app/bin/server

# Start the server
EXPOSE 8080
CMD ["/app/bin/server"]
