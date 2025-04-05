# Use a specific PostGIS version based on PostgreSQL 13+ requirement.
FROM postgis/postgis:17-3.5 AS builder

LABEL maintainer="ٍEbrahim Nejati <ebrahim@nejati.net>"
LABEL description="Pre-migrated PostGIS image for OpenStreetMap Website"

# --- Install Base Dependencies & rbenv ---
# Set environment variables for non-interactive installs
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    RAILS_ENV=production \
    # Use default postgres user/db provided by the base image initially
    POSTGRES_HOST=localhost \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=postgres \
    # rbenv environment variables
    RBENV_ROOT="/usr/local/rbenv" \
    PATH="/usr/local/rbenv/bin:/usr/local/rbenv/shims:$PATH"

# Install build dependencies, git, OSM dependencies, locales,
# AND dependencies needed to *build* Ruby with rbenv
RUN apt-get update \
  && apt-get install --no-install-recommends -y \
    # OSM App Dependencies
    build-essential \
    curl \
    default-jre-headless \
    file \
    git-core \
    gpg-agent \
    libarchive-dev \
    libffi-dev \
    libgd-dev \
    # libpq-dev is usually included in postgis images or dependencies
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
    # Dependencies for building Ruby (rbenv)
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    autoconf \
    bison \
    patch \
    # libyaml-dev already listed above
  # Configure locales
  && locale-gen en_US.UTF-8 \
  && update-locale LANG=en_US.UTF-8

# --- Install rbenv and Ruby ---
# Install rbenv and ruby-build plugin
RUN git clone https://github.com/rbenv/rbenv.git ${RBENV_ROOT} \
  && git clone https://github.com/rbenv/ruby-build.git ${RBENV_ROOT}/plugins/ruby-build \
  # Add rbenv init to profile (optional for build, but good practice)
  # && echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh \
  # && echo 'eval "$(rbenv init -)"' >> ~/.bashrc \
  # Install Ruby 3.2 (specify exact version, e.g., 3.2.4)
  # This step compiles Ruby and will take some time
  && rbenv install 3.2.4 \
  && rbenv global 3.2.4 \
  # Check Ruby version
  && ruby -v \
  # Install Bundler (use a version compatible with Ruby 3.2)
  && gem install bundler -v '~> 2.4' \
  # Rehash shims
  && rbenv rehash

# --- Setup Application & Run Migrations ---
WORKDIR /openstreetmap-website

# Clone the repository
RUN git clone --depth=1 https://github.com/openstreetmap/openstreetmap-website.git .

# Copy custom config files
COPY config/database.yml config/database.yml
COPY config/storage.yml config/storage.yml

# Install Ruby gems using the rbenv-managed Ruby/Bundler
# Make sure PATH includes rbenv shims
RUN bundle config set --local without 'development test' \
  && bundle config set --local deployment 'true' \
  && bundle install --jobs $(nproc) --retry 3

# Copy and make the custom entrypoint script executable
COPY migrate-entrypoint.sh /usr/local/bin/migrate-entrypoint.sh
RUN chmod +x /usr/local/bin/migrate-entrypoint.sh

# Run the migration script during build
# This uses the rbenv Ruby via shims because of the PATH setup
RUN /usr/local/bin/migrate-entrypoint.sh

# --- Cleanup Builder Stage ---
# Remove ruby build dependencies and rbenv sources/cache if possible to reduce size
# Note: Some build deps might be needed by runtime gems. Test carefully.
RUN apt-get purge -y --auto-remove \
      autoconf bison patch build-essential libssl-dev \
      libreadline-dev zlib1g-dev git-core \
  && rm -rf /var/lib/apt/lists/* \
            /root/.bundle/cache \
            /openstreetmap-website/tmp/* \
            ${RBENV_ROOT}/sources \
            ${RBENV_ROOT}/versions/3.2.4/share/doc \
            ${RBENV_ROOT}/versions/3.2.4/share/man \
  && find /usr/local/bundle/gems/ -name "*.c" -delete \
  && find /usr/local/bundle/gems/ -name "*.o" -delete \
  && find ${RBENV_ROOT}/versions/3.2.4/lib/ruby/gems/*/gems/ -name "*.c" -delete \
  && find ${RBENV_ROOT}/versions/3.2.4/lib/ruby/gems/*/gems/ -name "*.o" -delete


# --- Final Image Stage ---
# Use the same base image to ensure compatibility
FROM postgis/postgis:17-3.5

LABEL description="Pre-migrated PostGIS image for OpenStreetMap Website"

# Copy the migrated PostgreSQL data directory from the builder stage
COPY --from=builder /var/lib/postgresql/data /var/lib/postgresql/data

# Copy application code and runtime dependencies (Ruby + Gems) if needed at runtime
# If the sole purpose of this image is to provide the *data*, you might skip this.
# If you need Ruby/Rails available in the final image, copy rbenv and gems.
COPY --from=builder /usr/local/rbenv /usr/local/rbenv
COPY --from=builder /openstreetmap-website /openstreetmap-website # Contains installed gems in vendor/bundle
COPY --from=builder /etc/profile.d/rbenv.sh /etc/profile.d/rbenv.sh # If needed

# Set PATH if Ruby runtime is included and needed
ENV RBENV_ROOT="/usr/local/rbenv" \
    PATH="/usr/local/rbenv/bin:/usr/local/rbenv/shims:$PATH"

# Install runtime dependencies that were potentially removed from builder
# Only necessary if code/gems are copied and need them (e.g., libvips, libxml2)
# RUN apt-get update && apt-get install --no-install-recommends -y \
#       libvips42 libxml2 libxslt1.1 # Adjust versions/names as needed
#   && rm -rf /var/lib/apt/lists/*

# Ensure the postgres user owns the data directory
RUN chown -R postgres:postgres /var/lib/postgresql/data && \
    chmod 700 /var/lib/postgresql/data

# Set the default PostGIS user/password if needed (or rely on image defaults)
ENV POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres

# Expose the default PostgreSQL port
EXPOSE 5432

# Use the default entrypoint and command from the base postgis image
# ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"] # Inherited
# CMD ["postgres"] # Inherited