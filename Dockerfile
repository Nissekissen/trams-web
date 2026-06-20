FROM ruby:3.3-slim

# Build dependencies (needed to compile native gems like pg)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems first (layer is cached unless Gemfile changes)
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy the rest of the app
COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-p", "3000", "-e", "production"]
