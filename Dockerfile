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
    && gem install bundler --no-document

WORKDIR /app

COPY Gemfile* /app/
RUN bundle install

COPY . /app

EXPOSE ${PORT}
ENV PID_FILE /tmp/server.pid
CMD ["sh", "-c", "rm -f ${PID_FILE} && bundle exec rails server -p ${PORT} -b 0.0.0.0 --pid ${PID_FILE}"]
