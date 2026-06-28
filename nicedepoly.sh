#!/bin/bash
# ===== GitHub 私有仓库下载配置 =====
# 部署前只需修改下面这一行 GH_TOKEN，换成你的 fine-grained 只读令牌：
#   GitHub → Settings → Developer settings → Fine-grained tokens
#   仅授权 catherndoukasrsm/node 仓库，权限 Contents: Read-only，建议设置过期时间。
# 也可以运行前用环境变量覆盖：export GH_TOKEN=xxxxx
GH_TOKEN="${GH_TOKEN:-PUT_YOUR_FINE_GRAINED_TOKEN_HERE}"
GH_OWNER_REPO="catherndoukasrsm/node"
GH_REF="main"
# 从私有仓库下载文件到当前目录（GitHub Contents API，兼容 fine-grained 令牌）
gh_download() {
  curl -fSL \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "Accept: application/vnd.github.raw" \
    -o "$(basename "$1")" \
    "https://api.github.com/repos/${GH_OWNER_REPO}/contents/$1?ref=${GH_REF}"
}
# ===================================

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
# 代理转发节点优化 - 4C4G / 现代 Linux 内核 / 精简稳妥版
# 适用：Xray / sing-box / Trojan / realm / gost / Nginx stream
#
# 目标：
# - 保留内核自动调节，只提高代理转发需要的关键上限
# - 避免过大的 default 缓冲、tcp_mem、ECN、RACK/TLP 等重复或易负优化参数
# - 适合常见 1Gbps 以内、RTT 50-250ms、多连接代理转发场景
# =============================================================

# 文件句柄：服务本身仍需配合 systemd LimitNOFILE / ulimit
fs.file-max = 1048576

# =============================================================
# TCP 拥塞控制
# =============================================================
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0

# =============================================================
# Socket 缓冲
# 4G 内存不建议把 default 设大；让 Linux autotuning 按连接实际需要增长
# max 64MB 足够覆盖大多数跨境高 RTT 代理链路，且不会像 128/512MB 那样浪费内存
# =============================================================
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 系统级 TCP 内存池 (pages of 4KB) -- 与单 socket 16MB 上限匹配, 5.8G 内存留出 2G 头部
# min=768M (no pressure), pressure=1G, max=2G
net.ipv4.tcp_mem = 196608 262144 524288

# UDP/QUIC 基础缓冲下限，给 Hysteria/TUIC/sing-box QUIC 留一点余量
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# =============================================================
# 连接队列
# 4C 节点适中放大即可，过大只会掩盖应用层处理瓶颈
# =============================================================
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 32768
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_max_orphans = 65536

# =============================================================
# 连接回收与保活
# =============================================================
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# =============================================================
# 握手与基础 TCP 特性
# 这些参数在现代内核中稳定且低风险
# =============================================================
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1

# =============================================================
# 本地端口与转发
# =============================================================
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1

# 路由安全：代理转发/策略路由场景通常关闭 rp_filter，避免非对称路由被丢弃
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# =============================================================
# IPv6 转发
# 如果机器不用 IPv6，可以删除本段；不建议默认 disable_ipv6
# =============================================================
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# =============================================================
# Conntrack
# 仅在经过 iptables/nftables NAT、防火墙或透明代理时开启。
# 普通入站代理进程不一定需要，默认注释可避免无 netfilter 模块时报错。
# =============================================================
# net.netfilter.nf_conntrack_max = 262144
# net.netfilter.nf_conntrack_tcp_timeout_established = 3600
# net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
# net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
# net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
# net.netfilter.nf_conntrack_udp_timeout = 30
# net.netfilter.nf_conntrack_udp_timeout_stream = 120

# TPROXY / 本机回环转发需要时再开启，普通代理转发不建议默认打开
# net.ipv4.conf.all.route_localnet = 1
EOF
) > /etc/sysctl.conf
sysctl -p
#下载安装anytls
rm -rf server-anytls* README.md LICENSE
ARCHITECTURE=$(uname -m)
if [[ "$ARCHITECTURE" == "x86_64" ]]; then
gh_download server-anytls-linux-64.zip
unzip server-anytls-linux-64.zip
elif [[ "$ARCHITECTURE" == "aarch64" ]]; then
gh_download server-anytls-linux-arm64-v8a.zip
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