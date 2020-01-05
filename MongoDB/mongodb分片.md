# 一、MongoDB分片相关技术栈

## 1、分片机制的三种优势

* 对集群进行抽象，让集群“不可见”
* 保证集群总是可读写
* 使集群易于扩展

## 2、分片集群架构节点

| 组件              | 说明                                                         |
| ----------------- | ------------------------------------------------------------ |
| **Config Server** | 存储集群所有节点、分片数据路由信息。默认需要配置3个Config Server节点 |
| **Mongos**        | 提供对外应用访问入口，所有操作均通过mongos执行。一般有多个mongos节点 |
| **Mongod**        | 存储应用数据记录。一般有多个mongod节点，达到分片目的         |

* mongos

> 数据路由，和客户端打交道的模块。mongos本身没有任何数据，他也不知道怎么处理数据，会去找config server

* config server

> 所有shard节点信息、存储数据的方式，分片功能的一些配置信息。可以理解为真实数据的元数据

* shard

> 真正数据存储位置，以chunk为单位存数据

## 3、什么是chunk

在一个shard server内部，MongoDB还是会把数据分为chunks，每个chunk代表这个shard server内部一部分数据。chunk的产生会有以下两个用途：

<ol>
    <li><b>Splitting:</b>当一个chunk的大小超过配置中的chunk size时，MongoDB的后台进程会把这个chunk切分成更小的chunk，从而避免chunk过大</li>
    <li><b>Balancing:</b>在MongoDB中，balancer是一个后中进程，负责chunk的迁移，从而均衡各个shard server负载，系统初始1个chunk，<b>chunk size默认值64M</b>，生产库上选择适合业务的chunk size是最好的。MongoDB会自动拆分和迁移chunks。</li>
</ol>

## 4、如何选择chunk size?

* 小的chunk size：数据均衡迁移快，数据分布均匀，数据分裂频繁，路由节点消耗多
* 大的chunk size：数据分裂少。数据块移动集中消耗IO资源。通常100-200M
* 查询是不会分裂的，只有在插入和更新的时候才会分裂

## 5、chunk分裂及迁移

数据大小超过了配置chunk size（默认64M），就会分裂成两个。Mongos中的一个组件balance主会执行自动平衡。把chunk从chunk数量最多的shard节点挪动到数据量少的节点。

* chunk自动分裂会在数据写入的时候触发
* chunk只会分裂，不会合并

## 6、shard key分片键

MongoDB中数据分片是以集合为单位的，集合中的数据通过片键(Shard key)被分成多部分。其实片键就是在集合中选一个键，用该键作为数据拆分的依据。

所以一个好的片键至关重要。片键必须是一个索引。

对集合进行分片时，你需要选择一个片键，片键是每条记录都必须包含的，且建立了索引的单个字段或复合字段，MongoDB按照片键将数据划分到不同的数据块中，并将数据均衡地分布到所有分片中。

## 7、分片建策略

* 一个自增的片键对写入和数据均匀分布就是是很好
* 随机片键均匀分布好，利于排序查询

MongoDB使用基于**范围的分片方式**或者基于**哈希的分片方式**

注意事项：

* 分片键是不可变的
* 分片键必须有索引
* 分片键大小限制512B
* 分片键用于路由查询
* 键的文档（不支持空值插入）

### 基于范围分片方式

sharded cluster支持将单个集合的数据分散存储在多个shard上，用户可以指定根据集合内文档的某个字段（shard key）进行范围分片，如：

001-100  => shard 1

101-200  => shard 2

201-300  => shard 3

### 基于哈希的分片方式

分片过程中利用哈希索引作为分片的单个键，且哈希分片的片键只能使用一个字段，而基于哈希键最大的好处就是保证数据在各个节点分布基本均匀

## 8、分片集群部署常见错误

配置可复用集作为分片节点与配置单独使用的可复制基本一样。但启动参数中需指定——shardsvr参数。否则，在启动数据库分片时报错

分片不会默认生成，需要先在数据库中启动分片(sh.enableSharding("DBName"))，然后再设置集合分片(sh.shardCollection("Collection"{片键}))

# 二、基本安装

## 1、Shard 环境搭建

### 1）添加复制集配置文件mongo.conf

复制集配置(mongo.conf)，分别对应192.168.57.201、192.168.57.202、192.168.57.203三台电脑

```shell
fork=true
dbpath=/opt/mongo/data/db
port=27017
bind_ip=0.0.0.0
logpath=/opt/mongo/logs/mongodb.log
logappend=true
replSet=yidian_repl  # 复制集的名字(自己定义)
smallfiles=true
# 分片集群必须要有的属性
shardsvr=true
```

副本集配置(mongo2.conf)，分别对应192.168.57.201、192.168.57.202、192.168.57.203三台电脑

```shell
fork=true
dbpath=/opt/mongo/data2/db
port=27018
bind_ip=0.0.0.0
logpath=/opt/mongo/logs2/mongodb.log
logappend=true
replSet=yidian_repl2  # 副本集的名字(自己定义)
smallfiles=true
# 分片集群必须要有的属性
shardsvr=true
```

### 2）启动复制集和副本集

分别启动，192.168.57.201、192.168.57.202、192.168.57.203三台电脑

```shell
./mongod -f mongo.conf
./mongod -f mongo2.conf
```

### 3）配置复制集和副本集

配置复制集

```shell
# 进入mongo
./mongo --port 27017
---->
var reconf = {
	_id: "yidian_repl", // 这里的_id要与配置文件中指定的服务所属的复制集相同
	members: // 复制集成员
	[
		{
			_id: 1, // 成员ID
			host: "192.168.57.201:27017"
		}, {
			_id: 2, // 成员ID
			host: "192.168.57.202:27017"
		}, {
			_id: 3, // 成员ID
			host: "192.168.57.203:27017"
		}
	]
}
# 初始化配置(加载reconf变量)
rs.initiate(reconf);

# 查看状态
rs.status();
```

配置副本集

```shell
# 进入mongo
./mongo --port 27018
---->
var reconf = {
	_id: "yidian_repl2", // 这里的_id要与配置文件中指定的服务所属的复制集相同
	members: // 复制集成员
	[
		{
			_id: 1, // 成员ID
			host: "192.168.57.201:27018"
		}, {
			_id: 2, // 成员ID
			host: "192.168.57.202:27018"
		}, {
			_id: 3, // 成员ID
			host: "192.168.57.203:27087"
		}
	]
}
# 初始化配置(加载reconf变量)
rs.initiate(reconf);

# 查看状态
rs.status();
```

## 2、Config Server 环境搭建

### 1）创建config节点配置文件：mongo-cfg.conf

创建config节点文件,192.168.57.201、192.168.57.202、192.168.57.203三台电脑都需要配置

```yaml
systemLog:
	destination: file
	path: /opt/mongo/mongo-cfg/logs/mongodb.log
	logAppend: true
storage:
	journal:
		enabled: true
	dbPath: /opt/mongo/mongo-cfg/data  # 数据存储位置	
	directoryPerDB: true  # 是否一个库存放一个目录
	wiredTiger:
		engineConfig:
			cacheSizeGB: 1  # 最大使用的cache(根据真实情况调节)
			directoryForIndexs: true  # 是否将索引也按照数据库名单独存储
		collectionConfig:
			blockCompressor: zlib  # 表压缩配置
		indexConfig:  # index 配置
			prefixCompression: true
net:
	bindIp: 192.168.57.201
	port: 28018
replication:
	oplogSizeMB: 2048
	replSetName: configReplSet  # 配置配置的复制集名字
sharding:
	clusterRole: configsvr
processManagement:
	fork: true  # 后台进程
```

### 2）启动配置服务器复制集

启动配置服务器复制集,192.168.57.201、192.168.57.202、192.168.57.203三台电脑都需要启动

```shell
# 目录地址自己行调整
./mongd -f mongo-cfg.conf
```

### 3）初始化节点

```shell
# 登录
./mongo -host 192.168.57.201 -port 27018
```

初始化命令,在任意一台配置

```shell
rs.initiate({
	_id: "configReplSet",
	configsvr: true,
	members: [
		{_id: 0, host: "192.168.57.201:28018"},
		{_id: 1, host: "192.168.57.202:28018"},
		{_id: 2, host: "192.168.57.203:28018"}
	]
});
```

## 3、mongos节点

只需要配置一台:192.168.57.201

### 1) mongos配置文件 mongos.conf

```yaml
systemLog:
	destination: file
	path: /opt/mongo/mongos/log/mongos.log
	logAppend: true
net:
	bindIp: 192.168.57.201
	port: 28017
sharding:
	configDB: configReplSet/192.168.57.201:28017,192.168.57.202:28018,192.168.57.203:28018
processManagement:
	fork: true
```

### 3) 启动mongos

```shell
./mongos -config mongis.conf
```

### 4) 登录mongos

```shell
./mongo 192.168.57.201:28017
```

## 4、添加集群分片

### 添加shard 1 复制集

```js
db.runCommand({
 "addshard":"yidian_repl/192.168.57.201:27017,192.168.57.202:27017,192.168.57.203:27017",
 "name":"shard1"
})
```

### 添加shard2复制集

```js
db.runCommand({
 "addshard":"yidian_repl/192.168.57.201:27018,192.168.57.202:27018,192.168.57.203:27018",
 "name":"shard2"
})
```

### 查看分片

```js
db.runCommand({listshards: 1});
```

### 查看分片状态

```shell
# mongos
sh.status()
```

## 5、测试分片集群

### 开启数据库分片

```
db.runCommand({enablesharding: "testdb"})
```

### 创建分片的键

```
db.runCommand( {shardcollection: "testdb.users", key: {id: 1}} )
```

### 创建索引

```
use testdb
db.users.ensureIndex({id: 1})
```

### 添加测试数据

```shell
var arr = [];
for(var i=0;i<1500000;i++){
	var uid=1;
	var name = "name" + i;
	arr.push("id":uid, "name":name);
}
db.users.insertMany(arr);
```

## 6 、其他分片集群的命令

```
# 添加分片
db.runCommand({
 "addshard":"yidian_repl/192.168.57.201:27018,192.168.57.202:27018,192.168.57.203:27018",
 "name":"shard2"
})

# 删除分片
db.runCommand({removeShard: "shard2"})
```

## 7、Balancing相关配置

Balancing的操作会影响到mongoDB的性能 ,但是教程没有