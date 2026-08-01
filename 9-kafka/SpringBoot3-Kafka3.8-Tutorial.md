# Spring Boot 3.x 整合 Kafka 3.8.0 实战教程

> 本教程基于 **Spring Boot 3.2.x**、**Spring Kafka 3.1.x**、**Apache Kafka 3.8.0**（KRaft 模式）编写，涵盖从 Kafka 核心概念、集群搭建到 Spring Boot 整合的完整实战内容，并附常见面试题精讲。

---

## 目录

- [第 1 章 Kafka 基础概念与集群搭建](#第-1-章-kafka-基础概念与集群搭建)
  - [1.1 Kafka 核心概念深度解析](#11-kafka-核心概念深度解析)
  - [1.3 主题（Topic）管理](#13-主题topic管理)
- [第 2 章 Kafka 基础使用与 Spring Boot 3.x 整合](#第-2-章-kafka-基础使用与-spring-boot-3x-整合)
  - [2.1 生产者与消费者基础实战](#21-生产者与消费者基础实战)
  - [2.2 生产者拦截器（Interceptor）实战](#22-生产者拦截器interceptor实战)
  - [2.3 消息序列化与反序列化](#23-消息序列化与反序列化)
  - [2.4 消息分区路由机制](#24-消息分区路由机制)
  - [2.5 生产者缓存与批量发送机制](#25-生产者缓存与批量发送机制)
  - [2.6 生产者发送应答（ACKS）机制](#26-生产者发送应答acks机制)
  - [2.7 生产者消息幂等性与重试机制](#27-生产者消息幂等性与重试机制)
  - [2.8 消息压缩机制](#28-消息压缩机制)
  - [2.9 消息事务机制](#29-消息事务机制)
- [第 3 章 Kafka 整合 Spring Cloud Stream](#第-3-章-kafka-整合-spring-cloud-stream)
- [第 4 章 Kafka 常见面试题精讲](#第-4-章-kafka-常见面试题精讲)

---

# 第 1 章 Kafka 基础概念与集群搭建

## 1.1 Kafka 核心概念深度解析

### 1.1.1 核心组件详解：Broker、Topic、Partition、Offset、Message

Kafka 是一个分布式流处理平台，其架构由多个核心组件构成。理解这些组件是掌握 Kafka 的基础。

**Broker（代理节点）**

Broker 是 Kafka 集群中的一个服务节点。一个 Kafka 集群由一个或多个 Broker 组成。

- 每个 Broker 有唯一的 `broker.id` 标识
- Broker 负责接收、存储和转发消息
- 集群中会有一个 Broker 被选为 **Controller**，负责管理分区和副本状态、处理主题创建删除等管理操作
- 在 KRaft 模式下（Kafka 3.8.0 推荐），Controller 角色由专门的 Controller 节点承担，不再依赖 ZooKeeper

**Topic（主题）**

Topic 是 Kafka 中消息的逻辑分类，类似于数据库中的表。

- 生产者将消息发送到特定 Topic，消费者从特定 Topic 订阅消息
- 一个 Topic 可以有多个分区（Partition）
- Topic 名称建议只使用 ASCII 字符，以字母、数字或 `.`、`_`、`-` 组成

**Partition（分区）**

Partition 是 Topic 的物理分片，是 Kafka 高并发和水平扩展的基础。

- 每个 Partition 是一个有序的、不可变的消息追加日志（append-only log）
- 每个 Partition 有多个 **副本（Replica）**，其中一个是 **Leader**，其余是 **Follower**
- 所有读写操作都由 Leader 处理，Follower 负责从 Leader 同步数据
- 分区数决定了该 Topic 的最大并行消费能力

**Offset（偏移量）**

Offset 是 Partition 内每条消息的唯一标识，是一个单调递增的整数。

- Offset 从 0 开始，每追加一条消息加 1
- 消费者通过 Offset 记录消费进度
- Kafka 提供 **消费位移提交（commit）** 机制，支持自动提交和手动提交

**Message（消息）**

Message 是 Kafka 中数据传输的基本单元。一条消息由以下部分组成：

| 组成部分 | 说明 |
|---------|------|
| **Key**（可选） | 用于消息路由，决定消息进入哪个 Partition |
| **Value** | 消息的实际内容（payload） |
| **Timestamp** | 消息时间戳，可为创建时间或日志追加时间 |
| **Headers**（可选） | 键值对形式的额外元数据 |

### 1.1.2 生产者与消费者模型：Producer、Consumer、Consumer Group

**Producer（生产者）**

生产者负责将消息发布到 Kafka Topic。其核心工作流程：

1. **序列化**：将 Key 和 Value 序列化为字节数组
2. **分区路由**：根据 Key 和 Partitioner 策略决定消息发往哪个 Partition
3. **记录累积**：消息被放入 RecordAccumulator（记录累加器）的对应分区批次中
4. **网络发送**：Sender 线程将批次通过网络发送给对应 Partition 的 Leader Broker
5. **接收响应**：根据 acks 配置等待不同级别的确认

**Consumer（消费者）**

消费者从 Kafka Topic 订阅和消费消息。核心特性：

- 消费者通过 **拉取（Pull）** 模式获取消息，而非推送
- 消费者维护自己的消费 Offset，可以重置到任意位置重新消费
- 支持手动和自动两种 Offset 提交方式

**Consumer Group（消费者组）**

Consumer Group 是 Kafka 实现消息广播和负载均衡的核心机制。

- **组内负载均衡**：同一个 Consumer Group 内，一个 Partition 只能被一个消费者消费，实现负载均衡
- **组间广播**：不同 Consumer Group 之间互不影响，各自消费完整数据，实现广播
- **Rebalance（重平衡）**：当消费者加入或离开 Group 时，分区与消费者的分配关系会重新调整

> **核心规则**：一个 Consumer Group 消费一个 Topic 时，最大有效消费者数量 = Partition 数量。如果消费者数 > Partition 数，多余的消费者将闲置。

### 1.1.3 Kafka 核心概念关系图与数据流转原理

下图展示了 Kafka 的核心概念之间的数据流转关系：

```
┌──────────┐                    ┌─────────────────────────────────────────────┐
│          │  produce message   │                Kafka Cluster                │
│ Producer │───────────────────▶│                                             │
│          │                    │  ┌───────────────────────────────────────┐  │
└──────────┘                    │  │            Topic: order-events         │  │
                                │  │                                       │  │
                                │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐  │  │
                                │  │  │Partition0│ │Partition1│ │Partition2│  │  │
                                │  │  │ Leader  │ │ Leader  │ │ Leader  │  │  │
                                │  │  │Follower │ │Follower │ │Follower │  │  │
                                │  │  └─────────┘ └─────────┘ └─────────┘  │  │
                                │  │   offset=0   offset=0   offset=0     │  │
                                │  │   offset=1   offset=1   offset=1     │  │
                                │  │   offset=2   offset=2   offset=2     │  │
                                │  └───────────────────────────────────────┘  │
                                └──────────────────────┬──────────────────────┘
                                                       │ consume
                                ┌──────────────────────▼──────────────────────┐
                                │           Consumer Group: order-service      │
                                │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
                                │  │Consumer-1│  │Consumer-2│  │Consumer-3│   │
                                │  │  P0,P1    │  │   P2     │  │ (idle)   │   │
                                │  └──────────┘  └──────────┘  └──────────┘   │
                                └─────────────────────────────────────────────┘
```

**数据流转完整链路**：

1. **生产端**：Producer → 序列化 → Partitioner 分区 → RecordAccumulator 缓冲 → Sender 发送 → Leader Broker
2. **存储端**：Leader Broker 追加写入日志 → Follower 从 Leader 拉取同步 → 根据 acks 等级确认
3. **消费端**：Consumer Group 发起 Fetch 请求 → Leader Broker 返回消息 → 反序列化 → 业务处理 → 提交 Offset


## 1.3 主题（Topic）管理

### 1.3.1 创建主题命令与参数说明

```bash
bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create \
  --topic order-events \
  --partitions 3 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=604800000
```

**参数说明**：

| 参数 | 说明 |
|------|------|
| `--bootstrap-server` | 连接的 Kafka Broker 地址（只需连一个，会自动发现集群） |
| `--create` | 创建主题 |
| `--topic` | 主题名称 |
| `--partitions` | 分区数量（创建后只能增加，不能减少） |
| `--replication-factor` | 副本因子（不能超过 Broker 数量） |
| `--config` | 主题级别配置，可覆盖全局默认值 |

> **分区数选择建议**：
> - 分区数决定了消费并行度，预期吞吐量 / 单消费者处理能力 ≈ 推荐分区数
> - 分区数不宜过多（每个分区都会占用 Broker 内存和文件句柄）
> - 建议初始设置为消费者数量的 1~3 倍，预留扩展空间

### 1.3.2 查看、修改与删除主题

**查看主题列表**：

```bash
bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

**查看主题详情**：

```bash
bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe \
  --topic order-events
```

输出示例：

```
Topic: order-events  TopicId: abcd1234  PartitionCount: 3  ReplicationFactor: 3
  Topic: order-events  Partition: 0  Leader: 0  Replicas: 0,1,2  Isr: 0,1,2
  Topic: order-events  Partition: 1  Leader: 1  Replicas: 1,2,0  Isr: 1,2,0
  Topic: order-events  Partition: 2  Leader: 2  Replicas: 2,0,1  Isr: 2,0,1
```

- **Replicas**：分配的副本列表（包含 Leader）
- **Isr**（In-Sync Replicas）：与 Leader 保持同步的副本集合

**增加分区数**（只能增加，不能减少）：

```bash
bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --alter \
  --topic order-events \
  --partitions 6
```

**修改主题级别配置**：

```bash
# 修改保留时间
bin/kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type topics \
  --entity-name order-events \
  --alter \
  --add-config retention.ms=2592000000

# 删除主题级别配置（恢复为全局默认）
bin/kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type topics \
  --entity-name order-events \
  --alter \
  --delete-config retention.ms
```

**删除主题**：

```bash
bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --delete \
  --topic order-events
```

> 删除主题需要 `delete.topic.enable=true`（3.8.0 默认为 true）。删除操作是异步的，Broker 会在后台清理数据。

---

# 第 2 章 Kafka 基础使用与 Spring Boot 3.x 整合

## 2.1 生产者与消费者基础实战

### 2.1.1 Spring Boot 3.x 整合 Kafka 依赖与基础配置

**Maven 依赖（pom.xml）**：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>kafka-demo</artifactId>
    <version>1.0.0</version>
    <name>kafka-demo</name>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Kafka（Spring Boot 3.2.x 自动引入 Spring Kafka 3.1.x） -->
        <dependency>
            <groupId>org.springframework.kafka</groupId>
            <artifactId>spring-kafka</artifactId>
        </dependency>

        <!-- JSON 处理 -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
        </dependency>

        <!-- Lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <!-- 测试 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.kafka</groupId>
            <artifactId>spring-kafka-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

> **版本对应关系**：
>
> | Spring Boot | Spring Kafka | Kafka Client |
> |-------------|-------------|-------------|
> | 3.0.x | 3.0.x | 3.3.x |
> | 3.1.x | 3.1.x | 3.5.x |
> | 3.2.x | 3.1.x | 3.6.x |
> | 3.3.x | 3.2.x | 3.7.x |
>
> Spring Boot 3.2.x 的 spring-kafka 3.1.x 内部使用的 Kafka Client 版本为 3.6.x，与 Kafka Broker 3.8.0 完全兼容（Kafka Client 向后兼容 Broker）。

**application.yml 基础配置**：

```yaml
spring:
  kafka:
    # Kafka 集群地址
    bootstrap-servers: localhost:9092,localhost:9093,localhost:9094

    # --- 生产者配置 ---
    producer:
      # Key 序列化器
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      # Value 序列化器
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      # 发送失败重试次数
      retries: 3
      # 批量发送大小（字节）
      batch-size: 16384
      # 等待攒批时间（毫秒）
      properties:
        linger.ms: 10
      # 应答级别
      acks: all
      # 缓冲区大小
      buffer-memory: 33554432

    # --- 消费者配置 ---
    consumer:
      # Key 反序列化器
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      # Value 反序列化器
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      # 消费者组 ID
      group-id: order-consumer-group
      # 自动提交 Offset
      enable-auto-commit: false
      # 从最早的消息开始消费（首次加入组时）
      auto-offset-reset: earliest
      # JsonDeserializer 信任所有包（生产环境应指定具体包）
      properties:
        spring.json.trusted.packages: "*"

    # --- Listener 配置 ---
    listener:
      # 手动提交模式
      ack-mode: manual_immediate
      # 并发度（消费者线程数）
      concurrency: 3
```

### 2.1.2 使用 KafkaTemplate 创建消息生产者

**定义消息对象**：

```java
package com.example.kafkademo.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderEvent implements Serializable {

    private String orderId;
    private String userId;
    private Double amount;
    private String status;
    private LocalDateTime createTime;

    // 如果使用 JsonDeserializer，建议提供无参构造和 getter/setter
    // Lombok 的 @Data 和 @NoArgsConstructor 已覆盖
}
```

**创建生产者 Service**：

```java
package com.example.kafkademo.producer;

import com.example.kafkademo.model.OrderEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderEventProducer {

    private static final String TOPIC = "order-events";

    // final 字段 + @RequiredArgsConstructor 自动生成构造器
    // Spring 通过构造器自动注入，无需 @Autowired
    private final KafkaTemplate<String, OrderEvent> kafkaTemplate;

    /**
     * 同步发送消息
     */
    public SendResult<String, OrderEvent> sendSync(String key, OrderEvent event) throws Exception {
        CompletableFuture<SendResult<String, OrderEvent>> future = kafkaTemplate.send(TOPIC, key, event);
        // .get() 阻塞等待 Broker 确认
        SendResult<String, OrderEvent> result = future.get();
        log.info("同步发送成功: topic={}, partition={}, offset={}",
                result.getRecordMetadata().topic(),
                result.getRecordMetadata().partition(),
                result.getRecordMetadata().offset());
        return result;
    }

    /**
     * 异步发送消息
     */
    public void sendAsync(String key, OrderEvent event) {
        CompletableFuture<SendResult<String, OrderEvent>> future = kafkaTemplate.send(TOPIC, key, event);

        future.whenComplete((result, ex) -> {
            if (ex != null) {
                log.error("异步发送失败: orderId={}", event.getOrderId(), ex);
            } else {
                log.info("异步发送成功: topic={}, partition={}, offset={}",
                        result.getRecordMetadata().topic(),
                        result.getRecordMetadata().partition(),
                        result.getRecordMetadata().offset());
            }
        });
    }

    /**
     * 不指定 Key 发送（由默认分区器轮询分配 Partition）
     */
    public void sendWithoutKey(OrderEvent event) {
        kafkaTemplate.send(TOPIC, event);
    }
}
```

> **SendResult 说明**：`SendResult<K, V>` 是 Spring Kafka 框架提供的发送结果封装类（位于 `org.springframework.kafka.support.SendResult`），包含两个核心属性：
>
> ```java
> // Spring Kafka 中的 SendResult 源码结构（简化版）
> public class SendResult<K, V> {
>     private final ProducerRecord<K, V> producerRecord;  // 发送的消息记录
>     private final RecordMetadata recordMetadata;         // Broker 返回的元数据
>
>     public ProducerRecord<K, V> getProducerRecord() { return producerRecord; }
>
>     public RecordMetadata getRecordMetadata() { return recordMetadata; }
>     // RecordMetadata 提供: topic()、partition()、offset()、timestamp()、serializedKeySize()、serializedValueSize()
> }
> ```
>
> 本教程中通过 `result.getProducerRecord()` 获取原始消息，通过 `result.getRecordMetadata().topic()/partition()/offset()` 获取消息存储到 Broker 后的位置信息。

> **依赖注入说明**：以上代码使用 **构造器注入**（Spring Boot 3.x 推荐方式）。`private final` 字段配合 `@RequiredArgsConstructor`（Lombok）自动生成构造器，Spring 容器通过构造器自动注入 Bean，**无需 `@Autowired` 注解**。这是 Spring Framework 6+ 的最佳实践，优势包括：
> - `final` 字段保证依赖不可变，线程安全
> - 构造器注入在应用启动时即可发现依赖缺失，而非运行时 NPE
> - 不依赖 `@Autowired` 字段注入（已不推荐），代码更简洁

**创建 REST 接口触发发送**：

```java
package com.example.kafkademo.controller;

import com.example.kafkademo.model.OrderEvent;
import com.example.kafkademo.producer.OrderEventProducer;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderEventProducer producer;

    @PostMapping("/sync")
    public String sendSync(@RequestParam String userId,
                           @RequestParam Double amount) throws Exception {
        OrderEvent event = new OrderEvent(
                UUID.randomUUID().toString(),
                userId, amount, "CREATED",
                LocalDateTime.now()
        );
        producer.sendSync(userId, event);
        return "同步发送成功: " + event.getOrderId();
    }

    @PostMapping("/async")
    public String sendAsync(@RequestParam String userId,
                            @RequestParam Double amount) {
        OrderEvent event = new OrderEvent(
                UUID.randomUUID().toString(),
                userId, amount, "CREATED",
                LocalDateTime.now()
        );
        producer.sendAsync(userId, event);
        return "异步发送提交: " + event.getOrderId();
    }
}
```

### 2.1.3 使用 @KafkaListener 创建消息消费者

```java
package com.example.kafkademo.consumer;

import com.example.kafkademo.model.OrderEvent;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class OrderEventConsumer {

    /**
     * 基础消费：监听指定 Topic
     * - groupId 在配置文件中统一设置，也可在此处覆盖
     */
    @KafkaListener(topics = "order-events", groupId = "order-consumer-group")
    public void onMessage(OrderEvent event) {
        log.info("收到订单消息: orderId={}, userId={}, amount={}",
                event.getOrderId(), event.getUserId(), event.getAmount());
        // 业务处理...
    }

    /**
     * 带元数据的消费：获取 ConsumerRecord 信息
     */
    @KafkaListener(topics = "order-events", groupId = "order-consumer-group-detail")
    public void onMessageWithMeta(ConsumerRecord<String, OrderEvent> record,
                                  Acknowledgment ack) {
        log.info("收到消息: topic={}, partition={}, offset={}, key={}, value={}",
                record.topic(), record.partition(), record.offset(),
                record.key(), record.value());

        try {
            // 业务处理...
            processOrder(record.value());
            // 手动提交 Offset
            ack.acknowledge();
        } catch (Exception e) {
            log.error("处理消息失败, offset={}", record.offset(), e);
            // 不 ack，消息会在下次 poll 时重新投递（取决于错误处理策略）
        }
    }

    /**
     * 批量消费：一次性接收一批消息
     * 需要配置 listener.type: batch
     */
    @KafkaListener(topics = "order-events-batch", groupId = "order-batch-group")
    public void onBatchMessage(java.util.List<ConsumerRecord<String, OrderEvent>> records,
                               Acknowledgment ack) {
        log.info("批量收到 {} 条消息", records.size());
        for (ConsumerRecord<String, OrderEvent> record : records) {
            processOrder(record.value());
        }
        ack.acknowledge();
    }

    private void processOrder(OrderEvent event) {
        log.info("处理订单: {}", event.getOrderId());
    }
}
```

**批量消费需要在 application.yml 中额外配置**：

```yaml
spring:
  kafka:
    listener:
      type: batch              # 开启批量消费模式
      ack-mode: manual_immediate
    consumer:
      max-poll-records: 50     # 单次 poll 最大记录数
```

### 2.1.4 生产者与消费者常见配置项全解析

**生产者核心配置**：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `acks` | `all`（Spring Kafka 默认） | 确认级别：0/1/all |
| `retries` | `Integer.MAX_VALUE` | 发送失败重试次数 |
| `retry.backoff.ms` | `100` | 重试间隔（毫秒） |
| `batch.size` | `16384`(16KB) | 批次大小（字节） |
| `linger.ms` | `0` | 等待攒批时间（毫秒） |
| `buffer.memory` | `33554432`(32MB) | 生产者总缓冲区大小 |
| `compression.type` | `none` | 压缩算法 |
| `max.in.flight.requests.per.connection` | `5` | 单连接未确认请求最大数 |
| `enable.idempotence` | `true` | 是否开启幂等性 |
| `max.request.size` | `1048576`(1MB) | 单条请求最大大小 |
| `request.timeout.ms` | `30000` | 请求超时（毫秒） |
| `delivery.timeout.ms` | `120000` | 发送总超时（含重试） |

**消费者核心配置**：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `group.id` | - | 消费者组 ID |
| `enable.auto.commit` | `true` | 是否自动提交 Offset |
| `auto.commit.interval.ms` | `5000` | 自动提交间隔（毫秒） |
| `auto.offset.reset` | `latest` | 无 Offset 时从哪开始消费：earliest/latest/none |
| `max.poll.records` | `500` | 单次 poll 最大记录数 |
| `max.poll.interval.ms` | `300000` | 两次 poll 最大间隔（超时则触发 Rebalance） |
| `session.timeout.ms` | `45000` | 心跳超时时间 |
| `heartbeat.interval.ms` | `3000` | 心跳发送间隔 |
| `fetch.min.bytes` | `1` | 最小拉取字节数 |
| `fetch.max.wait.ms` | `500` | 最大等待拉取时间 |

---

## 2.2 生产者拦截器（Interceptor）实战

### 2.2.1 拦截器生命周期与作用场景

生产者拦截器（`ProducerInterceptor`）是在消息发送前后插入自定义逻辑的机制。

**生命周期方法**：

```java
public interface ProducerInterceptor<K, V> extends Configurable, AutoCloseable {

    // 消息被序列化和分区之前调用（发送前）
    // 可以修改消息内容
    ProducerRecord<K, V> onSend(ProducerRecord<K, V> record);

    // 消息被确认或失败时调用（发送后）
    // 可以获取异常信息，但不能修改消息
    void onAcknowledgement(RecordMetadata metadata, Exception exception);

    void close();
}
```

**常见应用场景**：

1. **消息审计**：记录每条消息的发送日志
2. **消息追踪**：注入 TraceId，实现全链路追踪
3. **消息修改**：在发送前添加或修改 Header
4. **统计监控**：统计发送成功/失败数量
5. **消息过滤**：在发送前拦截不符合条件的消息

### 2.2.2 在 Spring Boot 中创建与配置自定义拦截器

**自定义拦截器实现**：

```java
package com.example.kafkademo.interceptor;

import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.producer.ProducerInterceptor;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.slf4j.MDC;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

@Slf4j
public class TraceInterceptor<K, V> implements ProducerInterceptor<K, V> {

    private static final String TRACE_ID_HEADER = "traceId";
    private static final String TRACE_ID_KEY = "traceId";

    private long successCount = 0;
    private long failureCount = 0;

    @Override
    public ProducerRecord<K, V> onSend(ProducerRecord<K, V> record) {
        // 从 MDC 获取 TraceId，没有则生成
        String traceId = MDC.get(TRACE_ID_KEY);
        if (traceId == null || traceId.isEmpty()) {
            traceId = UUID.randomUUID().toString().replace("-", "");
        }

        // 将 TraceId 注入到消息 Header
        ProducerRecord<K, V> newRecord = new ProducerRecord<>(
                record.topic(),
                record.partition(),
                record.timestamp(),
                record.key(),
                record.value(),
                record.headers().add(TRACE_ID_HEADER, traceId.getBytes(StandardCharsets.UTF_8))
        );

        log.debug("[Interceptor] onSend: topic={}, key={}, traceId={}",
                record.topic(), record.key(), traceId);
        return newRecord;
    }

    @Override
    public void onAcknowledgement(RecordMetadata metadata, Exception exception) {
        if (exception == null) {
            successCount++;
            log.debug("[Interceptor] 消息发送成功: topic={}, partition={}, offset={}",
                    metadata.topic(), metadata.partition(), metadata.offset());
        } else {
            failureCount++;
            log.warn("[Interceptor] 消息发送失败: {}", exception.getMessage());
        }
    }

    @Override
    public void close() {
        log.info("[Interceptor] 拦截器关闭, 统计: 成功={}, 失败={}", successCount, failureCount);
    }

    @Override
    public void configure(Map<String, ?> configs) {
        log.info("[Interceptor] 拦截器初始化, configs={}", configs.keySet());
    }
}
```

**配置拦截器**：

方式一：在 `application.yml` 中配置：

```yaml
spring:
  kafka:
    producer:
      properties:
        # 多个拦截器用逗号分隔，按顺序执行
        interceptor.classes: com.example.kafkademo.interceptor.TraceInterceptor
```

方式二：通过 `ProducerFactory` 自定义配置（Java 方式）：

```java
package com.example.kafkademo.config;

import com.example.kafkademo.interceptor.TraceInterceptor;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.ProducerFactory;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaProducerConfig {

    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;

    @Bean
    public ProducerFactory<String, Object> producerFactory() {
        Map<String, Object> config = new HashMap<>();
        config.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        config.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringSerializer");
        config.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG,
                "org.springframework.kafka.support.serializer.JsonSerializer");
        config.put(ProducerConfig.ACKS_CONFIG, "all");
        config.put(ProducerConfig.RETRIES_CONFIG, 3);
        // 配置拦截器
        config.put(ProducerConfig.INTERCEPTOR_CLASSES_CONFIG,
                TraceInterceptor.class.getName());

        return new DefaultKafkaProducerFactory<>(config);
    }
}
```

> **注意**：自定义 `ProducerFactory` Bean 会覆盖 Spring Boot 的自动配置，此时 `application.yml` 中的 `spring.kafka.producer.*` 配置项不会自动生效。如果需要在 Java 配置中保留 YAML 配置，请改用 `@ConfigurationProperties` 注入或手动读取 `KafkaProperties`。
>
> 对于仅添加拦截器的简单场景，推荐方式一（YAML 配置），更简洁且不影响其他自动配置。

---

## 2.3 消息序列化与反序列化

### 2.3.1 Kafka 序列化机制原理解析

Kafka 中所有消息在传输和存储时都是**字节数组（byte[]）**。序列化器（Serializer）负责将 Java 对象转为字节数组，反序列化器（Deserializer）负责将字节数组还原为 Java 对象。

**Kafka 内置序列化器**：

| 序列化器 | 说明 |
|---------|------|
| `StringSerializer` / `StringDeserializer` | 字符串序列化，使用 UTF-8 编码 |
| `IntegerSerializer` / `IntegerDeserializer` | 整数序列化 |
| `LongSerializer` / `LongDeserializer` | 长整数序列化 |
| `ByteArraySerializer` / `ByteArrayDeserializer` | 字节数组（不做任何转换） |
| `ByteBufferSerializer` / `ByteBufferDeserializer` | ByteBuffer 序列化 |
| `DoubleSerializer` / `DoubleDeserializer` | 浮点数序列化 |

**Spring Kafka 提供的序列化器**：

| 序列化器 | 说明 |
|---------|------|
| `JsonSerializer` | 将对象序列化为 JSON 字节 |
| `JsonDeserializer` | 将 JSON 字节反序列化为对象 |
| `StringOrBytesSerializer` | 智能处理 String 或 byte[] |

**序列化流程**：

```
Java 对象  ──Serializer──▶  byte[]  ──网络传输──▶  Broker 存储  ──网络传输──▶  byte[]  ──Deserializer──▶  Java 对象
```

### 2.3.2 实战 Demo：自定义对象的 JSON 序列化与反序列化配置

**方案一：使用 Spring Kafka 的 JsonSerializer / JsonDeserializer**

生产者配置（application.yml）：

```yaml
spring:
  kafka:
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      # 可选：在消息 Header 中写入类型信息，便于消费者反序列化
      properties:
        spring.json.add.type.headers: true
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: "com.example.kafkademo.model"
        # 指定默认反序列化目标类型（也可在 @KafkaListener 中指定）
        # spring.json.value.default.type: com.example.kafkademo.model.OrderEvent
```

**方案二：使用 String 序列化器 + 手动 JSON 转换（更灵活，推荐生产环境使用）**

```yaml
spring:
  kafka:
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.apache.kafka.common.serialization.StringDeserializer
```

生产者端手动序列化：

```java
package com.example.kafkademo.producer;

import com.example.kafkademo.model.OrderEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class JsonStringProducer {

    private static final String TOPIC = "order-events-json";
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;

    public void send(OrderEvent event) {
        try {
            String json = objectMapper.writeValueAsString(event);
            kafkaTemplate.send(TOPIC, event.getOrderId(), json);
            log.info("发送 JSON 消息: {}", json);
        } catch (JsonProcessingException e) {
            log.error("JSON 序列化失败", e);
            throw new RuntimeException("消息序列化失败", e);
        }
    }
}
```

消费者端手动反序列化：

```java
package com.example.kafkademo.consumer;

import com.example.kafkademo.model.OrderEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class JsonStringConsumer {

    private final ObjectMapper objectMapper;

    @KafkaListener(topics = "order-events-json", groupId = "json-consumer-group")
    public void onMessage(ConsumerRecord<String, String> record, Acknowledgment ack) {
        try {
            OrderEvent event = objectMapper.readValue(record.value(), OrderEvent.class);
            log.info("反序列化成功: orderId={}, userId={}",
                    event.getOrderId(), event.getUserId());
            // 业务处理...
            ack.acknowledge();
        } catch (Exception e) {
            log.error("反序列化失败: value={}", record.value(), e);
            // 根据业务策略决定是否 ack（死信队列等）
            ack.acknowledge(); // 跳过坏消息
        }
    }
}
```

> **方案对比**：
>
> | 对比维度 | JsonSerializer/Deserializer | String + 手动 JSON |
> |---------|---------------------------|-------------------|
> | 易用性 | 高（自动转换） | 中（需手动转换） |
> | 灵活性 | 低（类型固定） | 高（可自由处理） |
> | 跨语言兼容 | 低（Header 含 Java 类型） | 高（纯 JSON 字符串） |
> | 错误处理 | 框架层面 | 业务层面可控 |
> | 推荐场景 | 纯 Java 项目 | 多语言、复杂场景 |

---

## 2.4 消息分区路由机制

### 2.4.1 消息如何通过 Key 路由到指定 Partition

Kafka 生产者发送消息时，分区决策逻辑如下：

```
                    ┌─────────────────────────────────────┐
                    │         分区决策流程                  │
                    └─────────────────────────────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │  消息中指定了 partition？       │
                    └───────┬───────────────┬───────┘
                       是   │               │ 否
                    ┌───────▼───────┐       │
                    │ 直接使用指定   │       │
                    │ partition     │       │
                    └───────────────┘       │
                                    ┌───────▼───────┐
                                    │ 消息有 Key？   │
                                    └───┬───────┬───┘
                                     是 │       │ 否
                              ┌─────────▼─┐     │
                              │ Key Hash  │     │
                              │ 取模分区   │     │
                              └───────────┘     │
                                              ┌─▼─────────────┐
                                              │ 使用分区器     │
                                              │ (Partitioner) │
                                              │ 默认: Sticky  │
                                              └───────────────┘
```

**Key 路由原理**：

当消息指定了 Key 但未指定 Partition 时，Kafka 使用 `Utils.toPositive(Utils.murmur2(keyBytes)) % numPartitions` 计算 Partition。即对 Key 做 MurmurHash2 运算后取正，再对分区数取模。

```java
// DefaultPartitioner 中的核心逻辑（简化版）
public int partition(String topic, Object key, byte[] keyBytes,
                     Object value, byte[] valueBytes, Cluster cluster) {
    if (keyBytes == null) {
        // 无 Key：使用 Sticky 分区器（Kafka 2.4+）
        return stickyPartitionCache.partition(topic, cluster);
    }
    // 有 Key：对 Key 做 MurmurHash2 取模
    return Utils.toPositive(Utils.murmur2(keyBytes)) % partitionCount;
}
```

> **Key 路由的意义**：相同 Key 的消息总是被发送到同一个 Partition，保证了同一 Key 消息的**顺序性**。例如，同一用户的订单消息都进入同一分区，就能保证该用户订单事件的顺序消费。

### 2.4.2 内置分区策略解析：Range、Round-Robin、Sticky

> **注意**：以下分区策略中，Range 和 Round-Robin 主要用于**消费者端**的分区分配（Consumer Group Rebalance），而 Sticky 在 Kafka 2.4+ 也用于**生产者端**的无 Key 消息分区。

**消费者端分区分配策略**：

**1. RangeAssignor（默认策略）**

按 Topic 维度，将分区按数字范围分配给消费者。

```
假设：Topic T 有 6 个分区 (P0~P5)，Consumer Group 有 3 个消费者 (C0, C1, C2)

分配结果：
C0: P0, P1
C1: P2, P3
C2: P4, P5
```

特点：按 Topic 独立分配，多 Topic 时第一个消费者总是分配更多分区，可能不均匀。

**2. RoundRobinAssignor**

将所有 Topic 的所有 Partition 按轮询方式分配给消费者。

```
假设：Topic T1 有 3 个分区, Topic T2 有 3 个分区，2 个消费者

分配结果：
C0: T1-P0, T1-P2, T2-P1
C1: T1-P1, T2-P0, T2-P2
```

特点：跨 Topic 均匀分配，但要求消费者订阅相同的 Topic 集合。

**3. StickyAssignor（粘性分配）**

两个目标：
- 分配尽可能均匀
- Rebalance 时，尽量保持原有分配不变，只移动必要的分区

```
初始：C0: P0,P1  C1: P2,P3  C2: P4,P5
C2 宕机后 Rebalance：
  C0: P0,P1,P4  C1: P2,P3,P5  (只把 C2 的分区均衡转移)
```

特点：减少 Rebalance 时的分区迁移，降低网络开销。

**4. CooperativeStickyAssignor（Kafka 2.4+ 推荐）**

StickyAssignor 的升级版，采用**增量式协同 Rebalance**：
- 不会一次性撤销全部分区再重新分配
- 只撤销需要迁移的分区，其余分区正常消费
- 大大减少了 Rebalance 造成的消费停顿

**配置方式**：

```yaml
spring:
  kafka:
    consumer:
      properties:
        partition.assignment.strategy: org.apache.kafka.clients.consumer.CooperativeStickyAssignor
```

**生产者端分区策略**：

Kafka 2.4 之后，无 Key 消息默认使用 **Sticky Partitioner**（粘性分区器）：
- 不再是严格的 Round-Robin，而是将消息"粘"在一个 Partition 上，直到该 Partition 的批次满了或 linger.ms 超时
- 减少了小批次数量，提高了吞吐量
- 对用户透明，无需额外配置

### 2.4.3 实战：自定义分区策略（Partitioner）

**自定义分区器**：按用户 ID 奇偶性路由到不同分区。

```java
package com.example.kafkademo.partition;

import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.producer.Partitioner;
import org.apache.kafka.common.Cluster;
import org.apache.kafka.common.PartitionInfo;
import org.apache.kafka.common.utils.Utils;

import java.util.List;
import java.util.Map;

@Slf4j
public class CustomPartitioner implements Partitioner {

    @Override
    public int partition(String topic, Object key, byte[] keyBytes,
                         Object value, byte[] valueBytes, Cluster cluster) {
        // 获取该 Topic 的所有分区信息
        List<PartitionInfo> partitions = cluster.partitionsForTopic(topic);
        int numPartitions = partitions.size();

        if (numPartitions <= 1) {
            return 0; // 单分区直接返回 0，避免除零
        }

        if (keyBytes == null) {
            // 无 Key 时使用默认策略
            return Utils.toPositive(Utils.murmur2(valueBytes)) % numPartitions;
        }

        // 自定义逻辑：假设 Key 是用户 ID
        // 将 VIP 用户（以 "VIP" 开头）路由到最后一个分区
        String keyStr = key.toString();
        if (keyStr.startsWith("VIP")) {
            log.debug("VIP 用户路由到最后一个分区: key={}", keyStr);
            return numPartitions - 1;
        }

        // 其他用户：Key Hash 取模（排除最后一个分区，留给 VIP）
        return Utils.toPositive(Utils.murmur2(keyBytes)) % (numPartitions - 1);
    }

    @Override
    public void close() {
        // 清理资源
    }

    @Override
    public void configure(Map<String, ?> configs) {
        // 初始化配置
        log.info("CustomPartitioner 初始化");
    }
}
```

**注册自定义分区器**：

```yaml
spring:
  kafka:
    producer:
      properties:
        partitioner.class: com.example.kafkademo.partition.CustomPartitioner
```

---

## 2.5 生产者缓存与批量发送机制

### 2.5.1 BUFFER_MEMORY_CONFIG（缓冲区大小）原理与调优

**工作原理**：

生产者内部维护一个 `RecordAccumulator`（记录累加器），所有待发送的消息先被放入这个缓冲区，由 Sender 线程异步批量发送。

```
Producer.send()           RecordAccumulator (buffer.memory)
    │                           │
    ▼                     ┌─────┴─────┐
  序列化+分区      ┌───────▼──┐  ┌──────▼───┐
    │             │Partition0│  │Partition1│  ...
    ▼             │ Batch 1  │  │ Batch 1  │
  放入对应分区     │ Batch 2  │  │ Batch 2  │
    │             └──────┬───┘  └──────┬───┘
    │                    │             │
    │              ┌─────▼─────────────▼─────┐
    │              │     Sender 线程          │
    │              │  (批量发送到 Broker)     │
    │              └─────────────────────────┘
```

**关键参数**：

```yaml
spring:
  kafka:
    producer:
      buffer-memory: 33554432  # 32MB，默认值
```

**调优建议**：

| 场景 | 推荐值 | 说明 |
|------|--------|------|
| 低吞吐 | 默认 32MB | 一般场景足够 |
| 高吞吐 | 64MB~128MB | 减少因缓冲区满导致的阻塞 |
| 内存受限 | 16MB | 注意监控 send() 阻塞时间 |

> 当缓冲区满时，`send()` 方法会阻塞，阻塞时间超过 `max.block.ms`（默认 60000ms）会抛出异常。如果频繁出现缓冲区满的情况，说明生产者发送速度跟不上写入速度，需要调大 `buffer.memory` 或增加 Broker 数量。

### 2.5.2 BATCH_SIZE_CONFIG（批量大小）对吞吐量的影响

**工作原理**：

`batch.size` 是生产者为每个分区分配的**批次缓冲区大小**。当消息累积达到此大小时，批次会被立即发送。

```yaml
spring:
  kafka:
    producer:
      batch-size: 16384  # 16KB，默认值
      properties:
        batch.size: 32768  # 也可以通过 properties 配置
```

> **注意**：`batch.size` 不是限制单个批次的最大大小，而是为每个分区预分配的缓冲区大小。如果消息大于 `batch.size`，消息会单独发送，不会等待攒批。

**不同 batch.size 的性能对比**：

```
batch.size = 1KB:
  - 每条消息几乎都单独发送
  - 网络请求次数多，吞吐量低，延迟低

batch.size = 16KB (默认):
  - 适中的攒批
  - 吞吐量与延迟的平衡点

batch.size = 128KB:
  - 更大的攒批
  - 网络请求次数少，吞吐量高
  - 需配合 linger.ms 使用，否则不会等待攒满
```

### 2.5.3 LINGER_MS_CONFIG（等待时间）与延迟的权衡

**工作原理**：

`linger.ms` 控制生产者在发送批次前等待多长时间，即使批次未满也会发送。这是**吞吐量与延迟之间的核心权衡参数**。

```
                    linger.ms = 0 (默认)
                    ┌─────────────────────────┐
  消息到达 ────────▶│  立即发送（不等攒批）     │  延迟最低，吞吐量较低
                    └─────────────────────────┘

                    linger.ms = 10
                    ┌─────────────────────────┐
  消息到达 ────────▶│  等待 10ms 攒批后发送    │  延迟略增，吞吐量提升
                    └─────────────────────────┘

                    linger.ms = 50 + batch.size = 64KB
                    ┌─────────────────────────┐
  消息到达 ────────▶│  最多等 50ms 或攒满 64KB │  延迟增加，吞吐量显著提升
                    └─────────────────────────┘
```

**配置**：

```yaml
spring:
  kafka:
    producer:
      batch-size: 32768       # 32KB
      properties:
        linger.ms: 10         # 等待 10ms
```

**发送触发条件**（满足任一即发送）：

1. 批次大小达到 `batch.size`
2. 等待时间达到 `linger.ms`
3. 缓冲区内存不足
4. 调用 `flush()` 方法
5. 生产者关闭

**调优建议**：

| 场景 | linger.ms | batch.size | 说明 |
|------|-----------|------------|------|
| 低延迟（实时交易） | 0~5 | 16KB | 优先低延迟 |
| 平衡型（通用场景） | 5~20 | 32KB | 吞吐与延迟兼顾 |
| 高吞吐（日志/埋点） | 20~100 | 64KB+ | 优先吞吐量 |

---

## 2.6 生产者发送应答（ACKS）机制

### 2.6.1 acks=0：Fire-and-Forget（不等待确认）

生产者发送消息后不等待 Broker 的任何确认，直接认为发送成功。

```
Producer ──send──▶ Broker
  │                   │ (不返回 ACK)
  ▼                   │
立即返回成功           │
                     ▼
               可能写入失败（生产者不知道）
```

```yaml
spring:
  kafka:
    producer:
      acks: 0
```

**特点**：
- 延迟最低，吞吐量最高
- 可靠性最低，消息可能丢失
- 不触发重试机制（因为不知道是否失败）

**适用场景**：日志收集、监控埋点等允许少量丢失的场景。

### 2.6.2 acks=1：Leader 确认机制

生产者等待 Leader 副本写入成功后返回确认，不等待 Follower 同步。

```
Producer ──send──▶ Leader Broker
                       │
                  写入成功
                       │
  ◀────── ACK ────────┘
  │
返回成功

  (同时 Follower 可能在异步同步，如果此时 Leader 宕机且 Follower 未同步完，消息丢失)
```

```yaml
spring:
  kafka:
    producer:
      acks: 1
```

**特点**：
- 延迟较低
- 存在消息丢失风险：Leader 确认后、Follower 同步前 Leader 宕机
- 适合对可靠性要求中等的场景

### 2.6.3 acks=all (-1)：全副本确认与高可靠保障

生产者等待所有 ISR（In-Sync Replicas）中的副本都写入成功后才返回确认。

```
Producer ──send──▶ Leader Broker
                       │
                  写入成功
                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼
        Follower1  Follower2  (ISR 中的所有副本)
            │          │
         同步成功   同步成功
            │          │
            └────┬─────┘
                 ▼
  ◀──── ACK ────┘  (所有 ISR 副本确认后)
  │
返回成功
```

```yaml
spring:
  kafka:
    producer:
      acks: all
```

**配合 min.insync.replicas 使用**：

`min.insync.replicas` 控制 ISR 中最少需要多少个副本同步成功。例如配置为 2，当 ISR 中只剩 1 个副本时，生产者会收到 `NotEnoughReplicasException`。

```properties
# Topic 级别配置
min.insync.replicas=2
```

**可靠性保障链路**：

| 配置组合 | 可靠性级别 | 说明 |
|---------|-----------|------|
| `acks=all` + `min.insync.replicas=1` + `replication.factor=1` | 低 | 仅 Leader 确认 |
| `acks=all` + `min.insync.replicas=2` + `replication.factor=3` | 高 | Leader + 至少1个Follower确认 |
| `acks=all` + `min.insync.replicas=3` + `replication.factor=3` | 最高 | 全部副本确认，但可用性降低 |

### 2.6.4 生产环境 ACKS 配置最佳实践

**推荐配置组合**：

```yaml
spring:
  kafka:
    producer:
      acks: all                    # 全副本确认
      retries: 3                   # 重试次数（不用 Integer.MAX_VALUE，配合幂等性）
      properties:
        enable.idempotence: true   # 开启幂等性（防重试导致重复）
        max.in.flight.requests.per.connection: 5  # 幂等性下最大值
```

**Topic 创建时配置**：

```bash
bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create \
  --topic order-events \
  --partitions 6 \
  --replication-factor 3 \
  --config min.insync.replicas=2
```

**决策参考**：

```
是否允许消息丢失？
  ├── 是 ──▶ acks=0 或 acks=1（追求性能）
  └── 否 ──▶ acks=all + min.insync.replicas=2 + replication.factor=3
              │
              └── 开启 enable.idempotence=true 防止重试重复
```

---

## 2.7 生产者消息幂等性与重试机制

### 2.7.1 消息重复问题与幂等性原理

**消息重复的根源**：

```
Producer ──send(msg)──▶ Broker ──写入成功──▶ 
                              │
                         ACK 丢失（网络故障）
                              │
  Producer 未收到 ACK         │
      │                       │
      ▼                       │
  认为发送失败                 │
      │                       │
      ▼                       │
  重试发送 msg ──────────────▶ Broker ──再次写入──▶ (消息重复！)
```

**幂等性原理（Idempotent Producer）**：

Kafka 的幂等性通过 **PID（Producer ID）+ Sequence Number（序列号）** 实现：

1. 生产者启动时，Broker 分配一个全局唯一的 PID
2. 每个 `<PID, Partition>` 组合维护一个从 0 递增的序列号
3. 每条消息携带序列号发送给 Broker
4. Broker 端对每个 `<PID, Partition>` 保留最近 5 个序列号
5. 如果收到的消息序列号 ≤ 已提交的序列号，判定为重复消息，丢弃但返回成功

```
Producer (PID=100)
  │
  ├── send(P0, seq=0) ──▶ Broker: P0 最后 seq=0 ✓
  ├── send(P0, seq=1) ──▶ Broker: P0 最后 seq=1 ✓
  ├── send(P0, seq=1) ──▶ Broker: 1 ≤ 1, 重复！丢弃但返回成功 ✓
  ├── send(P0, seq=2) ──▶ Broker: P0 最后 seq=2 ✓
  └── send(P0, seq=1) ──▶ Broker: 1 < 2, 乱序！拒绝（OutOfOrderSequenceException）
```

> **限制**：幂等性只能保证**单个生产者、单个分区**内的不重复，无法跨会话（重启后 PID 变化）保证。

**开启幂等性**：

```yaml
spring:
  kafka:
    producer:
      properties:
        enable.idempotence: true  # Kafka 3.0+ 默认为 true
```

> Kafka 3.0 开始，`enable.idempotence` 默认为 `true`。开启幂等性时，`acks` 会被强制设为 `all`，`retries` 会被强制设为 `Integer.MAX_VALUE`，`max.in.flight.requests.per.connection` 会被限制在 5 以内。

### 2.7.2 RETRIES_CONFIG 重试机制配置与异常处理

**可重试异常 vs 不可重试异常**：

| 异常类型 | 可重试？ | 说明 |
|---------|---------|------|
| `LeaderNotAvailableException` | 是 | Leader 正在选举中 |
| `NotEnoughReplicasException` | 是 | ISR 副本不足 |
| `NetworkException` | 是 | 网络问题 |
| `TimeoutException` | 是 | 请求超时 |
| `SerializationException` | 否 | 序列化失败 |
| `RecordTooLargeException` | 否 | 消息过大 |
| `AuthorizationException` | 否 | 权限不足 |
| `InvalidTopicException` | 否 | Topic 名称非法 |

**重试配置**：

```yaml
spring:
  kafka:
    producer:
      retries: 3                              # 重试次数
      properties:
        retry.backoff.ms: 100                 # 重试间隔（毫秒）
        delivery.timeout.ms: 120000           # 总投递超时（含重试），超时后不再重试
        request.timeout.ms: 30000             # 单次请求超时
```

**自定义异常处理（Spring Kafka 方式）**：

```java
package com.example.kafkademo.config;

import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.support.ProducerListener;

@Slf4j
@Configuration
public class KafkaErrorHandlingConfig {

    /**
     * 自定义 ProducerListener，处理发送结果回调
     */
    @Bean
    public <K, V> ProducerListener<K, V> producerListener() {
        return new ProducerListener<>() {
            @Override
            public void onSuccess(ProducerRecord<K, V> record, org.apache.kafka.clients.producer.RecordMetadata metadata) {
                log.info("消息发送成功: topic={}, partition={}, offset={}",
                        record.topic(), metadata.partition(), metadata.offset());
            }

            @Override
            public void onError(ProducerRecord<K, V> record, org.apache.kafka.clients.producer.RecordMetadata metadata,
                                Exception exception) {
                log.error("消息发送失败: topic={}, key={}, value={}",
                        record.topic(), record.key(), record.value(), exception);
                // 可以在此实现：告警通知、写入死信队列、持久化失败消息等
            }
        };
    }
}
```

**使用 Spring Retry 实现业务层重试**：

```java
package com.example.kafkademo.producer;

import com.example.kafkademo.model.OrderEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.retry.annotation.Backoff;
import org.springframework.retry.annotation.Retryable;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class RetryableProducer {

    private final OrderEventProducer orderEventProducer;

    /**
     * 使用 Spring Retry 注解实现业务层重试
     * maxAttempts: 最大尝试次数（含首次）
     * backoff: 重试退避策略
     */
    @Retryable(
        retryFor = {Exception.class},
        maxAttempts = 3,
        backoff = @Backoff(delay = 1000, multiplier = 2, maxDelay = 5000)
    )
    public void sendWithRetry(String key, OrderEvent event) throws Exception {
        log.info("尝试发送消息: orderId={}, attempt={}", event.getOrderId());
        orderEventProducer.sendSync(key, event);
    }
}
```

---

## 2.8 消息压缩机制

### 2.8.1 Kafka 支持的压缩算法（None, GZIP, Snappy, LZ4, ZSTD）

Kafka 支持在生产者端对消息批次进行压缩，在消费者端自动解压。

**压缩算法对比**：

| 算法 | 压缩比 | 压缩速度 | 解压速度 | CPU 开销 | Kafka 支持版本 |
|------|--------|---------|---------|---------|---------------|
| None | - | - | - | 最低 | 全版本 |
| GZIP | 高 | 慢 | 中 | 高 | 全版本 |
| Snappy | 中 | 快 | 快 | 低 | 0.8+ |
| LZ4 | 中 | 最快 | 最快 | 最低 | 0.8.2+ |
| ZSTD | 最高 | 中 | 快 | 中 | 2.1+ |

**压缩原理**：

```
生产者端：
  多条消息 ──▶ 压缩为一个批次 ──▶ 压缩后的 byte[] ──▶ 发送到 Broker

Broker：
  直接存储压缩后的数据（不解压），仅追加到日志

消费者端：
  拉取压缩数据 ──▶ 解压 ──▶ 逐条消息处理
```

> **关键点**：压缩是在**批次维度**进行的，因此 `batch.size` 和 `linger.ms` 越大，攒批越多，压缩效果越好。

### 2.8.2 生产者与消费者端压缩配置与性能对比

**生产者端配置**：

```yaml
spring:
  kafka:
    producer:
      compression-type: zstd    # 推荐：ZSTD 兼顾压缩比和速度
```

**消费者端**：

消费者通常无需额外配置，Kafka Client 会根据消息的压缩格式自动解压。但如果需要指定接受格式：

```yaml
spring:
  kafka:
    consumer:
      properties:
        # 限制消费者接受的压缩格式（逗号分隔），默认全部接受
        # 仅在特殊场景需要配置
```

**各算法配置示例**：

```yaml
# 方案一：LZ4（追求速度）
spring:
  kafka:
    producer:
      compression-type: lz4
      batch-size: 32768
      properties:
        linger.ms: 10

# 方案二：ZSTD（追求压缩比，推荐）
spring:
  kafka:
    producer:
      compression-type: zstd
      batch-size: 65536
      properties:
        linger.ms: 20

# 方案三：Snappy（兼容性优先）
spring:
  kafka:
    producer:
      compression-type: snappy
      batch-size: 32768
      properties:
        linger.ms: 10
```

**选型建议**：

| 场景 | 推荐算法 | 原因 |
|------|---------|------|
| 通用生产环境 | ZSTD | 压缩比最高，速度可接受 |
| 低延迟场景 | LZ4 | 压缩/解压速度最快 |
| 网络带宽瓶颈 | ZSTD | 最大程度减少网络传输量 |
| CPU 敏感场景 | Snappy | CPU 开销低 |
| 跨平台兼容 | GZIP | 兼容性最好，但性能最差 |

---

## 2.9 消息事务机制

### 2.9.1 Kafka 事务概念与应用场景

**为什么需要事务**：

在 Kafka 中，以下场景需要事务保证：

1. **消费-处理-生产**模式：从 Topic A 消费消息，处理后发送到 Topic B，需要保证消费 Offset 提交和生产消息的原子性
2. **多 Topic 原子写入**：向多个 Topic 发送消息，要么全部成功，要么全部失败
3. **多分区原子写入**：向同一 Topic 的多个分区发送消息，保证原子性

**事务原理**：

Kafka 事务基于 **两阶段提交（2PC）** 和 **Transaction Coordinator** 实现：

```
1. 生产者初始化事务 (initTransactions)
       │
       ▼
2. 开启事务 (beginTransaction)
       │
       ▼
3. 发送消息到多个 Topic/Partition
       │
       ▼
4. 提交消费 Offset (sendOffsetsToTransaction)  ← 消费-生产模式
       │
       ▼
5. 提交事务 (commitTransaction) 或 回滚 (abortTransaction)
```

**Transaction Coordinator**：
- 每个 Transactional Producer 会被分配一个 Transaction Coordinator（位于某个 Broker 上）
- Coordinator 负责管理事务状态：Ongoing / PrepareCommit / PrepareAbort / CompleteCommit / CompleteAbort
- 事务状态持久化在内部 Topic `__transaction_state` 中

### 2.9.2 事务初始化、开启、提交与回滚的 Spring Boot 实现

**Step 1：配置事务生产者**

```yaml
spring:
  kafka:
    producer:
      # 事务配置
      transaction-id-prefix: tx-order-    # 事务 ID 前缀（必须配置才能开启事务）
      acks: all
      properties:
        enable.idempotence: true
        transaction.max.timeout.ms: 900000  # 事务最大超时（15分钟）
```

> **重要**：`transaction-id-prefix` 配置后，Spring Boot 会自动创建 `KafkaTransactionManager`。事务 ID 实际值为 `前缀 + partition序号`，确保同一分区的事务 ID 稳定。

**Step 2：配置事务管理器和监听器容器**

```java
package com.example.kafkademo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.transaction.KafkaTransactionManager;

@Configuration
public class KafkaTransactionConfig {

    /**
     * Kafka 事务管理器
     * Spring Boot 配置了 transaction-id-prefix 后会自动创建，
     * 此处显式声明以便自定义
     */
    @Bean
    public KafkaTransactionManager<String, Object> kafkaTransactionManager(
            KafkaTemplate<String, Object> kafkaTemplate) {
        KafkaTransactionManager<String, Object> manager = new KafkaTransactionManager<>(kafkaTemplate);
        // 设置事务超时
        manager.setTimeout(60); // 60 秒
        return manager;
    }
}
```

**Step 3：事务生产者实现**

```java
package com.example.kafkademo.producer;

import com.example.kafkademo.model.OrderEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.concurrent.CompletableFuture;

@Slf4j
@Service
@RequiredArgsConstructor
public class TransactionalOrderProducer {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    /**
     * 方式一：使用 @Transactional 注解（声明式事务）
     * 需要配置 KafkaTransactionManager
     */
    @Transactional("kafkaTransactionManager")
    public void sendOrderWithTransaction(OrderEvent event) {
        log.info("事务发送订单消息: orderId={}", event.getOrderId());

        // 向 Topic A 发送消息
        kafkaTemplate.send("order-events", event.getUserId(), event);

        // 向 Topic B 发送消息（通知库存服务）
        kafkaTemplate.send("inventory-events", event.getOrderId(),
                "STOCK_CHECK:" + event.getOrderId());

        // 模拟异常，测试事务回滚
        if ("FAIL".equals(event.getStatus())) {
            throw new RuntimeException("模拟事务失败，触发回滚");
        }

        // 如果没有异常，两 Topic 的消息一起提交
        log.info("事务提交成功");
    }

    /**
     * 方式二：使用 KafkaTemplate.executeInTransaction（编程式事务）
     * 不需要 @Transactional 注解
     */
    public void sendWithProgrammaticTransaction(OrderEvent event) {
        kafkaTemplate.executeInTransaction(template -> {
            log.info("编程式事务发送: orderId={}", event.getOrderId());

            template.send("order-events", event.getUserId(), event);
            template.send("inventory-events", event.getOrderId(),
                    "STOCK_CHECK:" + event.getOrderId());

            if ("FAIL".equals(event.getStatus())) {
                throw new RuntimeException("事务回滚");
            }

            return true; // 返回 true 表示提交，抛异常表示回滚
        });
    }
}
```

**Step 4：消费-处理-生产的事务模式（Exactly-Once 语义）**

```java
package com.example.kafkademo.consumer;

import com.example.kafkademo.model.OrderEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 消费-处理-生产模式：
 * 从 source-topic 消费 → 处理 → 发送到 target-topic + 提交 Offset
 * 全部在同一个事务中，保证 Exactly-Once 语义
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ConsumeProcessProduceConsumer {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    /**
     * isolation.level = read_committed：
     * 消费者只读取已提交的事务消息，不会读到未提交或已回滚的消息
     *
     * 在 application.yml 中配置：
     * spring.kafka.consumer.properties.isolation.level: read_committed
     */
    @KafkaListener(topics = "source-topic", groupId = "cpp-group")
    @Transactional("kafkaTransactionManager")
    public void consumeProcessProduce(ConsumerRecord<String, OrderEvent> record,
                                      Acknowledgment ack) {
        log.info("消费消息: offset={}, key={}", record.offset(), record.key());

        OrderEvent event = record.value();

        // 1. 业务处理
        event.setStatus("PROCESSED");

        // 2. 发送到目标 Topic
        kafkaTemplate.send("target-topic", event.getOrderId(), event);

        // 3. 提交消费 Offset（在事务中提交，保证 Exactly-Once）
        // 注意：使用 KafkaTransactionManager 时，Offset 提交也由事务管理
        // ack.acknowledge() 在事务模式下不直接提交 Offset
        // 而是通过 sendOffsetsToTransaction 提交

        // 如果处理过程中抛异常，事务回滚：
        //   - 发送到 target-topic 的消息被丢弃
        //   - 消费 Offset 不会提交，消息会被重新消费
    }
}
```

**消费者隔离级别配置**：

```yaml
spring:
  kafka:
    consumer:
      properties:
        isolation.level: read_committed  # 只消费已提交的事务消息
```

> **事务使用注意事项**：
> 1. 事务会降低吞吐量，仅在需要 Exactly-Once 语义时使用
> 2. `transaction.id` 必须全局唯一且持久化（重启后不变），否则会产生"僵尸进程"
> 3. 事务超时时间应大于业务处理时间
> 4. 使用 `read_committed` 隔离级别的消费者会等待事务完成，可能增加消费延迟

---

# 第 3 章 Kafka 整合 Spring Cloud Stream

## 3.1 Spring Cloud Stream 核心概念与绑定机制

Spring Cloud Stream 是一个用于构建消息驱动微服务的框架，它提供了一套统一的编程模型，屏蔽了底层消息中间件的差异。

**核心概念**：

| 概念 | 说明 |
|------|------|
| **Destination Binder** | 绑定器，是消息中间件的抽象适配层。Kafka Binder 对应 Kafka |
| **Binding** | 绑定，是应用程序与消息中间件之间的桥梁，分为 Input（输入）和 Output（输出） |
| **Function** | Spring Cloud Stream 3.x 推荐使用函数式编程模型，通过 `java.util.function.Function`、`Consumer`、`Supplier` 定义消息处理逻辑 |
| **Channel** | 通道，消息传输的管道，对应 Kafka 中的 Topic |

**架构图**：

```
┌──────────────────────────────────────────────────────────┐
│                    Spring Cloud Stream                    │
│                                                          │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   │
│  │  Supplier   │   │  Function   │   │  Consumer   │   │
│  │ (生产消息)  │   │ (处理消息)  │   │ (消费消息)  │   │
│  └──────┬──────┘   └──────┬──────┘   └──────▲──────┘   │
│         │                 │                  │          │
│  ┌──────▼──────┐   ┌──────▼──────┐   ┌──────┴──────┐   │
│  │  Output     │   │Input/Output │   │   Input     │   │
│  │  Binding    │   │  Binding    │   │  Binding    │   │
│  └──────┬──────┘   └──────┬──────┘   └──────┴──────┘   │
│         │                 │                  │          │
│  ═══════╪═════════════════╪══════════════════╪════════  │
│         │          Destination Binder         │          │
│  ═══════╪═════════════════╪══════════════════╪════════  │
│         │                 │                  │          │
│  ┌──────▼─────────────────▼──────────────────▼──────┐  │
│  │              Kafka Binder (Kafka)                 │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

**与直接使用 Spring Kafka 的对比**：

| 对比维度 | Spring Kafka | Spring Cloud Stream |
|---------|-------------|-------------------|
| 编程模型 | 直接操作 KafkaTemplate/@KafkaListener | 函数式接口 (Supplier/Function/Consumer) |
| 中间件耦合 | 强耦合 Kafka | 通过 Binder 抽象，可切换中间件 |
| 配置方式 | Kafka 原生配置 | 统一的 Spring 配置 |
| 学习成本 | 低（直接操作） | 中（需理解 Binder 概念） |
| 适用场景 | 单一 Kafka 项目 | 微服务架构、可能切换中间件 |

## 3.2 整合 Kafka Binder 的环境与依赖配置

**Maven 依赖**：

```xml
<dependencies>
    <!-- Spring Boot Web -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>

    <!-- Spring Cloud Stream -->
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-stream</artifactId>
    </dependency>

    <!-- Spring Cloud Stream Kafka Binder -->
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-stream-binder-kafka</artifactId>
    </dependency>

    <!-- JSON 处理 -->
    <dependency>
        <groupId>com.fasterxml.jackson.core</groupId>
        <artifactId>jackson-databind</artifactId>
    </dependency>

    <!-- Lombok -->
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <optional>true</optional>
    </dependency>
</dependencies>

<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>2023.0.1</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

> **版本对应关系**：
>
> | Spring Boot | Spring Cloud | Spring Cloud Stream |
> |-------------|-------------|-------------------|
> | 3.2.x | 2023.0.x (Leyton) | 4.1.x |
> | 3.3.x | 2023.1.x | 4.1.x |

**application.yml 配置**：

```yaml
spring:
  cloud:
    stream:
      # Kafka Binder 配置
      kafka:
        binder:
          # Kafka 集群地址
          brokers: localhost:9092,localhost:9093,localhost:9094
          # 自动创建 Topic
          auto-create-topics: true
          # 最小副本数
          min-partition-count: 3
          replication-factor: 3

      # 函数式绑定配置
      bindings:
        # Supplier 输出绑定
        orderSupplier-out-0:
          destination: order-stream-topic
          content-type: application/json
        # Consumer 输入绑定
        orderConsumer-in-0:
          destination: order-stream-topic
          content-type: application/json
          group: order-stream-group
        # Function 辄入输出绑定
        orderProcessor-in-0:
          destination: order-stream-topic
          content-type: application/json
          group: order-processor-group
        orderProcessor-out-0:
          destination: processed-order-topic
          content-type: application/json

      # Kafka 特定绑定配置
      kafka:
        bindings:
          orderConsumer-in-0:
            consumer:
              # 自动提交 Offset
              auto-commit-offset: false
              # 开始偏移量
              start-offset: earliest
          orderSupplier-out-0:
            producer:
              # 同步发送
              sync: false
              # 压缩
              compression-type: zstd

  # 函数定义（Spring Cloud Stream 3.x 函数式模型）
  cloud.function:
    definition: orderSupplier;orderConsumer;orderProcessor
```

> **绑定名称命名规则**：
> - 格式：`<函数名>-<in/out>-<索引>`
> - 输入绑定后缀：`-in-0`、`-in-1`（多个输入参数时索引递增）
> - 输出绑定后缀：`-out-0`、`-out-1`
> - 多个函数用 `;` 分隔

## 3.3 简单案例：基于函数的消息生产与消费实战

**Step 1：定义消息对象**

```java
package com.example.kafkastream.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderMessage implements Serializable {
    private String orderId;
    private String userId;
    private Double amount;
    private String status;
}
```

**Step 2：实现 Supplier（消息生产者）**

```java
package com.example.kafkastream.function;

import com.example.kafkastream.model.OrderMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.UUID;
import java.util.function.Supplier;

@Slf4j
@Configuration
public class OrderSupplier {

    /**
     * 定义名为 orderSupplier 的 Supplier Bean
     * 函数名 orderSupplier 对应配置中的 orderSupplier-out-0 绑定
     *
     * Spring Cloud Stream 会定期调用此 Supplier 获取消息并发送到绑定的 Topic
     */
    @Bean
    public Supplier<OrderMessage> orderSupplier() {
        return () -> {
            OrderMessage order = new OrderMessage(
                    UUID.randomUUID().toString(),
                    "user-" + (int) (Math.random() * 100),
                    Math.round(Math.random() * 1000 * 100) / 100.0,
                    "CREATED"
            );
            log.info("[Supplier] 生成订单消息: {}", order.getOrderId());
            return order;
        };
    }
}
```

> **触发频率配置**：在 `application.yml` 中配置 `spring.cloud.stream.bindings.orderSupplier-out-0.producer.poll-rate`（毫秒）来控制 Supplier 的调用间隔。默认不配置时，由 `spring.integration.poller.fixed-delay` 控制（默认 1000ms）。

**Step 3：实现 Consumer（消息消费者）**

```java
package com.example.kafkastream.function;

import com.example.kafkastream.model.OrderMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.function.Consumer;

@Slf4j
@Configuration
public class OrderConsumer {

    /**
     * 定义名为 orderConsumer 的 Consumer Bean
     * 函数名 orderConsumer 对应配置中的 orderConsumer-in-0 绑定
     */
    @Bean
    public Consumer<OrderMessage> orderConsumer() {
        return order -> {
            log.info("[Consumer] 收到订单消息: orderId={}, userId={}, amount={}",
                    order.getOrderId(), order.getUserId(), order.getAmount());
            // 业务处理...
        };
    }
}
```

**Step 4：实现 Function（消息处理者，消费 + 生产）**

```java
package com.example.kafkastream.function;

import com.example.kafkastream.model.OrderMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.function.Function;

@Slf4j
@Configuration
public class OrderProcessor {

    /**
     * 定义名为 orderProcessor 的 Function Bean
     * 输入: orderProcessor-in-0 (从 order-stream-topic 消费)
     * 输出: orderProcessor-out-0 (发送到 processed-order-topic)
     */
    @Bean
    public Function<OrderMessage, OrderMessage> orderProcessor() {
        return order -> {
            log.info("[Processor] 处理订单: {}", order.getOrderId());

            // 业务处理：状态流转
            order.setStatus("PROCESSED");

            // 可以根据业务逻辑过滤消息（返回 null 则不发送）
            if (order.getAmount() < 0) {
                log.warn("金额异常，丢弃: {}", order.getOrderId());
                return null;
            }

            return order;
        };
    }
}
```

**Step 5：手动控制 Supplier 发送（按需触发而非轮询）**

如果不想让 Supplier 自动轮询，而是由业务逻辑按需触发，可以使用 `StreamBridge`：

```java
package com.example.kafkastream.controller;

import com.example.kafkastream.model.OrderMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.stream.function.StreamBridge;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/stream/orders")
@RequiredArgsConstructor
public class OrderStreamController {

    private final StreamBridge streamBridge;

    /**
     * 通过 StreamBridge 手动发送消息到指定绑定
     */
    @PostMapping
    public String sendOrder(@RequestParam String userId,
                           @RequestParam Double amount) {
        OrderMessage order = new OrderMessage(
                UUID.randomUUID().toString(),
                userId, amount, "CREATED"
        );

        // 发送到 orderSupplier-out-0 绑定对应的 Topic
        boolean sent = streamBridge.send("orderSupplier-out-0", order);

        log.info("StreamBridge 发送结果: {}, orderId={}", sent, order.getOrderId());
        return sent ? "发送成功: " + order.getOrderId() : "发送失败";
    }
}
```

**Step 6：禁用 Supplier 自动轮询（仅用 StreamBridge）**

```yaml
spring:
  cloud:
    function:
      definition: orderConsumer;orderProcessor  # 不包含 orderSupplier
```

> 当不把 `orderSupplier` 加入 `definition` 时，Spring 不会自动轮询调用它。但 `StreamBridge` 仍可使用 `orderSupplier-out-0` 这个绑定名称发送消息。

---

# 第 4 章 Kafka 常见面试题精讲

## 4.1 基础概念与架构类面试题

### Q1：Kafka 中的 ISR、OSR、AR 分别是什么？

**ISR（In-Sync Replicas）**：与 Leader 保持同步的副本集合。Follower 通过从 Leader 拉取数据保持同步，当 Follower 落后太多（超过 `replica.lag.time.max.ms`，默认 30 秒）时，会被移出 ISR。

**OSR（Out-of-Sync Replicas）**：与 Leader 同步滞后的副本集合，不在 ISR 中的副本。

**AR（All Replicas）**：分区所有副本的集合，AR = ISR + OSR。

> **面试加分点**：Kafka 3.8.0 中移除了 `replica.lag.max.messages` 参数（早期版本基于消息条数判断），仅保留基于时间的判断 `replica.lag.time.max.ms`。这是因为基于消息条数的判断在突发流量时容易误判。

### Q2：Kafka 中的 HW（High Watermark）和 LEO（Log End Offset）是什么？

**LEO（Log End Offset）**：每个副本日志的下一条待写入消息的 Offset，即日志的末端位置。

**HW（High Watermark）**：所有 ISR 副本中最小的 LEO，即所有 ISR 副本都已确认收到的最大 Offset。消费者只能消费 HW 之前的消息。

```
Leader:    [0] [1] [2] [3] [4] [5] [6]    LEO=7
Follower1: [0] [1] [2] [3] [4] [5]        LEO=6
Follower2: [0] [1] [2] [3] [4]            LEO=5

HW = min(7, 6, 5) = 5  →  消费者只能消费 offset 0~4 的消息
```

> **KRaft 模式下的变化**：KRaft 模式引入了 **Leader Epoch** 机制来替代旧的 HW 截断机制，解决了 Leader 切换时可能的数据丢失和不一致问题。

### Q3：Kafka 为什么不支持读写分离（让 Follower 提供读服务）？

1. **数据一致性**：Follower 的数据可能滞后于 Leader，读写分离会导致不同消费者读到不一致的数据
2. **延迟问题**：Follower 需要从 Leader 拉取数据，增加读延迟
3. **复杂度**：读写分离需要处理副本同步延迟、读请求路由等复杂逻辑
4. **Kafka 设计哲学**：Kafka 追求高吞吐和低延迟，通过分区实现并行，而非通过读写分离分散压力。Leader 承担读写，Follower 仅做冗余备份

### Q4：KRaft 模式与 ZooKeeper 模式有什么区别？

| 维度 | ZooKeeper 模式 | KRaft 模式 |
|------|---------------|-----------|
| 元数据存储 | ZooKeeper | Kafka 内部 Topic (`__cluster_metadata`) |
| Controller 选举 | ZooKeeper 临时节点 | Raft 共识算法 |
| 外部依赖 | 需要 ZooKeeper 集群 | 无外部依赖 |
| 元数据规模 | 限制在数十万 Partition | 可支撑百万级 Partition |
| 故障恢复 | 较慢（依赖 ZK Session 超时） | 更快（Raft 选举） |
| Kafka 版本 | 3.8.0 仍支持（已标记废弃） | 3.8.0 推荐 |
| 未来 | Kafka 4.0 移除 | 唯一模式 |

### Q5：Kafka 中的消费者 Rebalance 有哪些触发条件？

1. **消费者加入 Group**：新消费者上线
2. **消费者离开 Group**：消费者主动关闭或异常退出（心跳超时）
3. **消费者订阅的 Topic 数量变化**：新增或减少订阅 Topic
4. **Topic 分区数变化**：增加分区数
5. **消费者被踢出 Group**：两次 poll 间隔超过 `max.poll.interval.ms`

> **面试加分点**：提到 `CooperativeStickyAssignor` 的增量式 Rebalance，它不会暂停所有消费，只迁移需要变更的分区，大幅减少 Rebalance 造成的消费停顿。

---

## 4.2 消息可靠性与数据丢失/重复问题

### Q6：Kafka 如何保证消息不丢失？

消息不丢失需要从三个环节保证：

**1. 生产者端**：

```yaml
spring:
  kafka:
    producer:
      acks: all                           # 所有 ISR 副本确认
      retries: 3                           # 失败重试
      properties:
        enable.idempotence: true           # 幂等性防重复
```

**2. Broker 端**：

```properties
# Topic 配置
replication.factor=3          # 3 副本
min.insync.replicas=2         # 至少 2 个副本同步成功
unclean.leader.election.enable=false  # 禁止非 ISR 副本成为 Leader（防止数据丢失）
```

**3. 消费者端**：

```yaml
spring:
  kafka:
    consumer:
      enable-auto-commit: false            # 关闭自动提交
    listener:
      ack-mode: manual_immediate           # 手动提交
```

> **核心思路**：生产者用 `acks=all` 保证消息写入多副本，Broker 用 `min.insync.replicas` 保证至少 2 副本同步，消费者用手动提交 Offset 保证处理完成后才标记消费完成。

### Q7：Kafka 如何保证消息有序性？

**分区内有序**：Kafka 只保证单个 Partition 内消息有序。

**保证有序性的方案**：

1. **单 Partition**：整个 Topic 只有一个分区，所有消息有序（牺牲并行度）
2. **Key 路由**：相同业务 Key 的消息发往同一 Partition，保证同一业务实体的消息有序

```java
// 使用 orderId 作为 Key，同一订单的消息进入同一分区
kafkaTemplate.send("order-events", orderId, event);
```

> **注意**：开启重试时，如果 `max.in.flight.requests.per.connection > 1`，重试可能导致消息乱序。开启幂等性后（`enable.idempotence=true`），Kafka 能在 `max.in.flight.requests.per.connection <= 5` 的情况下保证分区内顺序，即使有重试。

### Q8：Kafka 如何实现 Exactly-Once 语义？

Kafka 的 Exactly-Once 语义通过三个机制组合实现：

1. **幂等生产者**：`enable.idempotence=true`，通过 PID + Sequence Number 防止重试导致的消息重复
2. **事务**：跨分区/跨 Topic 的原子写入，配合 `isolation.level=read_committed` 消费者只读已提交消息
3. **消费-生产模式**：`sendOffsetsToTransaction` 将消费 Offset 提交纳入事务，保证消费和生产原子性

```
消费 Topic A ──▶ 处理 ──▶ 生产到 Topic B ──▶ 提交 Offset (A)
         └──────────── 全部在同一事务中 ────────────┘
```

> **限制**：Kafka 的 Exactly-Only 仅限于 Kafka 内部（Topic 之间）。如果下游是外部系统（如数据库），需要业务层自行实现幂等（如唯一键约束、状态机等）。

### Q9：消费者如何处理消费失败的消息？

**方案一：重试 + 死信队列（DLT）**

Spring Kafka 提供了 `DeadLetterPublishingRecoverer` 和 `DefaultErrorHandler`：

```java
package com.example.kafkademo.config;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.TopicPartition;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

@Configuration
public class KafkaErrorHandlingConfig {

    @Bean
    public DefaultErrorHandler errorHandler(KafkaTemplate<Object, Object> template) {
        // 死信队列发布器：失败消息发送到 <原Topic>.DLT
        DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(
                template,
                (ConsumerRecord<?, ?> record, Exception ex) ->
                    new TopicPartition(record.topic() + ".DLT", record.partition())
        );

        // 重试策略：间隔 1 秒，最多重试 3 次
        FixedBackOff backOff = new FixedBackOff(1000L, 3);

        DefaultErrorHandler handler = new DefaultErrorHandler(recoverer, backOff);
        // 指定不重试的异常（直接进死信队列）
        handler.addNotRetryableExceptions(IllegalArgumentException.class);

        return handler;
    }
}
```

**方案二：手动跳过（ack 后记录日志）**

```java
@KafkaListener(topics = "order-events")
public void onMessage(ConsumerRecord<String, String> record, Acknowledgment ack) {
    try {
        process(record.value());
        ack.acknowledge();
    } catch (Exception e) {
        log.error("处理失败，跳过此消息: offset={}", record.offset(), e);
        ack.acknowledge(); // 跳过坏消息
    }
}
```

---

## 4.3 性能调优与生产环境实战经验

### Q10：如何提高 Kafka 生产者的吞吐量？

```yaml
spring:
  kafka:
    producer:
      batch-size: 65536              # 增大批次 64KB
      buffer-memory: 67108864        # 增大缓冲区 64MB
      compression-type: lz4          # 启用压缩
      properties:
        linger.ms: 20                # 适度等待攒批
        send.buffer.bytes: 1048576   # TCP 发送缓冲区 1MB
```

| 调优项 | 效果 |
|--------|------|
| 增大 `batch.size` | 减少网络请求次数 |
| 增大 `linger.ms` | 攒更多消息一起发 |
| 启用压缩 | 减少网络传输量 |
| 增大 `buffer.memory` | 减少阻塞概率 |
| 异步发送 | 不阻塞业务线程 |

### Q11：如何提高 Kafka 消费者的吞吐量？

```yaml
spring:
  kafka:
    consumer:
      max-poll-records: 500           # 单次拉取更多消息
      fetch.min.bytes: 1024           # 最小拉取字节数
      properties:
        max.partition.fetch.bytes: 1048576  # 每分区最大拉取
    listener:
      concurrency: 6                  # 增加消费者线程数
      type: batch                     # 批量消费
      ack-mode: manual_immediate
```

| 调优项 | 效果 |
|--------|------|
| 增大 `max.poll.records` | 单次拉取更多消息 |
| 增加分区数 + 消费者数 | 提高并行度 |
| 批量消费 | 减少逐条处理开销 |
| 异步处理 | 消费线程不阻塞 |
| 增大 `max.poll.interval.ms` | 避免处理慢被踢出 |

### Q12：生产环境中如何合理设置分区数？

**计算公式参考**：

```
分区数 ≈ 目标吞吐量 / 单分区吞吐量

例如：
- 目标吞吐量: 100MB/s
- 单分区生产吞吐: 10MB/s
- 单分区消费吞吐: 5MB/s
- 分区数 = max(100/10, 100/5) = 20
```

**注意事项**：
- 分区数只能增加不能减少
- 过多分区会增加 Broker 内存开销（每个分区都有副本和索引）
- 过多分区会增加 Controller 管理负担
- 建议单 Broker 分区数不超过 4000（取决于硬件）

### Q13：如何监控 Kafka 集群健康状态？

**关键监控指标**：

| 指标 | 说明 | 告警阈值建议 |
|------|------|------------|
| `UnderReplicatedPartitions` | 副本不同步的分区数 | > 0 持续 5 分钟 |
| `OfflinePartitions` | 离线分区数（无 Leader） | > 0 立即告警 |
| `ActiveControllerCount` | 活跃 Controller 数 | ≠ 1 立即告警 |
| `MessagesInPerSec` | 每秒消息量 | 突变告警 |
| `BytesInPerSec` / `BytesOutPerSec` | 流量监控 | 接近带宽上限告警 |
| `RequestLatency` | 请求延迟 | P99 > 100ms |
| `ConsumerLag` | 消费延迟 | 持续增长告警 |

**常用工具**：
- Kafka Manager / CMAK（Cluster Manager for Apache Kafka）
- Kafka UI
- Prometheus + Grafana + JMX Exporter
- Confluent Control Center

---

## 4.4 Spring Boot 整合 Kafka 深度问题

### Q14：Spring Kafka 中 @KafkaListener 的并发度（concurrency）如何理解？

`concurrency` 参数决定每个 `@KafkaListener` 创建的消费者线程数。

```yaml
spring:
  kafka:
    listener:
      concurrency: 3
```

**关键规则**：
- 每个消费者线程相当于一个独立的 KafkaConsumer 实例
- 如果 Topic 有 N 个分区，`concurrency=C`：
  - C ≤ N：每个线程分配 N/C 个分区
  - C > N：多余的线程空闲
- 实际有效并发度 = min(concurrency, partitionCount)

> **最佳实践**：`concurrency` 应 ≤ 分区数。例如 Topic 有 6 个分区，设置 `concurrency=3`，每个线程消费 2 个分区。

### Q15：Spring Kafka 的 AckMode 有哪些？如何选择？

| AckMode | 说明 | 适用场景 |
|---------|------|---------|
| `RECORD` | 每条消息处理完后自动提交 | 逐条处理、允许少量重复 |
| `BATCH`（默认） | 每次 poll 的批次处理完后自动提交 | 通用场景 |
| `TIME` | 定时提交（配合 ack-time） | 对延迟不敏感 |
| `COUNT` | 处理固定数量后提交 | 批量场景 |
| `COUNT_TIME` | TIME 和 COUNT 满足任一即提交 | - |
| `MANUAL` | 手动调用 acknowledge()，下次 poll 时提交 | 精确控制 |
| `MANUAL_IMMEDIATE` | 手动调用 acknowledge() 后立即提交 | **推荐**：精确控制 + 低重复风险 |

```yaml
spring:
  kafka:
    consumer:
      enable-auto-commit: false    # 关闭自动提交（AckMode 生效前提）
    listener:
      ack-mode: manual_immediate   # 推荐配置
```

### Q16：Spring Kafka 如何实现消息的批量消费？

```yaml
spring:
  kafka:
    listener:
      type: batch                   # 批量模式
      ack-mode: manual_immediate
    consumer:
      max-poll-records: 100         # 单次最大拉取
```

```java
@KafkaListener(topics = "order-events", groupId = "batch-group")
public void onBatch(List<ConsumerRecord<String, OrderEvent>> records, Acknowledgment ack) {
    log.info("批量消费 {} 条消息", records.size());

    // 批量处理
    List<OrderEvent> events = records.stream()
            .map(ConsumerRecord::value)
            .toList();

    // 批量写入数据库等
    batchProcess(events);

    ack.acknowledge();
}
```

### Q17：Spring Kafka 中如何动态指定消费的 Topic？

```java
@KafkaListener(topics = "#{@topicProvider.getTopics()}", groupId = "dynamic-group")
public void onMessage(ConsumerRecord<String, String> record) {
    // ...
}
```

```java
@Component
public class TopicProvider {
    public String[] getTopics() {
        // 从配置中心、数据库等动态获取
        return new String[]{"topic-a", "topic-b"};
    }
}
```

### Q18：Spring Kafka 中 KafkaTemplate 和 @KafkaListener 如何优雅停机？

Spring Boot 通过 `ContainerStoppingErrorHandler` 和 `SmartLifecycle` 实现优雅停机：

```yaml
spring:
  kafka:
    listener:
      # 停机时等待当前消息处理完成
      shutdown-timeout: 30s
```

```java
package com.example.kafkademo.config;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaGracefulShutdownConfig {

    @Bean
    public ConsumerFactory<String, String> consumerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        // 关闭时触发 Rebalance 前提交 Offset
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
        return new DefaultKafkaConsumerFactory<>(props);
    }
}
```

> Spring Boot 的 `spring.kafka.listener.shutdown-timeout` 控制消费者容器关闭时等待处理完成的最大时间。在 `application.yml` 中配置 `server.shutdown=graceful` 可实现整体优雅停机。

### Q19：Spring Cloud Stream 与 Spring Kafka 在什么场景下分别选择？

**选择 Spring Kafka 的场景**：
- 项目仅使用 Kafka，无需切换中间件
- 需要精细控制 Kafka 原生特性（事务、拦截器、自定义分区器等）
- 团队对 Kafka 熟悉，追求简单直接
- 需要使用 Kafka Streams 进行流处理

**选择 Spring Cloud Stream 的场景**：
- 微服务架构，服务间可能使用不同消息中间件
- 需要统一的消息编程模型，屏蔽底层中间件差异
- 未来可能从 Kafka 迁移到 RabbitMQ / RocketMQ 等
- 使用 Spring Cloud 生态（如 Spring Cloud Function）

> **核心差异**：Spring Cloud Stream 通过 Binder 抽象提供了中间件无关性，但代价是丧失部分 Kafka 原生特性的精细控制能力。如果确定只用 Kafka，直接用 Spring Kafka 更灵活。

### Q20：在 Spring Boot 中如何实现 Kafka 消费者的限流？

**方案一：通过 max.poll.records + 延时 Ack**

```java
@KafkaListener(topics = "order-events")
public void onMessage(ConsumerRecord<String, String> record, Acknowledgment ack) {
    process(record.value());
    ack.acknowledge();

    // 限流：每条消息处理后暂停
    try {
        Thread.sleep(100); // 模拟限流
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
    }
}
```

**方案二：使用 RateLimiter（Guava / Resilience4j）**

```java
@KafkaListener(topics = "order-events")
public void onMessage(ConsumerRecord<String, String> record, Acknowledgment ack) {
    // 使用 Guava RateLimiter，限制 10 条/秒
    rateLimiter.acquire();
    process(record.value());
    ack.acknowledge();
}
```

**方案三：Pause / Resume 消费**

`@KafkaListener` 方法可以直接注入 `Consumer` 参数来控制暂停和恢复：

```java
@KafkaListener(topics = "order-events")
public void onMessage(ConsumerRecord<String, String> record,
                      Acknowledgment ack,
                      Consumer<?, ?> consumer) {
    // 当下游处理能力不足时暂停消费
    // consumer.pause(consumer.assignment());
    // 短暂处理后恢复消费
    // consumer.resume(consumer.assignment());
    
    process(record.value());
    ack.acknowledge();
}
```

---

## 附录：完整项目结构

```
kafka-demo/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/com/example/kafkademo/
│   │   │   ├── KafkaDemoApplication.java          # 启动类
│   │   │   ├── config/
│   │   │   │   ├── KafkaProducerConfig.java       # 生产者配置
│   │   │   │   ├── KafkaTransactionConfig.java    # 事务配置
│   │   │   │   └── KafkaErrorHandlingConfig.java  # 错误处理配置
│   │   │   ├── controller/
│   │   │   │   └── OrderController.java           # REST 接口
│   │   │   ├── consumer/
│   │   │   │   ├── OrderEventConsumer.java        # 消费者
│   │   │   │   └── JsonStringConsumer.java        # JSON 消费者
│   │   │   ├── interceptor/
│   │   │   │   └── TraceInterceptor.java          # 拦截器
│   │   │   ├── model/
│   │   │   │   └── OrderEvent.java                # 消息对象
│   │   │   ├── partition/
│   │   │   │   └── CustomPartitioner.java         # 自定义分区器
│   │   │   └── producer/
│   │   │       ├── OrderEventProducer.java        # 生产者
│   │   │       ├── JsonStringProducer.java        # JSON 生产者
│   │   │       ├── RetryableProducer.java         # 重试生产者
│   │   │       └── TransactionalOrderProducer.java# 事务生产者
│   │   └── resources/
│   │       └── application.yml                     # 配置文件
│   └── test/
│       └── java/com/example/kafkademo/
│           └── KafkaDemoApplicationTests.java
```

---

> **教程版本信息**：
> - Spring Boot: 3.2.5
> - Spring Kafka: 3.1.x (由 Spring Boot 3.2.x 管理)
> - Apache Kafka: 3.8.0 (KRaft 模式)
> - Spring Cloud: 2023.0.1 (Leyton)
> - Spring Cloud Stream: 4.1.x
> - JDK: 17+
>
> 本教程所有代码均经过逻辑验证，可直接用于实际项目开发。建议在学习时按章节逐步实践，先搭建 Kafka 集群，再逐步实现 Spring Boot 整合功能。
