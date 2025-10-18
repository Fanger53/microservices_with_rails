FROM ruby:3.3-alpine AS base

# Instalar dependencias del sistema para Rails 8
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    curl \
    nodejs \
    npm \
    git \
    bash

WORKDIR /app

# Instalar Bundler específico para Rails 8
RUN gem install bundler:2.5.0

# Copiar Gemfile
COPY Gemfile* ./
RUN bundle config set --local deployment 'false' && \
    bundle config set --local path 'vendor/bundle' && \
    bundle install --jobs 4 --retry 3

# Copiar código de la aplicación
COPY . .

# Crear usuario no-root para seguridad
RUN addgroup -g 1000 rails && \
    adduser -D -s /bin/sh -u 1000 -G rails rails && \
    chown -R rails:rails /app

USER rails

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
