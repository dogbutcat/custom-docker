echo 'root:'${ROOT_PW} | chpasswd
echo ${SS_JSON} > ss.json
cat ss.json
/usr/bin/ssserver -c ./ss.json --workers ${WORKER_NUM} -d start
/usr/sbin/sshd -D