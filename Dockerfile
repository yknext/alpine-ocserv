From alpine:3.4
MAINTAINER soniclidi
USER root

RUN apk update && apk add musl musl-dev iptables gnutls-dev readline-dev libnl3-dev lz4-dev libseccomp-dev
RUN apk add libev libev-dev gnutls-utils libsodium supervisor
RUN apk --no-cache add python dnsmasq

RUN buildDeps="xz openssl gcc autoconf make linux-headers"; \
	set -x \
	&& apk add $buildDeps \
	&& cd \
	&& wget http://www.infradead.org/ocserv/download.html -O download.html \
	&& OC_VERSION=`sed -n 's/^.*version is <b>\(.*\)$/\1/p' download.html` \
	&& OC_FILE="ocserv-$OC_VERSION" \
	&& rm -fr download.html \
	&& wget ftp://ftp.infradead.org/pub/ocserv/$OC_FILE.tar.xz \
	&& tar xJf $OC_FILE.tar.xz \
	&& rm -fr $OC_FILE.tar.xz \
	&& cd $OC_FILE \
	&& sed -i '/#define DEFAULT_CONFIG_ENTRIES /{s/96/200/}' src/vpn.h \
	&& ./configure \
	&& make -j"$(nproc)" \
	&& make install \
	&& mkdir -p /etc/ocserv \
	&& cp ./doc/sample.config /etc/ocserv/ocserv.conf \
	&& cd \
	&& rm -fr ./$OC_FILE \
	&& apk del --purge $buildDeps

COPY route-except-private.txt /tmp/route-rule.txt
RUN set -x \
	&& sed -i 's/\.\/sample\.passwd/\/etc\/ocserv\/ocpasswd/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/\(max-same-clients = \)2/\110/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/\.\.\/tests/\/etc\/ocserv/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/#\(compression.*\)/\1/' /etc/ocserv/ocserv.conf \
	&& sed -i '/^ipv4-network = /{s/192.168.1.0/$SUB_NETWORK/}' /etc/ocserv/ocserv.conf \
	&& sed -i 's/192.168.1.2/8.8.8.8/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^route/#route/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^no-route/#no-route/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/try-mtu-discovery\ \=\ false/try-mtu-discovery\ \=\ true/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/dns\ \=\ 8.8.8.8/dns\ \=\ 223.6.6.6/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/plain\[passwd\=\/etc\/ocserv\/ocpasswd\]/certificate/' /etc/ocserv/ocserv.conf \
	&& echo 'dns = 223.5.5.5' >> /etc/ocserv/ocserv.conf \
	&& sed -i 's/default-domain/#default-domaim/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/cert-user-oid/#cert-user-oid/' /etc/ocserv/ocserv.conf \
	&& echo 'cert-user-oid = 2.5.4.3' >> /etc/ocserv/ocserv.conf \
	&& cat /tmp/route-rule.txt >> /etc/ocserv/ocserv.conf \
	&& rm -fr /tmp/route-rule.txt

WORKDIR /etc/ocserv

COPY ocm /bin
RUN chmod +x /bin/ocm

COPY dnsmasq.conf /etc/dnsmasq.conf

COPY supervisor.ini /etc/supervisord.d/application.ini

COPY etc/shadowsocks.json /shadowsocks.json

RUN mkdir /shadowsocks
ADD https://github.com/shadowsocks/shadowsocks-libev/archive/v2.5.6.tar.gz /shadowsocks
RUN ls /shadowsocks

RUN cd /shadowsocks/ && ./configure && make install && cd / && rm -rf /shadowsocks

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
