# Docker for Scumblr
# Author : Nag
# Select ubuntu as the base image
FROM ubuntu:16.04

MAINTAINER Nag <nagwww@gmail.com>

# Dockerfile for a Rails application using Nginx and Unicorn

# Install all the things
RUN apt-key adv \
    --keyserver keyserver.ubuntu.com \
    --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > \
    /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get upgrade -y \
    nginx \
    curl \
    libcurl3 \
    nodejs \
    git \
    python-pip python-dev \
    python-psycopg2 \
    libpq-dev \
    supervisor \
    libmysqlclient-dev \
    libxslt-dev \
    libxml2-dev \
    libfontconfig1 \
    python-software-properties \
    software-properties-common \
    wget

RUN wget -O /usr/local/share/phantomjs-1.9.7-linux-x86_64.tar.bz2 \
    https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2 && \
    tar -xf /usr/local/share/phantomjs-1.9.7-linux-x86_64.tar.bz2 -C /usr/local/share/ &&\
    ln -s /usr/local/share/phantomjs-1.9.7-linux-x86_64/bin/phantomjs /usr/local/bin/phantomjs


# Add Sketchy user (ubuntu):
RUN useradd -d /home/ubuntu -m -s /bin/bash ubuntu &&\
    chmod -R 755 /home/ubuntu &&\
    chown -R ubuntu:ubuntu /home/ubuntu

# Get Sketchy code
USER ubuntu
RUN git clone https://github.com/Netflix/sketchy.git /home/ubuntu/sketchy

# Install Sketchy
USER root
RUN cd /home/ubuntu/sketchy && python setup.py install &&\
    su ubuntu -c "python /home/ubuntu/sketchy/manage.py create_db"

ADD supervisord.ini /home/ubuntu/sketchy/supervisor/

# RUN chmod 755 /usr/local/lib/python2.7/dist-packages/tld-0.6.4-py2.7.egg/tld/res/effective_tld_names.dat.txt

RUN chown -R ubuntu:ubuntu /home/ubuntu/ && \
    chmod -R 755 /home/ubuntu/ && \
    cd /home/ubuntu/sketchy/supervisor && \
    touch /home/ubuntu/sketchy/sketchy-deploy.log && \
    chmod 755 /home/ubuntu/sketchy/sketchy-deploy.log

# Prevent nginx from running in daemon mode
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# Retrieve code from github
RUN git clone https://github.com/Netflix/scumblr.git /scumblr

# Install rvm, ruby, bundler, sidekiq
RUN command curl -sSL https://rvm.io/mpapis.asc | gpg --import -
RUN curl -sSL https://get.rvm.io | bash -s stable
RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install 2.0.0-p481"
RUN /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"
RUN /bin/bash -l -c "gem install sidekiq --no-ri --no-rdoc"

# set WORKDIR
WORKDIR /scumblr

# Install Nokogiri requirements
RUN apt-get install -qy libxslt-dev libxml2-dev

# Install Imagemagick requirements
RUN apt-get install -qy libmagickwand-dev imagemagick libmagickcore-dev

# Install Redis
RUN apt-get install -qy redis-server

# Install Postgres requirements
RUN apt-get install -qy libpq-dev

# bundle install
RUN /bin/bash -l -c "bundle install"

# Copy seed file
ADD config/scumblr/seeds.rb /scumblr/db/

# Copy database.yml
ADD config/scumblr/database.yml /scumblr/config/

# Copy scumblr config
ADD config/scumblr/scumblr.rb /scumblr/config/initializers/

# Setup db
# RUN /bin/bash -l -c "rake db:create"
# RUN /bin/bash -l -c "rake db:schema:load"
# RUN /bin/bash -l -c "rake db:seed"

# Add nginx config files and ssl cert/key
ADD config/nginx/nginx-sites.conf /etc/nginx/sites-enabled/default

# Add startup script
ADD scripts/start-server.sh /usr/bin/start-server.sh
RUN chmod +x /usr/bin/start-server.sh

# Startup commands
CMD /usr/bin/start-server.sh
