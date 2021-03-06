# =============================================================================
# jdeathe/centos-ssh
#
# CentOS-7 7.3.1611 x86_64 - SCL/EPEL/IUS Repos. / Supervisor / OpenSSH.
# 
# =============================================================================
FROM azul/zulu-openjdk-centos:8

MAINTAINER James Deathe <james.deathe@gmail.com>

# -----------------------------------------------------------------------------
# Base Install + Import the RPM GPG keys for Repositories
# -----------------------------------------------------------------------------
RUN    yum -y install \
		epel-release \
		vim-minimal \
		sudo \
		openssh \
		openssh-server \
		openssh-clients \
		python-setuptools \
		openssl \
	&& yum clean all \
	&& rm -rf /etc/ld.so.cache \
	&& rm -rf /sbin/sln \
	&& rm -rf /usr/{{lib,share}/locale,share/{man,doc,info,cracklib,i18n},{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive} \
	&& rm -rf /{root,tmp,var/cache/{ldconfig,yum}}/* \
	&& > /etc/sysconfig/i18n

# -----------------------------------------------------------------------------
# Install supervisord (required to run more than a single process in a container)
# Note: EPEL package lacks /usr/bin/pidproxy
# We require supervisor-stdout to allow output of services started by 
# supervisord to be easily inspected with "docker logs".
# -----------------------------------------------------------------------------
RUN easy_install \
		'supervisor == 3.3.1' \
		'supervisor-stdout == 0.1.1' \
	&& mkdir -p \
		/var/log/supervisor/

# -----------------------------------------------------------------------------
# UTC Timezone & Networking
# -----------------------------------------------------------------------------
RUN ln -sf \
		/usr/share/zoneinfo/UTC \
		/etc/localtime \
	&& echo "NETWORKING=yes" > /etc/sysconfig/network

# -----------------------------------------------------------------------------
# Enable the wheel sudoers group
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^# %wheel\tALL=(ALL)\tALL~%wheel\tALL=(ALL) ALL~g' \
	-e 's~\(.*\) requiretty$~#\1requiretty~' \
	/etc/sudoers

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD usr/sbin \
	/usr/sbin/
ADD opt/scmi \
	/opt/scmi/
ADD etc/systemd/system \
	/etc/systemd/system/
ADD etc/services-config/ssh/authorized_keys \
	etc/services-config/ssh/sshd-bootstrap.conf \
	etc/services-config/ssh/sshd-bootstrap.env \
	/etc/services-config/ssh/
ADD etc/services-config/supervisor/supervisord.conf \
	/etc/services-config/supervisor/
ADD etc/services-config/supervisor/supervisord.d \
	/etc/services-config/supervisor/supervisord.d/

RUN mkdir -p \
		/etc/supervisord.d/ \
	&& cp -pf \
		/etc/ssh/sshd_config \
		/etc/services-config/ssh/ \
	&& ln -sf \
		/etc/services-config/ssh/sshd_config \
		/etc/ssh/sshd_config \
	&& ln -sf \
		/etc/services-config/ssh/sshd-bootstrap.conf \
		/etc/sshd-bootstrap.conf \
	&& ln -sf \
		/etc/services-config/ssh/sshd-bootstrap.env \
		/etc/sshd-bootstrap.env \
	&& ln -sf \
		/etc/services-config/supervisor/supervisord.conf \
		/etc/supervisord.conf \
	&& ln -sf \
		/etc/services-config/supervisor/supervisord.d/sshd-wrapper.conf \
		/etc/supervisord.d/sshd-wrapper.conf \
	&& ln -sf \
		/etc/services-config/supervisor/supervisord.d/sshd-bootstrap.conf \
		/etc/supervisord.d/sshd-bootstrap.conf \
	&& chmod 700 \
		/usr/sbin/{scmi,sshd-{bootstrap,wrapper}}

EXPOSE 22

# -----------------------------------------------------------------------------
# Set default environment variables
# -----------------------------------------------------------------------------
ENV SSH_AUTHORIZED_KEYS="" \
	SSH_AUTOSTART_SSHD=true \
	SSH_AUTOSTART_SSHD_BOOTSTRAP=true \
	SSH_CHROOT_DIRECTORY="%h" \
	SSH_INHERIT_ENVIRONMENT=false \
	SSH_SUDO="ALL=(ALL) ALL" \
	SSH_USER="app-admin" \
	SSH_USER_FORCE_SFTP=false \
	SSH_USER_HOME="/home/%u" \
	SSH_USER_ID="500:500" \
	SSH_USER_PASSWORD="password" \
	SSH_USER_PASSWORD_HASHED=false \
	SSH_USER_SHELL="/bin/bash"

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]