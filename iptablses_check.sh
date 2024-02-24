# 检查iptables规则中是否包括PREROUTING和SSH_RATE_LIMIT规则
function check_rules() {
    # 获取iptables规则
    iptables_rules=$(iptables -L | grep "PREROUTING")
    ip6tables_rules=$(ip6tables -L | grep "PREROUTING")
    ssh_rules=$(iptables -L -n | grep "SSH_RATE_LIMIT")

    # 检查PREROUTING规则是否存在
    if [[ -z "$(echo "$iptables_rules" | grep "PREROUTING")" ]]; then
        # 添加PREROUTING规则
        iptables -t nat -A PREROUTING -p udp --dport 6000:21000 -j DNAT --to-destination :18301
        ip6tables -t nat -A PREROUTING -p udp --dport 6000:21000 -j DNAT --to-destination :18301
        iptables -t nat -A PREROUTING -p udp --dport 22000:35000 -j DNAT --to-destination :4433
        ip6tables -t nat -A PREROUTING -p udp --dport 22000:35000 -j DNAT --to-destination :4433
    fi

    # 检查SSH_RATE_LIMIT规则是否存在
    if [[ -z "$ssh_rules" ]]; then
        # 添加SSH_RATE_LIMIT规则
        iptables -N SSH_RATE_LIMIT
        iptables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --set
        iptables -A SSH_RATE_LIMIT -m state --state NEW -m recent --name sshattack --update --seconds 60 --hitcount 5 -j DROP
        iptables -A OUTPUT -p tcp --dport 22 -j SSH_RATE_LIMIT
    fi

    return 0
}

# 添加规则
function add_rules() {
}

# 检查规则
if check_rules; then
    echo "规则已添加"
else
    echo "规则已存在，无需添加"
fi