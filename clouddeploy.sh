#!/bin/bash
echo "注意，本脚本只支持Debian11+及ubuntu20.04+系统；请选择需要配置的网站：（输入数字1或2）"
echo "1. 部署节点"
echo "2. 升级hy1"
echo "3. 升级hy2"
read CHOICE
if [[ "$CHOICE" == "1" ]]; then
echo "请输入节点ID："
read NODE_ID
# set timezone
timedatectl set-timezone Asia/Hong_Kong
hwclock --systohc --utc
apt update
apt install cron unzip curl supervisor iptables-persistent vnstat -y
service cron restart
#优化linux参数:
ulimit -n 51200
echo "* soft nofile 51200" >> /etc/security/limits.conf
echo "* hard nofile 51200" >> /etc/security/limits.conf
echo "root soft nofile 51200" >> /etc/security/limits.conf
echo "root hard nofile 51200" >> /etc/security/limits.conf
echo "102400" > /proc/sys/fs/file-max
(cat <<EOF
fs.file-max = 102400
net.core.somaxconn = 1048576
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 1048576
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_orphan_retries = 1
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_local_port_range = 32768 65535
net.ipv4.tcp_rmem = 4096 131072 16777216
net.ipv4.tcp_wmem = 4096 131072 16777216
net.ipv4.tcp_mem = 4096 131072 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF
) > /etc/sysctl.conf
sysctl -p
#下载安装hyserver
rm -rf server-hysteria* restarthy.* LICENSE README.md
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/restarthy.sh
chmod +x restarthy.sh
ARCHITECTURE=$(uname -m)
if [[ "$ARCHITECTURE" == "x86_64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria-linux-64.zip
unzip server-hysteria-linux-64.zip
elif [[ "$ARCHITECTURE" == "aarch64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria-linux-arm64-v8a.zip
unzip server-hysteria-linux-arm64-v8a.zip
else
echo "Unsupported architecture: $ARCHITECTURE"
exit 1
fi
chmod +x server-hysteria
#下载安装hyserver2
rm -rf server-hysteria2* README.md LICENSE
if [[ "$ARCHITECTURE" == "x86_64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria2-linux-64.zip
unzip server-hysteria2-linux-64.zip
elif [[ "$ARCHITECTURE" == "aarch64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria2-linux-arm64-v8a.zip
unzip server-hysteria2-linux-arm64-v8a.zip
else
echo "Unsupported architecture: $ARCHITECTURE"
exit 1
fi
chmod +x server-hysteria2
#安装签发：
curl  https://get.acme.sh | sh -s email=michael.jie.44@gmail.com
#修改系统变量:
export HUAWEICLOUD_Username=acme
export HUAWEICLOUD_Password=6FmKVmUhsNjCtutz4xu
export HUAWEICLOUD_DomainName=hid_e9u9n5jin8vanwf
mkdir /root/.cert
# 配置节点id
(cat <<EOF
[program:hyserver]
directory=/root
command=/root/server-hysteria --api https://oord63pnde3k5td25wky6as692wwvyy7.assistai.cloud --token AKc3bfpmMuaKGcdgDuGQMX9SrpjTKTLB --node $NODE_ID --log_mode info
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hyserver.conf
(cat <<EOF
[program:hy2server]
directory=/root
command=/root/server-hysteria2 --api https://oord63pnde3k5td25wky6as692wwvyy7.assistai.cloud --token AKc3bfpmMuaKGcdgDuGQMX9SrpjTKTLB --node $NODE_ID --log_mode info
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hy2server.conf
#申请证书:
~/.acme.sh/acme.sh --issue --dns dns_huaweicloud -d cloudedge.cyou -d *.cloudedge.cyou --keylength ec-256 --renew-hook "/root/restarthy.sh"
#安装证书到目录:
~/.acme.sh/acme.sh --install-cert -d cloudedge.cyou -d *.cloudedge.cyou--ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
#配置防火墙：
iptables -t nat -F
ip6tables -t nat -F
iptables -F
ip6tables -F
iptables -t nat -A PREROUTING -p udp --dport 5000:15000 -j DNAT --to-destination :4430
ip6tables -t nat -A PREROUTING -p udp --dport 5000:15000 -j DNAT --to-destination :4430
iptables -t nat -A PREROUTING -p udp --dport 20000:30000 -j DNAT --to-destination :4433
ip6tables -t nat -A PREROUTING -p udp --dport 20000:30000 -j DNAT --to-destination :4433
iptables -N SSH_RATE_LIMIT
iptables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --set
iptables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --update --seconds 60 --hitcount 30 -j DROP
iptables -A OUTPUT -p tcp --dport 22 -j SSH_RATE_LIMIT
iptables -A OUTPUT -p tcp --dport 3389 -j SSH_RATE_LIMIT
ip6tables -N SSH_RATE_LIMIT
ip6tables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --set
ip6tables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --update --seconds 60 --hitcount 30 -j DROP
ip6tables -A OUTPUT -p tcp --dport 22 -j SSH_RATE_LIMIT
ip6tables -A OUTPUT -p tcp --dport 3389 -j SSH_RATE_LIMIT
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
#启动服务
supervisorctl update
#删除脚本不在服务上留下脚本内容
rm -rf clouddepoly.sh
#升级hy1
elif [[ "$CHOICE" == "2" ]]; then
rm -rf server-hysteria README.md LICENSE
if [[ "$ARCHITECTURE" == "x86_64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria-linux-64.zip
unzip server-hysteria-linux-64.zip
elif [[ "$ARCHITECTURE" == "aarch64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria-linux-arm64-v8a.zip
unzip server-hysteria-linux-arm64-v8a.zip
else
echo "Unsupported architecture: $ARCHITECTURE"
exit 1
fi
chmod +x server-hysteria
supervisorctl restart hyserver
./server-hysteria -V
#升级hy2
elif [[ "$CHOICE" == "3" ]]; then
rm -rf server-hysteria2* README.md LICENSE
if [[ "$ARCHITECTURE" == "x86_64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria2-linux-64.zip
unzip server-hysteria2-linux-64.zip
elif [[ "$ARCHITECTURE" == "aarch64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria2-linux-arm64-v8a.zip
unzip server-hysteria2-linux-arm64-v8a.zip
else
echo "Unsupported architecture: $ARCHITECTURE"
exit 1
fi
chmod +x server-hysteria2
supervisorctl restart hy2server
./server-hysteria2 -V
#加入日志自动清理：
echo "find /var/log/supervisor/ -type f -mtime +7 -exec rm {} \;" >> cleanup_logs.sh
chmod +x /root/cleanup_logs.sh
(crontab -l ; echo "0 0 * * * /root/cleanup_logs.sh") | crontab -
#删除脚本不在服务上留下脚本内容
rm -rf clouddepoly.sh
else
    echo "无效的选择: $CHOICE"
    exit 1
fi
