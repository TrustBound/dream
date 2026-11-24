# Build stage: the Gleam image compiles the app into an Erlang shipment
FROM ghcr.io/gleam-lang/gleam:v1.19.2-erlang-alpine AS build

# Copy source
WORKDIR /app
COPY . .

# Download the dependencies of manifest.toml, and compile the app and its
# dependencies into build/erlang-shipment
RUN gleam export erlang-shipment

# Run stage: the Erlang runtime of the Gleam image (OTP 29.1.1, Alpine), with
# no Gleam and no source
FROM erlang:29.1.1-alpine

WORKDIR /app
COPY --from=build /app/build/erlang-shipment .

# Expose port
EXPOSE 3000

# Mark the container unhealthy when /health does not answer 200
HEALTHCHECK --interval=5s --timeout=3s \
  CMD wget -q -O /dev/null http://localhost:3000/health || exit 1

# Run: entrypoint.sh replaces itself with the Erlang VM, so the VM is the
# first process of the container and gets the SIGTERM of docker stop
CMD ["./entrypoint.sh", "run"]
