# Spring Cloud Alibaba Seata 分布式事务教程

> **案例场景**: 模拟电商下单流程 — 创建订单 → 扣减库存 → 扣减账户余额,任一步骤失败则全局回滚。
>
> **技术栈**: Spring Boot + Spring Cloud + Spring Cloud Alibaba + Nacos + Seata + MyBatis + MySQL

---

## 目录

- [一、Seata 简介](#一seata-简介)
- [二、核心概念](#二核心概念)
- [三、版本说明与兼容性](#三版本说明与兼容性)
- [四、环境准备](#四环境准备)
- [五、Seata Server 安装与配置（配置文件解释）](#五seata-server-安装与配置配置文件解释)
- [六、数据库准备（SQL 解释）](#六数据库准备sql-解释)
- [七、案例项目结构与业务说明](#七案例项目结构与业务说明)
- [八、核心代码与配置文件解释](#八核心代码与配置文件解释)
- [九、启动与测试验证](#九启动与测试验证)
- [十、常见问题](#十常见问题)

---

## 一、Seata 简介

**Seata**（Simple Extensible Autonomous Transaction Architecture）是阿里巴巴开源的分布式事务解决方案，致力于提供高性能和简单易用的分布式事务服务。

### 为什么需要分布式事务？

在微服务架构中，一个业务操作往往涉及多个服务和多个数据库。例如"下单"操作需要：

```
订单服务(写订单) → 库存服务(扣库存) → 账户服务(扣余额)
```

这三个操作分布在不同的服务和数据库中，本地事务无法保证它们的一致性。如果扣完库存后账户余额不足，库存已经扣减却无法自动回滚，就会造成数据不一致。Seata 就是为了解决这个问题。

### Seata 支持的事务模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| **AT** | 自动补偿模式，无侵入，Seata 自动生成反向 SQL 回滚 | 大多数业务场景（**本教程使用**） |
| **TCC** | Try-Confirm-Cancel，需要自定义三个方法 | 需要精细控制的高性能场景 |
| **SAGA** | 长事务模式，通过补偿事务回滚 | 业务流程长、涉及第三方系统 |
| **XA** | 基于 XA 协议，强一致性 | 对一致性要求极高的场景 |

本教程使用 **AT 模式**，因为它对业务零侵入——只需加一个 `@GlobalTransactional` 注解即可。

---

## 二、核心概念

理解以下三个角色是理解 Seata 的基础：

```
         ┌──────────────────────────────────────────┐
         │           TC (Transaction Coordinator)    │
         │           事务协调者 = Seata Server        │
         │   维护全局事务状态, 决定提交或回滚          │
         └──────┬───────────────────┬───────────────┘
                │                   │
     ┌──────────┴──┐          ┌─────┴──────────┐
     │  TM (事务    │          │  RM (资源       │
     │  管理器)     │          │  管理器)        │
     │  开启/提交/  │          │  管理分支事务    │
     │  回滚全局事务│          │  执行SQL+undo   │
     └─────────────┘          └────────────────┘
       订单服务                  库存服务/账户服务
```

| 角色 | 全称 | 职责 | 本教程对应 |
|------|------|------|-----------|
| **TC** | Transaction Coordinator | 事务协调者，独立部署的 Seata Server，维护全局和分支事务状态 | seata-server |
| **TM** | Transaction Manager | 事务管理器，定义全局事务范围（开启、提交、回滚） | 订单服务 OrderService |
| **RM** | Resource Manager | 资源管理器，管理分支事务上的本地资源（数据库） | 库存服务、账户服务 |

### AT 模式工作流程

```
TM                        TC                        RM
 │                         │                         │
 │  1. 开启全局事务          │                         │
 │ ──────────────────────> │                         │
 │  返回 XID (全局事务ID)    │                         │
 │ <────────────────────── │                         │
 │                         │                         │
 │  2. 执行分支事务(带XID)  ──────────────────────>  │
 │                         │  3. 注册分支事务          │
 │                         │ <─────────────────────  │
 │                         │  4. 执行SQL + 记录undo   │
 │                         │  5. 上报分支状态          │
 │                         │ <─────────────────────  │
 │                         │                         │
 │  6. 全局提交/回滚         │                         │
 │ ──────────────────────> │                         │
 │                         │  7. 提交:异步删undo      │
 │                         │     回滚:通知RM补偿       │
 │                         │ ──────────────────────> │
```

**关键点**：AT 模式通过 `undo_log` 表记录数据变更前后的镜像，回滚时根据前镜像自动生成反向 SQL 执行补偿，对业务代码完全透明。

---

## 三、版本说明与兼容性

### 版本组合（经过官方兼容验证）

| 组件 | 版本 |
|------|------|
| Spring Boot | 3.5.0 |
| Spring Cloud | 2025.0.0 |
| Spring Cloud Alibaba | 2025.0.0.0 |
| Seata | 2.5.0（由 SCA BOM 管理） |
| Nacos Client | 3.0.3（由 SCA BOM 管理） |
| JDK | 17+ |

### 版本兼容性说明

本教程采用 Spring Cloud Alibaba 官方兼容矩阵中 **2025.0.0.0** 稳定版对应的组合。该组合的对应关系如下：

| Spring Cloud Alibaba | Spring Cloud | Spring Boot | JDK | Seata | Nacos |
|---------------------|-------------|-------------|-----|-------|-------|
| **2025.0.0.0** | 2025.0.0 | 3.5.0 | 17+ | 2.5.0 | 3.0.3 |

> **Spring Boot 3.x 关键变更**：
> 1. 全面使用 Jakarta EE 命名空间（`javax.*` → `jakarta.*`）
> 2. MySQL 驱动坐标变更（`mysql:mysql-connector-java` → `com.mysql:mysql-connector-j`）
> 3. Druid 需使用 `druid-spring-boot-3-starter`
> 4. MyBatis Spring Boot Starter 需 3.0+
> 5. Seata 已成为 Apache 顶级项目，Maven groupId 变更为 `org.apache.seata`
> 6. Spring Cloud 2025 移除了 Ribbon 和 Hystrix，负载均衡使用 Spring Cloud LoadBalancer

---

## 四、环境准备

### 4.1 所需软件

| 软件 | 版本 | 说明 |
|------|------|------|
| JDK | 17+ | Spring Boot 3.x 最低要求 JDK 17 |
| MySQL | 8.0+ | 需创建 4 个数据库 |
| Nacos Server | 3.x | 注册中心 (服务发现) |
| Seata Server | 2.5.0 | 事务协调者 (TC) |
| Maven | 3.6+ | 项目构建 |

### 4.2 环境启动顺序

```
1. 启动 MySQL (创建数据库和表)
2. 启动 Nacos Server
3. 启动 Seata Server
4. 启动业务服务 (storage → account → order)
5. 测试下单接口
```

### 4.3 Nacos 启动

```bash
# 下载 Nacos 3.x 后解压, 进入 bin 目录
sh startup.sh -m standalone   # Linux/Mac
startup.cmd -m standalone      # Windows

# 访问控制台: http://localhost:8848/nacos
# 默认账号密码: nacos / nacos
```

---

## 五、Seata Server 安装与配置（配置文件解释）

### 5.1 下载 Seata Server

```bash
# 下载 Apache Seata 2.5.0
# 官方下载页: https://github.com/apache/incubator-seata/releases
# 解压后目录结构:
# seata-server-2.5.0/
# ├── bin/          # 启动脚本
# │   ├── seata-server.sh
# │   └── seata-server.bat
# ├── conf/         # 配置文件
# │   └── application.yml    # (2.0+ 推荐) 主配置 (注册中心 + 存储模式)
# └── lib/          # 依赖 jar
```

### 5.2 配置文件详解

Seata 2.0+ 推荐使用 `application.yml` 作为唯一配置文件，替代旧版的 `registry.conf` + `file.conf`。本教程仅使用 `application.yml`，所有配置（注册中心、存储模式等）在此文件中统一管理。

#### 5.2.1 application.yml（推荐，Seata 2.0+）

文件位置：`seata-server/conf/application.yml`

> 完整文件见 `seata-server-config/application.yml`

```yaml
server:
  port: 7091                    # Seata Web 控制台端口 (注意: 不是 TC 通信端口)

seata:
  console:
    user:
      username: seata           # 控制台登录用户名
      password: seata           # 控制台登录密码

  # ==================== 注册中心 ====================
  # Seata Server 将自己注册到 Nacos, 客户端通过 Nacos 发现 TC
  registry:
    type: nacos                 # 注册中心类型: nacos
    nacos:
      application: seata-server # 注册的服务名 (客户端据此查找)
      server-addr: 127.0.0.1:8848  # Nacos 地址
      group: SEATA_GROUP        # 注册的分组
      namespace: ''             # 命名空间 (空 = public)
      cluster: default          # 集群名称 ★ 客户端必须与此一致

  # ==================== 存储模式 ====================
  # 所有存储配置直接在本地管理
  store:
    mode: db                    # ★ 存储: file/db/redis, 推荐 db
    db:
      datasource: druid         # 连接池
      db-type: mysql            # 数据库类型
      driver-class-name: com.mysql.cj.jdbc.Driver
      # ★ 完整数据库连接 URL (指向 seata_server 库, 需提前建好表)
      url: jdbc:mysql://127.0.0.1:3306/seata_server?useUnicode=true&characterEncoding=utf-8&useSSL=false&serverTimezone=Asia/Shanghai
      user: root                # 数据库用户名
      password: root            # 数据库密码
      min-conn: 5               # 最小连接数
      max-conn: 30              # 最大连接数
      global-table: global_table        # 全局事务表
      branch-table: branch_table        # 分支事务表
      lock-table: lock_table            # 全局锁表
      distributed-lock-table: distributed_lock  # 分布式锁表
      query-limit: 100          # 单次查询最大行数
      max-wait: 5000            # 获取连接最大等待时间 (ms)
```

**关键配置说明：**

| 配置项 | 说明 |
|--------|------|
| `server.port: 7091` | Seata 控制台端口，**不是** TC 通信端口。TC 默认通信端口为 8091 |
| `registry.type: nacos` | Seata Server 注册到 Nacos，客户端从 Nacos 发现 TC |
| `store.mode: db` | 事务日志存储到数据库，支持 Server 集群。file 模式仅支持单机 |
| `store.db.url` | 完整的数据库连接 URL，指向 `seata_server` 库（需提前建好 4 张表） |
| `cluster: default` | 集群名称，客户端的 `seata.registry.nacos.cluster` 必须与此一致 |

> **说明**：所有 Seata 配置在本地 `application.yml` 中管理，简洁直观。

### 5.3 Seata Server 建表

Seata Server 在 `db` 存储模式下需要 4 张表（见 `sql/seata-server.sql`）：

| 表名 | 说明 |
|------|------|
| `global_table` | 全局事务表，记录每个全局事务的 XID、状态、超时时间 |
| `branch_table` | 分支事务表，记录每个分支事务的信息 |
| `lock_table` | 全局锁表，AT 模式下实现写隔离 |
| `distributed_lock` | 分布式锁表，TC 集群选主用 |

```sql
-- 执行 sql/seata-server.sql, 在 seata_server 库中创建以上 4 张表
CREATE DATABASE IF NOT EXISTS `seata_server` DEFAULT CHARACTER SET utf8mb4;
USE `seata_server`;
-- 然后执行 seata-server.sql 中的建表语句
```

### 5.4 启动 Seata Server

```bash
# Linux/Mac
sh bin/seata-server.sh

# Windows
bin\seata-server.bat

# 后台启动 (Linux)
nohup sh bin/seata-server.sh > seata.log 2>&1 &

# 启动后验证:
# 1. 查看 Nacos 控制台 → 服务列表, 应出现 seata-server 服务
# 2. 访问 http://localhost:7091 (控制台, 账号 seata/seata)
```

---

## 六、数据库准备（SQL 解释）

### 6.1 数据库总览

本案例需要 4 个数据库：

| 数据库 | 用途 | 表 |
|--------|------|-----|
| `seata_server` | Seata Server 存储 | global_table, branch_table, lock_table, distributed_lock |
| `seata_order` | 订单业务库 | t_order, undo_log |
| `seata_storage` | 库存业务库 | t_storage, undo_log |
| `seata_account` | 账户业务库 | t_account, undo_log |

### 6.2 SQL 文件说明

| 文件 | 说明 |
|------|------|
| `sql/seata-server.sql` | Seata Server 的 4 张存储表 |
| `sql/business-db.sql` | 3 个业务库的建表语句 + 初始数据 + undo_log |
| `sql/undo_log.sql` | undo_log 表独立建表语句（已在 business-db.sql 中包含） |

### 6.3 执行顺序

```sql
-- 1. 创建 Seata Server 存储库 (执行 sql/seata-server.sql)
-- 2. 创建业务库 (执行 sql/business-db.sql)
```

### 6.4 undo_log 表解释

```sql
CREATE TABLE `undo_log` (
    `branch_id`     BIGINT       NOT NULL COMMENT '分支事务ID',
    `xid`           VARCHAR(128) NOT NULL COMMENT '全局事务ID',
    `context`       VARCHAR(128) NOT NULL COMMENT '序列化上下文',
    `rollback_info` LONGTEXT     NOT NULL COMMENT '回滚信息(前镜像+后镜像)',
    `log_status`    INT          NOT NULL COMMENT '0:正常 1:防悬挂',
    `log_created`   DATETIME(6)  NOT NULL COMMENT '创建时间',
    `log_modified`  DATETIME(6)  NOT NULL COMMENT '修改时间',
    UNIQUE KEY `ux_undo_log` (`xid`, `branch_id`)
);
```

**工作原理**：
- AT 模式下，Seata 自动代理数据源
- 执行业务 SQL **前**：解析 SQL，查询变更前的数据（**前镜像 before image**），存入 `rollback_info`
- 执行业务 SQL **后**：查询变更后的数据（**后镜像 after image**），存入 `rollback_info`
- **全局回滚时**：RM 根据 `rollback_info` 中的前镜像，生成反向 SQL 执行补偿
- **全局提交时**：TC 异步通知 RM 删除对应的 undo_log 记录

### 6.5 业务表结构与初始数据

```sql
-- t_order: 订单表
CREATE TABLE `t_order` (
    `id`         BIGINT NOT NULL AUTO_INCREMENT,
    `user_id`    BIGINT DEFAULT NULL COMMENT '用户ID',
    `product_id` BIGINT DEFAULT NULL COMMENT '产品ID',
    `count`      INT    DEFAULT NULL COMMENT '数量',
    `money`      DECIMAL(11,0) DEFAULT NULL COMMENT '金额',
    `status`     INT    DEFAULT NULL COMMENT '0-创建中 1-已完成',
    PRIMARY KEY (`id`)
);

-- t_storage: 库存表 (初始: 产品1, 总库存100, 剩余100)
CREATE TABLE `t_storage` (
    `id`         BIGINT NOT NULL AUTO_INCREMENT,
    `product_id` BIGINT DEFAULT NULL,
    `total`      INT    DEFAULT NULL COMMENT '总库存',
    `used`       INT    DEFAULT NULL COMMENT '已用',
    `residue`    INT    DEFAULT NULL COMMENT '剩余',
    PRIMARY KEY (`id`)
);
INSERT INTO `t_storage` VALUES (1, 1, 100, 0, 100);

-- t_account: 账户表 (初始: 用户1, 总额1000, 剩余1000)
CREATE TABLE `t_account` (
    `id`      BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT DEFAULT NULL,
    `total`   DECIMAL(11,0) DEFAULT NULL COMMENT '总额度',
    `used`    DECIMAL(11,0) DEFAULT NULL COMMENT '已用',
    `residue` DECIMAL(11,0) DEFAULT '0' COMMENT '剩余',
    PRIMARY KEY (`id`)
);
INSERT INTO `t_account` VALUES (1, 1, 1000, 0, 1000);
```

---

## 七、案例项目结构与业务说明

### 7.1 业务流程

```
用户下单 (HTTP)
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  订单服务 (TM)          库存服务 (RM)      账户服务 (RM)   │
│  seata-order-service    seata-storage-service  seata-account-service │
│                                                             │
│  @GlobalTransactional                                       │
│  1. 创建订单 ──> 写入 seata_order.t_order                    │
│  2. Feign调用 ──> 扣减 seata_storage.t_storage (库存)        │
│  3. Feign调用 ───────────────────────> 扣减 seata_account.t_account (余额) │
│  4. 更新订单状态                                              │
│                                                             │
│  任一步骤失败 → 全局回滚 → 所有分支事务自动补偿               │
└─────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    seata_order 库      seata_storage 库      seata_account 库
    (t_order + undo_log) (t_storage + undo_log) (t_account + undo_log)
```

### 7.2 项目结构

```
seata-demo/                          # 父工程
├── pom.xml                          # 父 POM, 管理依赖版本
├── seata-common/                    # 公共模块
│   ├── pom.xml
│   └── src/main/java/com/example/common/
│       └── entity/
│           ├── Order.java           # 订单实体
│           └── CommonResult.java    # 统一返回结果
├── seata-order-service/             # 订单服务 (TM)
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/example/order/
│       │   ├── OrderServiceApplication.java   # 启动类
│       │   ├── controller/OrderController.java
│       │   ├── service/OrderService.java       # ★ @GlobalTransactional
│       │   ├── mapper/OrderMapper.java
│       │   └── feign/
│       │       ├── StorageFeignService.java    # 调用库存服务
│       │       └── AccountFeignService.java    # 调用账户服务
│       └── resources/
│           ├── application.yml
│           └── mapper/OrderMapper.xml
├── seata-storage-service/           # 库存服务 (RM)
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/example/storage/
│       │   ├── StorageServiceApplication.java
│       │   ├── controller/StorageController.java
│       │   ├── service/StorageService.java
│       │   └── mapper/StorageMapper.java
│       └── resources/
│           ├── application.yml
│           └── mapper/StorageMapper.xml
├── seata-account-service/           # 账户服务 (RM)
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/example/account/
│       │   ├── AccountServiceApplication.java
│       │   ├── controller/AccountController.java
│       │   ├── service/AccountService.java     # ★ 超时回滚演示
│       │   └── mapper/AccountMapper.java
│       └── resources/
│           ├── application.yml
│           └── mapper/AccountMapper.xml
```

### 7.3 端口分配

| 服务 | 端口 | 数据库 |
|------|------|--------|
| Seata Server (控制台) | 7091 | seata_server |
| Seata Server (TC通信) | 8091 | - |
| Nacos | 8848 | - |
| 订单服务 | 2001 | seata_order |
| 库存服务 | 2002 | seata_storage |
| 账户服务 | 2003 | seata_account |

---

## 八、核心代码与配置文件解释

### 8.1 父 POM 依赖管理

文件：`code/pom.xml`

父 POM 负责统一管理版本号、引入三个 BOM、声明所有子模块共享的公共依赖，子模块自动继承无需重复声明。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>seata-demo</artifactId>
    <version>1.0.0</version>
    <packaging>pom</packaging>
    <name>seata-demo</name>
    <description>Spring Cloud Alibaba Seata 分布式事务教程案例</description>

    <!-- ==================== 子模块 ==================== -->
    <modules>
        <module>seata-common</module>
        <module>seata-order-service</module>
        <module>seata-storage-service</module>
        <module>seata-account-service</module>
    </modules>

    <!-- ==================== 版本声明 ==================== -->
    <properties>
        <java.version>17</java.version>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>

        <!-- 核心框架版本 (兼容组合) -->
        <spring-boot.version>3.5.0</spring-boot.version>
        <spring-cloud.version>2025.0.0</spring-cloud.version>
        <spring-cloud-alibaba.version>2025.0.0.0</spring-cloud-alibaba.version>

        <!-- Seata 版本 (Server 独立部署版本, 客户端由 SCA BOM 管理) -->
        <seata.version>2.5.0</seata.version>

        <!-- Spring Boot 3.x 兼容依赖 -->
        <mybatis-spring-boot.version>3.0.4</mybatis-spring-boot.version>
        <mysql-connector.version>9.2.0</mysql-connector.version>
        <druid.version>1.2.27</druid.version>
        <lombok.version>1.18.38</lombok.version>
    </properties>

    <!-- ==================== 依赖管理 (BOM) ==================== -->
    <dependencyManagement>
        <dependencies>
            <!-- Spring Boot BOM -->
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>${spring-boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <!-- Spring Cloud BOM -->
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <!-- Spring Cloud Alibaba BOM (管理 seata/nacos/sentinel 版本) -->
            <dependency>
                <groupId>com.alibaba.cloud</groupId>
                <artifactId>spring-cloud-alibaba-dependencies</artifactId>
                <version>${spring-cloud-alibaba.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <!-- ==================== 公共依赖 (所有子模块继承) ==================== -->
    <dependencies>
        <!-- Spring Boot Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <!-- Nacos 服务注册发现 -->
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
        </dependency>
        <!-- Seata AT 模式 (已包含 seata-spring-boot-starter:2.5.0) -->
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-starter-alibaba-seata</artifactId>
        </dependency>
        <!-- MyBatis (Spring Boot 3.x 需 3.0+) -->
        <dependency>
            <groupId>org.mybatis.spring.boot</groupId>
            <artifactId>mybatis-spring-boot-starter</artifactId>
            <version>${mybatis-spring-boot.version}</version>
        </dependency>
        <!-- MySQL 驱动 (Spring Boot 3.x 新坐标) -->
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <version>${mysql-connector.version}</version>
        </dependency>
        <!-- Druid 连接池 (Spring Boot 3.x 需 druid-spring-boot-3-starter) -->
        <dependency>
            <groupId>com.alibaba</groupId>
            <artifactId>druid-spring-boot-3-starter</artifactId>
            <version>${druid.version}</version>
        </dependency>
        <!-- Lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>${lombok.version}</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <version>${spring-boot.version}</version>
            </plugin>
        </plugins>
    </build>
</project>
```

**说明**：
- 三个 BOM 通过 `import` 方式引入，统一管理依赖版本，子模块无需指定版本号
- 公共依赖（web、nacos-discovery、seata、mybatis、mysql、druid）在父 POM 声明，子模块自动继承
- `spring-cloud-starter-alibaba-seata` 已包含 `org.apache.seata:seata-spring-boot-starter:2.5.0`（由 SCA BOM 管理），无需在子模块中手动指定版本
- Spring Boot 3.x 使用 `com.mysql:mysql-connector-j`（非旧版 `mysql:mysql-connector-java`）
- Spring Boot 3.x 使用 `druid-spring-boot-3-starter`（非旧版 `druid-spring-boot-starter`）

### 8.2 公共模块（seata-common）

公共模块提供实体类和统一返回结果，供三个业务服务共享依赖。

**pom.xml** — 文件：`code/seata-common/pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <!-- 继承父 POM, 自动获得公共依赖 -->
    <parent>
        <groupId>com.example</groupId>
        <artifactId>seata-demo</artifactId>
        <version>1.0.0</version>
    </parent>

    <artifactId>seata-common</artifactId>
    <name>seata-common</name>
    <description>公共模块: 实体类、统一返回结果</description>

    <dependencies>
        <!-- 仅需 Web 依赖 (由父 POM 继承, 提供 Spring MVC 基础) -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>
</project>
```

公共模块只需继承父 POM 并引入 `spring-boot-starter-web`，不需要 Seata、数据库等依赖。其他服务通过依赖 `seata-common` 即可使用 `CommonResult` 和 `Order` 实体类。

**CommonResult.java** — 统一返回结果：

```java
@Data
@AllArgsConstructor
@NoArgsConstructor
public class CommonResult<T> {
    private Integer code;    // 状态码: 200-成功, 500-失败
    private String message;  // 提示信息
    private T data;          // 返回数据

    public static <T> CommonResult<T> success(T data) {
        return new CommonResult<>(200, "操作成功", data);
    }

    public static <T> CommonResult<T> failed(String message) {
        return new CommonResult<>(500, message, null);
    }
}
```

**Order.java** — 订单实体：

```java
@Data
@AllArgsConstructor
@NoArgsConstructor
public class Order implements Serializable {
    private Long id;          // 主键
    private Long userId;      // 用户ID
    private Long productId;   // 产品ID
    private Integer count;    // 购买数量
    private BigDecimal money; // 订单金额
    private Integer status;   // 订单状态: 0-创建中, 1-已完成
}
```

### 8.3 订单服务（seata-order-service）

订单服务是整个分布式事务的 **TM（事务管理器）**，通过 `@GlobalTransactional` 开启全局事务，协调库存服务和账户服务。

#### 8.3.1 pom.xml 依赖

文件：`code/seata-order-service/pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.example</groupId>
        <artifactId>seata-demo</artifactId>
        <version>1.0.0</version>
    </parent>

    <artifactId>seata-order-service</artifactId>
    <name>seata-order-service</name>
    <description>订单服务 - TM角色, 发起全局事务</description>

    <dependencies>
        <!-- 公共模块 (CommonResult, Order 实体) -->
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>seata-common</artifactId>
            <version>1.0.0</version>
        </dependency>

        <!-- OpenFeign: 声明式 HTTP 调用 -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-openfeign</artifactId>
        </dependency>

        <!-- Spring Cloud LoadBalancer (SC 2025 移除了 Ribbon, 需显式引入) -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-loadbalancer</artifactId>
        </dependency>

        <!-- 注意: 不需要显式声明 seata-spring-boot-starter
             父 pom 的 spring-cloud-starter-alibaba-seata 已包含
             org.apache.seata:seata-spring-boot-starter:2.5.0 -->
    </dependencies>
</project>
```

订单服务比公共模块多引入了 OpenFeign 和 LoadBalancer，用于远程调用库存和账户服务。Seata 依赖已由父 POM 统一引入。

#### 8.3.2 application.yml 配置详解

文件：`code/seata-order-service/src/main/resources/application.yml`

```yaml
server:
  port: 2001

spring:
  application:
    name: seata-order-service
  # ====== Nacos 服务注册 ======
  cloud:
    nacos:
      discovery:
        server-addr: 127.0.0.1:8848   # Nacos 地址
        namespace: public              # 命名空间
        group: SEATA_GROUP             # 分组
  # ====== 数据源 (订单库) ======
  datasource:
    type: com.alibaba.druid.pool.DruidDataSource
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql://127.0.0.1:3306/seata_order?...
    username: root
    password: root

# ====== MyBatis ======
mybatis:
  mapper-locations: classpath:mapper/*.xml
  configuration:
    map-underscore-to-camel-case: true  # 下划线转驼峰

# ====== Seata 核心配置 ======
seata:
  enabled: true                          # 启用 Seata
  application-id: ${spring.application.name}  # 应用ID
  tx-service-group: default_tx_group     # ★ 事务组名称
  enable-auto-data-source-proxy: true    # ★ AT 模式必须: 自动代理数据源
  data-source-proxy-mode: AT             # 代理模式: AT
  service:
    vgroup-mapping:
      default_tx_group: default          # ★ 事务组 -> 集群映射 (本地配置)
    grouplist:
      default: 127.0.0.1:8091           # TC 地址 (Nacos 模式下可省略)
  # ====== 注册中心 (Nacos) ======
  # 客户端通过 Nacos 发现 Seata Server (TC) 地址
  # Seata 配置在本地 application.yml 中管理
  registry:
    type: nacos
    nacos:
      application: seata-server          # ★ 查找的 TC 服务名
      server-addr: 127.0.0.1:8848
      group: SEATA_GROUP
      cluster: default                   # ★ 集群名 (必须与 Server 一致)

# ====== Feign 超时配置 ======
# 正常下游响应 < 1s, 5s 足够;
# 超时回滚测试时 account.sleep=true 会 sleep 20s > 5s, 触发 Feign 超时 -> 全局回滚
feign:
  client:
    config:
      default:
        connect-timeout: 5000           # 连接超时 5s
        read-timeout: 5000              # 读取超时 5s
```

| 配置项 | 说明 |
|--------|------|
| `tx-service-group` | 事务组名称，通过 `vgroup-mapping` 找到 TC 集群 |
| `enable-auto-data-source-proxy` | AT 模式核心：Seata 代理 JDBC，自动记录 undo_log |
| `service.vgroup-mapping` | 事务组→集群映射，本地配置 |
| `registry.type: nacos` | 从 Nacos 发现 TC 地址 |
| `cluster: default` | 集群名称，必须与 Seata Server 一致 |

#### 8.3.3 启动类（OrderServiceApplication）

文件：`code/seata-order-service/src/main/java/com/example/order/OrderServiceApplication.java`

```java
package com.example.order;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.openfeign.EnableFeignClients;

/**
 * 订单服务启动类
 *
 * - @EnableDiscoveryClient: 注册到 Nacos
 * - @EnableFeignClients: 开启 Feign 声明式调用
 */
@SpringBootApplication
@EnableDiscoveryClient
@EnableFeignClients
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}
```

**注解说明**：

| 注解 | 作用 |
|------|------|
| `@SpringBootApplication` | Spring Boot 核心注解，包含 `@Configuration` + `@EnableAutoConfiguration` + `@ComponentScan` |
| `@EnableDiscoveryClient` | 将服务注册到 Nacos 注册中心，其他服务可通过服务名发现并调用 |
| `@EnableFeignClients` | 开启 OpenFeign 声明式 HTTP 调用，扫描 `@FeignClient` 接口并生成代理实现 |

> 订单服务作为 TM（事务管理器），需要 `@EnableFeignClients` 来远程调用库存和账户服务。Seata 的 `@GlobalTransactional` 不需要在启动类上声明，直接在 Service 方法上使用即可。

#### 8.3.4 OrderController — 下单入口

文件：`code/seata-order-service/src/main/java/com/example/order/controller/OrderController.java`

```java
@RestController
public class OrderController {

    @Resource
    private OrderService orderService;

    /**
     * 下单接口
     * 测试正常: POST /order/create?userId=1&productId=1&count=10&money=100
     * 测试超时: 账户服务加 -Daccount.sleep=true 启动, sleep 20s > Feign 5s 超时 -> 回滚
     */
    @PostMapping("/order/create")
    public CommonResult createOrder(@RequestParam("userId") Long userId,
                                    @RequestParam("productId") Long productId,
                                    @RequestParam("count") Integer count,
                                    @RequestParam("money") BigDecimal money) {
        Order order = new Order();
        order.setUserId(userId);
        order.setProductId(productId);
        order.setCount(count);
        order.setMoney(money);
        orderService.createOrder(order);
        return CommonResult.success("订单创建成功");
    }
}
```

Controller 负责接收 HTTP 请求，组装 `Order` 对象后调用 Service 层。测试时通过 curl 或 Postman 调用。

#### 8.3.5 OrderService — @GlobalTransactional 核心（TM）

文件：`code/seata-order-service/src/main/java/com/example/order/service/OrderService.java`

```java
@Slf4j
@Service
public class OrderService {

    @Resource
    private OrderMapper orderMapper;
    @Resource
    private StorageFeignService storageFeignService;
    @Resource
    private AccountFeignService accountFeignService;

    /**
     * ★ @GlobalTransactional 开启全局事务
     * Seata 自动通过 RPC header 将 XID 传播到下游服务
     */
    @GlobalTransactional(name = "create-order", rollbackFor = Exception.class)
    public void createOrder(Order order) {
        log.info("========== 开始下单, XID: {} ==========", RootContext.getXID());

        // 1. 创建订单 (状态: 0-创建中)
        order.setStatus(0);
        orderMapper.createOrder(order);

        // 2. 远程调用: 扣减库存
        storageFeignService.decreaseStorage(order.getProductId(), order.getCount());

        // 3. 远程调用: 扣减余额
        accountFeignService.decreaseAccount(order.getUserId(), order.getMoney());

        // 4. 修改订单状态 (0-创建中 -> 1-已完成)
        orderMapper.updateOrderStatus(order.getUserId(), 1);

        log.info("========== 下单完成 ==========");
    }
}
```

**说明**：
- `@GlobalTransactional` 是 Seata 的核心注解，标记此方法为全局事务入口（TM 角色）
- `name`：全局事务名称，用于标识和监控
- `rollbackFor`：指定哪些异常触发回滚，建议设为 `Exception.class`
- XID 传播是自动的：Seata 拦截 Feign 调用，将 XID 放入请求头，下游服务自动加入全局事务

#### 8.3.6 OrderMapper + OrderMapper.xml — 数据访问层

文件：`code/seata-order-service/src/main/java/com/example/order/mapper/OrderMapper.java`

```java
@Mapper
public interface OrderMapper {

    /** 创建订单 (状态: 0-创建中) */
    void createOrder(Order order);

    /** 更新订单状态 (0-创建中 -> 1-已完成) */
    void updateOrderStatus(@Param("userId") Long userId, @Param("status") Integer status);
}
```

文件：`code/seata-order-service/src/main/resources/mapper/OrderMapper.xml`

```xml
<mapper namespace="com.example.order.mapper.OrderMapper">

    <insert id="createOrder" parameterType="com.example.common.entity.Order"
            useGeneratedKeys="true" keyProperty="id">
        INSERT INTO t_order (user_id, product_id, count, money, status)
        VALUES (#{userId}, #{productId}, #{count}, #{money}, #{status})
    </insert>

    <update id="updateOrderStatus">
        UPDATE t_order SET status = #{status}
        WHERE user_id = #{userId} AND status = 0
    </update>
</mapper>
```

`createOrder` 插入订单记录（状态 0-创建中），`updateOrderStatus` 在事务最后将状态改为 1-已完成。Seata AT 模式会自动代理数据源，在执行这些 SQL 时记录 undo_log。

#### 8.3.7 Feign 远程调用（StorageFeignService / AccountFeignService）

文件：`code/seata-order-service/src/main/java/com/example/order/feign/`

```java
@FeignClient(value = "seata-storage-service")  // Nacos 中的服务名
public interface StorageFeignService {

    @PostMapping("/storage/decrease")
    CommonResult decreaseStorage(@RequestParam("productId") Long productId,
                                 @RequestParam("count") Integer count);
}

@FeignClient(value = "seata-account-service")
public interface AccountFeignService {

    @PostMapping("/account/decrease")
    CommonResult decreaseAccount(@RequestParam("userId") Long userId,
                                 @RequestParam("money") BigDecimal money);
}
```

Feign 调用时，Seata 的 `SeataFeignClient` 拦截器自动将当前线程的 XID 通过 HTTP Header（`TX_XID`）传递给下游服务。下游服务收到请求后，Seata 过滤器提取 XID 绑定到当前线程，使该服务作为 RM 自动加入全局事务。

### 8.4 库存服务（seata-storage-service）

库存服务作为 **RM（资源管理器）** 参与全局事务，业务代码无需任何 Seata 注解。

#### 8.4.1 pom.xml 依赖

文件：`code/seata-storage-service/pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.example</groupId>
        <artifactId>seata-demo</artifactId>
        <version>1.0.0</version>
    </parent>

    <artifactId>seata-storage-service</artifactId>
    <name>seata-storage-service</name>
    <description>库存服务 - RM角色, 扣减库存</description>

    <dependencies>
        <!-- 公共模块 (CommonResult, Order 实体) -->
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>seata-common</artifactId>
            <version>1.0.0</version>
        </dependency>

        <!-- 注意: 不需要显式声明 seata-spring-boot-starter
             父 pom 的 spring-cloud-starter-alibaba-seata 已包含
             org.apache.seata:seata-spring-boot-starter:2.5.0 -->
    </dependencies>
</project>
```

库存服务作为 RM 角色，不需要 OpenFeign（不被其他服务调用也不调用其他服务），只需公共模块依赖。Seata 依赖由父 POM 统一引入。

#### 8.4.2 application.yml 配置

文件：`code/seata-storage-service/src/main/resources/application.yml`

```yaml
server:
  port: 2002

spring:
  application:
    name: seata-storage-service
  # ========== Nacos 注册中心 ==========
  cloud:
    nacos:
      discovery:
        server-addr: 127.0.0.1:8848
        namespace: public
        group: SEATA_GROUP
  # ========== 数据源配置 (库存库) ==========
  datasource:
    type: com.alibaba.druid.pool.DruidDataSource
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql://127.0.0.1:3306/seata_storage?useUnicode=true&characterEncoding=utf-8&useSSL=false&serverTimezone=Asia/Shanghai
    username: root
    password: root

# ========== MyBatis 配置 ==========
mybatis:
  mapper-locations: classpath:mapper/*.xml
  type-aliases-package: com.example.common.entity
  configuration:
    map-underscore-to-camel-case: true

# ========== Seata 配置 (与订单服务保持一致) ==========
seata:
  enabled: true
  application-id: ${spring.application.name}
  tx-service-group: default_tx_group
  enable-auto-data-source-proxy: true
  data-source-proxy-mode: AT
  service:
    vgroup-mapping:
      default_tx_group: default
    grouplist:
      default: 127.0.0.1:8091
  registry:
    type: nacos
    nacos:
      application: seata-server
      server-addr: 127.0.0.1:8848
      group: SEATA_GROUP
      namespace: ''
      cluster: default

logging:
  level:
    io.seata: info
    com.example: debug
```

与订单服务的区别仅在于：端口 `2002`、服务名 `seata-storage-service`、数据源指向 `seata_storage` 库。Seata 配置部分完全相同——所有服务必须使用相同的事务组和集群名。

#### 8.4.3 启动类（StorageServiceApplication）

文件：`code/seata-storage-service/src/main/java/com/example/storage/StorageServiceApplication.java`

```java
package com.example.storage;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

/**
 * 库存服务启动类 (RM 角色)
 */
@SpringBootApplication
@EnableDiscoveryClient
public class StorageServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(StorageServiceApplication.class, args);
    }
}
```

**注解说明**：

| 注解 | 作用 |
|------|------|
| `@SpringBootApplication` | Spring Boot 核心注解，自动装配 + 组件扫描 |
| `@EnableDiscoveryClient` | 注册到 Nacos，供订单服务通过 Feign 发现并调用 |

> 库存服务作为 RM（资源管理器），**不需要** `@EnableFeignClients`（它不调用其他服务，只被调用）。AT 模式下 RM 由 Seata 自动代理数据源生效，启动类无需任何 Seata 注解。

#### 8.4.4 StorageController — 库存扣减接口

文件：`code/seata-storage-service/src/main/java/com/example/storage/controller/StorageController.java`

```java
@RestController
public class StorageController {

    @Resource
    private StorageService storageService;

    @PostMapping("/storage/decrease")
    public CommonResult decreaseStorage(@RequestParam("productId") Long productId,
                                        @RequestParam("count") Integer count) {
        storageService.decreaseStorage(productId, count);
        return CommonResult.success("扣减库存成功");
    }
}
```

#### 8.4.5 StorageService — RM 角色

文件：`code/seata-storage-service/src/main/java/com/example/storage/service/StorageService.java`

```java
@Slf4j
@Service
public class StorageService {

    @Resource
    private StorageMapper storageMapper;

    public void decreaseStorage(Long productId, Integer count) {
        log.info("------> 库存服务: 扣减库存, productId={}, count={}", productId, count);
        storageMapper.decreaseStorage(productId, count);
        // Seata 自动代理数据源, 在执行 SQL 前后记录 undo_log
    }
}
```

AT 模式的优势——RM 端业务代码完全无侵入。Seata 通过 `DataSourceProxy` 代理 JDBC，在执行 SQL 时自动：
1. 解析 SQL，确定操作的表和行
2. 查询前镜像（before image）
3. 执行业务 SQL
4. 查询后镜像（after image）
5. 将镜像信息写入 `undo_log` 表
6. 向 TC 注册分支事务并获取全局锁

#### 8.4.6 StorageMapper + StorageMapper.xml — 数据访问层

文件：`code/seata-storage-service/src/main/java/com/example/storage/mapper/StorageMapper.java`

```java
@Mapper
public interface StorageMapper {

    /** 扣减库存: used 增加, residue 减少 */
    void decreaseStorage(@Param("productId") Long productId, @Param("count") Integer count);
}
```

文件：`code/seata-storage-service/src/main/resources/mapper/StorageMapper.xml`

```xml
<mapper namespace="com.example.storage.mapper.StorageMapper">

    <update id="decreaseStorage">
        UPDATE t_storage
        SET used   = used + #{count},
            residue = residue - #{count}
        WHERE product_id = #{productId}
    </update>
</mapper>
```

### 8.5 账户服务（seata-account-service）

账户服务作为 **RM** 参与全局事务，同时用于演示超时回滚场景。

#### 8.5.1 pom.xml 依赖

文件：`code/seata-account-service/pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.example</groupId>
        <artifactId>seata-demo</artifactId>
        <version>1.0.0</version>
    </parent>

    <artifactId>seata-account-service</artifactId>
    <name>seata-account-service</name>
    <description>账户服务 - RM角色, 扣减余额, 包含超时回滚演示</description>

    <dependencies>
        <!-- 公共模块 (CommonResult, Order 实体) -->
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>seata-common</artifactId>
            <version>1.0.0</version>
        </dependency>

        <!-- 注意: 不需要显式声明 seata-spring-boot-starter
             父 pom 的 spring-cloud-starter-alibaba-seata 已包含
             org.apache.seata:seata-spring-boot-starter:2.5.0 -->
    </dependencies>
</project>
```

账户服务与库存服务的 POM 结构一致，作为 RM 角色只需公共模块依赖。

#### 8.5.2 application.yml 配置

文件：`code/seata-account-service/src/main/resources/application.yml`

```yaml
server:
  port: 2003

spring:
  application:
    name: seata-account-service
  # ========== Nacos 注册中心 ==========
  cloud:
    nacos:
      discovery:
        server-addr: 127.0.0.1:8848
        namespace: public
        group: SEATA_GROUP
  # ========== 数据源配置 (账户库) ==========
  datasource:
    type: com.alibaba.druid.pool.DruidDataSource
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql://127.0.0.1:3306/seata_account?useUnicode=true&characterEncoding=utf-8&useSSL=false&serverTimezone=Asia/Shanghai
    username: root
    password: root

# ========== MyBatis 配置 ==========
mybatis:
  mapper-locations: classpath:mapper/*.xml
  type-aliases-package: com.example.common.entity
  configuration:
    map-underscore-to-camel-case: true

# ========== Seata 配置 ==========
seata:
  enabled: true
  application-id: ${spring.application.name}
  tx-service-group: default_tx_group
  enable-auto-data-source-proxy: true
  data-source-proxy-mode: AT
  service:
    vgroup-mapping:
      default_tx_group: default
    grouplist:
      default: 127.0.0.1:8091
  registry:
    type: nacos
    nacos:
      application: seata-server
      server-addr: 127.0.0.1:8848
      group: SEATA_GROUP
      namespace: ''
      cluster: default

logging:
  level:
    io.seata: info
    com.example: debug
```

与订单服务的区别仅在于：端口 `2003`、服务名 `seata-account-service`、数据源指向 `seata_account` 库。超时回滚通过启动参数 `-Daccount.sleep=true` 控制（在 Service 中通过 `@Value("${account.sleep:false}")` 读取）。

#### 8.5.3 启动类（AccountServiceApplication）

文件：`code/seata-account-service/src/main/java/com/example/account/AccountServiceApplication.java`

```java
package com.example.account;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

/**
 * 账户服务启动类 (RM 角色)
 */
@SpringBootApplication
@EnableDiscoveryClient
public class AccountServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(AccountServiceApplication.class, args);
    }
}
```

**注解说明**：

| 注解 | 作用 |
|------|------|
| `@SpringBootApplication` | Spring Boot 核心注解，自动装配 + 组件扫描 |
| `@EnableDiscoveryClient` | 注册到 Nacos，供订单服务通过 Feign 发现并调用 |

> 账户服务与库存服务一样作为 RM 角色，启动类配置相同。超时回滚通过启动参数 `-Daccount.sleep=true` 控制，无需在启动类上做额外配置。

#### 8.5.4 AccountController — 账户扣减接口

文件：`code/seata-account-service/src/main/java/com/example/account/controller/AccountController.java`

```java
@RestController
public class AccountController {

    @Resource
    private AccountService accountService;

    @PostMapping("/account/decrease")
    public CommonResult decreaseAccount(@RequestParam("userId") Long userId,
                                        @RequestParam("money") BigDecimal money) {
        accountService.decreaseAccount(userId, money);
        return CommonResult.success("扣减余额成功");
    }
}
```

#### 8.5.5 AccountService — 超时回滚演示（RM）

文件：`code/seata-account-service/src/main/java/com/example/account/service/AccountService.java`

```java
@Slf4j
@Service
public class AccountService {

    @Resource
    private AccountMapper accountMapper;

    @Value("${account.sleep:false}")
    private boolean needSleep;

    public void decreaseAccount(Long userId, BigDecimal money) {
        log.info("------> 账户服务: 扣减余额, userId={}, money={}", userId, money);

        // 模拟超时, 触发全局事务回滚
        if (needSleep) {
            log.info("------> 账户服务: 模拟超时, sleep 20s ...");
            Thread.sleep(20000);
        }

        accountMapper.decreaseAccount(userId, money);
    }
}
```

**超时回滚流程**：
1. 订单服务调用账户服务，账户服务 sleep 20s
2. Feign 超时（read-timeout 5s），订单服务收到 `ReadTimeoutException`
3. `@GlobalTransactional` 捕获异常，向 TC 发起全局回滚
4. TC 通知库存服务 RM 根据 undo_log 回滚库存
5. TC 通知订单服务 RM 根据 undo_log 回滚订单
6. 所有数据恢复到下单前的状态

#### 8.5.6 AccountMapper + AccountMapper.xml — 数据访问层

文件：`code/seata-account-service/src/main/java/com/example/account/mapper/AccountMapper.java`

```java
@Mapper
public interface AccountMapper {

    /** 扣减账户余额: used 增加, residue 减少 */
    void decreaseAccount(@Param("userId") Long userId, @Param("money") BigDecimal money);
}
```

文件：`code/seata-account-service/src/main/resources/mapper/AccountMapper.xml`

```xml
<mapper namespace="com.example.account.mapper.AccountMapper">

    <update id="decreaseAccount">
        UPDATE t_account
        SET used   = used + #{money},
            residue = residue - #{money}
        WHERE user_id = #{userId}
    </update>
</mapper>
```

### 8.6 AT 模式工作原理总结

整个案例的 AT 模式工作流程：

| 步骤 | 角色 | 动作 |
|------|------|------|
| 1 | TM（OrderService） | `@GlobalTransactional` 开启全局事务，向 TC 注册获取 XID |
| 2 | TM | 创建订单，Seata 代理数据源记录 undo_log，向 TC 注册分支事务 |
| 3 | TM → RM | Feign 调用库存服务，XID 通过 HTTP Header 传播 |
| 4 | RM（StorageService） | 扣减库存，Seata 代理数据源记录 undo_log，向 TC 注册分支事务 |
| 5 | TM → RM | Feign 调用账户服务，XID 传播 |
| 6 | RM（AccountService） | 扣减余额，Seata 代理数据源记录 undo_log，向 TC 注册分支事务 |
| 7 | TM | 更新订单状态，向 TC 提交全局事务 |
| 8 | TC | 通知所有 RM 提交分支事务，删除 undo_log |

**异常回滚流程**：任一步骤失败 → TM 捕获异常 → 向 TC 发起回滚 → TC 通知所有已注册的 RM → RM 根据 undo_log 的前镜像反向补偿数据 → 删除 undo_log。

---

## 九、启动与测试验证

### 9.1 启动顺序

```
1. MySQL 启动, 执行全部 SQL
2. Nacos 启动 (sh startup.sh -m standalone)
3. Seata Server 启动 (sh seata-server.sh)
   → 验证: Nacos 服务列表出现 seata-server
4. 启动 seata-storage-service (端口 2002)
5. 启动 seata-account-service (端口 2003)
6. 启动 seata-order-service (端口 2001)
   → 验证: Nacos 服务列表出现 3 个业务服务
```

### 9.2 测试正常流程

```bash
# 下单: 用户1, 产品1, 数量10, 金额100
curl -X POST "http://localhost:2001/order/create?userId=1&productId=1&count=10&money=100"
```

**预期结果**：
```json
{"code":200,"message":"订单创建成功","data":null}
```

**验证数据**：
```sql
-- 订单已创建且状态为1(已完成)
SELECT * FROM seata_order.t_order;
-- 库存: used=10, residue=90
SELECT * FROM seata_storage.t_storage WHERE product_id=1;
-- 余额: used=100, residue=900
SELECT * FROM seata_account.t_account WHERE user_id=1;
-- undo_log 已被清理 (全局事务提交后异步删除)
SELECT * FROM seata_order.undo_log;
SELECT * FROM seata_storage.undo_log;
SELECT * FROM seata_account.undo_log;
```

### 9.3 测试超时回滚

```bash
# 以超时模式启动账户服务
java -Daccount.sleep=true -jar seata-account-service.jar

# 或者: 修改 application.yml 添加 account.sleep: true

# 再次下单
curl -X POST "http://localhost:2001/order/create?userId=1&productId=1&count=10&money=100"
```

**预期结果**：
- 接口返回 500 错误（Feign 超时）
- 订单服务日志出现全局事务回滚信息

**验证数据（全部回滚到初始状态）**：
```sql
-- 订单表: 无新订单 (已回滚)
SELECT * FROM seata_order.t_order;
-- 库存: used=10, residue=90 (上一轮的正常数据, 本次回滚未影响)
SELECT * FROM seata_storage.t_storage WHERE product_id=1;
-- 余额: used=100, residue=900 (同上)
SELECT * FROM seata_account.t_account WHERE user_id=1;
```

### 9.4 Seata 控制台验证

访问 `http://localhost:7091`（账号 seata/seata）：
- **全局事务**：可看到创建和回滚的事务记录
- **分支事务**：可看到每个全局事务下的分支事务
- **全局锁**：可看到 AT 模式的行锁信息

---

## 十、常见问题

### Q1: can not connect to services-server

**原因**：客户端无法连接 Seata Server

**排查**：
1. 检查 Seata Server 是否已启动并注册到 Nacos
2. 检查 Nacos 服务列表是否有 `seata-server`
3. 检查 `seata.registry.nacos.cluster` 是否与 Server 一致（都为 `default`）
4. 检查 `seata.registry.nacos.group` 是否与 Server 一致（都为 `SEATA_GROUP`）

### Q2: could not find any cluster name in the registry

**原因**：事务组映射配置错误

**排查**：
1. 检查客户端 `seata.service.vgroup-mapping.default_tx_group` 是否为 `default`
2. 检查客户端 `seata.tx-service-group` 是否为 `default_tx_group`
3. 检查客户端 `seata.registry.nacos.cluster` 是否与 Seata Server 一致（都为 `default`）

### Q3: undo_log 表不存在

**原因**：业务库未创建 undo_log 表

**解决**：每个参与分布式事务的数据库都必须创建 undo_log 表，执行 `sql/undo_log.sql`。

### Q4: 数据源代理未生效

**原因**：Seata 未代理数据源，AT 模式无法工作

**排查**：
1. 确认 `seata.enable-auto-data-source-proxy: true`
2. 确认 `seata.data-source-proxy-mode: AT`
3. 如果使用自定义 DataSource Bean，需要手动创建 `DataSourceProxy`

### Q5: Feign 调用超时

**原因**：OpenFeign 默认 read-timeout 60s，超时回滚测试中 account.sleep=20s 不会触发默认超时

**解决**：本教程已在订单服务 application.yml 中配置 read-timeout=5s，确保 `account.sleep=true` 时 20s > 5s 触发超时。如需调整：

```yaml
feign:
  client:
    config:
      default:
        connect-timeout: 5000   # 连接超时 5s
        read-timeout: 30000     # 读取超时 30s (调大可避免误超时)
```

### Q6: 版本不兼容问题

**原因**：Spring Boot / Spring Cloud / Spring Cloud Alibaba 版本不匹配

**解决**：参考本教程第三章的版本兼容组合。本教程采用 Spring Boot 3.5.0 + Spring Cloud 2025.0.0 + Spring Cloud Alibaba 2025.0.0.0 + Seata 2.5.0 + JDK 17，该组合经过官方兼容验证。

---

## 附录：文件清单

| 文件路径 | 说明 |
|----------|------|
| `seata-tutorial.md` | 本教程文档 |
| `sql/seata-server.sql` | Seata Server 建表 SQL (4张表) |
| `sql/business-db.sql` | 业务库建表 SQL + 初始数据 + undo_log |
| `sql/undo_log.sql` | undo_log 独立建表 SQL |
| `seata-server-config/application.yml` | Seata Server 主配置 (2.0+推荐) |
| `code/pom.xml` | 父工程 POM |
| `code/seata-common/` | 公共模块 (实体类) |
| `code/seata-order-service/` | 订单服务 (TM) |
| `code/seata-storage-service/` | 库存服务 (RM) |
| `code/seata-account-service/` | 账户服务 (RM) |
