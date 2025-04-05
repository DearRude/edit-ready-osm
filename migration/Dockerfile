# Stage 1: Prepare Ruby environment
FROM ruby:3.2-slim-bullseye AS ruby-builder

# Install bundler
RUN gem install bundler --version "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)" --no-document

# ---

# Stage 2: Build and Migrate
FROM postgis/postgis:13-3.4 AS builder

# Environment variables (same as before)
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    RAILS_ENV=production \
    POSTGRES_HOST=localhost \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=postgres \
    PATH=/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Install system dependencies 
RUN apt-get update \
  && apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    default-jre-headless \
    file \
    git-core \
    gpg-agent \
    libarchive-dev \
    libffi-dev \
    libgd-dev \
    libsasl2-dev \
    libvips-dev \
    libxml2-dev \
    libxslt1-dev \
    libyaml-dev \
    locales \
    postgresql-client \
    tzdata \
    unzip \
    osmosis \
  # Configure locales
  && locale-gen en_US.UTF-8 \
  && update-locale LANG=en_US.UTF-8 \
  # Clean up apt cache
  && rm -rf /var/lib/apt/lists/*

# Copy Ruby installation (executables, libraries, gems) from the ruby-builder stage
COPY --from=ruby-builder /usr/local/bin/ /usr/local/bin/
COPY --from=ruby-builder /usr/local/lib/ /usr/local/lib/
COPY --from=ruby-builder /usr/local/bundle/ /usr/local/bundle/

# Set up work directory
WORKDIR /openstreetmap-website

# Clone the repository
RUN git clone --depth=1 https://github.com/openstreetmap/openstreetmap-website.git .

# Copy custom config files
COPY config/database.yml config/database.yml
COPY config/storage.yml config/storage.yml

# Install Ruby gems using the copied bundler
# Ensure PATH includes /usr/local/bundle/bin
RUN bundle config set --local without 'development test' \
  && bundle config set --local deployment 'true' \
  && bundle install --jobs $(nproc) --retry 3 \
  # Optional: Clean up unnecessary build artifacts/dependencies if needed
  # && apt-get purge -y build-essential \ # Careful: some gems might need build tools at runtime
  # && apt-get autoremove -y \
  && rm -rf /root/.bundle/cache /openstreetmap-website/tmp/* \
  && find /usr/local/bundle/gems/ -name "*.c" -delete \
  && find /usr/local/bundle/gems/ -name "*.o" -delete

# Copy and make the custom entrypoint script executable
COPY migrate-entrypoint.sh /usr/local/bin/migrate-entrypoint.sh
RUN chmod +x /usr/local/bin/migrate-entrypoint.sh

# Run the migration script during build
# This starts PG, runs migrations, stops PG
RUN /usr/local/bin/migrate-entrypoint.sh

# ---

# Stage 3: Final Image
# Use the same base image for the final stage
FROM postgis/postgis:13-3.4

# Copy only the migrated PostgreSQL data directory from the builder stage
COPY --from=builder /var/lib/postgresql/data /var/lib/postgresql/data

# *** IMPORTANT DECISION ***
# Do you need the Ruby runtime or the openstreetmap-website code
# in the FINAL image that gets pushed?
# If the goal is ONLY a PostGIS server with pre-migrated data,
# then you DON'T need to copy Ruby or the app code below.
# This keeps the final image small and clean.

# Uncomment the following lines ONLY IF you need Ruby/App code at runtime
# COPY --from=builder /usr/local/bin/ /usr/local/bin/
# COPY --from=builder /usr/local/lib/ruby/ /usr/local/lib/ruby/
# COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
# COPY --from=builder /openstreetmap-website /openstreetmap-website
# ENV PATH=/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Ensure the postgres user owns the data directory
RUN chown -R postgres:postgres /var/lib/postgresql/data && \
    chmod 700 /var/lib/postgresql/data

# Set the default PostGIS user/password if needed (or rely on image defaults)
ENV POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres

# Use the default entrypoint and command from the base postgis image
# (Inherited by default, no need to specify ENTRYPOINT/CMD)

# Expose the default PostgreSQL port
EXPOSE 5432

LABEL maintainer="Ebrahim Nejati <ebrahim@nejati.net>"
LABEL description="Pre-migrated PostGIS image for OpenStreetMap Website"
