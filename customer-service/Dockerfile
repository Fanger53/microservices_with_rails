FROM ruby:3.3-alpine AS base# syntax=docker/dockerfile:1

# check=error=true

# Instalar dependencias del sistema para Rails 8

RUN apk add --no-cache \# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:

    build-base \# docker build -t app .

    postgresql-dev \# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name app app

    tzdata \

    curl \# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

    nodejs \

    npm \# Make sure RUBY_VERSION matches the Ruby version in .ruby-version

    git \ARG RUBY_VERSION=3.3.9

    bash \FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

    gcompat \

    postgresql-client# Rails app lives here

WORKDIR /rails

WORKDIR /app

# Install base packages

# Instalar Bundler específico para Rails 8RUN apt-get update -qq && \

RUN gem install bundler:2.5.0    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \

    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Configuración de entorno

ENV RAILS_ENV=production \# Set production environment

    BUNDLE_DEPLOYMENT=1 \ENV RAILS_ENV="production" \

    BUNDLE_PATH=/usr/local/bundle \    BUNDLE_DEPLOYMENT="1" \

    BUNDLE_WITHOUT="development:test"    BUNDLE_PATH="/usr/local/bundle" \

    BUNDLE_WITHOUT="development"

# Copiar Gemfile

COPY Gemfile* ./# Throw-away build stage to reduce size of final image

RUN bundle config set --local deployment 'true' && \FROM base AS build

    bundle config set --local path '/usr/local/bundle' && \

    bundle config set --local without 'development test' && \# Install packages needed to build gems

    bundle install --jobs 4 --retry 3 && \RUN apt-get update -qq && \

    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \

    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copiar código de la aplicación

COPY . .# Install application gems

COPY Gemfile Gemfile.lock ./

# Precompilar bootsnap para arranque más rápidoRUN bundle install && \

RUN bundle exec bootsnap precompile app/ lib/    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \

    bundle exec bootsnap precompile --gemfile

# Crear usuario no-root para seguridad

RUN addgroup -g 1000 rails && \# Copy application code

    adduser -D -s /bin/sh -u 1000 -G rails rails && \COPY . .

    chown -R rails:rails /app

# Precompile bootsnap code for faster boot times

USER railsRUN bundle exec bootsnap precompile app/ lib/



EXPOSE 3000



# Health check

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \# Final stage for app image

  CMD curl -f http://localhost:3000/health || exit 1FROM base



# Entrypoint para preparar la base de datos# Copy built artifacts: gems, application

ENTRYPOINT ["/app/bin/docker-entrypoint"]COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"

COPY --from=build /rails /rails

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
