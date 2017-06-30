#!/bin/bash

service ssh start

# Initialize redmine, @@@ ignore error
#
echo `pwd`
/docker-entrypoint.sh rails

if [ ! -e /usr/src/redmine/plugins/redmine_git_hosting ]; then
	cd /usr/src/redmine/plugins
	git clone https://github.com/jbox-web/redmine_bootstrap_kit.git
	cd redmine_bootstrap_kit
	chekcout 95ede96e7e011488bd421dfda95af2631bd5313b # Commits on Mar 29, 2017

	cd /usr/src/redmine/plugins
	git clone https://github.com/jbox-web/redmine_git_hosting.git
	cd redmine_git_hosting
	checkout 905e512a06e6b4f1806d6d72b729d9d72d205520 # Commits on Apr 10, 2017

	# rdoc comment & add rspec
	#
	sed -i 's/\(^.*rdoc.*$\)/#\1/' ./redmine_git_hosting/Gemfile
	echo "gem 'rspec'" >> ./redmine_git_hosting/Gemfile
	echo "gem 'rspec-rails'" >> ./redmine_git_hosting/Gemfile

	cd /usr/src/redmine

	bundle install --without development test

	#@@@ sperate install, migrate
	bundle exec rake redmine:plugins:migrate RAILS_ENV=production NAME=redmine_git_hosting
fi

if [ ! -e /usr/src/redmine/.rghp_migrated ]; then
	cd /usr/src/redmine
	bundle exec rake redmine:plugins:migrate RAILS_ENV=production NAME=redmine_git_hosting
	toucn .rghp_migrated
fi

# If the redmine's home directory does not exist, create it and change ownership.
#
if [ ! -e /home/redmine ]; then
	mkdir /home/redmine
	chown redmine:redmine /home/redmine
fi

# If the ssh key does not exist, create it.
#
if [ ! -e /home/redmine/ssh_keys ]; then
	cd /home/redmine
	gosu redmine mkdir ssh_keys
	gosu redmine ssh-keygen -N '' -f ssh_keys/redmine_gitolite_admin_id_rsa
fi

# If the user does not exist, create it.
#
if [ -z $(getent passwd git) ]; then
	useradd -m git
fi

# If gitolite is not installed,
#
if [ ! -e /home/git/bin/gitolite ]; then
	cd /home/git
	gosu git mkdir -p /home/git/bin
	gosu git git clone git://github.com/sitaramc/gitolite
	gosu git gitolite/install -to /home/git/bin
	gosu git cp /home/redmine/ssh_keys/redmine_gitolite_admin_id_rsa.pub .
	gosu git bin/gitolite setup -pk redmine_gitolite_admin_id_rsa.pub

	cat > gitolite.conf << EOF
repo    gitolite-admin
  RW+                            = redmine_gitolite_admin_id_rsa
EOF

	#echo `cat gitolite.conf`

	gosu git sed -i \
		"s@GIT_CONFIG_KEYS.*@GIT_CONFIG_KEYS  =>  '.*',@" \
		/home/git/.gitolite.rc
	gosu git sed -i \
		"s@# LOCAL_CODE.*ENV.*@LOCAL_CODE       =>  \"\$ENV{HOME}/local\",@" \
		/home/git/.gitolite.rc

	#echo `cat /home/git/.gitolite.rc`

fi

if [ ! -e /etc/sudoers.d/redmine ]; then
	cat > /etc/sudoers.d/redmine << EOF
Defaults:redmine !requiretty
redmine ALL=(git) NOPASSWD:ALL
EOF
	chmod 440 /etc/sudoers.d/redmine
fi

	#echo `cat /etc/sudoers.d/redmine`


cd /home/redmine
#gosu redmine ssh -o StrictHostKeyChecking=no -i ssh_keys/redmine_gitolite_admin_id_rsa git@localhost info
gosu redmine ssh -i ssh_keys/redmine_gitolite_admin_id_rsa git@localhost info


if [ ! -e /usr/src/redmine/plugins/redmine_git_hosting/ssh_keys/redmine_gitolite_admin_id_rsa ]; then
	cp -r /home/redmine/ssh_keys /usr/src/redmine/plugins/redmine_git_hosting/
	chown -R redmine:redmine /usr/src/redmine/plugins
fi

cd /usr/src/redmine
/docker-entrypoint.sh "$@"

