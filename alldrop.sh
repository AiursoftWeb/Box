sudo docker stack rm $(sudo docker stack ls -q)
sleep 10
sudo docker kill $(sudo docker ps -q)
sleep 10
sudo docker rm $(sudo docker ps -q)
sleep 10
sudo docker volume rm $(sudo docker volume ls -q)
sleep 10
sudo docker image rm $(sudo docker image ls -q)
sleep 10
sudo docker volume prune -f
