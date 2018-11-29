echo 'root:'${ROOT_PW} | chpasswd

echo ${SS_JSON} > ss.json
cat ss.json
# add ip forward for centos-7
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.conf
/usr/bin/ssserver -c ./ss.json --workers ${WORKER_NUM} -d start
/usr/sbin/sshd -D

finish(){
	/usr/bin/ssserver -c ./ss.json --workers ${WORKER_NUM} -d stop
	exit 0
}

trap finish SIGTERM SIGINT SIGQUIT

sleep infinity &
wait $!