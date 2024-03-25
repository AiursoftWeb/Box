known_secrets=$(sudo docker secret ls --format '{{.Name}}')

# Swarmpit:
sudo mkdir -p /swarm-vol/swarmpit-db-data
sudo mkdir -p /swarm-vol/swarmpit-influx-data
sudo docker stack deploy -c swarmpit/docker-compose.yml   swarmpit --detach  # Ports 888

# Tracer
sudo docker stack deploy -c tracer/docker-compose.yml     tracer --detach    # Ports 48466

# Manhours:
sudo mkdir -p /swarm-vol/manhours-data
sudo docker stack deploy -c manhours/docker-compose.yml   manhours --detach  # Ports 48467

# Chess:
sudo mkdir -p /swarm-vol/chess-data
sudo docker stack deploy -c chess/docker-compose.yml      chess --detach     # Ports 48468

# Stathub:
sudo mkdir -p /swarm-vol/stathub-data
sudo docker stack deploy -c stathub/docker-compose.yml    stathub --detach   # Ports 48469

# Health:
sudo mkdir -p /swarm-vol/prometheus-config
sudo mkdir -p /swarm-vol/prometheus-data
sudo mkdir -p /swarm-vol/grafana-config
sudo mkdir -p /swarm-vol/grafana-data
sudo mkdir -p /swarm-vol/sleepagent-data
sudo docker stack deploy -c health/docker-compose.yml     health --detach    # Ports 48470 48471

# Chat:
if [[ $known_secrets != *"openai-key"* ]]; then
  echo "Please enter openai-key secret"
  read openai_key
  echo $openai_key | sudo docker secret create openai-key -
fi
if [[ $known_secrets != *"openai-instance"* ]]; then
  echo "Please enter openai-instance secret"
  read openai_instance
  echo $openai_instance | sudo docker secret create openai-instance -
fi
if [[ $known_secrets != *"bing-search-key"* ]]; then
  echo "Please enter bing-search-key secret"
  read bing_search_key
  echo $bing_search_key | sudo docker secret create bing-search-key -
fi
sudo mkdir -p /swarm-vol/chat-data
sudo docker stack deploy -c chat/docker-compose.yml       chat --detach      # Ports 48472

# Stateless:
sudo docker stack deploy -c homepage/docker-compose.yml   homepage   # Ports 48473
sudo docker stack deploy -c gameoflife/docker-compose.yml gameoflife # Ports 48474
sudo docker stack deploy -c howtocook/docker-compose.yml  howtocook  # Ports 48475
sudo docker stack deploy -c edgeneko-blog/docker-compose.yml  edgeneko-blog --detach # Ports 48476

# Cpprunner:
sudo mkdir -p /swarm-vol/cpprunner-data
sudo docker stack deploy -c cpprunner/docker-compose.yml  cpprunner --detach # Ports 48477

# Lab
sudo docker stack deploy -c lab/docker-compose.yml        lab --detach       # Ports 48478

# Nuget
if [[ $known_secrets != *"nuget-publish-key"* ]]; then
  echo "Please enter nuget_key secret"
  read nuget_key
  echo $nuget_key | sudo docker secret create nuget-publish-key -
fi
sudo mkdir -p /swarm-vol/nuget-data
sudo docker stack deploy -c nuget/docker-compose.yml    nuget --detach   # Ports 48479

# Remotely
sudo mkdir -p /swarm-vol/remotely-data
sudo mkdir -p /swarm-vol/remotely-asp
sudo docker stack deploy -c remotely/docker-compose.yml  remotely --detach # Ports 48480

# Runner
if [[ $known_secrets != *"gitlab-runner-token"* ]]; then
  echo "Please enter gitlab-runner-token secret"
  read gitlab_runner_token
  echo $gitlab_runner_token | sudo docker secret create gitlab-runner-token -
fi
sudo docker stack deploy -c runner/docker-compose.yml    runner --detach