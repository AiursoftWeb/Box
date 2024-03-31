#!/bin/bash
echo "Building Moongladepure..."

echo "JimMoen 48466
Rest 48467
Anduin 48468
Cody 48469
Gxhao 48470
Anois 48471
Dvorak 48472
Kitlau 48473
Xinboo 48474
Gbiner 48475
Rdf 48476
Lyx 48477
Shubuzuo 48478
Lily 48479
Carson 48480
ZoneBlog 48481" > /tmp/tenants.txt

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