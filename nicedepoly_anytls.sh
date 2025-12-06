#!/bin/bash
echo "注意，本脚本只支持Debian11+及ubuntu20.04+系统；请选择需要配置的网站：（输入数字1或2）"
echo "1. 配置qf(起帆)"
echo "2. 配置xly(小鲤鱼)"
echo "3. 配置chaoyue(超悦)"
read CHOICE
echo "请输入节点ID："
read NODE_ID
echo "# set timezone"
timedatectl set-timezone Asia/Hong_Kong
timedatectl set-local-rtc 0
apt update
echo "停止ufw"
systemctl stop ufw
systemctl disable ufw
echo "删除iptables和ufw等"
apt remove --purge iptables xtables-addons-common iptables-persistent netfilter-persistent ufw -y
echo "清除无用的依赖"
apt autoremove --purge -y
apt install cron unzip curl supervisor nftables vnstat net-tools mtr-tiny rsync systemd-timesyncd -y
apt install systemd-resolved -y
systemctl restart cron
timedatectl set-ntp true
# 写入systemd-resolved配置文件
cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=1.1.1.1 8.8.8.8 1.0.0.1 8.8.4.4
FallbackDNS=9.9.9.9 149.112.112.112 2606:4700:4700::1111 2606:4700:4700::1001
Cache=yes
CacheFromLocalhost=yes
DNSStubListener=yes
DNSStubListenerExtra=127.0.0.1:853
ReadEtcHosts=yes
ResolveUnicastSingleLabel=yes
EOF
# 重启systemd-resolved服务
systemctl enable systemd-resolved
systemctl restart systemd-resolved
# 将/etc/resolv.conf软链接到/run/systemd/resolve/stub-resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
echo "# systemd-resolved配置完成。"
echo "设置nftables开机启动"
systemctl enable nftables
systemctl start nftables
echo "清空当前nftables规则"
nft flush ruleset
echo "#优化linux参数:"
ulimit -n 51200
echo "* soft nofile 51200" >> /etc/security/limits.conf
echo "* hard nofile 51200" >> /etc/security/limits.conf
echo "root soft nofile 51200" >> /etc/security/limits.conf
echo "root hard nofile 51200" >> /etc/security/limits.conf
echo "102400" > /proc/sys/fs/file-max
modprobe nf_conntrack
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
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_local_port_range = 32768 65535
net.ipv4.tcp_rmem = 8192 262144 536870912
net.ipv4.tcp_wmem = 4096 16384 536870912
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_notsent_lowat = 131072
net.ipv4.tcp_mem = 4096 131072 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.netfilter.nf_conntrack_max=262144
net.netfilter.nf_conntrack_buckets=65536
vm.swappiness=1
EOF
) > /etc/sysctl.conf
sysctl -p
#下载安装anytls
rm -rf server-anytls* restarthy.* LICENSE README.md
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/restarthy.sh
chmod +x restarthy.sh
ARCHITECTURE=$(uname -m)
if [[ "$ARCHITECTURE" == "x86_64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-anytls-linux-64.zip
unzip server-anytls-linux-64.zip
elif [[ "$ARCHITECTURE" == "aarch64" ]]; then
wget --header 'Authorization: token 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' https://raw.githubusercontent.com/catherndoukasrsm/node/main/server-anytls-linux-arm64-v8a.zip
unzip server-anytls-linux-arm64-v8a.zip
else
echo "Unsupported architecture: $ARCHITECTURE"
exit 1
fi
chmod +x server-anytls
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
[program:anytlsserver]
directory=/root
command=/root/server-anytls --api https://ty78y3nby40auwwdsjpid0uo84ottci3.assistai.cloud --token HxUhw93lMX8Dx6aG8NSveUCt75FOcr25 --node $NODE_ID --log_mode info
autostart=true
autorestart=true
startretries=100
startsecs=5
EOF
) > /etc/supervisor/conf.d/anytlsserver.conf
#申请qf证书:
~/.acme.sh/acme.sh --issue --dns dns_ali -d *.shiyuandian.shop --keylength ec-256 --renew-hook "/root/restarthy.sh" --dnssleep
#安装qf证书到目录:
~/.acme.sh/acme.sh --install-cert -d *.shiyuandian.shop --ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
# 配置xly
elif [[ "$CHOICE" == "2" ]]; then
    echo "配置xly(小鲤鱼)..."
(cat <<EOF
[program:anytlsserver]
directory=/root
command=/root/server-anytls --api https://uwrp9i1xbz82767xl3fmdk9w4enlhkro.assistai.cloud --token Bh1HcFlXc5JnDZRW3cF4KcYNo6ZBIWwh --node $NODE_ID --log_mode info
autostart=true
autorestart=true
startretries=100
startsecs=5
EOF
) > /etc/supervisor/conf.d/anytlsserver.conf
#申请xiaoliyu证书:
~/.acme.sh/acme.sh --issue --dns dns_ali -d *.xiaoliyu.cyou --keylength ec-256 --renew-hook "/root/restarthy.sh" --dnssleep
#安装xiaoliyu证书到目录:
~/.acme.sh/acme.sh --install-cert -d *.xiaoliyu.cyou --ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
# 配置chaoyue
elif [[ "$CHOICE" == "3" ]]; then
    echo "配置chaoyue..."
(cat <<EOF
[program:anytlsserver]
directory=/root
command=/root/server-anytls --api https://g16lczfrycrbgiymq4z9jud2iq8rrbjb.assistai.cloud --token iG2SIaczVtkDRNTlOiIpvuVbkeKwbMRb --node $NODE_ID --log_mode info
autostart=true
autorestart=true
startretries=100
startsecs=5
EOF
) > /etc/supervisor/conf.d/anytlsserver.conf
#申请chaoyue证书:
~/.acme.sh/acme.sh --issue --dns dns_ali -d *.chaoyuenode.sbs --keylength ec-256 --renew-hook "/root/restarthy.sh" --dnssleep
#安装chaoyue证书到目录:
~/.acme.sh/acme.sh --install-cert -d *.chaoyuenode.sbs --ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
else
    echo "无效的选择: $CHOICE"
    exit 1
fi
echo "清空当前nftables规则"
nft flush ruleset
echo "#配置nftables防火墙："
echo "创建inet hysteria_porthopping表和链"
nft add table inet hysteria_porthopping
nft 'add chain inet hysteria_porthopping prerouting { type nat hook prerouting priority dstnat; policy accept; }'
echo "设置6000-11000->18301"
nft add rule inet hysteria_porthopping prerouting udp dport 6000-11000 redirect to :18301
echo "设置22000-27000->4433"
nft add rule inet hysteria_porthopping prerouting udp dport 22000-27000 redirect to :4433
echo "创建inet outbound_limit表和链"
nft add table inet outbound_limit
nft 'add chain inet outbound_limit output { type filter hook output priority 0; }'
echo "创建outbound_limit计数器"
nft add counter inet outbound_limit smtp_counter
nft add counter inet outbound_limit ssh_rdp_counter
echo "添加 SMTP 规则（端口 25, 465, 587）"
nft 'add rule inet outbound_limit output meta l4proto tcp tcp dport { 25, 465, 587 }' \
    limit rate 20/minute counter name smtp_counter accept
echo "添加 SSH 和 RDP 规则（端口 22 和 3389）"
nft 'add rule inet outbound_limit output meta l4proto tcp tcp dport { 22, 3389 }' \
    limit rate 20/minute counter name ssh_rdp_counter accept
echo "丢弃超过限制的连接"
nft add rule inet outbound_limit output meta l4proto tcp tcp dport { 25, 465, 587, 22, 3389 } drop
echo "保存规则"
nft list ruleset > /etc/nftables.conf
supervisorctl update && supervisorctl restart hyserver
#加入日志自动清理：
echo "find /var/log/supervisor/ -type f -mtime +7 -exec rm {} \;" >> cleanup_logs.sh
chmod +x /root/cleanup_logs.sh
(crontab -l ; echo "0 0 * * * /root/cleanup_logs.sh") | crontab -
rm -rf nicedepoly.sh