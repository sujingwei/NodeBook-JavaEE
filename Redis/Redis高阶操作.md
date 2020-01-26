# Redis高阶操作

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