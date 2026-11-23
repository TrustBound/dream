FROM ghcr.io/gleam-lang/gleam:v1.19.2-erlang-alpine

# Copy source
WORKDIR /app
COPY . .

# Install dependencies and build
RUN gleam deps download
RUN gleam build

# Expose port
EXPOSE 3000

# Mark the container unhealthy when /health does not answer 200
HEALTHCHECK --interval=5s --timeout=3s \
  CMD wget -q -O /dev/null http://localhost:3000/health || exit 1

# Run
CMD ["gleam", "run"]
