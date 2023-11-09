#!/bin/bash
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
