#!/bin/bash
echo "1. 升级hy1"
echo "2. 升级hy2"
echo "3. 部署hy2"
read CHOICE
ARCHITECTURE=$(uname -m)
rm -rf server-hysteria* README.md LICENSE
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
elif [[ "$CHOICE" == "4" ]]; then
echo "1. 配置qifan"
echo "2. 配置xiaoliyu"
echo "3. 配置chaoyue"
read SITES
echo "请输入节点ID："
read NODE_ID
rm -rf README.md LICENSE
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
command=/root/server-hysteria2 --api https://ty78y3nby40auwwdsjpid0uo84ottci3.assistai.cloud --token HxUhw93lMX8Dx6aG8NSveUCt75FOcr25 --node $NODE_ID
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
command=/root/server-hysteria2 --api https://uwrp9i1xbz82767xl3fmdk9w4enlhkro.assistai.cloud --token Bh1HcFlXc5JnDZRW3cF4KcYNo6ZBIWwh --node $NODE_ID
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
command=/root/server-hysteria2 --api https://g16lczfrycrbgiymq4z9jud2iq8rrbjb.assistai.cloud --token iG2SIaczVtkDRNTlOiIpvuVbkeKwbMRb --node $NODE_ID
autostart=true
autorestart=true
EOF
) > /etc/supervisor/conf.d/hy2server.conf
else
    echo "无效的选择: $SITES"
    exit 1
fi
supervisorctl update
rm -rf up_ss_hy.sh
iptables -t nat -A PREROUTING -p udp --dport 22000:35000 -j DNAT --to-destination :4433
ip6tables -t nat -A PREROUTING -p udp --dport 22000:35000 -j DNAT --to-destination :4433
iptables -N SSH_RATE_LIMIT
iptables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --set
iptables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --update --seconds 60 --hitcount 5 -j DROP
iptables -A OUTPUT -p tcp --dport 22 -j SSH_RATE_LIMIT
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
else
    echo "无效的选择: $CHOICE"
    exit 1
fi