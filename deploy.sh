# Swarmpit:
sudo mkdir -p /mnt/docker/swarmpit/db-data
sudo mkdir -p /mnt/docker/swarmpit/db-log
sudo mkdir -p /mnt/docker/swarmpit/influx-data
sudo docker stack deploy -c swarmpit/docker-compose.yml   swarmpit   # Ports 888

# Manhours:
sudo mkdir -p /mnt/docker/manhours
sudo docker stack deploy -c manhours/docker-compose.yml   manhours   # Ports 48467

# Stateless:
sudo docker stack deploy -c tracer/docker-compose.yml     tracer     # Ports 48466
sudo docker stack deploy -c chess/docker-compose.yml      chess      # Ports 48468
sudo docker stack deploy -c stathub/docker-compose.yml    stathub    # Ports 48469
sudo docker stack deploy -c health/docker-compose.yml     health     # Ports 48470 48471
sudo docker stack deploy -c chat/docker-compose.yml       chat       # Ports 48472
sudo docker stack deploy -c homepage/docker-compose.yml   homepage   # Ports 48473
sudo docker stack deploy -c gameoflife/docker-compose.yml gameoflife # Ports 48474
sudo docker stack deploy -c howtocook/docker-compose.yml  howtocook  # Ports 48475
sudo docker stack deploy -c edgeneko-blog/docker-compose.yml  edgeneko-blog  # Ports 48476
sudo docker stack deploy -c cpprunner/docker-compose.yml  cpprunner  # Ports 48477
sudo docker stack deploy -c lab/docker-compose.yml        lab        # Ports 48478