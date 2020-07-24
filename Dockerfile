FROM ruby:2.7-alpine

ENV LANG C.UTF-8
ENV TZ Asia/Tokyo
ENV EDITOR vi

ENV PORT 3000
ENV RACK_ENV production
ENV RAILS_LOG_TO_STDOUT 1

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

# ARG RAILS_ENV
# ARG SECRET_KEY_BASE

# ENV RAILS_ENV=$RAILS_ENV
# ENV SECRET_KEY_BASE=$SECRET_KEY_BASE

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
ENV PID_FILE /tmp/server.pid
CMD ["sh", "-c", "rm -f ${PID_FILE} && bundle exec rails server -p ${PORT} -b 0.0.0.0 --pid ${PID_FILE}"]
# CMD ["bundle", "exec", "puma", "-C", "pumaconf.rb"]
