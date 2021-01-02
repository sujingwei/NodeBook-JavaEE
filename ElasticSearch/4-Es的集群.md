# 一、通往集群的道路

- 高可用
- 负载均衡
- 高性能

# 二、Elastic Search集群的核心概念

* Cluster 集群
  
  * 一个Elastic Search集群由一个或多个集群组成，每个集群都有一个共同的集群名称作为标识。
* Node 节点
  * 一个Elastic Search实例就是一个Node，一台机器可以有多个实例，正常使用下每个实例应该会部署在不同的机器上。Elastic Search的配置文件可以通过node.master、node.data来设置节点类型。
  * node.master： 表示节点是否具有成为主节点的资格
    * true：代表有资格竞选主节点
    * false：代码没有资格竞选主节点
  * node.data：表示节点是否存储数据

* Node节点组合

  * 主节点 + 数据节点 (master + data)

    ```yaml
    node.master: true
    node.data: true
    ```

  * 数据节点(data)，不参数主节点选举

    ```yaml
    node.master: false
    node.data: true
    ```

  * 客户端点节(client)，不会成为主节点，也不会存储数据，主要是针对海量请求的时候可以进行负载均衡

    ```yaml
    node.master: false
    node.data: false
    ```

* Shard分片
  
  * 每个索引有一个或多个分片，每个分片存储不同的数据。分片可分为**主分片(primary shard)**和**复制分片(replica shard)**，复制分片是主分片的拷贝。默认每个主分片有一个复制分片，一个索引的复制分片的数量可以动态地调整，复制分片从不与它的主分片在同一个节点上，复制分片可以动态调整个数分布在集群中。

# 三、搭建Elastic Search集群

## 1、集群的配置&启动

### 1）第一步、配置文件

**elasticsearch.yml**

```yaml
cluster.name: my-application
node.name: node-1 / node-2 / node-3  # 我要配置3个节点
node.master: true
node.data: true

# 集群最大节点数
node.max_local_storage_nodes: 3

# 网关地址
network.host: 0.0.0.0

# 端口
http.port: 9200 / 9201 / 9202

# 内部沟通端口
transport.tcp.port: 9300 / 9400 / 9500

# 7.x后新配置，写入候选节点的设置地址，在开启服务后可以被选为主节点
discovery.seed_hosts: ["localhost:9300", "localhost:9400", "localhost:9500"]

# 7.x后新配置，初始化一个新的集群时需要此配置来选择master
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]

# 数据存储路径，可以不用配置
path.data: /Users/louis.chen/Documents/study/search/storage/a/data
path.logs: /Users/louis.chen/Documents/study/search/storage/a/logs
```

### 2）启动

一个节点一个节点的启动

### 3）配置kibana并启动

**kibana.yml**

