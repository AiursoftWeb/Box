echo "Stopping docker cluster..."
docker-compose stop
docker-compose rm -f
sleep 1

echo "Cleaning staged configuration..."
sudo rm -rf ./stage/configuration
sleep 1

echo "Staging configuration..."
mkdir -p ./stage
mkdir -p ./stage/configuration
mkdir -p ./stage/datastore
mkdir -p ./stage/logs
cp -r ./declare/configuration ./stage/
sleep 1

echo "Setting permissions..."
sudo chmod -R 777 ./stage
sleep 3

echo "Starting..."
docker-compose up