#!/bin/bash
echo "Building Moongladepure..."
curl https://gitlab.aiursoft.cn/aiursoft/moongladepure/-/raw/master/assets/tenants --output /tmp/tenants.txt
rm ./Sites/Blogging/Moonglade.conf
touch ./Sites/Blogging/Moonglade.conf
while read -r tenant port
do
        echo "Building tenant $tenant..."
        echo "His port is $port..."

        tenantToLower=$(echo "$tenant" | tr '[:upper:]' '[:lower:]')
        echo "

$tenantToLower.aiursoft.cn {
        log
        import hsts
        encode br gzip
        reverse_proxy http://moongladeweb01:$port http://moongladeweb02:$port http://moongladeweb03:$port {
                lb_policy cookie lb
                health_port     $port
                health_interval 10s
                health_timeout  10s
                health_status   200
                health_uri /
        }
}" | tee -a ./Sites/Blogging/Moonglade.conf
done < /tmp/tenants.txt

echo "Cleaning up..."
rm ./Dist -rf
mkdir Dist

echo "Building Caddyfile..."
find ./Sites -type f -name "*.conf" | while read -r file; do cat "$file"; echo -e "\n\n"; done | tee ./Dist/Sites.temp
#find ./Sites -type f -name "*.conf" | xargs -L 1 cat | tee ./Dist/Sites.temp
cat ./baseline ./Dist/Sites.temp | tee ./Dist/Caddyfile

echo "Caddyfile built."