
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

ARG version=latest-jdk25

FROM jenkins/agent:$version

ARG version
LABEL Description="This is a base image, which allows connecting Jenkins agents via JNLP protocols" Vendor="Jenkins project" Version="$version"

USER root

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl git openssh-server openjdk-21-jre-headless \
    nodejs gnupg gnupg2 libyaml-dev lsb-release imagemagick build-essential zlib1g-dev libssl-dev \
    libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev \
    libffi-dev libgmp-dev libpq-dev gawk autoconf automake bison libgdbm-dev libncurses5-dev libtool \
    pkg-config libvips42 unzip ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# RUN mkdir /var/run/sshd
# Pas de mot de passe ni de sudo pour l'utilisateur jenkins : l'agent exécute
# du code arbitraire (les pipelines), il ne doit pas pouvoir devenir root.

# ------------------------------------------------------------------
# Outils de sécurité (Gitleaks, Trivy, Nuclei, Opengrep)
# Versions figées et sommes de contrôle vérifiées.
# ------------------------------------------------------------------

# Opengrep plante (UnicodeDecodeError) sans locale UTF-8
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG GITLEAKS_VERSION=8.30.1
ARG TRIVY_VERSION=0.74.0
ARG NUCLEI_VERSION=3.11.1
ARG OPENGREP_VERSION=1.30.0

WORKDIR /tmp/tools

RUN curl -sSLO https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz \
    && curl -sSLO https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_checksums.txt \
    && grep " gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz$" gitleaks_${GITLEAKS_VERSION}_checksums.txt | sha256sum -c - \
    && tar -xzf gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz -C /usr/local/bin gitleaks

RUN curl -sSLO https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz \
    && curl -sSLO https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt \
    && grep " trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz$" trivy_${TRIVY_VERSION}_checksums.txt | sha256sum -c - \
    && tar -xzf trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz -C /usr/local/bin trivy

RUN curl -sSLO https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_linux_amd64.zip \
    && curl -sSLO https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_checksums.txt \
    && grep " nuclei_${NUCLEI_VERSION}_linux_amd64.zip$" nuclei_${NUCLEI_VERSION}_checksums.txt | sha256sum -c - \
    && unzip -o nuclei_${NUCLEI_VERSION}_linux_amd64.zip nuclei -d /usr/local/bin

RUN curl -sSL -o /usr/local/bin/opengrep \
      https://github.com/opengrep/opengrep/releases/download/v${OPENGREP_VERSION}/opengrep_manylinux_x86 \
    && chmod +x /usr/local/bin/opengrep \
    && git clone --depth 1 https://github.com/opengrep/opengrep-rules /opt/opengrep-rules \
    && rm -rf /opt/opengrep-rules/.git

WORKDIR /
RUN rm -rf /tmp/tools

ARG user=jenkins

COPY jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
USER ${user}

ARG ruby_version=3.3.12
ENV RUBY_VERSION=${ruby_version}
# Versions demandées par les projets (.ruby-version) : préinstallées, sinon un
# agent éphémère (pod Kubernetes) recompilerait Ruby à chaque build.
# candlekeep-backend : ruby-3.2.2
ARG ruby_extra_versions="3.2.2"

RUN \curl -sSL https://rvm.io/mpapis.asc | gpg2 --import
RUN \curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import
RUN \curl -sSL https://get.rvm.io | bash -s stable
RUN echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"'  >> /home/jenkins/.bashrc

# Install an actual Ruby (the base RVM install above only provides the
# version manager, not a Ruby) and make it the default, generating
# standalone wrapper scripts in ~/.rvm/wrappers/default so `ruby`/`gem`/
# `bundle` work from Jenkins' non-interactive `sh -c` build steps without
# sourcing rvm first.
# autolibs désactivé : sans sudo, RVM ne peut pas lancer apt-get lui-même.
# Les dépendances de compilation sont déjà installées par l'apt-get ci-dessus.
RUN bash -c "source \$HOME/.rvm/scripts/rvm && \
    rvm autolibs disable && \
    for v in ${ruby_extra_versions}; do \
      rvm install \$v && rvm use \$v && gem install bundler --no-document || exit 1; \
    done && \
    rvm install ${RUBY_VERSION} && \
    rvm use ${RUBY_VERSION} --default && \
    rvm cleanup all && \
    gem install bundler --no-document"

ENV PATH="/home/jenkins/.rvm/wrappers/default:/home/jenkins/.rvm/bin:${PATH}"

# Brakeman (analyse de sécurité Rails), installé dans le Ruby par défaut :
# RVM génère son wrapper dans ~/.rvm/wrappers/default, déjà dans le PATH
RUN bash -c "source \$HOME/.rvm/scripts/rvm && gem install brakeman --no-document"

# Base de vulnérabilités Trivy et templates Nuclei pré-téléchargés.
# Reconstruire l'image régulièrement pour suivre les nouvelles CVE.
RUN trivy fs --download-db-only --cache-dir /home/jenkins/.cache/trivy \
    && nuclei -update-templates -silent

ENTRYPOINT ["jenkins-agent"]
