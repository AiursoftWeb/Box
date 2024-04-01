#!/bin/bash
echo "Building Caddyfile..."
mkdir -p ./Dist
find ./Sites -type f -name "*.conf" | while read -r file; do cat "$file"; echo -e "\n\n"; done | tee ./Dist/Sites.temp
cat ./baseline ./Dist/Sites.temp | tee ./Dist/Caddyfile
echo "Caddyfile built."