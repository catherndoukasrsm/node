#!/bin/bash
echo "注意，本脚本只支持Debian11+及ubuntu20.04+系统；请选择需要配置的网站：（输入数字1或2）"
echo "1. 部署节点"
echo "2. 升级hy1"
echo "3. 升级hy2"
read CHOICE
if [[ "$CHOICE" == "1" ]]; then
echo "请输入节点ID："
read NODE_ID
echo "# set timezone"
timedatectl set-timezone Asia/Hong_Kong
hwclock --systohc --utc
apt update
echo "停止ufw"
systemctl stop ufw
systemctl disable ufw
echo "删除iptables和ufw等"
apt remove --purge iptables xtables-addons-common iptables-persistent netfilter-persistent ufw -y
echo "清除无用的依赖"
apt autoremove --purge -y
apt install cron unzip curl supervisor nftables vnstat net-tools mtr-tiny -y
apt install systemd-resolved -y
systemctl restart cron
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
#下载安装hyserver
rm -rf server-hysteria* server-hysteria-linux* restarthy.* LICENSE README.md
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
startretries=100
startsecs=5
EOF
) > /etc/supervisor/conf.d/hyserver.conf
(cat <<EOF
[program:hy2server]
directory=/root
command=/root/server-hysteria2 --api https://oord63pnde3k5td25wky6as692wwvyy7.assistai.cloud --token AKc3bfpmMuaKGcdgDuGQMX9SrpjTKTLB --node $NODE_ID --log_mode info
autostart=true
autorestart=true
startretries=100
startsecs=5
EOF
) > /etc/supervisor/conf.d/hy2server.conf
#申请证书:
~/.acme.sh/acme.sh --issue --dns dns_huaweicloud -d cloudedge.cyou -d *.cloudedge.cyou --keylength ec-256 --renew-hook "/root/restarthy.sh" --dnssleep
#安装证书到目录:
~/.acme.sh/acme.sh --install-cert -d cloudedge.cyou -d *.cloudedge.cyou--ecc \
--key-file       /root/.cert/server.key  \
--fullchain-file /root/.cert/server.crt
echo "清空当前nftables规则"
nft flush ruleset
echo "#配置nftables防火墙："
echo "创建inet hysteria_porthopping表和链"
nft add table inet hysteria_porthopping
nft 'add chain inet hysteria_porthopping prerouting { type nat hook prerouting priority dstnat; policy accept; }'
echo "设置5000-10000->4430"
nft add rule inet hysteria_porthopping prerouting udp dport 5000-10000 redirect to :4430
echo "设置15000-20000->4433"
nft add rule inet hysteria_porthopping prerouting udp dport 15000-20000 redirect to :4433
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
#启动服务
supervisorctl update
#删除脚本不在服务上留下脚本内容
rm -rf clouddepoly.sh
#升级hy1
elif [[ "$CHOICE" == "2" ]]; then
rm -rf server-hysteria server-hysteria-linux* README.md LICENSE
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
