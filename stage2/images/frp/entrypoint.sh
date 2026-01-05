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

# Function to start frpc and check if it stays running
start_frpc_with_timeout() {
    local attempt=$1
    echo "Starting frpc (attempt $attempt)..."
    
    # Start frpc in background
    /usr/bin/frpc -c /etc/frp/frpc.toml &
    local frpc_pid=$!
    
    # Wait 30 seconds and check if process is still running
    sleep 30
    
    if kill -0 $frpc_pid 2>/dev/null; then
        # Process is still running, success!
        echo "frpc started successfully"
        wait $frpc_pid
        return $?
    else
        # Process exited within 30 seconds, failure
        echo "frpc exited within 30 seconds"
        return 1
    fi
}

# Function to comment out QUIC line
disable_quic() {
    echo "Disabling QUIC protocol in config..."
    sed -i 's/^transport.protocol = "quic"/#transport.protocol = "quic"/' /etc/frp/frpc.toml
}

echo "Starting frpc with automatic QUIC fallback..."

# Attempt 1: Try with QUIC
if ! start_frpc_with_timeout 1; then
    echo "First attempt failed, QUIC may be blocked by cloud provider"
    
    # Disable QUIC and retry
    disable_quic
    
    # Attempt 2: Try without QUIC
    if ! start_frpc_with_timeout 2; then
        echo "Second attempt failed, giving up"
        exit 1
    fi
fi