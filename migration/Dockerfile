# Example: postgis/postgis:16-3.4 uses PG16, postgis/postgis:13-3.4 uses PG13
FROM postgis/postgis:16-3.4 AS final

LABEL maintainer="Ebrahim Nejati <ebrahim@nejati.net>"
LABEL description="Pre-migrated PostGIS image for OpenStreetMap Website"

# Set environment variables for non-interactive installs
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    RAILS_ENV=production \
    POSTGRES_HOST=localhost \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=postgres

# Install build dependencies, Ruby 3.2+, git, OSM dependencies, and locales
RUN apt-get install ruby ruby-dev ruby-bundler \
  libvips-dev libxml2-dev libxslt1-dev \
  build-essential git-core \
  postgresql postgresql-contrib libpq-dev libsasl2-dev \
  libffi-dev libgd-dev libarchive-dev libyaml-dev libbz2-dev \
  # Configure locales
  && locale-gen en_US.UTF-8 \
  && update-locale LANG=en_US.UTF-8 \
  # Clean up apt cache
  && rm -rf /var/lib/apt/lists/*

# Set up work directory for the app
WORKDIR /openstreetmap-website

# Clone the specific repository branch/tag if needed, otherwise master/main
RUN git clone --depth=1 https://github.com/openstreetmap/openstreetmap-website.git .

# Copy custom config files (assuming they exist next to the Dockerfile)
COPY config/database.yml config/database.yml
COPY config/storage.yml config/storage.yml

# Install Ruby gems
# Using --jobs to speed up, adjust number based on runner cores if needed
# Using deployment mode for production installs
RUN bundle config set --local without 'development test' \
  && bundle config set --local deployment 'true' \
  # && bundle config build.nokogiri --use-system-libraries \ # Uncomment if nokogiri has issues
  && bundle install --jobs $(nproc) --retry 3

# Copy and make the custom entrypoint script executable
COPY migrate-entrypoint.sh /usr/local/bin/migrate-entrypoint.sh
RUN chmod +x /usr/local/bin/migrate-entrypoint.sh

# --- Build-time Migration Execution ---
# Temporarily override the CMD and set the entrypoint to our migration script.
# When Docker builds this layer, it will run this entrypoint.
# The script will start postgres, run migrations, and stop postgres.
# The resulting filesystem state (with migrated DB data) is saved in the image layer.
ENTRYPOINT ["/usr/local/bin/migrate-entrypoint.sh"]
CMD []

# --- Final Image Configuration ---
# After the build-time migration, reset the ENTRYPOINT and CMD
# to the original PostGIS entrypoint/cmd so the image behaves
# like a standard PostGIS image when run later.
# We achieve this by creating a new stage FROM the current one.
# Note: This is a bit of a workaround. A more robust way might involve
# running the build steps, then separately running a container from that image
# to perform the migration, and committing the container state to a new image tag.
# However, the entrypoint override trick is common for baking DB state.

# Let's stick to the single stage approach with the entrypoint trick for simplicity first.
# If this proves unreliable, we can switch to a multi-container build process in the Action.

# ---> The ENTRYPOINT set above will run ONCE during docker build <---

# Reset ENTRYPOINT/CMD for the final image *after* build.
# This requires a multi-stage build where the final stage resets them.
# Let's modify the structure slightly:

# STAGE 1: Build and Migrate (as above)
FROM postgis/postgis:16-3.4 AS builder
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    RAILS_ENV=production \
    POSTGRES_HOST=localhost \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=postgres
RUN apt-get update \
  && apt-get install --no-install-recommends -y \
    build-essential curl default-jre-headless file git-core gpg-agent \
    libarchive-dev libffi-dev libgd-dev libsasl2-dev libvips-dev libxml2-dev \
    libxslt1-dev libyaml-dev locales postgresql-client ruby3.2 ruby3.2-dev \
    ruby-bundler tzdata unzip osmosis \
  && locale-gen en_US.UTF-8 \
  && update-locale LANG=en_US.UTF-8
WORKDIR /openstreetmap-website
RUN git clone --depth=1 https://github.com/openstreetmap/openstreetmap-website.git .
COPY config/database.yml config/database.yml
COPY config/storage.yml config/storage.yml
RUN bundle config set --local without 'development test' \
  && bundle config set --local deployment 'true' \
  && bundle install --jobs $(nproc) --retry 3 \
  # Clean up build-only dependencies if possible (tricky with Ruby deps)
  # && apt-get purge -y build-essential ruby3.2-dev \
  # && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/* /root/.bundle/cache /openstreetmap-website/tmp/* \
  && find /usr/local/bundle/gems/ -name "*.c" -delete \
  && find /usr/local/bundle/gems/ -name "*.o" -delete

COPY migrate-entrypoint.sh /usr/local/bin/migrate-entrypoint.sh
RUN chmod +x /usr/local/bin/migrate-entrypoint.sh

# Run the migration script during build
RUN /usr/local/bin/migrate-entrypoint.sh


# STAGE 2: Final Image
# Use the same base image to ensure compatibility
FROM postgis/postgis:13-3.4
# Copy the migrated PostgreSQL data directory from the builder stage
COPY --from=builder /var/lib/postgresql/data /var/lib/postgresql/data
# Copy the application code and installed gems (optional, only if needed at runtime)
# COPY --from=builder /openstreetmap-website /openstreetmap-website
# COPY --from=builder /usr/local/bundle /usr/local/bundle

# Ensure the postgres user owns the data directory
RUN chown -R postgres:postgres /var/lib/postgresql/data && \
    chmod 700 /var/lib/postgresql/data

# Set the default PostGIS user/password if needed (or rely on image defaults)
ENV POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres

# Use the default entrypoint and command from the base postgis image
# Find these using 'docker inspect postgis/postgis:13-3.4' if necessary
# Example defaults (might vary slightly):
# ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# CMD ["postgres"]
# No need to redefine ENTRYPOINT/CMD if inheriting from the base image is desired

# Expose the default PostgreSQL port
EXPOSE 5432