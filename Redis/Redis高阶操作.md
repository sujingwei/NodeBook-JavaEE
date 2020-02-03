# Redis 高阶操作

## 一、持久化

​	Redis支持两种方式的持久化，一种是**RDB**方式，另一种是**AOF**方式。前者会根据指定的规则“定时”将内存中的数据存在数据存储的硬盘上，而后者在每次执行命令后，将命令本身记录下来。两种持久化方式可以单独使用其中一种，但更多情况下是将二者结合使用

### 1、RDB方式

RDB方式的持久化是通过快照完成的。当符合一定条件时Redis会自动将内存中的所有数据生成一份副本存储在硬盘上，这个过程就是“快照”。Redistribution会在以下几种情况对数据进行快照：

* 根据配置规则自动快照
* 用户执行 save 或 bgsave命令
* 执行flushall命令
* 执行复制

#### （1）根据配置规则进行自动快照

```
save 900 1      # 900 秒内发生一次更新
save 300 10     # 300 秒内发生10次更新
save 60 10000   # 60 秒内发生10000次更新
```

满足以上条件的其中之一都会进行快照

#### （2）用户执行save或bgsave命令

redis提供这两个命令来手动执行快照。

##### 1）save

在快照执行的过程中会阻塞所有来自客户端的请求。当数据库中数据比较多时，这一过程会导致Redis较长时间不响应，尽量避免使用。

##### 2）bgsave

bgsave命令可以后台异步地进行快照操作，快照的同时服务器还可以继续响应来自客户端的请求。执行`bgsave`后Redis立即返回OK表示 开始执行快照操作，如果想要知道快照是否完成，可以通过`lastsave`命令获取

```shell
redis > lastsave
(integer) 1423537869
```

#### （3）FLUSHALL命令

flushall命令会清除数据库中的所有数据。不论清空数据库的过程是否触发快照条件，只要自动快照条件不为空，Redis就会执行一次快照操作。

#### （4）执行复制操作时

当设置了主从模式时，Redis会在复制初始化时进行自动快照。

#### （5）快照原理

理清Redis实现快照的过程对我们了解快昭文件的特性有很大的帮助。Redis默认会将快照文件存储在Redis当前进程的工作目录中的dump.rdb文件中，可以通过配置dir和dbfilename两个参数分别指定快照文件存储的路径和文件名。快照的过程如下：

##### 1）Redis使用fork函数复制一份当前进程的副本（子进程）；

##### 2）父进程继续接收并处理客户端发来的命令，而子进程开始将内存中的数据写入硬盘的临时文件；

##### 3）当子进程写入所有数据后会用该临时文件替换旧的RDB文件，至此一次快照操作完成。

### 2、AOF方式

AOF可以将Redis执行的每一条写命令追加到硬盘文件中，这一过程显然会降低Redis的性能，但部分情况下这个影响是可以接受的，另外可以使用较快的硬盘可以提高AOF的性能。

#### （1）开启AOF

通过配置appendonly 参数启动

```shell
appendonly yes
```

AOF文件保存位置和RDB文件的位置相同，都是通过dir参数设置的，默认的文件名是appendonly.aof，可以通过appendfilename参数修改。

```shell
appendfilename appendonly.aof
```

## 二、主从复制

在复制的概念中，数据库分为两类，一类是主数据库(Master)，另一类是从数据库(Slave)。主数据库可以进行读写操作，当写操作导致数据变化时会自动将数据同步给从数据库存。而从数据库一般是只读的，并接受主数据库同步过来的数据。一个数据库可以多个从数据库，而一个从数据库只能拥有一个主数据库。

Redis使用复制功能非常容易，<span style='background:blue;color:white;'>只需要在从数据库的配置文件中加入<b>slaveof 主数据库IP 主数据库存端口</b>即可，主数据库无需任何配置</span>。或者，在从数据库中使用 `slaveof 主数据库IP 主数据端口` 命令。

## 三、哨兵模式

哨兵的作用就是监控Redis系统的运行状况。

* 监控主数据库和从数据库是否正常运行
* 主数据库出现故障时自动将从数据库转换为主数据库

### 1、步骤

#### 第一步：步骤三台redis服务器，分别是6379、6380及6381，如下：

```
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:2
slave0:ip=127.0.0.1,port=6380,state=online,offset=75077,lag=0
slave1:ip=127.0.0.1,port=6381,state=online,offset=74944,lag=1

127.0.0.1:6380> info replication
# Replication
role:slave
master_host:127.0.0.1
master_port:6379

127.0.0.1:6381> info replication
# Replication
role:slave
master_host:127.0.0.1
master_port:6378
```

#### 第二步：开启哨兵进程

```shell
./redis-sentinel sentinel.conf

# sentinel.conf 文件内容如下：
# 格式： sentinel monitor master-name ip port quorum
sentinel monitor mymaster 127.0.0.1 6379 1
```

开启成功后显示如下信息：

```shell
                _._                                                  
           _.-``__ ''-._                                             
      _.-``    `.  `_.  ''-._           Redis 5.0.7 (00000000/0) 64 bit
  .-`` .-```.  ```\/    _.,_ ''-._                                   
 (    '      ,       .-`  | `,    )     Running in sentinel mode
 |`-._`-...-` __...-.``-._|'` _.-'|     Port: 26379
 |    `-._   `._    /     _.-'    |     PID: 14338
  `-._    `-._  `-./  _.-'    _.-'                                   
 |`-._`-._    `-.__.-'    _.-'_.-'|                                  
 |    `-._`-._        _.-'_.-'    |           http://redis.io        
  `-._    `-._`-.__.-'_.-'    _.-'                                   
 |`-._`-._    `-.__.-'    _.-'_.-'|                                  
 |    `-._`-._        _.-'_.-'    |                                  
  `-._    `-._`-.__.-'_.-'    _.-'                                   
      `-._    `-.__.-'    _.-'                                       
          `-._        _.-'                                           
              `-.__.-'                                               

14338:X 24 Jan 2020 10:58:22.943 # WARNING: The TCP backlog setting of 511 cannot be enforced because /proc/sys/net/core/somaxconn is set to the lower value of 128.
14338:X 24 Jan 2020 10:58:22.945 # Sentinel ID is a1b81ac2d24402a46a1b13586089498311a9a95
14338:X 24 Jan 2020 10:58:22.945 # +monitor master mymaster 127.0.0.1 6379 quorum 1
14338:X 24 Jan 2020 10:58:22.972 * +slave slave 127.0.0.1:6380 127.0.0.1 6380 @ mymaster 127.0.0.1 6379
14338:X 24 Jan 2020 10:58:22.974 * +slave slave 127.0.0.1:6381 127.0.0.1 6381 @ mymaster 127.0.0.1 6379
```

#### 测试哨兵模式是否正常运行

```shell
kill -9 14236   # 杀死master服务的进程
```

此时（等30秒后），6381会变为主库

```shell
127.0.0.1:6381> info replication
# Replication
role:master
connected_slaves:1
slave0:ip=127.0.0.1,port=6380,state=online,offset=75077,lag=0

127.0.0.1:6380> info replication
# Replication
role:slave
master_host:127.0.0.1
master_port:6381
```

再次开启 6379 服务，此时它将变为从库。

### 2、哨兵的部署

哨兵本身就可能会发生单点故障。相对稳妥的部署方案是使得哨兵的视角尽可能地与每个节点的视角一致：

* 为每个节点（无论是主数据库或从数据库）部署一个哨兵
* 使每个哨兵与其对应的节点的网络环境相同或相近

* 设置quorm的值为 N/2 + 1，这样使得只有当大部分哨兵节点同意后才会进行故障恢复

## 四、集群

### 1、部署

分别配置6380、6381、6382、6383、6384、6385六台服务器，配置文件如下：

```shell
bind 127.0.0.1
port 6380
pidfile /var/run/redis_6380.pid
dir /home/sjw/works/redis/cluster/6380
cluster-enabled yes
cluster-config-file nodes-6380.conf
cluster-node-timeout 15000
cluster-replica-validity-factor 10
cluster-migration-barrier 1
cluster-require-full-coverage yes
cluster-replica-no-failover no
```

加入同一个集群中：

> 使用 <span style="background:blue;color:#FFF;">redis-cli</span> 命令就可以，5.0.4之前的redis使用 <span style="background:blue;color:#FFF;">redis-trib.rb</span> 工具（在安装目录上找）
>
> ./redis-cli --cluster create 127.0.0.1:6380 127.0.0.1:6381 127.0.0.1:6382 127.0.0.1:6383 127.0.0.1:6384 127.0.0.1:6385 --cluster-replicas 1 
>
>  --cluster-replicas 1 指定每一个主数据库，都必需包含一个从数据库

```shell
./redis-cli --cluster create 127.0.0.1:6380 127.0.0.1:6381 127.0.0.1:6382 127.0.0.1:6383 127.0.0.1:6384 127.0.0.1:6385 --cluster-replicas 1 
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica 127.0.0.1:6384 to 127.0.0.1:6380
Adding replica 127.0.0.1:6385 to 127.0.0.1:6381
Adding replica 127.0.0.1:6383 to 127.0.0.1:6382
>>> Trying to optimize slaves allocation for anti-affinity
[WARNING] Some slaves are in the same host as their master
M: f85107080b5210c7728ba84a773e5d29fedd91db 127.0.0.1:6380
   slots:[0-5460] (5461 slots) master
M: 1d534a715ef2ee97ecb226b5ed9aec0008f47a7c 127.0.0.1:6381
   slots:[5461-10922] (5462 slots) master
M: 6df2f07b411f3a05b1e6be9165860f9fb2dcbb7d 127.0.0.1:6382
   slots:[10923-16383] (5461 slots) master
S: c219a6a3dcc65d69996c3045a0863e56d526986f 127.0.0.1:6383
   replicates 6df2f07b411f3a05b1e6be9165860f9fb2dcbb7d
S: 443a3185193352fae1f5a77df9161052a8e33ef6 127.0.0.1:6384
   replicates f85107080b5210c7728ba84a773e5d29fedd91db
S: 42708fadf266e54855eaa806f06f5f86bcdccb86 127.0.0.1:6385
   replicates 1d534a715ef2ee97ecb226b5ed9aec0008f47a7c
Can I set the above configuration? (type 'yes' to accept): yes  # 如果上面配置没有问题：yes
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join
........
>>> Performing Cluster Check (using node 127.0.0.1:6380)
M: f85107080b5210c7728ba84a773e5d29fedd91db 127.0.0.1:6380
   slots:[0-5460] (5461 slots) master
   1 additional replica(s)
M: 6df2f07b411f3a05b1e6be9165860f9fb2dcbb7d 127.0.0.1:6382
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
S: 443a3185193352fae1f5a77df9161052a8e33ef6 127.0.0.1:6384
   slots: (0 slots) slave
   replicates f85107080b5210c7728ba84a773e5d29fedd91db
M: 1d534a715ef2ee97ecb226b5ed9aec0008f47a7c 127.0.0.1:6381
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
S: 42708fadf266e54855eaa806f06f5f86bcdccb86 127.0.0.1:6385
   slots: (0 slots) slave
   replicates 1d534a715ef2ee97ecb226b5ed9aec0008f47a7c
S: c219a6a3dcc65d69996c3045a0863e56d526986f 127.0.0.1:6383
   slots: (0 slots) slave
   replicates 6df2f07b411f3a05b1e6be9165860f9fb2dcbb7d
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

### 2、槽位

新的节点加入集群后有两种选择，要么使用cluster replicate命令复制每个主数据库来以从数据库的形式运行；要么向集群申请分配插槽(slot)来以主数据库的形式运行。

在一个集群中，所有臽会被分配给16384个插槽，每个主数据库会负责处理其中的一部分插槽。

查看插槽分配情况：

> CLUSTER SLOTS

```shell
127.0.0.1:6380> cluster slots
1) 1) (integer) 10923
   2) (integer) 16383
   3) 1) "127.0.0.1"
      2) (integer) 6382
      3) "6df2f07b411f3a05b1e6be9165860f9fb2dcbb7d"
   4) 1) "127.0.0.1"
      2) (integer) 6383
      3) "c219a6a3dcc65d69996c3045a0863e56d526986f"
2) 1) (integer) 0
   2) (integer) 5460
   3) 1) "127.0.0.1"
      2) (integer) 6380
      3) "f85107080b5210c7728ba84a773e5d29fedd91db"
   4) 1) "127.0.0.1"
      2) (integer) 6384
      3) "443a3185193352fae1f5a77df9161052a8e33ef6"
3) 1) (integer) 5461
   2) (integer) 10922
   3) 1) "127.0.0.1"
      2) (integer) 6381
      3) "1d534a715ef2ee97ecb226b5ed9aec0008f47a7c"
   4) 1) "127.0.0.1"
      2) (integer) 6385
      3) "42708fadf266e54855eaa806f06f5f86bcdccb86"
```

为了直观点，我使用表格来展示，并且不展示从库：

| SLOT          | IP:PORT (Master) | ID                                       |
| ------------- | ---------------- | ---------------------------------------- |
| 0 - 5460      | 127.0.0.1:6380   | f85107080b5210c7728ba84a773e5d29fedd91db |
| 5461 - 10922  | 127.0.0.1:6381   | 1d534a715ef2ee97ecb226b5ed9aec0008f47a7c |
| 10923 - 16383 | 127.0.0.1:6382   | 6df2f07b411f3a05b1e6be9165860f9fb2dcbb7d |

### 3、节点管理

#### 1) 添加主节点

```shell
# 127.0.0.1:6386 为新节点信息
# 127.0.0.1:6380 为集群中任意节点
./redis-cli --cluster add-node 127.0.0.1:6386 127.0.0.1:6380
```

此时127.0.0.1:6386已成为集群中的一份子，但它还没有包含任何插槽(slot)，这个新节点不会被选中。分配插槽(slot)：

```shell
# 127.0.0.1:6381为，集群中任选一节点的信息
./redis-cli --cluster reshard 127.0.0.1:6381

# 以下为关键步骤说明
How many slots do you want to move (from 1 to 16384)? # 需要移动多少个插槽
Source node #1: all/done all在所有节点中分配，done在指定节点中分配
```

添加主节点完成，查看集群信息（cluster nodes），我使用表格方式展示：

| IP & PORT            | 主 / 从 | 槽位                         |
| -------------------- | ------- | ---------------------------- |
| 127.0.0.1:6384@16384 | slave   | --                           |
| 127.0.0.1:6383@16383 | slave   | --                           |
| 127.0.0.1:6381@16381 | master  | 6827-10922                   |
| 127.0.0.1:6382@16382 | master  | 12288-16383                  |
| 127.0.0.1:6380@16380 | master  | 1365-5460                    |
| 127.0.0.1:6386@16386 | master  | 0-1364 5461-6826 10923-12287 |
| 127.0.0.1:6385@16385 | slave   | --                           |

从上面信息可知，127.0.0.1:6386节点的槽位是由6380、6381、6382三个节点分配的。

#### 2) 添加从节点

```shell
# 这一步和添加主节点是一样的
# 127.0.0.1:6387 为新节点信息
# 127.0.0.1:6380 为集群中任意节点
./redis-cli --cluster add-node 127.0.0.1:6387 127.0.0.1:6380
```

再使用`CLUSTER REPLICATE`命令改变一个从节点的主节点。

```shell
# 让当前节点的主节点为：9e7507689ea905bd4b6adf57b7078c4fc0b99755(127.0.0.1:6386)
127.0.0.1:6387> cluster replicate 9e7507689ea905bd4b6adf57b7078c4fc0b99755
OK
```

