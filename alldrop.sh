# sudo docker stack deploy -c swarmpit/docker-compose.yml swarmpit # Ports 888
# sudo docker stack deploy -c tracer/docker-compose.yml tracer # Ports 48466
# sudo docker stack deploy -c manhours/docker-compose.yml manhours # Ports 48467
sudo docker stack rm swarmpit
sudo docker stack rm tracer
sudo docker stack rm manhours
sudo docker kill $(sudo docker ps -q)
sudo docker rm $(sudo docker ps -q)
sudo docker volume prune -f
sudo docker volume rm $(sudo docker volume ls -q)

ssh anduin@sworker1 'sudo docker kill $(sudo docker ps -q)'
ssh anduin@sworker1 'sudo docker rm $(sudo docker ps -q)'
ssh anduin@sworker1 'sudo docker volume prune -f'
ssh anduin@sworker1 'sudo docker volume rm $(sudo docker volume ls -q)'

ssh anduin@sworker2 'sudo docker kill $(sudo docker ps -q)'
ssh anduin@sworker2 'sudo docker rm $(sudo docker ps -q)'
ssh anduin@sworker2 'sudo docker volume prune -f'
ssh anduin@sworker2 'sudo docker volume rm $(sudo docker volume ls -q)'
