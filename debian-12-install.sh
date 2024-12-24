#!/bin/bash
## Script for building/installing FreeSWITCH from source.
## URL: https://gist.github.com/mariogasparoni/dc4490fcc85a527ac45f3d42e35a962c
## Freely distributed under the MIT license
##
##
set -xe
FREESWITCH_SOURCE=https://github.com/signalwire/freeswitch.git
FREESWITCH_RELEASE=1.10.12 #or set this to any other version, for example: v1.10.5
PREFIX=/usr/share/freeswitch

#Clean old prefix and build
sudo rm -rf $PREFIX

#install dependencies
sudo apt-get update && sudo apt-get install -y git-core build-essential python-is-python3 python3-dev autoconf automake libtool libncurses5 libncurses5-dev make libjpeg-dev pkg-config zlib1g-dev sqlite3 libsqlite3-dev libpcre3-dev libspeexdsp-dev libspeex-dev libedit-dev libldns-dev liblua5.2-0-dev libcurl4-gnutls-dev libapr1-dev yasm libsndfile-dev libopus-dev libtiff-dev libavformat-dev libswscale-dev libswresample-dev libpq-dev zip libmemcached-dev libshout3-dev sox libsox-fmt-mp3 sngrep libmp3lame-dev python3-setuptools

#cd back one
cd ..

PVERSION=( ${FREESWITCH_RELEASE//./ } )
MIN_VERSION=${PVERSION[1]}
PATCH_VERSION=${PVERSION[2]}

if [[ $FREESWITCH_RELEASE = "master" ]] || [[ $MIN_VERSION -ge 10  &&  $PATCH_VERSION -ge 3 ]]
then
    echo "VERSION => 1.10.3 - need to build libsk2, signalwire-c , spandsp and sofia-sip separatedly"

    #build and install libspandev
    rm -dfr spandsp
    git clone https://github.com/freeswitch/spandsp.git
    cd spandsp
    ./bootstrap.sh
    ./configure
    make
    sudo make install
    cd ..

    #build and install mod_sofia
    rm -dfr sofia-sip
    git clone https://github.com/freeswitch/sofia-sip.git
    cd sofia-sip
    git checkout v1.13.17
    ./bootstrap.sh
    ./configure
    make
    sudo make install
    cd ..
fi

cd freeswitch

./bootstrap.sh

# enable required modules
#sed -i /usr/src/freeswitch/modules.conf -e s:'#applications/mod_avmd:applications/mod_avmd:'
sed -i modules.conf -e s:'#applications/mod_av:formats/mod_av:'
sed -i modules.conf -e s:'#applications/mod_callcenter:applications/mod_callcenter:'
sed -i modules.conf -e s:'#applications/mod_cidlookup:applications/mod_cidlookup:'
sed -i modules.conf -e s:'#applications/mod_memcache:applications/mod_memcache:'
sed -i modules.conf -e s:'#applications/mod_nibblebill:applications/mod_nibblebill:'
sed -i modules.conf -e s:'#applications/mod_curl:applications/mod_curl:'
sed -i modules.conf -e s:'#applications/mod_translate:applications/mod_translate:'
sed -i modules.conf -e s:'#applications/mod_http_cache:applications/mod_http_cache:'
sed -i modules.conf -e s:'#formats/mod_shout:formats/mod_shout:'
sed -i modules.conf -e s:'#formats/mod_pgsql:formats/mod_pgsql:'
sed -i modules.conf -e s:'#say/mod_say_es:say/mod_say_es:'
sed -i modules.conf -e s:'#say/mod_say_fr:say/mod_say_fr:'

#disable module or install dependency libks to compile signalwire
sed -i modules.conf -e s:'applications/mod_signalwire:#applications/mod_signalwire:'
sed -i modules.conf -e s:'endpoints/mod_skinny:#endpoints/mod_skinny:'
sed -i modules.conf -e s:'endpoints/mod_httapi:#endpoints/mod_httapi:'
sed -i modules.conf -e s:'endpoints/mod_verto:#endpoints/mod_verto:'


#configure , build and install
#env PKG_CONFIG_PATH=/usr/share/freeswitch/lib/pkgconfig ./configure --prefix=/usr/share/freeswitch --exec_prefix=/etc/freeswitch --localstatedir=/var --sysconfdir=/etc  --libdir=/var/lib --datadir=/usr/share --disable-libvpx
./configure --enable-portable-binary --disable-dependency-tracking --prefix=/usr --localstatedir=/var --sysconfdir=/etc --with-gnu-ld --with-python --with-python3 --with-openssl

make
make install sounds-install moh-install cd-sounds-install cd-moh-install #config-vanilla

#create user and group
cd /usr/share
groupadd freeswitch
adduser --quiet --system --home /usr/share/freeswitch --gecos "FreeSWITCH open source softswitch" --ingroup freeswitch freeswitch --disabled-password
chown -R freeswitch:freeswitch /usr/share/freeswitch/ 
mkdir -p /var/cache/freeswitch
chown -R freeswitch:freeswitch /var/cache/freeswitch
chmod -R ug=rwX,o= /usr/share/freeswitch/
chmod -R u=rwx,g=rx /etc/freeswitch/

cd freeswitch
cp debian/freeswitch-systemd.freeswitch.service /etc/systemd/system/freeswitch.service
systemctl daemon-reload
systemctl enable freeswitch
