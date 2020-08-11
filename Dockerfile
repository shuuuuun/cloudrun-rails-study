FROM ruby:2.7-alpine

ENV LANG C.UTF-8
ENV TZ Asia/Tokyo
ENV EDITOR vi

ENV PORT 3000
ENV RACK_ENV production
ENV RAILS_ENV production
ENV RAILS_LOG_TO_STDOUT 1

ARG RAILS_MASTER_KEY
ENV RAILS_MASTER_KEY ${RAILS_MASTER_KEY}

RUN set -ex \
    && apk update \
    && apk add --no-cache \
        alpine-sdk \
        mariadb-dev \
        mariadb-client \
        tzdata \
        nodejs \
    && gem install bundler --no-document \
    && bundle config set without 'test development'

WORKDIR /app

COPY Gemfile* /app/
RUN bundle install --jobs=2

COPY app /app/app
COPY bin /app/bin
COPY config /app/config
COPY db /app/db
COPY lib /app/lib
COPY public /app/public
COPY Rakefile config.ru /app/

RUN set -ex \
    && bundle add activerecord-nulldb-adapter \
    && bundle exec rails assets:precompile DATABASE_URL=nulldb://localhost \
    && bundle rem activerecord-nulldb-adapter

COPY . /app

EXPOSE ${PORT}
# CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
CMD ["/app/bin/start"]
