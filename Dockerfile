FROM alpine:3.11 as builder

ENV ZEEK_VERSION 3.1.1

RUN apk add --no-cache zlib openssl libstdc++ libpcap libgcc
RUN apk add --no-cache -t .build-deps \
  bsd-compat-headers \
  libmaxminddb-dev \
  linux-headers \
  openssl-dev \
  libpcap-dev \
  python-dev \
  zlib-dev \
  binutils \
  fts-dev \
  cmake \
  clang \
  bison \
  bash \
  swig \
  perl \
  make \
  flex \
  git \
  g++ \
  fts

RUN echo "===> Cloning zeek..." \
  && cd /tmp \
  && git clone --recursive --branch v$ZEEK_VERSION https://github.com/zeek/zeek.git

RUN echo "===> Compiling zeek..." \
  && cd /tmp/zeek \
  && CC=clang ./configure --prefix=/usr/local/zeek \
  --build-type=Release \
  --disable-broker-tests \
  --disable-auxtools \
  && make -j 2 \
  && make install

RUN echo "===> Compiling af_packet plugin..." \
  && cd /tmp/zeek/aux/ \
  && git clone https://github.com/J-Gras/zeek-af_packet-plugin.git \
  && cd /tmp/zeek/aux/zeek-af_packet-plugin \
  && CC=clang ./configure --with-kernel=/usr --zeek-dist=/tmp/zeek \
  && make -j 2 \
  && make install \
  && /usr/local/zeek/bin/zeek -NN Zeek::AF_Packet

RUN echo "===> Shrinking image..." \
  && strip -s /usr/local/zeek/bin/zeek

RUN echo "===> Size of the Zeek install..." \
  && du -sh /usr/local/zeek
####################################################################################################
FROM alpine:3.11

# python & bash are needed for zeekctl scripts
# util-linux provides taskset command needed to pin CPUs
RUN apk --no-cache add ca-certificates zlib openssl libstdc++ libpcap libmaxminddb libgcc fts python bash util-linux

COPY --from=builder /usr/local/zeek /usr/local/zeek
COPY local.zeek /usr/local/zeek/share/zeek/site/local.zeek
COPY zeekctl-cron.sh /etc/periodic/15min/zeekctl-cron.sh
COPY docker-entrypoint.sh /docker-entrypoint.sh

WORKDIR /pcap

ENV ZEEKPATH .:/data/config:/usr/local/zeek/share/zeek:/usr/local/zeek/share/zeek/policy:/usr/local/zeek/share/zeek/site
ENV PATH $PATH:/usr/local/zeek/bin

ENTRYPOINT ["/docker-entrypoint.sh"]

# /usr/local/zeek/logs
# /usr/local/zeek/etc/node.cfg
# /usr/local/zeek/share/zeek/site/local.zeek

