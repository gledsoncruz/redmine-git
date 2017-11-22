#!/bin/bash

# If ssh host key is not exist, regenerate it.
#
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server

service ssh start

# Initialize redmine, @@@ ignore error
#
echo `pwd`
/docker-entrypoint.sh rails -v

if [ ! -e /usr/src/redmine/.rghp_migrated ]; then
	cd /usr/src/redmine
	bundle exec rake redmine:plugins:migrate RAILS_ENV=production NAME=redmine_git_hosting
	touch .rghp_migrated
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
	groupadd -g $GIT_GID git && useradd -m -u $GIT_UID -g $GIT_GID git
	cp /etc/skel/.[a-z]* /home/git
	chown -R git:git /home/git
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

