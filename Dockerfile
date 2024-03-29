  
# The MIT License
#
#  Copyright (c) 2015-2017, CloudBees, Inc.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

ARG version=3107.v665000b_51092-4-jdk11

FROM jenkins/agent:$version

ARG version
LABEL Description="This is a base image, which allows connecting Jenkins agents via JNLP protocols" Vendor="Jenkins project" Version="$version"

USER root

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl git openssh-server openjdk-11-jre-headless sudo nodejs gnupg gnupg2 libyaml-dev imagemagick build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev libgmp-dev libpq-dev gawk autoconf automake bison libgdbm-dev libncurses5-dev libtool pkg-config  libvips42

RUN mkdir /var/run/sshd
RUN echo "jenkins:jenkins" | chpasswd
RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ARG user=jenkins

COPY jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
USER ${user}

RUN \curl -sSL https://rvm.io/mpapis.asc | gpg2 --import
RUN \curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import
RUN \curl -sSL https://get.rvm.io | bash -s stable
RUN echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"'  >> /home/jenkins/.bashrc

ENTRYPOINT ["jenkins-agent"]
