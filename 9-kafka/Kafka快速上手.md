# Kafka 快速上手

## 1. 快速了解Kafka

### 1.1 MQ的使用

消息队列（Message Queue，简称 MQ）是分布式系统中重要的中间件，核心作用体现在三个方面：**异步、解耦、削峰**。

#### 1.1.1 异步

**场景案例：用户注册送积分**

- **同步方式**：用户注册完成后，系统依次执行"保存用户信息 → 发送注册邮件 → 初始化用户积分"。整个流程耗时 = 数据库写入 + 邮件发送 + 积分初始化，响应时间很长，用户体验差。
- **异步方式**：用户注册完成后，系统只完成"保存用户信息"，然后将"发送邮件"和"初始化积分"作为消息写入 MQ，立即返回注册成功。邮件服务和积分服务从 MQ 中消费消息，异步处理。用户感知的响应时间大大缩短。

```
同步：请求 → [注册] → [发邮件] → [送积分] → 响应（慢）
异步：请求 → [注册] → 响应（快）
                ↘ MQ → [发邮件]（后台处理）
                     → [送积分]（后台处理）
```

#### 1.1.2 解耦

**场景案例：电商订单系统**

- **耦合方式**：订单创建后，需要直接调用库存系统扣库存、调用物流系统创建运单、调用短信系统发通知。每接入一个新系统，都要改订单代码，系统间强依赖，一处故障可能级联影响。
- **解耦方式**：订单创建后，向 MQ 发送一条"订单已创建"的消息。库存系统、物流系统、短信系统各自订阅该消息，独立消费。新增下游系统只需订阅 MQ 即可，订单服务完全不用改动。

```
耦合：系统A → 系统B、C、D（A 直接依赖 B/C/D，牵一发而动全身）
解耦：系统A → MQ → 系统B、C、D（A 只依赖 MQ，下游可独立扩展）
```

#### 1.1.3 削峰

**场景案例：秒杀活动**

- **直连方式**：秒杀瞬间大量请求涌入后端，数据库连接被占满，系统崩溃。
- **削峰方式**：请求先写入 MQ，后端服务按自身处理能力（如每秒 1000 条）匀速消费。超过 MQ 容量的请求直接快速失败，提示用户"请稍后再试"，系统不会因为瞬时流量而崩溃。

```
秒杀流量：████████████████████（50000 QPS 瞬间涌入）
                ↓ MQ 缓冲
消费能力：████████████████████（恒定 1000 QPS 匀速处理，系统平稳）
```

---

### 1.2 Kafka 产品介绍

Kafka 是由 **LinkedIn** 开发、后贡献给 **Apache 基金会**的开源分布式消息引擎系统，现为 Apache 顶级项目。

Kafka 最初的设计目标是解决 LinkedIn 内部海量日志数据的实时收集和传输问题。它不是一个传统意义上的"消息队列"，更像是一个**分布式流处理平台**，主要用于：

- **发布/订阅消息流**：类似消息队列，支持生产者和消费者模式。
- **持久化存储消息**：消息写入磁盘持久化，支持事后回放和重复消费。
- **实时流处理**：配合 Kafka Streams 或 Flink 等框架，对数据流进行实时计算和转换。

Kafka 由 Scala 和 Java 编写，目前广泛应用于大数据、日志采集、用户行为追踪、流计算、微服务异步通信等场景。

---

### 1.3 Kafka 的特点

#### 1.3.1 数据吞吐量很大

Kafka 采用**顺序写入磁盘**、**零拷贝（Zero-Copy）**、**批量发送**和**数据压缩**等技术，单机吞吐量可达每秒数十万甚至百万条消息，远超传统的 RabbitMQ、ActiveMQ 等消息队列。

- **顺序写**：消息以追加方式写入日志文件，避免了磁盘随机寻道，写入速度接近磁盘顺序 I/O 的物理上限。
- **零拷贝**：数据从磁盘到网络传输的过程尽量减少 CPU 拷贝，直接使用 DMA 传输，大幅提升消费性能。
- **批量与压缩**：生产者可批量发送消息，支持 GZIP、Snappy、LZ4 等压缩算法，减少网络和磁盘开销。

#### 1.3.2 集群容错性高

Kafka 天然支持分布式集群部署，通过以下机制保证高可用：

- **分区（Partition）**：每个 Topic 分为多个 Partition，分布在不同 Broker 上，实现水平扩展。
- **副本（Replica）**：每个 Partition 有多个副本（Leader + Follower），Leader 负责读写，Follower 从 Leader 同步数据。
- **故障转移**：当 Leader 所在 Broker 宕机时，ISR（In-Sync Replica）中的 Follower 自动选举为新 Leader，保证服务不中断。
- **分布式协调**：通过 ZooKeeper（或 KRaft 模式）管理集群元数据和 Leader 选举。

#### 1.3.3 功能不需要太复杂

相比于 RabbitMQ 支持 AMQP 协议、复杂的路由规则和消息确认机制，Kafka 的设计理念是 **"简单即高效"**：

- 不提供复杂的路由功能，生产者直接指定 Topic 和 Partition。
- 消费者使用**拉模式（Pull）**，自控消费速率，逻辑简单透明。
- 消息模型只有 Topic / Partition / Consumer Group 几个核心概念，上手成本低。

如果你的场景不需要复杂的路由、事务和 EIP（企业集成模式），Kafka 的"简陋"反而是一种优势——简单意味着稳定、好运维。

#### 1.3.4 允许少量数据丢失

Kafka 在追求高吞吐量的同时，设计上允许在特定配置下牺牲一定的可靠性来换取性能：

- **异步发送**：生产者默认异步发送，宕机可能丢失缓冲区中未发送的消息（可配置 `acks=all` 来保证不丢失）。
- **不完全刷盘**：消息先写入操作系统的 Page Cache，不保证立即刷盘，极端情况下（断电）可能丢失少量数据。
- **接收即提交**：Kafka 以"消息已被后续消息确认"的方式提交，而非每条消息逐条确认，少量滞后数据可能未完全持久化。

但需要注意的是，Kafka 的这些行为都是**可配置的**。如果你的场景对可靠性要求极高，可以通过调整参数（如 `acks=all`、`min.insync.replicas`、`enable.idempotence=true` 等）来做到**零丢失**，代价是吞吐量会有所下降。

---

## 2. 快速上手kafka

### 2.1 快速上手

#### 2.1.1 Kafka 环境启动

##### 2.1.1.1 下载 Kafka

我使用的版本是 `kafka_2.13-3.8.0.tgz`，其中 `2.13` 表示 Scala 版本，`3.8.0` 表示 Kafka 版本。

下载后解压到目标目录：

```bash
tar -xzf kafka_2.13-3.8.0.tgz
cd kafka_2.13-3.8.0
```

> **版本说明**：Kafka 3.8.0 是 2024 年 7 月发布的一个稳定版本，支持 KRaft（Kafka Raft）模式，可以脱离 ZooKeeper 独立运行。但本笔记仍然使用传统的 ZooKeeper 模式，便于理解 Kafka 的架构演进。

##### 2.1.1.2 启动 ZooKeeper

Kafka 依赖 ZooKeeper 管理集群元数据和 Leader 选举（新版本也可选择 KRaft 模式不依赖 ZooKeeper）。先启动 ZooKeeper：

```bash
bin/zookeeper-server-start.sh config/zookeeper.properties
```

`zookeeper.properties` 中默认端口为 `2181`，数据目录为 `/tmp/zookeeper`。生产环境需要修改为持久化目录。

##### 2.1.1.3 启动 Kafka

ZooKeeper 启动成功后，另开一个终端窗口，启动 Kafka Broker：

```bash
bin/kafka-server-start.sh config/server.properties
```

`server.properties` 中关键配置：
- `listeners=PLAINTEXT://:9092` — 监听端口 9092
- `log.dirs=/tmp/kafka-logs` — 消息日志存储目录，生产环境需改为持久化目录
- `zookeeper.connect=localhost:2181` — 连接的 ZooKeeper 地址

---

#### 2.1.2 Kafka 简单的发消息

##### 2.1.2.1 创建 Topic

消息发送前需要先创建一个 Topic（主题），生产者将消息发送到指定 Topic，消费者从 Topic 订阅消费。

```bash
# 创建名为 test 的 Topic
bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic test

# 查看所有 Topic 列表，确认创建成功
bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

> 默认不指定分区数和副本数时，Kafka 使用 `num.partitions=1` 和 `replication.factor=1`。

##### 2.1.2.2 启动消息发送者（生产者）

使用 Kafka 自带的控制台生产者工具，可以交互式地发送消息：

```bash
bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test
```

回车后进入交互模式，每行输入一条消息，按 `Ctrl+C` 退出。例如：

```
> hello kafka
> this is a test message
> 你好 Kafka
```

##### 2.1.2.3 启动消息消费者

另开一个终端，使用控制台消费者工具消费消息：

```bash
# 默认从最新位置开始消费（只消费启动后新发送的消息）
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test
```

**常用参数：**

```bash
# --from-beginning：从头消费所有历史消息（包括启动前已存在的消息）
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --from-beginning

# --partition 0 --offset 2：指定从分区 0 的第 2 个偏移量开始消费
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --partition 0 --offset 2
```

**使用消费者组（Consumer Group）：**

```bash
# --group testGroup：指定消费者组
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --group testGroup
```

> **消费者组的作用**：同一个消费者组内，每个 Partition 只会被组内的一个消费者消费。如果启动多个同名消费者组，那么 Topic 的每个 Partition 只会分配给其中一个消费者，实现负载均衡。这也是 Kafka 保证消息不重复消费（同组内）的基础机制。

#### 2.1.2.4 核心概念关系图

**关键要点：**

```
┌──────────────────────────────────────────────────────────────┐
│                        Topic: order-topic                     │
├─────────────────┬─────────────────┬───────────────────────────┤
│   Partition 0   │   Partition 1   │      Partition 2          │
│  ┌───────────┐  │  ┌───────────┐  │  ┌───────────┐            │
│  │ Offset 0  │  │  │ Offset 0  │  │  │ Offset 0  │  ← 旧消息  │
│  │ Offset 1  │  │  │ Offset 1  │  │  │ Offset 1  │            │
│  │ Offset 2  │  │  │ Offset 2  │  │  │ Offset 2  │  ← 新消息  │
│  └───────────┘  │  └───────────┘  │  └───────────┘            │
├─────────────────┴─────────────────┴───────────────────────────┤
│                      Consumer Group: group-A                   │
│  ┌──────────────┐  ┌──────────────┐                            │
│  │  Consumer 1  │  │  Consumer 2  │                            │
│  │  P0 + P1     │  │  P2          │   ← 同组内分区互斥分配     │
│  └──────────────┘  └──────────────┘                            │
├───────────────────────────────────────────────────────────────┤
│                      Consumer Group: group-B                   │
│  ┌──────────────┐                                              │
│  │  Consumer 3  │   ← 不同组独立消费，互不影响                  │
│  │  P0 + P1 + P2│                                              │
│  └──────────────┘                                              │
└───────────────────────────────────────────────────────────────┘
```

| 概念 | 说明 |
|------|------|
| **Producer**（生产者） | 向 Topic 发送消息，可指定分区策略（轮询 / Key 哈希 / 手动指定） |
| **Topic**（主题） | 消息的逻辑分类，类似数据库的"表" |
| **Partition**（分区） | Topic 的物理分片，每个 Partition 是一个有序、不可变的消息队列 |
| **Offset**（偏移量） | 消息在 Partition 中的唯一编号，从 0 开始递增，消费者通过 Offset 记录消费位置 |
| **Message**（消息） | 由 Key、Value、Timestamp 组成，写入后不可修改 |
| **Consumer**（消费者） | 从 Topic 拉取消息，属于某个 Consumer Group |
| **Consumer Group**（消费者组） | 组内消费者共享消费进度，**同一 Partition 只会被组内一个 Consumer 消费**；不同 Consumer Group 之间互不影响，各自独立消费（各自维护自己的 Offset） |

---

---

### 2.2 Kafka 集群

#### 2.2.1 搭建集群

Kafka 集群由多个 Broker 组成，每个 Broker 有唯一的 `broker.id`。在同一台机器上模拟集群时，需要为每个 Broker 准备独立的配置文件和日志存储目录。

从 `config/server.properties` 复制三份配置文件：

**config/server-0.properties**（节点 0，端口 9092）

```properties
broker.id=0
listeners=PLAINTEXT://:9092
log.dirs=/tmp/kafka-logs-0
```

**config/server-1.properties**（节点 1，端口 9093）

```properties
broker.id=1
listeners=PLAINTEXT://:9093
log.dirs=/tmp/kafka-logs-1
```

**config/server-2.properties**（节点 2，端口 9094）

```properties
broker.id=2
listeners=PLAINTEXT://:9094
log.dirs=/tmp/kafka-logs-2
```

| 配置项 | 说明 |
|--------|------|
| `broker.id` | 集群中 Broker 的唯一标识，必须互不相同。ZooKeeper 通过它来识别和管理各个节点 |
| `listeners` | 监听地址和端口，同一台机器上每个 Broker 需使用不同端口避免冲突 |
| `log.dirs` | 消息数据存储目录，每个 Broker 独立使用一个目录，避免数据混乱 |

> 这三个配置文件继承自 `server.properties` 的默认值，其中 `zookeeper.connect=localhost:2181` 保持不变，三个节点连接同一个 ZooKeeper，ZooKeeper 会自动将它们注册到同一个集群中。

**分别启动三个 Broker（各开一个终端窗口）：**

```bash
# 终端 1：启动 Broker 0
bin/kafka-server-start.sh config/server-0.properties

# 终端 2：启动 Broker 1
bin/kafka-server-start.sh config/server-1.properties

# 终端 3：启动 Broker 2
bin/kafka-server-start.sh config/server-2.properties
```

启动后，三个 Broker 会向 ZooKeeper 注册，组成一个三节点的 Kafka 集群。接下来创建 Topic 时，就可以指定多个分区和副本了：

```bash
# 创建有 3 个分区、3 个副本的 Topic（副本数不能超过 Broker 数量）
bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic test-cluster \
  --partitions 3 --replication-factor 3

# 查看 Topic 详情，确认分区和副本分布
bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic test-cluster
```

> **集群验证**：尝试停掉某个 Broker（如 Broker 0），Topic 读写仍可正常进行——因为其他 Broker 上保留了该分区的副本，Leader 会自动切换，体现了 Kafka 的高可用性。

---

#### 2.2.2 对集群进行操作

##### 2.2.2.1 创建主题

创建一个名为 `disTopic` 的主题，指定 2 个副本、4 个分区：

```bash
bin/kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --replication-factor 2 --partitions 4 --topic disTopic
```

**查看主题详情：**

```bash
bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic disTopic
```

输出示例：

```
Topic: disTopic    TopicId: yIw7XIo6TNKgKiXvpjGyqw    PartitionCount: 4    ReplicationFactor: 2    Configs:
    Topic: disTopic    Partition: 0    Leader: 2    Replicas: 2,1    Isr: 2,1    Elr: N/A    LastKnownElr: N/A
    Topic: disTopic    Partition: 1    Leader: 1    Replicas: 1,0    Isr: 1,0    Elr: N/A    LastKnownElr: N/A
    Topic: disTopic    Partition: 2    Leader: 0    Replicas: 0,2    Isr: 0,2    Elr: N/A    LastKnownElr: N/A
    Topic: disTopic    Partition: 3    Leader: 2    Replicas: 2,0    Isr: 2,0    Elr: N/A    LastKnownElr: N/A
```

**输出字段解释：**

| 字段 | 说明 |
|------|------|
| `Topic` | 主题名称 |
| `TopicId` | 主题的唯一标识符（UUID），Kafka 内部使用 |
| `PartitionCount` | 分区总数，此处为 4 |
| `ReplicationFactor` | 副本因子，此处为 2，即每条消息保存 2 份 |
| `Partition` | 分区编号（0 ~ 3），共 4 个分区 |
| `Leader` | 当前负责该分区读写的 Broker ID。比如 Partition 0 的 Leader=2，表示 Broker 2 处理该分区的读写请求 |
| `Replicas` | 该分区的所有副本所在 Broker 列表。比如 `2,1` 表示副本分布在 Broker 2 和 Broker 1 上，排在前面的通常是 Preferred Leader |
| `Isr`（In-Sync Replica） | 与 Leader 保持同步的副本列表。正常情况下 `Isr` 与 `Replicas` 一致；如果某个副本同步滞后，会从 Isr 中移除 |
| `Elr` / `LastKnownElr` | End Log Replica，一般情况下为 `N/A`，通常不用关注 |

> 从上面输出可以看出：4 个分区的 Leader 分别分布在 Broker 0、1、2 上，做到了负载均衡；每个分区的 2 个副本分布在不同 Broker 上，保证了高可用。

##### 2.2.2.2 创建生产者

```bash
bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic disTopic
```

连的是 Broker 0（9092），但生产者会从集群元数据中获取 `disTopic` 各个分区的 Leader 信息，并自动将消息路由到对应的 Leader Broker。

##### 2.2.2.3 创建消费者

```bash
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic disTopic --group testGroup
```

消费者属于 `testGroup` 消费者组。因为 `disTopic` 有 4 个分区，而当前只有 1 个消费者，所以该消费者会独享所有 4 个分区的消息。

##### 2.2.2.4 查看消费者组

```bash
bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group testGroup
```

输出示例：

```
GROUP       TOPIC      PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG   CONSUMER-ID                                         HOST            CLIENT-ID
testGroup   disTopic   1          0               0               0     console-consumer-22b16694-...                       /192.168.0.106  console-consumer
testGroup   disTopic   2          0               0               0     console-consumer-22b16694-...                       /192.168.0.106  console-consumer
testGroup   disTopic   0          0               0               0     console-consumer-22b16694-...                       /192.168.0.106  console-consumer
testGroup   disTopic   3          8               8               0     console-consumer-22b16694-...                       /192.168.0.106  console-consumer
```

**输出字段解释：**

| 字段 | 说明 |
|------|------|
| `GROUP` | 消费者组名称 |
| `TOPIC` | 订阅的主题 |
| `PARTITION` | 分区编号 |
| `CURRENT-OFFSET` | 消费者组当前在该分区的消费位置（已消费到的 Offset） |
| `LOG-END-OFFSET` | 该分区当前最新消息的 Offset（即日志末尾位置） |
| `LAG` | 消费延迟 = `LOG-END-OFFSET` - `CURRENT-OFFSET`。0 表示已追上最新消息，没有积压 |
| `CONSUMER-ID` | 消费者实例的唯一标识 |
| `HOST` | 消费者所在主机 IP |
| `CLIENT-ID` | 客户端 ID |

> 从输出可见：Partition 3 的 `CURRENT-OFFSET=8`、`LOG-END-OFFSET=8`，说明该分区已产生 8 条消息且已全部消费（LAG=0）；Partition 0~2 均为 0，暂未收到消息。整个消费者组只有一个消费者实例，独占了 4 个分区。

**消费者组关键结论：**

- 同一个消费者组内，**每个 Partition 只会分配给一个消费者**，保证消息不会被重复消费。
- 如果组内消费者数量 > 分区数，那么多出的消费者会处于**空闲状态**，不消费任何分区。
- 不同消费者组之间**完全独立**，各自维护消费进度（Offset），互不影响。

## 3. kafka java客户端

### 3.1 基础生产与消费

在 Kafka 集群搭建完成后，我们可以通过 Java 客户端来编写生产者和消费者程序。Kafka 提供了 `kafka-clients` 依赖，只需引入即可使用。

**Maven 依赖：**

```xml
<dependency>
    <groupId>org.apache.kafka</groupId>
    <artifactId>kafka-clients</artifactId>
    <version>3.8.0</version>
</dependency>
```

---

#### 3.1.1 生产者（MyProducer）

生产者负责向 Kafka Topic 发送消息。核心步骤：**配置参数 → 创建 KafkaProducer 实例 → 构建 ProducerRecord → 发送消息**。

**示例代码：**

```java
package com.example.basic;

import org.apache.kafka.clients.producer.*;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

public class MyProducer {
    private static final String BOOTSTRAP_SERVERS = "localhost:9092,localhost:9092,localhost:9094";
    private static final String TOPIC = "disTopic";

    public static void main(String[] args) throws ExecutionException, InterruptedException {
        // 1. 配置生产者参数
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringSerializer");
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringSerializer");

        // 2. 创建生产者实例
        Producer<String, String> producer = new KafkaProducer<>(props);

        // 3. 发送消息
        for (int i = 0; i < 1000; i++) {
            ProducerRecord<String, String> record =
                    new ProducerRecord<>(TOPIC, Integer.toString(i), "value" + i);
            RecordMetadata metadata = producer.send(record).get();

            System.out.println("topic:" + metadata.topic()
                    + " partition:" + metadata.partition()
                    + " offset:" + metadata.offset()
                    + " message:" + metadata);
        }

        // 4. 关闭生产者（释放资源）
        producer.close();
    }
}
```

**关键配置说明：**

| 配置项 | 说明 |
|--------|------|
| `BOOTSTRAP_SERVERS_CONFIG` | Kafka 集群地址列表，多个地址用逗号分隔。生产者会通过该地址获取集群元数据 |
| `KEY_SERIALIZER_CLASS_CONFIG` | Key 的序列化器。消息在网络上传输必须是字节数组，StringSerializer 将 String 转为 byte[] |
| `VALUE_SERIALIZER_CLASS_CONFIG` | Value 的序列化器，同上 |

**发送方式说明：**

- **同步发送**：`producer.send(record).get()` — 调用 `get()` 阻塞等待 Broker 响应，返回 `RecordMetadata`（包含 topic、partition、offset 等信息）。适合需要确保消息已写入的场景，但吞吐量较低。
- **异步发送**：`producer.send(record, callback)` — 传入 `Callback` 回调，不阻塞主线程，Broker 响应后触发回调。适合高吞吐场景。

---

#### 3.1.2 消费者（MyConsumer）

消费者从 Kafka Topic 拉取消息。核心步骤：**配置参数 → 创建 KafkaConsumer 实例 → 订阅 Topic → 轮询拉取消息 → 提交位移**。

**示例代码：**

```java
package com.example.basic;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class MyConsumer {
    private static final String BOOTSTRAP_SERVERS = "localhost:9092,localhost:9092,localhost:9094";
    private static final String TOPIC = "disTopic";
    private static final String GROUP_ID = "disGroup";

    public static void main(String[] args) {
        // 1. 配置消费者参数
        Properties props = new Properties();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        props.put(ConsumerConfig.GROUP_ID_CONFIG, GROUP_ID);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringDeserializer");
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringDeserializer");

        // 2. 创建消费者实例
        KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);

        // 3. 订阅 Topic
        consumer.subscribe(Collections.singletonList(TOPIC));

        try {
            // 4. 轮询拉取消息
            while (true) {
                ConsumerRecords<String, String> records =
                        consumer.poll(Duration.ofMillis(1000));
                for (ConsumerRecord<String, String> record : records) {
                    System.out.println("topic:" + record.topic()
                            + " partition:" + record.partition()
                            + " offset:" + record.offset()
                            + " key:" + record.key()
                            + " value:" + record.value());
                }
                // 5. 同步提交位移
                consumer.commitSync();
            }
        } finally {
            // 6. 关闭消费者
            consumer.close();
        }
    }
}
```

**关键配置说明：**

| 配置项 | 说明 |
|--------|------|
| `BOOTSTRAP_SERVERS_CONFIG` | Kafka 集群地址，与生产者相同 |
| `GROUP_ID_CONFIG` | 消费者组 ID。同一个组内的消费者共享消费进度，每个分区只会被组内一个消费者消费 |
| `KEY_DESERIALIZER_CLASS_CONFIG` | Key 的反序列化器，与生产者的序列化器对应 |
| `VALUE_DESERIALIZER_CLASS_CONFIG` | Value 的反序列化器，与生产者的序列化器对应 |

**消费流程核心要点：**

| 步骤 | 方法 | 说明 |
|------|------|------|
| 订阅 | `subscribe()` | 订阅一个或多个 Topic。消费者会加入 Consumer Group，由 Group Coordinator 分配分区 |
| 拉取 | `poll(Duration)` | 轮询拉取消息，参数为超时时间。返回 `ConsumerRecords`，可能包含多个分区的多条消息 |
| 处理 | 遍历 `records` | 逐条处理消息，可从 `ConsumerRecord` 获取 topic、partition、offset、key、value |
| 提交位移 | `commitSync()` | **同步提交**当前消费到的 Offset，阻塞直到 Broker 确认。保证位移提交成功，但影响吞吐量 |

> **位移提交的两种方式：**
> - **同步提交** `commitSync()`：阻塞等待 Broker 确认，可靠性高但会降低吞吐量。示例中使用此方式，适合对一致性要求高的场景。
> - **异步提交** `commitAsync()`：不阻塞，提交后立即返回，吞吐量高但不保证提交一定成功。适合高吞吐、可容忍少量重复消费的场景。
> - **自动提交**：设置 `enable.auto.commit=true`（默认），由消费者后台定时自动提交，最简单但可能造成重复消费。

---

#### 3.1.3 生产者与消费者对应关系

| 维度 | 生产者（Producer） | 消费者（Consumer） |
|------|-------------------|-------------------|
| 核心类 | `KafkaProducer` | `KafkaConsumer` |
| 序列化 | `StringSerializer`（Key / Value） | `StringDeserializer`（Key / Value） |
| 关键操作 | `send()` 发送消息 | `poll()` 拉取消息 |
| 数据载体 | `ProducerRecord` | `ConsumerRecord` |
| 元数据 | `RecordMetadata`（topic / partition / offset） | `ConsumerRecord` 自带（topic / partition / offset / key / value） |
| 连接地址 | `BOOTSTRAP_SERVERS_CONFIG` | `BOOTSTRAP_SERVERS_CONFIG` |
| 组概念 | 无 | 必须有 `GROUP_ID_CONFIG`（属于某个消费者组） |
| 位移管理 | 无需关心 | 需要提交 Offset（`commitSync` / `commitAsync` / 自动提交） |

> **总结**：生产者和消费者通过 **Topic** 解耦，配置项对称（序列化 ↔ 反序列化），消费者多了**消费者组**和**位移提交**两个关键概念。掌握了这两个基础类，就掌握了 Kafka Java 客户端的核心用法。

### 3.2 消费者与消费者组详解

消费者（Consumer）是 Kafka 消息的接收方。与生产者直接指定分区不同，消费者是通过**消费者组（Consumer Group）**来管理和协调消息消费的。理解消费者组的工作原理，是掌握 Kafka 的关键。

---

#### 3.2.1 消费者组架构模型

Kafka 的消费者组采用**队列模式 + 发布/订阅模式的混合模型**：

```
                          Broker（集群）
              ┌─────────────────────────────────┐
              │         Topic: disTopic          │
              │  P0    P1    P2    P3  （4 分区）│
              └────┬────┬────┬────┬─────────────┘
                   │    │    │    │
         ┌─────────┼────┼────┼────┼─────────────┐
         │         ▼    ▼    ▼    ▼              │
         │   Consumer Group: group-A             │
         │   ┌──────┐  ┌──────┐                 │
         │   │  C1  │  │  C2  │                 │
         │   │P0 P1 │  │P2 P3 │  ← 分区互斥分配  │
         │   └──────┘  └──────┘                 │
         └──────────────────────────────────────┘
         ┌──────────────────────────────────────┐
         │   Consumer Group: group-B             │
         │   ┌──────┐                            │
         │   │  C3  │                            │
         │   │P0-P3 │  ← 独立消费，不受 group-A 影响│
         │   └──────┘                            │
         └──────────────────────────────────────┘
```

**核心规则：**

| 规则 | 说明 |
|------|------|
| **分区互斥** | 同一个 Consumer Group 内，一个 Partition 最多只能被一个 Consumer 消费 |
| **一对多** | 一个 Consumer 可以同时消费多个 Partition |
| **组间独立** | 不同 Consumer Group 之间完全独立，各自维护自己的消费进度（Offset），互不影响 |
| **消费者 ≤ 分区数** | 当组内消费者数量 > 分区数时，多余的消费者将处于**空闲状态**，不消费任何消息 |
| **消费者 > 分区数** | 当组内消费者数量 < 分区数时，部分消费者需要同时消费多个分区 |

---

#### 3.2.2 分区分配策略（Partition Assignment Strategy）

当消费者加入或离开消费者组时，Kafka 的 **Group Coordinator** 会触发 **Rebalance（重平衡）**，将分区重新分配给组内的消费者。Kafka 提供了多种分区分配策略：

##### 3.2.2.1 Range 策略（默认）

Range 策略按**分区序号连续**分配，将每个 Topic 的分区按序号范围分配给消费者。

```
Topic: disTopic（4 个分区：P0 P1 P2 P3），2 个消费者 C1、C2

分配过程：
  分区总数 / 消费者数 = 4 / 2 = 2 个/人

  C1 → P0, P1  （前 2 个分区）
  C2 → P2, P3  （后 2 个分区）
```

**配置方式：**

```java
props.put(ConsumerConfig.PARTITION_ASSIGNMENT_STRATEGY_CONFIG,
        "org.apache.kafka.clients.consumer.RangeAssignor");
```

**特点：** 简单直观，但当 Topic 数量多时可能导致分配不均（每个 Topic 独立按 Range 分配，可能导致某些消费者总是分配到更多分区）。

##### 3.2.2.2 RoundRobin 策略

RoundRobin 将**所有订阅 Topic 的所有分区**统一排序后，**轮询**分配给消费者。

```
Topic-A（2 分区：A0 A1），Topic-B（2 分区：B0 B1），2 个消费者 C1、C2

统一排序：[A0, A1, B0, B1]

轮询分配：
  A0 → C1, A1 → C2, B0 → C1, B1 → C2

结果：
  C1 → A0, B0
  C2 → A1, B1
```

**配置方式：**

```java
props.put(ConsumerConfig.PARTITION_ASSIGNMENT_STRATEGY_CONFIG,
        "org.apache.kafka.clients.consumer.RoundRobinAssignor");
```

**特点：** 分配更加均匀，但如果消费者订阅的 Topic 不同，轮询会出问题，需要所有消费者订阅相同的 Topic 集合。

##### 3.2.2.3 Sticky 策略

Sticky（粘性）策略在**保证均匀分配**的同时，**尽量保持原有分配不变**，减少 Rebalance 时不必要的分区迁移。

```
初始分配（2 消费者，4 分区）：
  C1 → P0, P1
  C2 → P2, P3

C2 宕机后 → Rebalance：
  Range：  C1 → P0, P1, P2, P3  （全量重新分配）
  Sticky： C1 → P0, P1, P2, P3  （C1 保留原有的 P0, P1，只接管 P2, P3）

C3 加入后 → Rebalance：
  Sticky 尽量保持 P0,P1 仍在 C1 上，只迁移部分分区给 C3
```

**配置方式：**

```java
props.put(ConsumerConfig.PARTITION_ASSIGNMENT_STRATEGY_CONFIG,
        "org.apache.kafka.clients.consumer.StickyAssignor");
```

##### 3.2.2.4 CooperativeSticky 策略（推荐）

CooperativeSticky 是 Sticky 的**渐进式**版本，Rebalance 时分多轮执行：第一轮先撤销不需要的分区，第二轮再分配新分区。在整个过程中，**不需要停止消费**。

```java
props.put(ConsumerConfig.PARTITION_ASSIGNMENT_STRATEGY_CONFIG,
        "org.apache.kafka.clients.consumer.CooperativeStickyAssignor");
```

**四种策略对比：**

| 维度 | Range | RoundRobin | Sticky | CooperativeSticky |
|------|-------|------------|--------|-------------------|
| 分配依据 | 分区序号连续 | 全局轮询 | 均匀 + 尽量保留 | 均匀 + 尽量保留 |
| 均匀性 | 一般（多 Topic 时可能倾斜） | 好 | 好 | 好 |
| Rebalance 迁移量 | 可能较大 | 可能较大 | 小 | 小 |
| Rebalance 时是否停消费 | 是（Eager） | 是（Eager） | 是（Eager） | **否（Cooperative）** |
| 推荐场景 | 单 Topic | 多 Topic、订阅一致 | 需要减少迁移开销 | **生产环境推荐** |

---

#### 3.2.3 Rebalance（重平衡）机制

Rebalance 是消费者组内分区重新分配的过程。当消费者组发生以下变化时触发：

**触发条件：**

| 条件 | 说明 |
|------|------|
| **消费者加入** | 新消费者加入消费者组，需要重新分配分区以实现负载均衡 |
| **消费者离开** | 消费者主动关闭或崩溃，其负责的分区需要转给其他消费者 |
| **消费者超时** | 消费者长时间未发送心跳（`session.timeout.ms`），被 Coordinator 踢出 |
| **Topic 分区数变化** | 管理员增加了 Topic 的分区数 |
| **消费者取消订阅** | 消费者取消对某些 Topic 的订阅 |

**Rebalance 流程：**

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────┐
│  Consumer 1  │     │ Group Coordinator│     │  Consumer 2  │
└──────┬───────┘     └────────┬────────┘     └──────┬───────┘
       │                      │                     │
       │  ① JoinGroup请求     │                     │
       │─────────────────────►│                     │
       │                      │  ② JoinGroup请求     │
       │                      │◄─────────────────────│
       │                      │                     │
       │  ③ 选举Leader Consumer                     │
       │                      │                     │
       │  ④ 发送分区分配方案   │                     │
       │◄─────────────────────│                     │
       │                      │                     │
       │  ⑤ SyncGroup（同步分配结果）                │
       │─────────────────────►│                     │
       │                      │◄────────────────────│
       │                      │                     │
       │  ⑥ 开始消费新分区     │                     │
       │◄─────────────────────│────────────────────►│
```

**关键流程说明：**

1. **JoinGroup**：所有消费者向 Group Coordinator 发送 JoinGroup 请求。
2. **选举 Leader Consumer**：Coordinator 选择一个消费者作为 Group Leader（第一个发送 JoinGroup 的消费者）。
3. **Leader 制定分配方案**：Coordinator 将组内消费者信息和分区信息发给 Leader，Leader 根据分配策略制定方案。
4. **SyncGroup**：Leader 将分配方案发给 Coordinator，Coordinator 再分发给所有消费者。
5. **开始消费**：每个消费者根据分配结果，消费自己负责的分区。

**相关超时参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `session.timeout.ms` | 45s（新版本） | 消费者与 Coordinator 的会话超时。超时未收到心跳，消费者被踢出组，触发 Rebalance |
| `heartbeat.interval.ms` | 3s | 心跳间隔，建议设为 `session.timeout.ms` 的 1/3 |
| `max.poll.interval.ms` | 5min | 两次 poll 的最大间隔。超过此时间未 poll，消费者被认为"卡住"，触发 Rebalance |
| `group.initial.rebalance.delay.ms` | 3s | 首次 Rebalance 的延迟等待时间，等待更多消费者加入后再一起分配 |

> **生产建议**：适当调大 `session.timeout.ms` 和 `max.poll.interval.ms` 可以避免因 GC 停顿或短暂处理延迟导致的非必要 Rebalance。

---

#### 3.2.4 位移（Offset）管理

Kafka 不像传统 MQ 那样由 Broker 记录消息是否被消费，而是由**消费者自己记录消费到哪个 Offset 了**，这个过程叫「提交位移」。位移保存在 Kafka 内部的 `__consumer_offsets` Topic 中。

##### 3.2.4.1 自动提交

```java
// 开启自动提交（默认即为 true）
props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, true);
// 自动提交间隔，默认 5s
props.put(ConsumerConfig.AUTO_COMMIT_INTERVAL_MS_CONFIG, 5000);
```

```
时间线：
  poll() ── 处理消息 ── 5s后自动提交 ── poll() ── 处理消息
                              ↑
                    提交的是上次 poll 的 Offset
                    而不是当前处理到的位置！
```

| 优点 | 缺点 |
|------|------|
| 使用简单，无需手动编码 | 可能重复消费：如果处理完消息后、自动提交前宕机，重启后会重新消费 |
| 适合对一致性要求不高的场景 | 可能丢失消息：如果自动提交后、处理完消息前宕机，消息被认为已消费但实际未处理完 |

##### 3.2.4.2 同步提交（commitSync）

```java
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000));
    for (ConsumerRecord<String, String> record : records) {
        // 逐条处理业务逻辑
        processRecord(record);
    }
    // 处理完一批后，同步提交位移
    consumer.commitSync();  // 阻塞直到 Broker 确认成功（或抛异常）
}
```

```
时间线：
  poll() ── 处理消息 ── commitSync()（阻塞等待确认）── poll() ── ...
                            ↑
                    阻塞直到 Broker 返回成功
```

| 优点 | 缺点 |
|------|------|
| 可靠性高：位移一定提交成功后才继续 | 阻塞等待，影响吞吐量 |
| 失败时可立即重试或处理异常 | 如果处理完消息后、commitSync 前宕机，重启后仍会重复消费 |

##### 3.2.4.3 异步提交（commitAsync）

```java
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000));
    for (ConsumerRecord<String, String> record : records) {
        processRecord(record);
    }
    // 异步提交，不阻塞
    consumer.commitAsync((offsets, exception) -> {
        if (exception != null) {
            // 提交失败的处理逻辑（如记录日志、重试）
            System.err.println("Commit failed for offsets: " + offsets + ", error: " + exception.getMessage());
        } else {
            System.out.println("Commit succeeded: " + offsets);
        }
    });
}
```

```
时间线：
  poll() ── 处理消息 ── commitAsync()（立即返回）── poll() ── ...
                            ↑
                    不等待 Broker 确认，回调通知结果
```

| 优点 | 缺点 |
|------|------|
| 不阻塞，吞吐量高 | 提交可能失败，且回调是异步的，不便重试 |
| 适合高吞吐场景 | 失败时可能导致重复消费 |

##### 3.2.4.4 按分区粒度提交

```java
// 按分区精确提交位移
for (TopicPartition partition : records.partitions()) {
    List<ConsumerRecord<String, String>> partitionRecords = records.records(partition);
    long lastOffset = partitionRecords.get(partitionRecords.size() - 1).offset();
    // 提交该分区的 offset + 1（表示下一条要消费的位置）
    consumer.commitSync(Collections.singletonMap(partition, new OffsetAndMetadata(lastOffset + 1)));
}
```

##### 3.2.4.5 三种提交方式对比

| 方式 | 阻塞 | 可靠性 | 吞吐量 | 适用场景 |
|------|------|--------|--------|----------|
| 自动提交 | 否 | 低 | 高 | 日志采集、监控数据等可容忍少量丢失/重复的场景 |
| commitSync | 是 | 高 | 低 | 订单、支付等对一致性要求高的场景 |
| commitAsync | 否 | 中 | 高 | 高吞吐 + 可容忍少量重复的场景 |

> **最佳实践**：正常消费过程中使用 `commitAsync` 提高吞吐，在消费者关闭前使用 `commitSync` 做最后一次可靠提交，确保位移不丢失：
>
> ```java
> try {
>     while (true) {
>         // ... 处理消息 ...
>         consumer.commitAsync();  // 日常异步提交
>     } 
> } catch (Exception e) {
>     // 异常处理
> } finally {
>     try {
>         consumer.commitSync();  // 关闭前同步提交，确保位移落地
>     } finally {
>         consumer.close();
>     }
> }
> ```

---

#### 3.2.5 从指定位置开始消费

消费者默认从**上次提交的 Offset** 恢复消费。如果从未提交过，则根据 `auto.offset.reset` 配置决定：

```java
// earliest：从最早的消息开始消费（相当于 --from-beginning）
props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

// latest：从最新的消息开始消费（默认，只消费启动后的新消息）
props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "latest");

// none：如果未找到之前的 Offset，则抛出异常
props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "none");
```

**手动指定 Offset（Seek）：**

```java
// 订阅 Topic
consumer.subscribe(Collections.singletonList(TOPIC));

// 等待分区分配完成
consumer.poll(Duration.ofMillis(0));

// 获取已分配的分区列表
Set<TopicPartition> assignments = consumer.assignment();

// 方式1：从头开始消费（seekToBeginning）
consumer.seekToBeginning(assignments);

// 方式2：从末尾开始消费（seekToEnd）
consumer.seekToEnd(assignments);

// 方式3：指定某个分区的某个 Offset 开始
consumer.seek(new TopicPartition(TOPIC, 0), 100);  // 从分区 0 的 Offset=100 开始

// 方式4：根据时间戳查找 Offset，消费某个时间点之后的消息
Map<TopicPartition, Long> timestampsToSearch = new HashMap<>();
timestampsToSearch.put(new TopicPartition(TOPIC, 0), System.currentTimeMillis() - 3600_000);
Map<TopicPartition, OffsetAndTimestamp> offsetsForTimes = consumer.offsetsForTimes(timestampsToSearch);
for (Map.Entry<TopicPartition, OffsetAndTimestamp> entry : offsetsForTimes.entrySet()) {
    consumer.seek(entry.getKey(), entry.getValue().offset());
}
```

---

#### 3.2.6 消费者关键配置汇总

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `bootstrap.servers` | — | Kafka 集群地址 |
| `group.id` | — | **必填**，消费者组 ID |
| `key.deserializer` | — | **必填**，Key 反序列化器 |
| `value.deserializer` | — | **必填**，Value 反序列化器 |
| `enable.auto.commit` | `true` | 是否自动提交位移 |
| `auto.commit.interval.ms` | `5000` | 自动提交间隔（毫秒） |
| `auto.offset.reset` | `latest` | 无初始 Offset 时的策略：`earliest` / `latest` / `none` |
| `session.timeout.ms` | `45000` | 会话超时，超时未收到心跳触发 Rebalance |
| `heartbeat.interval.ms` | `3000` | 心跳发送间隔，建议为 session.timeout 的 1/3 |
| `max.poll.interval.ms` | `300000` | 两次 poll 最大间隔，超时触发 Rebalance |
| `max.poll.records` | `500` | 单次 poll 返回的最大记录数 |
| `fetch.min.bytes` | `1` | 单次 fetch 请求的最小数据量（字节），调大可减少请求次数 |
| `fetch.max.wait.ms` | `500` | fetch 请求最大等待时间，与 `fetch.min.bytes` 配合使用 |
| `partition.assignment.strategy` | `Range` | 分区分配策略，推荐 `CooperativeStickyAssignor` |

---

#### 3.2.7 多消费者场景验证

以下通过实际操作来验证消费者组的核心行为。假设 Topic `disTopic` 有 4 个分区：

**场景一：同组多消费者（负载均衡）**

```bash
# 终端1：启动消费者 C1（属于 disGroup）
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic disTopic --group disGroup

# 终端2：启动消费者 C2（也属于 disGroup）
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic disTopic --group disGroup
```

此时 4 个分区会分配给 C1 和 C2（例如各 2 个），每条消息只会被 C1 或 C2 中的一个消费。

```bash
# 查看消费者组状态
bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group disGroup
```

**场景二：不同组独立消费（发布/订阅）**

```bash
# 终端1：消费者属于 group-A
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic disTopic --group group-A

# 终端2：消费者属于 group-B
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic disTopic --group group-B
```

同一条消息在 group-A 和 group-B 中各被消费一次，两个组各自维护 Offset，互不影响。

**场景三：消费者多于分区数（部分空闲）**

```bash
# disTopic 有 4 个分区，启动 5 个同组消费者
# 其中 4 个消费者各分配 1 个分区，第 5 个消费者空闲
```

> **结论**：扩展消费者时不需要超过分区数，多余消费者只是浪费资源。合理规划分区数 = max（预期消费者数 × 2，吞吐需求 / 单分区吞吐）。

---

#### 3.2.8 小结

消费者与消费者组是 Kafka 最核心的设计之一，要点总结：

1. **消费者必须属于某个消费者组**（`group.id` 必填），同组内分区互斥分配，不同组间独立消费。
2. **Rebalance** 是分区的再分配过程，触发条件包括消费者加入/离开/超时。生产环境推荐使用 `CooperativeStickyAssignor` 策略减少 Rebalance 影响。
3. **位移管理** 有三种方式：自动提交（简单但有丢失/重复风险）、同步提交（可靠但慢）、异步提交（快但可能失败）。实际项目推荐「日常异步 + 关闭前同步」的组合策略。
4. **消费者数量 ≤ 分区数**，否则多余的消费者空闲。
5. 合理配置 `session.timeout.ms`、`max.poll.interval.ms` 等超时参数，避免非必要的 Rebalance。

### 3.3 拦截器（ProducerInterceptor）

Kafka 生产者拦截器（`ProducerInterceptor`）允许在消息发送流程的关键节点插入自定义逻辑，是一个典型的**责任链模式**实现。通过拦截器，可以在不修改业务代码的前提下，实现消息统一处理、监控、过滤等横切关注点。

---

#### 3.3.1 拦截器接口定义

`ProducerInterceptor<K, V>` 接口定义了 4 个方法，对应消息发送生命周期的不同阶段：

```java
public interface ProducerInterceptor<K, V> extends Configurable, Closeable {

    // 消息发送前调用 —— 可修改或过滤消息
    ProducerRecord<K, V> onSend(ProducerRecord<K, V> record);

    // Broker 确认后调用 —— 可记录发送结果
    void onAcknowledgement(RecordMetadata metadata, Exception exception);

    // 拦截器关闭时调用 —— 释放资源
    void close();

    // 初始化时调用 —— 获取配置参数
    void configure(Map<String, ?> configs);
}
```

**调用流程：**

```
生产者 send(record)
       │
       ▼
┌──────────────────────────────┐
│  拦截器链 onSend(record)      │  ← 可修改/过滤消息（责任链依次执行）
└──────────────┬───────────────┘
       │ 返回（可能被修改的）record
       ▼
┌──────────────────────────────┐
│  序列化器  Key/Value → byte[] │
└──────────────┬───────────────┘
       │
       ▼
┌──────────────────────────────┐
│  分区器  确定目标 Partition    │
└──────────────┬───────────────┘
       │
       ▼
┌──────────────────────────────┐
│  发送到 Broker                │
└──────────────┬───────────────┘
       │
       ▼  Broker 返回响应（或超时/异常）
       │
       ▼
┌──────────────────────────────┐
│  拦截器链 onAcknowledgement() │  ← 可记录发送结果（责任链依次执行）
└──────────────────────────────┘
```

---

#### 3.3.2 自定义拦截器示例

以下是一个完整的自定义拦截器实现：

```java
package com.example.basic.interceptor;

import org.apache.kafka.clients.producer.ProducerInterceptor;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;

import java.util.Map;

public class ProductInterceptor implements ProducerInterceptor<String, String> {

    /**
     * 初始化拦截器
     * 在 KafkaProducer 构造时调用，可获取生产者所有配置参数
     */
    @Override
    public void configure(Map<String, ?> configs) {
        System.out.println("---------初始化拦截器---------");
        configs.forEach((k, v) -> System.out.println(k + ":" + v));
        System.out.println("---------初始化完成---------");
    }

    /**
     * 消息发送前回调
     * 在序列化和分区计算之前执行
     * 返回 null 表示过滤掉该消息（不发送）
     * 返回新的 ProducerRecord 可修改消息内容
     */
    @Override
    public ProducerRecord<String, String> onSend(ProducerRecord<String, String> record) {
        System.out.println("拦截器开始工作:" + record.toString());
        // 【注意】返回 null 会将消息丢弃，不发送到 Broker
        // 如需正常发送，应 return record;
        return null;
    }

    /**
     * 消息发送后回调（收到 Broker 响应时触发）
     * 无论发送成功或失败都会调用，exception != null 表示发送失败
     */
    @Override
    public void onAcknowledgement(RecordMetadata metadata, Exception e) {
        System.out.println("收到服务器响应时触发" + metadata.toString());
    }

    /**
     * 关闭拦截器
     * 在 KafkaProducer.close() 时调用
     */
    @Override
    public void close() {
        System.out.println("关闭拦截器");
    }
}
```

**四个方法详解：**

| 方法 | 调用时机 | 返回值 | 典型用途 |
|------|----------|--------|----------|
| `configure(Map)` | KafkaProducer 构造时，最早调用 | void | 读取配置、初始化资源（连接池、计数器等） |
| `onSend(record)` | `send()` 调用后，**序列化之前** | `ProducerRecord` 或 `null` | 修改消息内容（追加 Header）、**消息过滤**、统一日志记录 |
| `onAcknowledgement(metadata, exception)` | 收到 Broker 响应后（异步） | void | 统计发送成功率/延迟、异常告警 |
| `close()` | `producer.close()` 时 | void | 清理资源、刷新缓冲区、上报最终统计 |

---

#### 3.3.3 在生产者中注册拦截器

在 `MyProducer` 中通过 `ProducerConfig.INTERCEPTOR_CLASSES_CONFIG` 注册拦截器：

```java
// 注册拦截器（多个拦截器用逗号分隔，按注册顺序依次执行）
props.put(ProducerConfig.INTERCEPTOR_CLASSES_CONFIG,
        "com.example.basic.interceptor.ProductInterceptor");
```

完整配置示例：

```java
public class MyProducer {
    private static final String BOOTSTRAP_SERVERS = "localhost:9092,localhost:9092,localhost:9094";
    private static final String TOPIC = "disTopic";

    public static void main(String[] args) throws ExecutionException, InterruptedException {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        // ★ 注册自定义拦截器
        props.put(ProducerConfig.INTERCEPTOR_CLASSES_CONFIG,
                "com.example.basic.interceptor.ProductInterceptor");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringSerializer");
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringSerializer");

        Producer<String, String> producer = new KafkaProducer<>(props);
        // ... 发送消息 ...
        producer.close();
    }
}
```

---

#### 3.3.4 拦截器链的执行机制

可以同时注册**多个拦截器**，Kafka 会按注册顺序构建**责任链**：

```java
// 注册两个拦截器（按顺序执行）
props.put(ProducerConfig.INTERCEPTOR_CLASSES_CONFIG,
        "com.example.basic.interceptor.InterceptorA,"
        + "com.example.basic.interceptor.InterceptorB");
```

**责任链执行流程：**

```
send(record)
    │
    ▼
InterceptorA.onSend(record)  ──→ 返回 recordA（或 null 终止）
    │
    ▼
InterceptorB.onSend(recordA) ──→ 返回 recordB（或 null 终止）
    │
    ▼
序列化 → 分区 → 发送到 Broker
    │
    ▼ Broker 响应
    │
    ▼
InterceptorB.onAcknowledgement()  ← 先注册的后执行（栈式）
    │
    ▼
InterceptorA.onAcknowledgement()  ← 后注册的先执行（栈式）
```

> **注意两点**：
> - `onSend` 按注册顺序执行（A → B），如果任一拦截器返回 `null`，消息被丢弃，后续拦截器和实际发送都不会执行。
> - `onAcknowledgement` 按注册**逆序**执行（B → A），类似栈的 FILO 顺序。

---

#### 3.3.5 拦截器的典型应用场景

| 场景 | 实现位置 | 示例 |
|------|----------|------|
| **消息审计日志** | `onSend` | 记录每条消息的 topic、key、timestamp 到日志系统 |
| **消息过滤/限流** | `onSend` 返回 `null` | 根据 key 或 value 前缀过滤不需要发送的消息；或按速率丢弃超限消息 |
| **消息增强** | `onSend` 修改 record | 自动添加 traceId Header、补充时间戳、注入来源系统标识 |
| **发送监控** | `onAcknowledgement` | 统计成功/失败次数、计算发送延迟（P99/P50）、采集异常信息 |
| **业务告警** | `onAcknowledgement` | 发送失败时触发钉钉/邮件告警 |

---

#### 3.3.6 注意事项

1. **`onSend` 返回 `null` 会丢弃消息**：如果只是想记录日志而不修改消息，务必 `return record`（原样返回），而不是 `return null`。
2. **`onAcknowledgement` 在异步线程执行**：不要在这个方法中做耗时操作，否则会阻塞其他消息的回调处理。
3. **拦截器实例是单例的**：每个 KafkaProducer 实例对应一组拦截器实例，需要保证线程安全（`onAcknowledgement` 可能与 `onSend` 并发执行）。
4. **异常处理**：如果拦截器中抛出未捕获异常，可能导致生产者关闭，建议在拦截器方法中做好 try-catch。
5. **`configure` 中可以获取敏感信息**：遍历 `configs` 打印时要谨慎，避免将密码、密钥等敏感信息输出到日志。

> **生产实践**：通常将拦截器用于**日志记录**和**监控打点**，不用于核心业务逻辑。对于消息过滤和增强等操作，推荐使用独立的处理层，保持拦截器职责单一。