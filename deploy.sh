sudo docker stack deploy -c swarmpit/docker-compose.yml swarmpit # Ports 888
sudo docker stack deploy -c tracer/docker-compose.yml tracer # Ports 48466
sudo docker stack deploy -c manhours/docker-compose.yml manhours # Ports 48467
sudo docker stack deploy -c chess/docker-compose.yml chess # Ports 48468
sudo docker stack deploy -c stathub/docker-compose.yml stathub # Ports 48469
sudo docker stack deploy -c health/docker-compose.yml health # Ports 48470 48471