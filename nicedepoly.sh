#!/bin/bash
echo "注意，本脚本只支持Debian11+及ubuntu20.04+系统；请选择需要配置的网站：（输入数字1或2）"
echo "1. 配置qf(起帆)"
echo "2. 配置xly(小鲤鱼)"
echo "3. 配置chaoyue(超悦)"
read CHOICE
echo "请输入节点ID："
read NODE_ID
# set timezone
timedatectl set-timezone Asia/Hong_Kong
service cron restart
hwclock --systohc --utc
apt update
apt install unzip curl supervisor iptables-persistent -y
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
#安装签发：
curl  https://get.acme.sh | sh -s email=catherndoukasrsm92@gmail.com
#修改系统变量:
export Ali_Key="LTAI5t5cFX1pgK34RT1eRB1b"
export Ali_Secret="XclcTf9pDa2eq15kT0t6ysw6pvl9yv"
mkdir /root/.cert
# 配置qf
if [[ "$CHOICE" == "1" ]]; then
    echo "配置qf(起帆)..."
(cat <<EOF
[program:hyserver]
directory=/root
command=/root/server-hysteria --api https://ty78y3nby40auwwdsjpid0uo84ottci3.assistai.cloud --token HxUhw93lMX8Dx6aG8NSveUCt75FOcr25 --node $NODE_ID
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hyserver.conf
#申请qf证书:
~/.acme.sh/acme.sh --issue --dns dns_ali -d *.shiyuandian.shop --keylength ec-256 --renew-hook "/root/restarthy.sh"
#安装qf证书到目录:
~/.acme.sh/acme.sh --install-cert -d *.shiyuandian.shop --ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
# 配置xly
elif [[ "$CHOICE" == "2" ]]; then
    echo "配置xly(小鲤鱼)..."
(cat <<EOF
[program:hyserver]
directory=/root
command=/root/server-hysteria --api https://uwrp9i1xbz82767xl3fmdk9w4enlhkro.assistai.cloud --token Bh1HcFlXc5JnDZRW3cF4KcYNo6ZBIWwh --node $NODE_ID
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hyserver.conf
#申请xiaoliyu证书:
~/.acme.sh/acme.sh --issue --dns dns_ali -d *.xiaoliyu.cyou --keylength ec-256 --renew-hook "/root/restarthy.sh"
#安装xiaoliyu证书到目录:
~/.acme.sh/acme.sh --install-cert -d *.xiaoliyu.cyou --ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
# 配置chaoyue
elif [[ "$CHOICE" == "3" ]]; then
    echo "配置chaoyue..."
(cat <<EOF
[program:hyserver]
directory=/root
command=/root/server-hysteria --api https://g16lczfrycrbgiymq4z9jud2iq8rrbjb.assistai.cloud --token iG2SIaczVtkDRNTlOiIpvuVbkeKwbMRb --node $NODE_ID
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hyserver.conf
#申请chaoyue证书:
~/.acme.sh/acme.sh --issue --dns dns_ali -d *.chaoyuenode.sbs --keylength ec-256 --renew-hook "/root/restarthy.sh"
#安装chaoyue证书到目录:
~/.acme.sh/acme.sh --install-cert -d *.chaoyuenode.sbs --ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
else
    echo "无效的选择: $CHOICE"
    exit 1
fi
rm -rf nicedepoly.sh
#配置防火墙：
iptables -t nat -F
ip6tables -t nat -F
iptables -F
ip6tables -F
iptables -t nat -A PREROUTING -p udp --dport 6000:21000 -j DNAT --to-destination :18301
ip6tables -t nat -A PREROUTING -p udp --dport 6000:21000 -j DNAT --to-destination :18301
iptables -t nat -A PREROUTING -p udp --dport 22000:35000 -j DNAT --to-destination :4433
ip6tables -t nat -A PREROUTING -p udp --dport 22000:35000 -j DNAT --to-destination :4433
iptables -N SSH_RATE_LIMIT
iptables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --set
iptables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --update --seconds 60 --hitcount 5 -j DROP
iptables -A OUTPUT -p tcp --dport 22 -j SSH_RATE_LIMIT
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
supervisorctl update && supervisorctl restart hyserver