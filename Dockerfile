FROM alpine

# prepare everything
RUN apk update
RUN apk add vim lsof tar
# RUN apk add py-pip libsodium
# for centos 7 upgrade
WORKDIR /opt/speederv2
ENV PATH="/opt/speederv2:${PATH}"

# UDPspeeder 20180806.0
RUN wget https://github.com/wangyu-/UDPspeeder/releases/download/20180806.0/speederv2_linux.tar.gz &&\
	tar xzvf speederv2_linux.tar.gz

# copy pre-setting to workspace
# COPY script script

# next need to excute in host
# enable ip_forward
# RUN sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
# keep this code for set sysctl.conf for bbr kernel
# RUN echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
# RUN echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
# active setting
# RUN sysctl -p

# RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
# RUN /sbin/service sshd start && /sbin/service sshd stop

# CMD ["/usr/sbin/sshd", "-D" ]
# find options here https://github.com/wangyu-/UDPspeeder#full-options
ENTRYPOINT ["speederv2_amd64"]
CMD ["-s", "-l","0.0.0.0:4096", "-r", "127.0.0.1:7777", "-f","20:10", "-k", "passwd"]
