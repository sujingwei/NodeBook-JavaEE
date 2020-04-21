# 一、单机安装

## 1、下载安装

下载地址：http://zookeeper.apache.org/

- 安装jdk
- 上传zoopeeker并解压到 /opt 目录
- 解压zookeeper，并创建 data（可以是别的名字或目录）目录
- 进入conf目录，把zoo_sample.cfg复制为zoo.cfg
- 修改zoo.cfg文件，修改dataDir属性的值，指定data目录

## 2、启动、停止Zookeeper

/bin/zkServer.sh start 启动

/bin/zkServer.sh stop 停止

/bin/zkServer.sh status 查看服务状

# 二、集群步骤

## 1、环境

centos 7.x：IP地址分别为:192.168.25.97, 192.168.25.89, 192.168.25.66

Apache ZooKeeper 3.6.0

## 2、配置文件设置

```shell
[root@localhost ~]# cat /export/server/zookeeper/conf/zoo.cfg
# The number of milliseconds of each tick
tickTime=2000
# The number of ticks that the initial 
# synchronization phase can take
initLimit=10
# The number of ticks that can pass between 
# sending a request and getting an acknowledgement
syncLimit=5
# the directory where the snapshot is stored.
# do not use /tmp for storage, /tmp here is just 
# example sakes.
dataDir=/zk/data/zkdata
# the port at which the clients will connect
clientPort=2181
# the maximum number of client connections.
# increase this if you need to handle more clients
#maxClientCnxns=60
#
# Be sure to read the maintenance section of the 
# administrator guide before turning on autopurge.
#
# http://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_maintenance
#
# The number of snapshots to retain in dataDir
#autopurge.snapRetainCount=3
# Purge task interval in hours
# Set to "0" to disable auto purge feature
#autopurge.purgeInterval=1

## Metrics Providers
#
# https://prometheus.io Metrics Exporter
#metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider
#metricsProvider.httpPort=7000
#metricsProvider.exportJvmInfo=true

# --- 添加集群配置 -------------------------
# todo server.1 中的“1”是myid
# 2888是心跳端口，3888是选举端口
server.1=192.168.25.97:2888:3888
server.2=192.168.25.89:2888:3888
server.3=192.168.25.66:2888:3888
```

## 3、设置myid

上一步配置文件里指定了`/zk/data/zkdata`数据存储目录，在这个目录中新建名为`myid`的文件，并输入以下内容：

节点，192.168.25.97 的myid：

```
1
```

节点，192.168.25.89 的myid：

```
2
```

节点，192.168.25.66 的myid：

```
3
```

**注意**：每个zookeeper节点下的myid都是不一样的，必须保证唯一，并对应配置文件中`server.1=192.168.25.97:2888:3888`的配置

## 4、启动

配置完成后分别启动

```sh
bin/zkServer.sh start
```

## 5、查看状态 

192.168.25.89

```
[root@localhost ~]# /export/server/zookeeper/bin/zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /export/server/zookeeper/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost.
Mode: leader  # 领导者
```

192.168.25.97

```
[root@localhost zkdata]# /export/server/zookeeper/bin/zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /export/server/zookeeper/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost.
Mode: follower  # 跟随者
```

