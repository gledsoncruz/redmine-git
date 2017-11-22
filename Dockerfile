FROM redmine:3.4.3

EXPOSE 22

WORKDIR /usr/src/redmine

RUN	apt-get update && apt-get install -y --no-install-recommends \
		build-essential \
		libssh2-1 \
		libssh2-1-dev \
		cmake \
		libgpg-error-dev \
		pkg-config \
		openssh-server \
		sudo \
	&& rm /etc/ssh/ssh_host_* \
	&& rm -rf /var/lib/apt/lists/*

RUN	LG='\033[1;32m' && NC='\033[0m' \
	&& cd /usr/src/redmine/plugins && echo $LG`pwd`$NC \
	&& git clone https://github.com/jbox-web/redmine_bootstrap_kit.git \
	&& cd redmine_bootstrap_kit && echo $LG`pwd`$NC \
	&& git checkout 0.2.5 \
	&& cd /usr/src/redmine/plugins && echo $LG`pwd`$NC \
	&& git clone https://github.com/jbox-web/redmine_git_hosting.git \
	&& cd redmine_git_hosting && echo $LG`pwd`$NC \
	&& git checkout 1.2.3 \
	&& REDCARPET_GEM=$(grep redcarpet /usr/src/redmine/Gemfile) \
	&& sed -i "/^#/! s/gem 'redcarpet'.*/$REDCARPET_GEM/g" Gemfile \
	&& cd /usr/src/redmine && echo $LG`pwd`$NC \
	&& bundle install --without development test \
	&& apt-get purge -y --auto-remove build-essential libssh2-1-dev cmake libgpg-error-dev

COPY ./redmine-git-entrypoint.sh /
RUN chmod +x /redmine-git-entrypoint.sh

ARG BUILD_DATE
ARG VCS_REF
ENV REDMINE_GIT_VERSION 3.4.3.0
LABEL \
	org.label-schema.build-date="$BUILD_DATE" \
	org.label-schema.description="Redmine + redmine-git-hosting plugin" \
	org.label-schema.name="redmine-git" \
	org.label-schema.schema-version="1.0" \
	org.label-schema.url="https://hub.docker.com/r/buxis/redmine-git" \
	org.label-schema.vcs-url="https://github.com/buxis/redmine-git" \
	org.label-schema.vcs-ref="$VCS_REF" \
	org.label-schema.vendor="buxis.gq" \
	org.label-schema.version="$REDMINE_GIT_VERSION"

VOLUME /home/git/repositories
ENV GIT_UID 998
ENV GIT_GID 998

ENTRYPOINT ["/redmine-git-entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
