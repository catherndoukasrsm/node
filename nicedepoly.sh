#!/bin/bash
echo "注意，本脚本只支持Debian11+及ubuntu20.04+系统；请选择需要配置的网站：（输入数字1或2）"
echo "1. 配置qf(起帆)"
echo "2. 配置xly(小鲤鱼)"
echo "3. 配置chaoyue(超悦)"
read CHOICE
echo "请输入节点ID："
read NODE_ID
echo "# set hostname"
hostnamectl set-hostname "$(hostname -I | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || echo '0.0.0.0')-$(hostname | sed -E 's/^([0-9]{1,3}\.){3}[0-9]{1,3}-//g' | sed 's/^-//' | head -c 50 || echo 'host')"
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
# 删除所有 nofile 相关的行
sed -i '/soft nofile/d; /hard nofile/d' /etc/security/limits.conf
# 添加新的配置
cat >> /etc/security/limits.conf << EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
root soft nofile 1048576
root hard nofile 1048576
EOF
echo "102400" > /proc/sys/fs/file-max
modprobe nf_conntrack
(cat <<EOF
# =============================================================
# 代理节点优化 - 2C2G VPS / 高丢包(5-10%) / 高延迟(150ms)
# 适用于：Trojan, Xray, sing-box, Hysteria, TUIC
# =============================================================

# =============================================================
# 系统资源
# =============================================================
fs.file-max = 1048576

vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1

# =============================================================
# TCP 缓冲区 - 高丢包需要更大缓冲容纳重传
# =============================================================
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 2097152
net.core.wmem_default = 2097152

# min / default / max
# default 设大：单连接初始就有足够空间
# max 设大：容纳乱序包和重传
net.ipv4.tcp_rmem = 4096 2097152 67108864
net.ipv4.tcp_wmem = 4096 2097152 67108864

# tcp_mem (单位：4KB页) - 适配 2G 内存
# 约 48MB / 128MB / 192MB
net.ipv4.tcp_mem = 12288 32768 49152

# =============================================================
# 窗口与流控 - 高丢包高延迟专用
# =============================================================
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1

# 窗口 = 1/2 缓冲区，高丢包需要大窗口
net.ipv4.tcp_adv_win_scale = -1

# 高丢包场景不限制发送，让 BBR 自己控制
# net.ipv4.tcp_notsent_lowat = 不设置

# =============================================================
# 拥塞控制 - BBR 对丢包容忍度最高
# =============================================================
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# 关键：空闲后不重置窗口，高丢包环境重建窗口代价太大
net.ipv4.tcp_slow_start_after_idle = 0

# =============================================================
# 丢包检测与恢复 - 核心优化
# =============================================================
# SACK: 选择性确认，知道具体丢了哪些包
net.ipv4.tcp_sack = 1
# D-SACK: 检测虚假重传
net.ipv4.tcp_dsack = 1

# RACK (Recent ACK): 基于时间的丢包检测，比传统 3 个重复 ACK 更准
# 内核 4.15+ 默认启用，这里确保开启
net.ipv4.tcp_recovery = 1

# Early Retransmit: 不等 3 个重复 ACK
# 3 = 启用 ER + TLP (Tail Loss Probe)
net.ipv4.tcp_early_retrans = 3

# TLP: 尾部丢包探测，高丢包必备
# 在 RTO 之前发送探测包
net.ipv4.tcp_thin_linear_timeouts = 1

# 减少 RTO 最小值影响（通过更激进的重传）
# F-RTO: 检测虚假超时，避免不必要的慢启动
net.ipv4.tcp_frto = 2

# 孤儿连接重试减少，快速释放资源
net.ipv4.tcp_orphan_retries = 1

# 重传次数：高丢包环境适当增加容忍度
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 8

# =============================================================
# ECN - 高丢包环境建议关闭
# 很多高丢包链路 ECN 不可靠，会导致额外问题
# =============================================================
net.ipv4.tcp_ecn = 0

# =============================================================
# MTU 探测 - 高丢包环境重要
# 避免因 MTU 黑洞导致的丢包
# =============================================================
net.ipv4.tcp_mtu_probing = 1
# base_mss: 起始探测值
net.ipv4.tcp_base_mss = 1024

# =============================================================
# 连接队列 - 高丢包会有更多半开连接
# =============================================================
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_max_orphans = 32768
net.ipv4.tcp_max_tw_buckets = 65535

# =============================================================
# SYN 相关 - 高丢包握手优化
# =============================================================
net.ipv4.tcp_syncookies = 1
# TFO: 减少握手 RTT
net.ipv4.tcp_fastopen = 3
# SYN 重试：高丢包适当增加
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3

# =============================================================
# 连接复用与超时
# =============================================================
net.ipv4.tcp_tw_reuse = 1
# FIN 超时短一点，快速回收
net.ipv4.tcp_fin_timeout = 10

# Keepalive: 高丢包环境缩短间隔，快速检测死连接
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5

# =============================================================
# UDP 缓冲区 - QUIC/Hysteria 高丢包关键
# Hysteria 有 FEC，配合大缓冲效果更好
# =============================================================
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 8000
net.ipv4.udp_rmem_min = 262144
net.ipv4.udp_wmem_min = 262144
net.ipv4.udp_mem = 65536 262144 524288

# =============================================================
# 端口与路由
# =============================================================
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_forward = 1
net.ipv4.conf.all.route_localnet = 1

# 路由安全
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# ARP 缓存
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192

# =============================================================
# IPv6
# =============================================================
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# =============================================================
# Conntrack - 高丢包会有更多重传，适当放大
# =============================================================
net.netfilter.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_buckets = 65536
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 120

# TCP 松散模式：允许非严格序列的包通过（高丢包乱序常见）
net.netfilter.nf_conntrack_tcp_loose = 1
EOF
) > /etc/sysctl.conf
sysctl -p
#下载安装anytls
rm -rf server-anytls* README.md LICENSE
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
#创建证书目录
mkdir -p /root/.cert
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
#生成qf自签证书:
openssl ecparam -genkey -name prime256v1 -out /root/.cert/server.key
openssl req -new -x509 -days 36500 -key /root/.cert/server.key -out /root/.cert/server.crt \
-subj "/CN=*.shiyuandian.shop" \
-addext "subjectAltName=DNS:*.shiyuandian.shop,DNS:shiyuandian.shop"
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
#生成xiaoliyu自签证书:
openssl ecparam -genkey -name prime256v1 -out /root/.cert/server.key
openssl req -new -x509 -days 36500 -key /root/.cert/server.key -out /root/.cert/server.crt \
-subj "/CN=*.xiaoliyu.cyou" \
-addext "subjectAltName=DNS:*.xiaoliyu.cyou,DNS:xiaoliyu.cyou"
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
#生成chaoyue自签证书:
openssl ecparam -genkey -name prime256v1 -out /root/.cert/server.key
openssl req -new -x509 -days 36500 -key /root/.cert/server.key -out /root/.cert/server.crt \
-subj "/CN=*.chaoyuenode.sbs" \
-addext "subjectAltName=DNS:*.chaoyuenode.sbs,DNS:chaoyuenode.sbs"
else
    echo "无效的选择: $CHOICE"
    exit 1
fi
supervisorctl update
(crontab -l 2>/dev/null; echo "40 5 * * * supervisorctl restart anytlsserver") | crontab -
echo "清空当前nftables规则"
nft flush ruleset
echo "#配置nftables防火墙："
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
supervisorctl update && supervisorctl restart anytlsserver
#加入日志自动清理：
echo "find /var/log/supervisor/ -type f -mtime +7 -exec rm {} \;" >> cleanup_logs.sh
chmod +x /root/cleanup_logs.sh
(crontab -l ; echo "0 0 * * * /root/cleanup_logs.sh") | crontab -
rm -rf nicedepoly.sh