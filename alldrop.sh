# sudo docker stack deploy -c swarmpit/docker-compose.yml swarmpit # Ports 888
# sudo docker stack deploy -c tracer/docker-compose.yml tracer # Ports 48466
# sudo docker stack deploy -c manhours/docker-compose.yml manhours # Ports 48467
sudo docker stack rm swarmpit
sudo docker stack rm tracer
sudo docker stack rm manhours
sudo docker kill $(sudo docker ps -q)
sudo docker volume prune -f
sudo docker volume rm $(sudo docker volume ls -q)
sudo systemctl stop docker-store
sudo rm /var/lib/docker-volumes/netshare/nfs -rf
sudo find /var/lib/docker/volumes/ -type d -exec rm -rf {} \;
sudo systemctl start docker-store

ssh anduin@sworker1 'sudo docker kill $(sudo docker ps -q)'
ssh anduin@sworker1 'sudo docker volume prune -f'
ssh anduin@sworker1 'sudo docker volume rm $(sudo docker volume ls -q)'
ssh anduin@sworker1 'sudo systemctl stop docker-store'
ssh anduin@sworker1 'sudo rm /var/lib/docker-volumes/netshare/nfs -rf'
ssh anduin@sworker1 'sudo systemctl start docker-store'

ssh anduin@sworker2 'sudo docker kill $(sudo docker ps -q)'
ssh anduin@sworker2 'sudo docker volume prune -f'
ssh anduin@sworker2 'sudo docker volume rm $(sudo docker volume ls -q)'
ssh anduin@sworker2 'sudo systemctl stop docker-store'
ssh anduin@sworker2 'sudo rm /var/lib/docker-volumes/netshare/nfs -rf'
ssh anduin@sworker2 'sudo systemctl start docker-store'