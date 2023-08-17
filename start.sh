echo "Stopping docker cluster..."
docker-compose stop
docker-compose rm -f
sleep 1

echo "Cleaning staged configuration..."
rm -rf ./stage/configuration
sleep 1

echo "Staging configuration..."
cp -r ./declare/configuration ./stage/
sleep 1

echo "Setting permissions..."
sudo chmod -R 777 ./stage/datastore
sudo chmod -R 777 ./stage/logs
sleep 3

echo "Starting..."
docker-compose up