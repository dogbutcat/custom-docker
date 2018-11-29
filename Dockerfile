FROM centos:7

# prepare everything
RUN yum update -y
RUN yum install -y yum-plugin-ovl vim lsof
RUN yum install -y openssh-server openssh-clients epel-release
RUN yum -y install python-pip libsodium
# for centos 7 upgrade
RUN pip install --upgrade pip
RUN pip install https://github.com/shadowsocks/shadowsocks/archive/master.zip -U

ENV ROOT_PW='root'
ENV WORKER_NUM=2
ENV SS_JSON='{"server":"0.0.0.0","server_port":3389,"local_port":1080,"password":"0x0x0x0x","timeout":600,"method":"aes-256-gcm"}'

# copy pre-setting to workspace
WORKDIR /root/ss
COPY script script

# enable ip_forward
# RUN sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
# stop iptables
# RUN /sbin/service iptables stop

# keep this code for set sysctl.conf for bbr kernel
# RUN echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
# RUN echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
# active setting
# RUN sysctl -p

RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
# RUN /sbin/service sshd start && /sbin/service sshd stop

EXPOSE 22
EXPOSE 3389
EXPOSE 3389/udp

# CMD ["/usr/sbin/sshd", "-D" ]
CMD ["/bin/sh","./script/final.sh"]
