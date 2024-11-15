#!/bin/bash
echo "1. 升级hy1"
echo "2. 升级hy2"
echo "3. 部署hy2"
read CHOICE
ARCHITECTURE=$(uname -m)
#升级hy1
if [[ "$CHOICE" == "1" ]]; then
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
elif [[ "$CHOICE" == "2" ]]; then
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
#部署hy2
elif [[ "$CHOICE" == "3" ]]; then
echo "1. 配置qifan"
echo "2. 配置xiaoliyu"
echo "3. 配置chaoyue"
read SITES
echo "请输入节点ID："
read NODE_ID
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
#根据选择配置站点：
#配置qf
if [[ "$SITES" == "1" ]]; then
    echo "配置qf..."
(cat <<EOF
[program:hy2server]
directory=/root
command=/root/server-hysteria2 --api https://ty78y3nby40auwwdsjpid0uo84ottci3.assistai.cloud --token HxUhw93lMX8Dx6aG8NSveUCt75FOcr25 --node $NODE_ID --log_mode info
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hy2server.conf
#配置xly
elif [[ "$SITES" == "2" ]]; then
    echo "配置xly..."
(cat <<EOF
[program:hy2server]
directory=/root
command=/root/server-hysteria2 --api https://uwrp9i1xbz82767xl3fmdk9w4enlhkro.assistai.cloud --token Bh1HcFlXc5JnDZRW3cF4KcYNo6ZBIWwh --node $NODE_ID --log_mode info
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hy2server.conf
#配置chaoyue
elif [[ "$SITES" == "3" ]]; then
    echo "配置chaoyue..."
(cat <<EOF
[program:hy2server]
directory=/root
command=/root/server-hysteria2 --api https://g16lczfrycrbgiymq4z9jud2iq8rrbjb.assistai.cloud --token iG2SIaczVtkDRNTlOiIpvuVbkeKwbMRb --node $NODE_ID --log_mode info
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hy2server.conf
else
    echo "无效的选择: $SITES"
    exit 1
fi
supervisorctl update
(crontab -l 2>/dev/null; echo "20 5 * * * supervisorctl restart hyserver") | crontab -
(crontab -l 2>/dev/null; echo "30 5 * * * supervisorctl restart hy2server") | crontab -
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
else
    echo "无效的选择: $CHOICE"
    exit 1
fi
rm -rf niceupdate.sh