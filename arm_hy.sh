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
net.core.wmem_max = 16777216
net.core.wmem_default = 131072
net.core.rmem_max = 16777216
net.core.rmem_default = 131072
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 1048576
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_orphan_retries = 1
net.ipv4.ip_local_port_range = 32768 65535
net.ipv4.tcp_rmem = 4096 131072 16777216
net.ipv4.tcp_wmem = 4096 131072 16777216
net.ipv4.tcp_mem = 4096 131072 16777216
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF
) > /etc/sysctl.conf
sysctl -p
#下载安装hyserver
rm -rf restarthy.* LICENSE README.md
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/restarthy.sh
chmod +x restarthy.sh
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-hysteria-linux-arm64-v8a.zip
unzip server-hysteria-linux-arm64-v8a.zip
chmod +x server-hysteria
(cat <<EOF
[program:hyserver]
directory=/root
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hyserver.conf
#安装证书签发：
curl  https://get.acme.sh | sh -s email=keleqishui@proton.me
#修改系统变量:
export HUAWEICLOUD_Username=hid_gv8xss-1l6n6z5t
export HUAWEICLOUD_Password=Xiaobin123
export HUAWEICLOUD_DomainName=hid_gv8xss-1l6n6z5t
#申请证书:
~/.acme.sh/acme.sh --issue --dns dns_huaweicloud -d *.shiyuandian.shop --keylength ec-256 --renew-hook "/root/restarthy.sh"
#安装证书到目录:
mkdir /root/.cert
~/.acme.sh/acme.sh --install-cert -d *.shiyuandian.shop --ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
rm -rf 64_hy.sh
#配置防火墙：
iptables -t nat -A PREROUTING -p udp --dport 6000:21000 -j DNAT --to-destination :18301
ip6tables -t nat -A PREROUTING -p udp --dport 6000:21000 -j DNAT --to-destination :18301
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
#手动执行指定节点
#sed -i '2a\command=/root/server-hysteria --api https://ty78y3nby40auwwdsjpid0uo84ottci3.assistai.cloud --token HxUhw93lMX8Dx6aG8NSveUCt75FOcr25 --node 35' /etc/supervisor/conf.d/hyserver.conf
#supervisorctl update && supervisorctl restart hyserver
