# Redis高可用集群

我使用docker安装Redis

```shell
# 下载容器
docker pull redis

# 运行容器
docker run -d --privileged=true -p 6379:6379 --name redis6379 -v /e/dockerVo/redis/6379/redis.conf:/etc/redis/redis.conf -v /e/dockerVo/redis/6379/data:/data redis redis-server /etc/redis/redis.conf --appendonly yes
# --privileged=true 文件可写
# -v /e/dockerVo/redis/6379/redis.conf:/etc/redis/redis.conf 绑定配置文件
# -v /e/dockerVo/redis/6379/data:/data 持久化数据
# --appendonly yes 开启持久化数据
```

## 一、Redis集群演变过程

### 1、单机版

核心技术：持久化

持久化是最简单的高可用方法，保证数据不会因进程退出而丢失

### 2、主从复制

* 主机(Master)：用于写数据
* 从机(Slave)：用于读数据

通过持久化功能，Redis保证了即使在服务器重启的情况下也不会损失数据，因为持久化会把内存中数据保存到硬盘上，重启会从硬盘上加载数据。

但是由于数据是存储在一台服务器上的，如果这台服务器出现硬盘故障等问题，也会导致数据丢失。为了避免单点故障，其他服务依然可以继续提供服务。为此，**Redis提供了复制(replication)功能，可以实现当一台数据库中的数据更新后，自动将更新的数据同步到其他数据库上**。

在复制概念中，数据库分为两类，一类是主数据库(master)，另一类是从数据库(slave)。主数据库可以进行读写操作，当写操作导致数据变化时会将数据同步给从数据库。而从数据库一般是只读的，并接受主数据库同步过来的数据。**一个主数据库可以拥有多个从数据库，而一个从数据库只能拥有一个主数据库**。

#### 主从数据库的配置

主数据库存不用配置，从redis的conf文件中可以加载从数据库的信息，也可以在启动时，使用redis-server --port 6380 --saveof 127.0.0.1 6379

从数据库一般是只读，可以改为可写，但写入的数据很容易被主同步没，所以还是只读就可以。 也可以在运行时使用slaveof ip port命令，停止原来的主，切换成刚刚设置的主  slaveof no one会把自己变成主

#### 复制原理

当**从数据库启动时，会向主数据库发送sync命令，主数据库收到sync后开始在后台保存快照rdb**，在保存快照期间收到的命令缓存起来，当快照完成时，主数据库会将快照和缓存的命令一块发送给从\*\*。复制初始化结束。

之后，**Master**每收到1个命令就同步发送给**Slave**

主从复制是乐观复制，当客户端发送写执行给主，主执行完立即将结果返回客户端，并异步的把命令发送给从，从而不影响性能。也可以设置至少同步给多个从主才可写。

无硬盘复制:如果硬盘效率低将会影响复制性能，2.8之后可以设置无硬盘复制，repl-diskless-sync yes

### 3、哨兵模式

**在复制的基础上，哨兵实现了自动化的故障恢复。**当主数据库遇到异常中断服务后，开发者可以通过手动的方式选择一个从数据库来升格为主数据库，以使得系统能够继续提供服务。然而整个过程相对麻烦，并需要人工介入，难以实现自动化。Redis2.8后提供了哨兵工具。**哨兵的作用就是监控Redis主、从数据库是否正常运行，主出现故障自动将从数据库转换为主数据库**。

> 注：配置哨兵监控一个系统时，只需配置监控主数据库即可，哨兵会自动发现所有复制该主数据库的从数据库

### 4、高可用集群（cluster-enable）

使用集群，只需要将每个数据库节点cluster-enable配置打开即可。每个集群中至少需要三个主数据库才能正常运行。

即使使用哨兵，redis每个实例也是倒是存储，每个redis存储的内容都是完整的数据，浪费内存且有木桶效应。为了最大利用内存，可以采用集群，就是分布式存储。即每台Redis存储不同的内容。集群至少需要3主3从，且每个实例使用不同的配置文件，主从不用配置，集群会筷选。

![Redis-Cluster](/img/2dd7642c44ea16545905a50d18e2d51.png)

Redis集群中`redis-server`节点共有16384个槽位，每新增一个redis-server节点(哨兵集群)，就会平分其中的槽位。

redis在设置存储数据的时候`set hello world`会对键(key)进行哈希算法，再对16384进行取模，后分配到不同的`redis-server`节点上(哨兵集群主节点)。算法如下：

```shell
crc16(hello) % 16384 = 866
# 就会分配到 866所在槽位区间的 redis-server哨兵集群中
```

# 二、搭建集群

## 1、原生搭建

### 2）开启多台redis集群服务

先批量创建 6 台 redis 的容器

```shell
# 使用docker的redis容器还要配置‘集群总线端口’
# 集群总线端口的偏移是固定的：客户端口 + 10000

docker run -d --privileged=true -p 7000:7000 -p 17000:17000 --name redis_7000 -v /e/dockerVo/redis/7000/redis.conf:/etc/redis/redis.conf -v /e/dockerVo/redis/7000/data:/data redis redis-server /etc/redis/redis.conf --appendonly yes
...
docker run -d --privileged=true -p 7005:7005 -p 17005:17005 --name redis_7005 -v /e/dockerVo/redis/7005/redis.conf:/etc/redis/redis.conf -v /e/dockerVo/redis/7005/data:/data redis redis-server /etc/redis/redis.conf --appendonly yes
```

* 此时，redis无法插入数据

### 3）meet操作

* 让集群可以互相通信

`cluster meet ip port`

```
# 随便连接一个redis
docker exec -it redis_7000 redis-cli
```

### 4）指派槽位

```
cluster addslost slot
```

### 5）分配主从

```
cluster replicate node-id
```

## 2、使用Redis提供的rb脚本

```sh
# 进入其中一个容器之中
docker exec -it redis_7000 /bin/bash

# 一条命令完成原生搭建的 2、3、4步。meet、指派槽位、分配主从操作
# 192.168.25.216 为宿主机的IP
redis-cli --cluster create 192.168.25.216:7000 192.168.25.216:7001 192.168.25.216:7002 192.168.25.216:7003 192.168.25.216:7004 192.168.25.216:7005 --cluster-replicas 1

```

