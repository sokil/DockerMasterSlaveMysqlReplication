#!/bin/bash

# See: https://www.percona.com/blog/2016/03/30/docker-mysql-replication-101/

function wait_mysql {
    container_name=$1;
    docker exec -it $container_name mysql -Nsqe "use replicated_db;" >/dev/null 2>/dev/null;
    if [ $? -ne 0 ]
    then
        echo -n .
        sleep 1
        wait_mysql $container_name
    fi
}

## Run containers
docker-compose up -d

## Wait for master
echo -n Waiting for container rpl_mysql_master
wait_mysql "rpl_mysql_master";
echo ''

## Wait for slave
echo -n Waiting for container rpl_mysql_slave
wait_mysql "rpl_mysql_slave";
echo ''

## Run on MASTER

# allow access of slave user
echo 'Add permissions for slave on master'
docker exec -it rpl_mysql_master \
    mysql -Nsqe "GRANT REPLICATION SLAVE ON *.* TO 'slave'@'%' IDENTIFIED BY 'slave'; FLUSH PRIVILEGES;"

# Lock table
echo 'Lock tables on master'
docker exec -it rpl_mysql_master \
    mysql -Nsqe "USE replicated_db; FLUSH TABLES WITH READ LOCK;"

# Get file and position
echo 'Get file and position of replication'
MASTER_LOG_FILE=$(docker exec -it rpl_mysql_master mysql -Nsqe "SHOW MASTER STATUS" | awk -F' ' '{print $1}')
MASTER_LOG_POS=$(docker exec -it rpl_mysql_master mysql -Nsqe "SHOW MASTER STATUS" | awk -F' ' '{print $2}')

# Dump current master
echo 'Dump current master database'
docker exec -it rpl_mysql_master \
    bash -c 'mysqldump -u root replicated_db > /var/mysql/common/replicated_db.sql'

# Unlock
echo 'Unlock master tables'
docker exec -it rpl_mysql_master \
    mysql -Nsqe "USE replicated_db; UNLOCK TABLES;"

## Run on SLAVE
echo "Load dump to slave"
docker exec -it rpl_mysql_slave \
    bash -c 'mysql replicated_db < /var/mysql/common/replicated_db.sql'

echo "Configure connection to master"
docker exec -it rpl_mysql_slave \
    mysql -Nsqe "CHANGE MASTER TO MASTER_HOST='mysql_master', MASTER_USER='slave', MASTER_PASSWORD='slave', MASTER_LOG_FILE = '$MASTER_LOG_FILE', MASTER_LOG_POS = $MASTER_LOG_POS; START SLAVE;"

## Show slave status
echo "Slave status"
docker exec -it rpl_mysql_slave \
    mysql -sqe "SHOW SLAVE STATUS\G"

