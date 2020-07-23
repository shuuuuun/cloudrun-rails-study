FROM ruby:2.7-alpine
# FROM ruby:2.7-slim

ENV LANG C.UTF-8
ENV TZ Asia/Tokyo
ENV EDITOR vi

ENV RACK_ENV production
ENV RAILS_LOG_TO_STDOUT 1

RUN set -ex

# RUN apt-get update \
#     && apt-get install -y curl gnupg \
#     && curl -sL https://deb.nodesource.com/setup_12.x | bash - \
#     && apt-get install -y \
#         default-libmysqlclient-dev \
#         nodejs \
#         git \
#         vim \
#         build-essential \
#     && gem install bundler --no-document

RUN apk update \
    && apk add --no-cache \
        alpine-sdk \
        mariadb-dev \
        mariadb-client \
        tzdata \
        nodejs \
    && gem install bundler --no-document

WORKDIR /app

# COPY Gemfile* /app/
# RUN bundle install

# COPY . /app

EXPOSE 3000
ENV PID_FILE /tmp/server.pid
CMD ["sh", "-c", "rm -f ${PID_FILE} && bundle exec rails server -p 3000 -b 0.0.0.0 --pid ${PID_FILE}"]
