# Build stage
FROM hexpm/elixir:1.14.5-erlang-25.3.2-alpine-3.18.0 AS build

# Install build dependencies
RUN apk add --no-cache build-base git npm

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy config files
COPY config/config.exs config/$MIX_ENV.exs config/

# Compile dependencies
RUN mix deps.compile

# Build assets
COPY assets assets
RUN cd assets && npm install && npm run deploy
RUN mix phx.digest

# Copy priv
COPY priv priv

# Copy lib
COPY lib lib

# Compile project
RUN mix compile

# Build release
RUN mix release

# App stage
FROM alpine:3.18.0 AS app

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/jump ./

ENV HOME=/app

CMD ["bin/jump", "start"]

