token=$(cat /run/secrets/frp-token)

# If token is empty, exit
if [ -z "$token" ]; then
    echo "No token provided."
    exit 1
fi

echo "Touching frpc.toml"
touch /etc/frp/frpc.toml

echo "Editing frpc.toml"
sed -i "s/FRP_TOKEN/$token/g" /etc/frp/frpc.toml

echo "Starting frpc"
/usr/bin/frpc -c /etc/frp/frpc.toml