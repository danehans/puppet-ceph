#!/bin/sh

set -x
set -e

# ensure a correct domain name is set from dhclient
grep -q 'supersede domain-name "test";' /etc/dhcp/dhclient.conf ||  {
    echo 'supersede domain-name "test";' >> /etc/dhcp/dhclient.conf
    pkill -9 dhclient
    dhclient eth0
}

# add hosts to /etc/hosts
grep -q "ceph-mon0" /etc/hosts || echo "192.168.251.10	ceph-mon0 ceph-mon0.test" >> /etc/hosts
grep -q "ceph-mon1" /etc/hosts || echo "192.168.251.11	ceph-mon1 ceph-mon1.test" >> /etc/hosts
grep -q "ceph-mon2" /etc/hosts || echo "192.168.251.12	ceph-mon2 ceph-mon2.test" >> /etc/hosts
grep -q "ceph-osd0" /etc/hosts || echo "192.168.251.100	ceph-osd0 ceph-osd0.test" >> /etc/hosts
grep -q "ceph-osd1" /etc/hosts || echo "192.168.251.101	ceph-osd1 ceph-osd1.test" >> /etc/hosts
grep -q "ceph-osd2" /etc/hosts || echo "192.168.251.102	ceph-osd2 ceph-osd2.test" >> /etc/hosts

aptitude update

# Install puppetmaster, etc. …
if hostname | grep -q "ceph-mon0"; then
    aptitude install -y puppetmaster sqlite3 libsqlite3-ruby libactiverecord-ruby git augeas-tools puppet ruby1.8 ruby1.8-dev libruby1.8

    # Ensure ruby1.8 is the default
    update-alternatives --set ruby /usr/bin/ruby1.8

    # This lens seems to be broken currently on wheezy/sid ?
    test -f /usr/share/augeas/lenses/dist/cgconfig.aug && rm -f /usr/share/augeas/lenses/dist/cgconfig.aug
    augtool << EOT
set /files/etc/puppet/puppet.conf/agent/pluginsync true
set /files/etc/puppet/puppet.conf/agent/server ceph-mon0.test
set /files/etc/puppet/puppet.conf/master/storeconfigs true
save
EOT

    # Autosign certificates from our test setup
    echo "*.test" > /etc/puppet/autosign.conf

    git clone git://github.com/fcharlier/puppet-ceph.git /etc/puppet/modules/ceph
    git clone git://github.com/ripienaar/puppet-concat.git /etc/puppet/modules/concat

    cp /etc/puppet/modules/ceph/examples/site.pp /etc/puppet/manifests/
    service puppetmaster restart
else
    aptitude install -y augeas-tools

    # This lens seems to be broken currently on wheezy/sid ?
    test -f /usr/share/augeas/lenses/dist/cgconfig.aug && rm -f /usr/share/augeas/lenses/dist/cgconfig.aug
    augtool << EOT
set /files/etc/puppet/puppet.conf/agent/pluginsync true
set /files/etc/puppet/puppet.conf/agent/server ceph-mon0.test
save
EOT

fi

# Enable sid source for ceph
grep -q "sid" /etc/apt/sources.list || echo "deb http://ftp2.fr.debian.org/debian/ sid main" >> /etc/apt/sources.list
aptitude update

# And finally, run the puppet agent
puppet agent --verbose --debug --onetime --no-daemonize
