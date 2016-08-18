#!/bin/bash

mkdir -p /etc/nginx/ssl
# Certbot only if domain is specified
if ! [ -z "$DNS_NAME" ]; then
  # Get and place certbot
  mkdir /certbot
  cd /certbot
  wget https://dl.eff.org/certbot-auto
  chmod a+x certbot-auto
  # Generate certs
  ./certbot-auto certonly --standalone -d $DNS_NAME
  # Link up certs
  ln -s /etc/letsencrypt/live/$DNS_NAME/privkey.pem /etc/nginx/ssl/server.key
  ln -s /etc/letsencrypt/live/$DNS_NAME/fullchain.pem /etc/nginx/ssl/server.crt
else
  # Generate self-signed certs
  openssl req -subj '/CN=nodomain.local /O=Scumblrbag /C=US' \
    -new \
    -newkey rsa:2048 \
    -days 365 \
    -nodes -x509 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt
fi

source /etc/profile.d/rvm.sh

cd /scumblr

if [ "$SCUMBLR_CREATE_DB" == "true" ]; then
  bundle exec rake db:create
fi

if [ "$SCUMBLR_LOAD_SCHEMA" == "true" ]; then
  bundle exec rake db:schema:load
fi

if [ "$SCUMBLR_RUN_MIGRATIONS" == "true" ]; then
  bundle exec rake db:migrate
fi

bundle exec rake db:seed
bundle exec rake assets:precompile
bundle exec unicorn -D -p 8080

redis-server &
sidekiq -l log/sidekiq.log &
nginx
