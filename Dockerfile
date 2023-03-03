FROM adoptopenjdk/openjdk8:jdk8u362-b09-debian

ARG version=4.8.0
ARG tz=Asia/Shanghai
ENV ROCKETMQ_VERSION=${version} \
    DEBIAN_FRONTEND=noninteractive \
    TZ=${tz}

RUN set -ex; \
	if ! command -v gpg > /dev/null; then \
		apt-get update; \
		apt-get install -y --no-install-recommends \
			gnupg \
			dirmngr \
		; \
		rm -rf /var/lib/apt/lists/*; \
	fi

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.12
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true


ENV ROCKETMQ_HOME=/opt/rocketmq
ENV PATH=$ROCKETMQ_HOME/bin:$PATH

RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget p7zip-full; \
	rm -rf /var/lib/apt/lists/*; \
	\
	ROCKETMQ_SOURCE_URL="https://archive.apache.org/dist/rocketmq/${ROCKETMQ_VERSION}/rocketmq-all-${ROCKETMQ_VERSION}-bin-release.zip"; \
	ROCKETMQ_PATH="/usr/local/src/rocketmq-$ROCKETMQ_VERSION"; \
	\
	wget --progress dot:giga --output-document "$ROCKETMQ_PATH.zip.asc" "$ROCKETMQ_SOURCE_URL.asc"; \
	wget --progress dot:giga --output-document "$ROCKETMQ_PATH.zip" "$ROCKETMQ_SOURCE_URL"; \
	wget --progress dot:giga https://www.apache.org/dist/rocketmq/KEYS; \
	\
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --import KEYS; \
	#gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$ROCKETMQ_PGP_KEY_ID"; \
	gpg --batch --verify "$ROCKETMQ_PATH.zip.asc" "$ROCKETMQ_PATH.zip"; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	\
	mkdir -p "$ROCKETMQ_HOME"; \
	7z x $ROCKETMQ_PATH.zip; \
	mv rocketmq*/* $ROCKETMQ_HOME; \
	rmdir rocketmq*  ; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf KEYS


# make the "en_US.UTF-8" locale so rocketmq will be utf-8 enabled by default
RUN set -eux; \
	if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
# if this file exists, we're likely in "debian:xxx-slim", and locales are thus being excluded so we need to remove that exclusion (since we need locales)
		grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
		sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
		! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
	fi; \
	apt-get update; apt-get install -y --no-install-recommends locales; rm -rf /var/lib/apt/lists/*; \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8


RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# install "nss_wrapper" in case we need to fake "/etc/passwd" and "/etc/group" (especially for OpenShift)
# https://github.com/docker-library/postgres/issues/359
# https://cwrap.org/nss_wrapper.html
		libnss-wrapper \
		xz-utils \
		psmisc procps iproute2 net-tools libfreetype6 fontconfig fonts-dejavu \
	; \
	rm -rf /var/lib/apt/lists/*

EXPOSE 9876 10909 10911 10912

# Debian uses Bash as the default interactive shell.
# https://wiki.debian.org/Shell
RUN rm -rf /bin/sh && ln -s /bin/bash /bin/sh



COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s /usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh



STOPSIGNAL SIGINT


# explicitly set user/group IDs
RUN set -eux; \
	groupadd -r rocketmq --gid=3000; \
	useradd -r -g rocketmq --uid=3000 --shell=/bin/bash rocketmq; \
	mkdir -p /home/rocketmq/logs; \
	mkdir -p /home/rocketmq/store; \
	chown -R rocketmq:rocketmq ${ROCKETMQ_HOME}; \
	chown -R rocketmq:rocketmq /home/rocketmq

RUN \
	sed -i '/-server -Xms/d' ${ROCKETMQ_HOME}/bin/runserver.sh; \
	sed -i "s@\$JAVA \${JAVA_OPT}@exec \$JAVA \${JAVA_OPT}@g" ${ROCKETMQ_HOME}/bin/runserver.sh; \
	sed -i '/-server -Xms/d;/-XX:MaxDirectMemorySize=/d' ${ROCKETMQ_HOME}/bin/runbroker.sh; \
	sed -i '/^numactl --interleave/,$d' ${ROCKETMQ_HOME}/bin/runbroker.sh; \
	sed -i '$aexec \$JAVA \${JAVA_OPT} \$@' ${ROCKETMQ_HOME}/bin/runbroker.sh; \
	sed -i "s@sh \${ROCKETMQ_HOME}@exec \${ROCKETMQ_HOME}@g" ${ROCKETMQ_HOME}/bin/mqbroker; \
	sed -i "s@sh \${ROCKETMQ_HOME}@exec \${ROCKETMQ_HOME}@g" ${ROCKETMQ_HOME}/bin/mqnamesrv;
	

WORKDIR ${ROCKETMQ_HOME}/bin
ENTRYPOINT ["/docker-entrypoint.sh"]