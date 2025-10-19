FROM ruby:3.3-alpine

# Instalar dependencias del sistema para Rails 8
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    curl \
    nodejs \
    npm \
    git \
    bash \
    gcompat \
    postgresql-client

WORKDIR /app

# Instalar Bundler específico para Rails 8
RUN gem install bundler:2.5.0

# Configuración de entorno
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

# Copiar Gemfile
COPY Gemfile* ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local path '/usr/local/bundle' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3 && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copiar código de la aplicación
COPY . .

# Precompilar bootsnap para arranque más rápido
RUN bundle exec bootsnap precompile app/ lib/

# Crear usuario no-root para seguridad
RUN addgroup -g 1000 rails && \
    adduser -D -s /bin/sh -u 1000 -G rails rails && \
    chown -R rails:rails /app

USER rails

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Entrypoint para preparar la base de datos
ENTRYPOINT ["/app/bin/docker-entrypoint"]

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]