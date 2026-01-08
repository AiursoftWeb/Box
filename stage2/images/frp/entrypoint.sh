token=$(echo $FRP_TOKEN)
serverip=$(echo $FRP_SERVER)

# If token is empty, exit
if [ -z "$token" ]; then
    echo "No token provided."
    exit 1
fi

if [ -z "$serverip" ]; then
    echo "No server ip provided."
    exit 1
fi

echo "Server IP: $serverip"

echo "Touching frpc.toml"
touch /etc/frp/frpc.toml

echo "Editing frpc.toml"
sed -i "s/FRP_TOKEN/$token/g" /etc/frp/frpc.toml
sed -i "s/FRP_SERVER_IP/$serverip/g" /etc/frp/frpc.toml

echo "Starting frpc"
/usr/bin/frpc -c /etc/frp/frpc.toml