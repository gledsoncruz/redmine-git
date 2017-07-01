FROM redmine:3.3.3

EXPOSE 22

RUN apt-get update && apt-get install -y --no-install-recommends \
		build-essential \
		libssh2-1 \
		libssh2-1-dev \
		cmake \
		libgpg-error-dev \
		pkg-config \
		openssh-server \
		sudo \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/redmine
RUN	LG='\033[1;32m' && NC='\033[0m' \
	&& cd /usr/src/redmine/plugins && echo $LG`pwd`$NC \
	&& git clone https://github.com/jbox-web/redmine_bootstrap_kit.git \
	&& cd redmine_bootstrap_kit && echo $LG`pwd`$NC \
	&& git reset --hard `git rev-list -1 --before="2017-06-30" devel` \
	&& cd /usr/src/redmine/plugins && echo $LG`pwd`$NC \
	&& git clone https://github.com/jbox-web/redmine_git_hosting.git \
	&& cd redmine_git_hosting && echo $LG`pwd`$NC \
	&& git reset --hard `git rev-list -1 --before="2017-06-30" devel` \
	&& sed -i 's/\(^.*rdoc.*$\)/#\1/' ./Gemfile \
	&& echo "gem 'rspec'" >> ./Gemfile \
	&& echo "gem 'rspec-rails'" >> ./Gemfile \
	&& cd /usr/src/redmine && echo $LG`pwd`$NC \
	&& echo "$RAILS_ENV:" > ./config/database.yml \
	&& echo "  adapter: sqlite3" >> ./config/database.yml \
	&& bundle install --without development test \
	&& rm ./config/database.yml \
	&& apt-get purge -y --auto-remove build-essential libssh2-1-dev cmake libgpg-error-dev

COPY ./redmine-git-entrypoint.sh /
RUN chmod +x /redmine-git-entrypoint.sh

ARG BUILD_DATE
ARG VCS_REF
ENV REDMINE_GIT_VERSION 3.3.3.2
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

ENTRYPOINT ["/redmine-git-entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
