FROM phusion/baseimage:0.9.22
# updated from an0t8/mythtv-server

# Set correct environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME="/root"
ENV TERM=xterm
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# These should be set at runtime.
ENV USER_ID=99
ENV GROUP_ID=100
ENV DATABASE_HOST=mysql
ENV DATABASE_PORT=3306
ENV DATABASE_ROOT=root
ENV DATABASE_ROOT_PWD=pwd

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

# Expose ports
EXPOSE 3389 5000/udp 6543 6544


# set volumes
VOLUME /home/mythtv /var/lib/mythtv

# Add files
COPY files /root/

# chfn workaround - Known issue within Dockers
RUN ln -s -f /bin/true /usr/bin/chfn

# Set the locale
RUN locale-gen en_US.UTF-8 && \
mkdir -p /etc/my_init.d && \
mv /root/startup/* /etc/my_init.d && \
rmdir /root/startup && \
chmod +x /etc/my_init.d/*

# add repos
RUN apt-add-repository ppa:ubuntu-mate-dev/ppa && \
apt-add-repository ppa:ubuntu-mate-dev/xenial-mate
RUN apt-get update -qq

# install mate and dependencies

RUN apt-get install -qy --force-yes --no-install-recommends \
wget \
sudo \
mate-desktop-environment-core \
x11vnc \
xvfb \
gtk2-engines-murrine \
ttf-ubuntu-font-family \
pwgen \
supervisor

# install xrdp
RUN apt-get install \
xrdp -y && \
mv /root/xrdp.ini /etc/xrdp/xrdp.ini

# add repositories
RUN add-apt-repository universe -y && \
apt-add-repository ppa:mythbuntu/30 -y && \
apt-get update -qq

RUN apt-get install -y mythtv-common ||true

RUN sed -i 's/\(^.*chmod.*NEW\)/#\1/' /var/lib/dpkg/info/mythtv-common.postinst
RUN sed -i 's/\(^.*chown.*NEW\)/#\1/' /var/lib/dpkg/info/mythtv-common.postinst
RUN apt-get install -y mythtv-common
RUN chown mythtv:mythtv /etc/mythtv/config.xml
RUN chmod 660 /etc/mythtv/config.xml

# install mythtv-backend, database and ping util
RUN apt-get install -y --no-install-recommends mythtv-backend mythtv-database xmltv unzip mythtv-status iputils-ping xmltv-util

# install mythweb
RUN apt-get install \
mythweb -y

# install mythnuv2mkv
RUN apt-get install \
libmyth-python mythtv-transcode-utils perl mplayer mencoder wget imagemagick \
libmp3lame0 x264 faac faad mkvtoolnix vorbis-tools gpac -y && \
mv /root/mythnuv2mkv.sh /usr/bin/ && \
chmod +x /usr/bin/mythnuv2mkv.sh

# install hdhomerun utilities
RUN apt-get install \
hdhomerun-config-gui \
hdhomerun-config -y

# set mythtv to uid and gid
RUN usermod -u ${USER_ID} mythtv && \
usermod -g ${GROUP_ID} mythtv

# create/place required files/folders
RUN mkdir -p /home/mythtv/.mythtv /var/lib/mythtv /var/log/mythtv /root/.mythtv

# set a password for user mythtv and add to required groups
RUN echo "mythtv:mythtv" | chpasswd && \
usermod -s /bin/bash -d /home/mythtv -a -G users,mythtv,adm,sudo mythtv

# set permissions for files/folders
RUN chown -R mythtv:users /var/lib/mythtv /var/log/mythtv /home/mythtv

# set up passwordless sudo
RUN echo '%adm ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/adm && \
chmod 0440 /etc/sudoers.d/adm

#Workaround for bug: https://bugreports.qt.io/browse/QTBUG-44938
RUN echo 'XKB_DEFAULT_RULES=base' |tee -a /root/.bashrc |tee -a /home/mythtv/.bashrc

#Workaround if /dev/dvb is owned by root:
RUN usermod -a -G root mythtv
#cat /etc/udev/rules.d/90-dvbdocker.rules
#ATTRS{vendor}=="0x1ade", ATTRS{device}=="0x3038", RUN+="/bin/chown -R mythtv:users /dev/dvb"
#SUBSYSTEM="dvb", RUN+="/bin/chown -R mythtv:users /dev/dvb"

# clean up
RUN apt-get clean && \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
/usr/share/man /usr/share/groff /usr/share/info \
/usr/share/lintian /usr/share/linda /var/cache/man && \
(( find /usr/share/doc -depth -type f ! -name copyright|xargs rm || true )) && \
(( find /usr/share/doc -empty|xargs rmdir || true ))
