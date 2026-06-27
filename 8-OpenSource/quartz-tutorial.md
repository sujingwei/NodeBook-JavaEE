# Quartz 调度框架完整教程

> 整合 Spring Boot · 含全部代码与分步说明 · 从零到生产

---

## 目录

- [第一步之前：理解 Quartz 的运行原理](#第一步之前理解-quartz-的运行原理)
- [核心概念速查](#核心概念速查)
- [第 1 步：创建项目 & 引入依赖](#第-1-步创建项目--引入依赖)
- [第 2 步：配置 application.yml](#第-2-步配置-applicationyml)
- [第 3 步：解决 Job 依赖注入（最关键的坑）](#第-3-步解决-job-依赖注入最关键的坑)
- [第 4 步：编写 Job 类（业务逻辑）](#第-4-步编写-job-类业务逻辑)
- [第 5 步：编写调度服务层](#第-5-步编写调度服务层)
- [第 6 步：编写 REST 接口](#第-6-步编写-rest-接口)
- [第 7 步：编写监听器（可选但推荐）](#第-7-步编写监听器可选但推荐)
- [第 8 步：启动时自动注册任务](#第-8-步启动时自动注册任务)
- [第 9 步：运行与测试](#第-9-步运行与测试)
  - [9.1 内存模式](#91-内存模式无需数据库开箱即用)
  - [9.2 JDBC 持久化模式](#92-jdbc-持久化模式生产推荐)
- [Cron 表达式速查](#cron-表达式速查)
- [最佳实践与避坑](#最佳实践与避坑)

---

## 第一步之前：理解 Quartz 的运行原理

在动手之前，先搞清楚 Quartz **到底在做什么**。一句话概括：Quartz 是一个「到点了就帮你跑一段代码」的调度引擎。但它和 Spring 的 `@Scheduled` 有本质区别——它把「做什么」和「何时做」拆成了两个独立对象，交给一个中央调度器统一管理，还能把任务存进数据库、支持集群。

### 为什么需要 Quartz？

假设你有这样的需求：

- 每天凌晨 2 点清理过期数据，且**重启不能丢任务**
- 用户在前端点「开启提醒」，**运行时动态**创建定时任务
- 3 台服务器部署同一应用，但定时任务**只能跑一次**，不能重复

这三个场景 `@Scheduled` 全部搞不定——它不支持持久化、不支持动态管理、集群下每个节点都会执行。Quartz 正是为这些场景而生。

### Quartz 的核心运转流程

```
① 你编写 Job 类（业务逻辑）
     ↓
② 用 JobBuilder 把 Job 类包装成 JobDetail（绑定名字、参数）
     ↓
③ 用 TriggerBuilder 创建 Trigger（指定调度规则：间隔 / Cron）
     ↓
④ scheduler.scheduleJob(jobDetail, trigger)  注册到调度器
     ↓
⑤ 调度器把 JobDetail + Trigger 存入 JobStore（内存 or 数据库）
     ↓
⑥ 调度器后台线程扫描 Trigger，到点了从 ThreadPool 取一个线程
     ↓
⑦ 通过反射 newInstance() 创建 Job 实例 → 调用 execute()
     ↓
⑧ 执行完毕，Job 实例被丢弃（每次都是新实例）
```

### 关键设计决策及其原因

#### ① 为什么 Job 和 JobDetail 要分开？

同一个 Job 类（比如 `SimpleJob`）你可能想用不同参数跑多次——「每 5 秒发邮件给 A」和「每 10 秒发邮件给 B」。如果 Job 类本身代表调度单元，就做不到。**JobDetail 是调度单元**（有唯一 name+group），Job 类只是它的实现逻辑。一个 Job 类 → 多个 JobDetail，各自独立调度。

#### ② 为什么每次执行都 new 新实例？

Quartz 通过反射 `newInstance()` 创建 Job，执行完就丢弃。这是为了**线程安全**——多个线程可能同时执行同一个 JobDetail 的不同实例，如果共享可变状态就会出错。这也意味着**不要在 Job 里放成员变量来存状态**，状态应该放 JobDataMap。

#### ③ 为什么默认 Job 不能 @Autowired？

因为 Quartz 用 `newInstance()` 创建 Job，**不走 Spring 容器**。解决方案是自定义 `JobFactory`，在 Job 创建后手动调用 Spring 的 `autowireBean()` 完成注入——这是本教程第 3 步的核心。

#### ④ 内存模式 vs JDBC 模式

| | RAMJobStore（内存） | JDBCJobStore（数据库） |
|---|---|---|
| 速度 | 快 | 稍慢（有 DB IO） |
| 重启后 | 任务全部丢失 | 任务保留，继续调度 |
| 集群 | 不支持 | 支持 |
| 适用 | 开发调试、非关键任务 | 生产环境 |

---

## 核心概念速查

| 概念 | 一句话解释 | 类比 |
|---|---|---|
| `Scheduler` | 调度器，整个框架的入口 | 工厂的车间主任 |
| `Job` | 任务接口，业务逻辑写这里 | 工人的技能（会做什么） |
| `JobDetail` | 任务定义（Job 的元数据+参数） | 一张工单（做什么+什么参数） |
| `Trigger` | 触发器（调度规则） | 闹钟（什么时候执行） |
| `JobStore` | 任务存储 | 工单柜（内存版/数据库版） |
| `ThreadPool` | 线程池 | 工人池 |

> **技术选型**：本教程基于 **Spring Boot 2.7.18**（兼容 Java 8+）+ **Quartz 2.3.2**（由 spring-boot-starter-quartz 自动引入）。Lombok 用于简化日志，Hutool 为可选工具库。

---

## 第 1 步：创建项目 & 引入依赖

### 创建 Maven 项目，配置 pom.xml

用 IDE（IDEA / Eclipse / VS Code）创建一个 Maven 项目，groupId 填 `com.example`，artifactId 填 `quartz-demo`。然后替换 `pom.xml` 为以下完整内容。

**每个依赖的作用**（面试常问，也决定了你后面能不能少踩坑）：

- `spring-boot-starter-web` — 提供 REST 接口，让我们能通过 HTTP 动态管理任务
- `spring-boot-starter-quartz` — **核心**，自动配置 SchedulerFactoryBean 和 Scheduler，并引入 Quartz 2.3.2
- `spring-boot-starter-data-jpa` + `mysql-connector-java` — JDBC 持久化模式需要数据源
- `lombok` — 简化 `@Slf4j` 日志等样板代码
- `hutool-all` — 可选工具库，本案例中方便后续扩展

**`pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <!-- 2.7.x 是最后一个兼容 Java 8 的 LTS 版本，Quartz 2.3.2 已被自动引入 -->
        <version>2.7.18</version>
        <relativePath/>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>quartz-demo</artifactId>
    <version>1.0.0</version>
    <name>quartz-demo</name>
    <description>Spring Boot + Quartz 整合教程案例</description>

    <properties>
        <java.version>1.8</java.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Web：提供 REST 接口动态管理任务 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- 核心：Spring Boot 整合 Quartz，自动配置 SchedulerFactoryBean -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-quartz</artifactId>
        </dependency>

        <!-- Spring Data JPA：用于 JDBC JobStore 持久化演示 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

        <!-- MySQL 驱动 -->
        <dependency>
            <groupId>mysql</groupId>
            <artifactId>mysql-connector-java</artifactId>
            <scope>runtime</scope>
        </dependency>

        <!-- Lombok：简化样板代码 -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <!-- 工具类 -->
        <dependency>
            <groupId>cn.hutool</groupId>
            <artifactId>hutool-all</artifactId>
            <version>5.8.25</version>
        </dependency>

        <!-- 测试 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

同时创建启动类：

**`src/main/java/com/example/quartz/QuartzDemoApplication.java`**

```java
package com.example.quartz;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Spring Boot + Quartz 整合案例启动类
 */
@SpringBootApplication
public class QuartzDemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(QuartzDemoApplication.class, args);
    }
}
```

---

## 第 2 步：配置 application.yml

### 配置 Quartz 参数（内存模式）

spring-boot-starter-quartz 提供了 `QuartzAutoConfiguration`，会自动创建 `SchedulerFactoryBean` 和 `Scheduler` 并注入 Spring 容器。你**不需要写任何 Java 配置类就能跑起来**——只需在 yml 里配参数。

**每个配置项的含义**：

- `job-store-type: memory` — 用内存存储任务（开发阶段首选，无需数据库）
- `wait-for-jobs-to-complete-on-shutdown: true` — 关闭时等任务跑完，避免中断
- `instanceId: AUTO` — 自动生成唯一实例 ID，集群模式**必需**
- `threadCount: 10` — 线程池大小，决定能同时执行多少个任务
- `misfireThreshold: 60000` — 触发器超过 60 秒没触发就算 misfire（错过）

**`src/main/resources/application.yml`**

```yaml
server:
  port: 8080

spring:
  # 默认使用内存模式；切换持久化改为 jdbc
  profiles:
    active: ram

  # ===== Quartz 全局配置（内存模式）=====
  quartz:
    # memory=内存(RAMJobStore)，jdbc=数据库(JDBCJobStore)
    job-store-type: memory
    # 启动延迟
    startup-delay: 0s
    # 启动时是否等待任务执行完再关闭
    wait-for-jobs-to-complete-on-shutdown: true
    properties:
      org.quartz.scheduler.instanceName: QuartzScheduler
      # AUTO 自动生成唯一实例 ID，集群环境必需
      org.quartz.scheduler.instanceId: AUTO
      org.quartz.threadPool.class: org.quartz.simpl.SimpleThreadPool
      org.quartz.threadPool.threadCount: 10
      org.quartz.threadPool.threadPriority: 5
      # 触发器超过该时间(毫秒)未触发视为 misfire
      org.quartz.jobStore.misfireThreshold: 60000

logging:
  level:
    org.quartz: INFO
    com.example.quartz: DEBUG
```

> 💡 **到这里其实已经能跑了**：此时启动项目，Scheduler 已经在后台运行。但还无法管理任务——因为我们还没写 Job 和接口。接下来的步骤就是在往这个骨架里填业务。

---

## 第 3 步：解决 Job 依赖注入（最关键的坑）

### 自定义 JobFactory，让 Job 支持 @Autowired

> ⚠️ **这是 Quartz 整合 Spring 最大的坑**
>
> Quartz 通过反射 `newInstance()` 创建 Job 实例，**不走 Spring 容器**。所以直接在 Job 里 `@Autowired` 会得到 `null`，运行时抛 NPE。如果你跳过这步，后面所有 Job 内的注入都会失败。

**解决方案**：自定义一个 `JobFactory`，继承 Spring 提供的 `SpringBeanJobFactory`，在 Job 实例化后调用 `autowireBean()` 把它交给 Spring 处理依赖注入。

**`src/main/java/com/example/quartz/config/AutowiringSpringBeanJobFactory.java`**

```java
package com.example.quartz.config;

import org.quartz.spi.TriggerFiredBundle;
import org.springframework.beans.factory.config.AutowireCapableBeanFactory;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;
import org.springframework.scheduling.quartz.SpringBeanJobFactory;
import org.springframework.stereotype.Component;

/**
 * 让 Quartz 创建的 Job 实例能注入 Spring Bean。
 *
 * 背景：Quartz 通过反射 newInstance() 创建 Job，默认不走 Spring 容器，
 * 所以 Job 内部的 @Autowired 会失效。本类在 Job 实例化后，
 * 调用 AutowireCapableBeanFactory#autowireBean(Object) 把它交给 Spring 处理依赖注入。
 */
@Component
public class AutowiringSpringBeanJobFactory extends SpringBeanJobFactory
        implements ApplicationContextAware {

    private transient AutowireCapableBeanFactory beanFactory;

    @Override
    public void setApplicationContext(ApplicationContext applicationContext) {
        this.beanFactory = applicationContext.getAutowireCapableBeanFactory();
    }

    @Override
    protected Object createJobInstance(TriggerFiredBundle bundle) throws Exception {
        // 1. 先按 Quartz 默认方式创建 Job 实例
        Object job = super.createJobInstance(bundle);
        // 2. 再让 Spring 对其进行依赖注入（@Autowired、@Value 都会生效）
        beanFactory.autowireBean(job);
        return job;
    }
}
```

然后通过 `SchedulerFactoryBeanCustomizer` 把这个 JobFactory 设到 SchedulerFactoryBean 上：

**`src/main/java/com/example/quartz/config/QuartzConfig.java`**

```java
package com.example.quartz.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.quartz.SchedulerFactoryBeanCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Quartz 核心配置。
 *
 * spring-boot-starter-quartz 会自动创建 SchedulerFactoryBean 和 Scheduler，
 * 我们只需要通过 SchedulerFactoryBeanCustomizer 注入自定义 JobFactory，
 * 让 Job 实例支持 Spring 依赖注入即可。
 *
 * 其余 Quartz 参数（线程池、JobStore 等）全部在 application.yml 中通过
 * spring.quartz.properties 统一配置，无需在此硬编码。
 */
@Configuration
public class QuartzConfig {

    @Autowired
    private AutowiringSpringBeanJobFactory jobFactory;

    /**
     * 关键：把自定义 JobFactory 设置到 SchedulerFactoryBean 上，
     * 这样 Quartz 创建 Job 时会走 Spring 的依赖注入。
     */
    @Bean
    public SchedulerFactoryBeanCustomizer schedulerFactoryBeanCustomizer() {
        return schedulerFactoryBean -> schedulerFactoryBean.setJobFactory(jobFactory);
    }
}
```

> 💡 **完成这一步后**：Job 内部的 `@Autowired`、`@Value` 等都能正常工作了。这是整个整合中最关键的一步，也是最容易遗漏的一步。

---

## 第 4 步：编写 Job 类（业务逻辑）

### 创建 3 个 Job：SimpleJob、CronJob、DataMapJob

Job 是你写业务逻辑的地方，只需实现 `Job` 接口的 `execute()` 方法。我们写 3 个 Job 覆盖三种典型场景。

#### 4.1 SimpleJob — 最基础的任务（验证依赖注入）

这个 Job 注入了 `EmailService`，用来验证第 3 步的依赖注入方案是否生效。如果没有第 3 步，这里的 `@Autowired` 会是 null。

**`src/main/java/com/example/quartz/jobs/SimpleJob.java`**

```java
package com.example.quartz.jobs;

import com.example.quartz.service.EmailService;
import lombok.extern.slf4j.Slf4j;
import org.quartz.Job;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * 最基础的 Job：实现 Job 接口，在 execute() 中编写业务逻辑。
 *
 * 关键点：
 * - Job 实例由 Quartz 通过反射 newInstance() 创建，配合 AutowiringSpringBeanJobFactory 后可注入 Spring Bean
 * - 每次触发都会新建一个 Job 实例，所以不要在 Job 里放可变成员状态
 * - execute 抛出异常会被 JobListener 捕获，但不会中断整个调度器
 */
@Slf4j
public class SimpleJob implements Job {

    // 验证依赖注入是否生效（普通 Job 默认无法 @Autowired，需配合 AutowiringSpringBeanJobFactory）
    @Autowired
    private EmailService emailService;

    @Override
    public void execute(JobExecutionContext context) throws JobExecutionException {
        String time = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        log.info("[SimpleJob] 任务执行，触发时间={}，线程={}", time, Thread.currentThread().getName());
        emailService.send("admin@example.com", "SimpleJob 触发于 " + time);
    }
}
```

#### 4.2 CronJob — Cron 表达式驱动的任务

这个 Job 从 `JobDataMap` 读取参数，演示任务传参。`getMergedJobDataMap()` 会合并 JobDetail 和 Trigger 两个层级的参数（Trigger 覆盖同名 key）。

**`src/main/java/com/example/quartz/jobs/CronJob.java`**

```java
package com.example.quartz.jobs;

import lombok.extern.slf4j.Slf4j;
import org.quartz.Job;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Cron 表达式驱动的 Job。
 * 由 CronTrigger 按表达式调度，例如 "0/5 * * * * ?" 表示每 5 秒一次。
 */
@Slf4j
public class CronJob implements Job {

    @Override
    public void execute(JobExecutionContext context) throws JobExecutionException {
        String time = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS"));
        // getMergedJobDataMap 合并了 JobDetail 和 Trigger 的 JobDataMap（Trigger 覆盖同名 key）
        String cronDesc = context.getMergedJobDataMap().getString("cronDesc");
        log.info("[CronJob] 定时任务执行，cron描述={}，当前时间={}", cronDesc, time);
    }
}
```

#### 4.3 DataMapJob — 有状态任务（JobDataMap 计数 + 并发控制）

这个 Job 演示两个高级注解：

- `@PersistJobDataAfterExecution` — 执行后把修改过的 JobDataMap 持久化，下次能读到新值
- `@DisallowConcurrentExecution` — 禁止同一 JobDetail 并发执行，避免状态写冲突

注册时 `count` 从 0 开始，每次执行 +1，下次能读到更新后的值。这就是「有状态 Job」。

**`src/main/java/com/example/quartz/jobs/DataMapJob.java`**

```java
package com.example.quartz.jobs;

import lombok.extern.slf4j.Slf4j;
import org.quartz.*;

/**
 * 演示 JobDataMap 传参 + 有状态计数。
 *
 * 关键注解：
 * - @PersistJobDataAfterExecution：执行后把修改过的 JobDataMap 持久化回 JobDetail，
 *   下次执行能读到更新值（仅 JDBC JobStore 才真正跨重启持久化；内存模式下进程内有效）
 * - @DisallowConcurrentExecution：禁止同一 JobDetail 并发执行，
 *   配合状态修改避免并发写冲突
 *
 * 注意：这两个注解是基于 JobDetail 维度的，不是 Job 类维度。
 */
@Slf4j
@PersistJobDataAfterExecution
@DisallowConcurrentExecution
public class DataMapJob implements Job {

    @Override
    public void execute(JobExecutionContext context) throws JobExecutionException {
        // 读取 JobDetail 级别的 JobDataMap
        JobDataMap dataMap = context.getJobDetail().getJobDataMap();

        String jobDesc = dataMap.getString("jobDesc");
        int count = dataMap.getInt("count");

        log.info("[DataMapJob] 描述={}，当前累计执行次数={}", jobDesc, count);

        // 累加并写回，配合 @PersistJobDataAfterExecution 在下次执行时生效
        dataMap.put("count", count + 1);
    }
}
```

#### 4.4 被 Job 注入的业务 Service

简单写一个 Service 供 Job 注入，验证依赖注入确实生效：

**`src/main/java/com/example/quartz/service/EmailService.java`**

```java
package com.example.quartz.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 示例业务服务：被 Job 注入，用于验证 Quartz Job 中的 Spring 依赖注入是否生效。
 */
@Slf4j
@Service
public class EmailService {

    public void send(String to, String content) {
        log.info("[EmailService] 发送邮件 -> to={}, content={}", to, content);
    }
}
```

---

## 第 5 步：编写调度服务层

### 封装 Scheduler 操作：注册、暂停、删除、查询

`Scheduler` 由 Spring 自动注入（第 2 步配置的产物）。这里封装常用操作，供 Controller 调用。涵盖三种任务注册方式 + 增删改查。

**核心 API 说明**：

- `JobBuilder.newJob(XXX.class)` — 构建 JobDetail，`withIdentity(name, group)` 设唯一标识
- `TriggerBuilder.newTrigger()` — 构建 Trigger
- `SimpleScheduleBuilder.simpleSchedule().withIntervalInSeconds(n).repeatForever()` — 固定间隔无限重复
- `CronScheduleBuilder.cronSchedule(expr)` — Cron 表达式调度
- `scheduler.scheduleJob(jobDetail, trigger)` — 注册任务
- `scheduler.pauseJob / resumeJob / deleteJob / triggerJob` — 管理操作

**`src/main/java/com/example/quartz/service/SchedulerService.java`**

```java
package com.example.quartz.service;

import com.example.quartz.jobs.CronJob;
import com.example.quartz.jobs.DataMapJob;
import com.example.quartz.jobs.SimpleJob;
import lombok.extern.slf4j.Slf4j;
import org.quartz.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

/**
 * 任务调度核心服务：封装 Scheduler 的常用操作。
 *
 * 覆盖三种典型场景：
 * - SimpleTrigger：固定间隔重复
 * - CronTrigger：Cron 表达式
 * - JobDataMap：任务传参 + 有状态计数
 * 以及暂停 / 恢复 / 删除 / 立即触发 / 列表查询。
 */
@Slf4j
@Service
public class SchedulerService {

    @Autowired
    private Scheduler scheduler;

    /** 注册 SimpleTrigger 任务：固定间隔重复 repeatCount 次（-1 表示无限） */
    public void addSimpleJob(String jobName, String group, int intervalSeconds, int repeatCount) throws SchedulerException {
        JobDetail jobDetail = JobBuilder.newJob(SimpleJob.class)
                .withIdentity(jobName, group)
                .withDescription("SimpleTrigger 示例任务")
                .storeDurably()
                .build();

        SimpleTrigger trigger = TriggerBuilder.newTrigger()
                .withIdentity(jobName + "_trigger", group)
                .startNow()
                .withSchedule(SimpleScheduleBuilder.simpleSchedule()
                        .withIntervalInSeconds(intervalSeconds)
                        .withRepeatCount(repeatCount))
                .build();

        scheduler.scheduleJob(jobDetail, trigger);
        log.info("[SchedulerService] 注册 SimpleJob: {}, 间隔={}s, 重复次数={}", jobName, intervalSeconds, repeatCount);
    }

    /** 注册 CronTrigger 任务 */
    public void addCronJob(String jobName, String group, String cron, String desc) throws SchedulerException {
        JobDetail jobDetail = JobBuilder.newJob(CronJob.class)
                .withIdentity(jobName, group)
                .withDescription("CronTrigger 示例任务")
                .usingJobData("cronDesc", desc)
                .storeDurably()
                .build();

        CronTrigger trigger = TriggerBuilder.newTrigger()
                .withIdentity(jobName + "_trigger", group)
                .withSchedule(CronScheduleBuilder.cronSchedule(cron)
                        // misfire 策略：错过的不再补执行
                        .withMisfireHandlingInstructionDoNothing())
                .build();

        scheduler.scheduleJob(jobDetail, trigger);
        log.info("[SchedulerService] 注册 CronJob: {}, cron={}", jobName, cron);
    }

    /** 注册带参数的有状态任务（演示 JobDataMap） */
    public void addDataMapJob(String jobName, String group, String desc, int intervalSeconds) throws SchedulerException {
        JobDetail jobDetail = JobBuilder.newJob(DataMapJob.class)
                .withIdentity(jobName, group)
                .withDescription("JobDataMap 有状态任务")
                .usingJobData("jobDesc", desc)
                .usingJobData("count", 0)
                .build();

        SimpleTrigger trigger = TriggerBuilder.newTrigger()
                .withIdentity(jobName + "_trigger", group)
                .startNow()
                .withSchedule(SimpleScheduleBuilder.simpleSchedule()
                        .withIntervalInSeconds(intervalSeconds)
                        .repeatForever())
                .build();

        scheduler.scheduleJob(jobDetail, trigger);
        log.info("[SchedulerService] 注册 DataMapJob: {}", jobName);
    }

    /** 暂停任务 */
    public void pauseJob(String jobName, String group) throws SchedulerException {
        scheduler.pauseJob(JobKey.jobKey(jobName, group));
    }

    /** 恢复任务 */
    public void resumeJob(String jobName, String group) throws SchedulerException {
        scheduler.resumeJob(JobKey.jobKey(jobName, group));
    }

    /** 删除任务（同时删除关联触发器） */
    public boolean deleteJob(String jobName, String group) throws SchedulerException {
        return scheduler.deleteJob(JobKey.jobKey(jobName, group));
    }

    /** 立即触发一次（不影响原有调度计划） */
    public void triggerJobOnce(String jobName, String group) throws SchedulerException {
        scheduler.triggerJob(JobKey.jobKey(jobName, group));
    }

    /** 查询所有任务列表 */
    public List<String> listJobs() throws SchedulerException {
        List<String> result = new ArrayList<>();
        for (String group : scheduler.getJobGroupNames()) {
            for (JobKey jobKey : scheduler.getJobKeys(GroupMatcher.jobGroupEquals(group))) {
                JobDetail detail = scheduler.getJobDetail(jobKey);
                List<? extends Trigger> triggers = scheduler.getTriggersOfJob(jobKey);
                String nextFire = triggers.isEmpty() ? "无" : String.valueOf(triggers.get(0).getNextFireTime());
                result.add(String.format("Job=%s | Group=%s | Class=%s | 下次触发=%s",
                        jobKey.getName(), jobKey.getGroup(),
                        detail.getJobClass().getSimpleName(), nextFire));
            }
        }
        return result;
    }
}
```

---

## 第 6 步：编写 REST 接口

### Controller：通过 HTTP 动态管理任务

有了 Service 层，再写一组 REST 接口暴露给前端/运维调用。为了便于前端对接、参数扩展和 Swagger 文档生成，**POST / PUT / DELETE 统一使用 JSON 请求体**，而不是 URL 查询参数。

#### 6.1 定义请求 DTO

先创建 4 个简单的请求参数类。DTO（Data Transfer Object）让接口参数清晰、可校验，也避免 Controller 里堆满 `@RequestParam`。

**`src/main/java/com/example/quartz/dto/SimpleJobRequest.java`**

```java
package com.example.quartz.dto;

import lombok.Data;

@Data
public class SimpleJobRequest {
    private String jobName;
    private String group = "DEFAULT";
    private Integer intervalSeconds;
    private Integer repeatCount = -1;
}
```

**`src/main/java/com/example/quartz/dto/CronJobRequest.java`**

```java
package com.example.quartz.dto;

import lombok.Data;

@Data
public class CronJobRequest {
    private String jobName;
    private String group = "DEFAULT";
    private String cron;
    private String desc = "";
}
```

**`src/main/java/com/example/quartz/dto/DataMapJobRequest.java`**

```java
package com.example.quartz.dto;

import lombok.Data;

@Data
public class DataMapJobRequest {
    private String jobName;
    private String group = "DEFAULT";
    private String desc;
    private Integer intervalSeconds;
}
```

**`src/main/java/com/example/quartz/dto/JobKeyRequest.java`**

```java
package com.example.quartz.dto;

import lombok.Data;

@Data
public class JobKeyRequest {
    private String jobName;
    private String group = "DEFAULT";
}
```

#### 6.2 编写 Controller

用 `@RequestBody` 接收 JSON，Spring 会自动把 JSON 映射到 DTO。GET 查询接口保持无参。

**`src/main/java/com/example/quartz/controller/JobController.java`**

```java
package com.example.quartz.controller;

import com.example.quartz.dto.*;
import com.example.quartz.service.SchedulerService;
import lombok.RequiredArgsConstructor;
import org.quartz.SchedulerException;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 任务管理 REST 接口。
 * POST / PUT / DELETE 统一使用 JSON 请求体入参。
 */
@RestController
@RequestMapping("/jobs")
@RequiredArgsConstructor
public class JobController {

    private final SchedulerService schedulerService;

    /** 注册 SimpleTrigger 任务 */
    @PostMapping("/simple")
    public Map<String, Object> addSimple(@RequestBody SimpleJobRequest req) throws SchedulerException {
        schedulerService.addSimpleJob(req.getJobName(), req.getGroup(), req.getIntervalSeconds(), req.getRepeatCount());
        return ok("SimpleJob 注册成功: " + req.getJobName());
    }

    /** 注册 CronTrigger 任务 */
    @PostMapping("/cron")
    public Map<String, Object> addCron(@RequestBody CronJobRequest req) throws SchedulerException {
        schedulerService.addCronJob(req.getJobName(), req.getGroup(), req.getCron(), req.getDesc());
        return ok("CronJob 注册成功: " + req.getJobName());
    }

    /** 注册带参数的有状态任务 */
    @PostMapping("/datamap")
    public Map<String, Object> addDataMap(@RequestBody DataMapJobRequest req) throws SchedulerException {
        schedulerService.addDataMapJob(req.getJobName(), req.getGroup(), req.getDesc(), req.getIntervalSeconds());
        return ok("DataMapJob 注册成功: " + req.getJobName());
    }

    /** 暂停任务 */
    @PutMapping("/pause")
    public Map<String, Object> pause(@RequestBody JobKeyRequest req) throws SchedulerException {
        schedulerService.pauseJob(req.getJobName(), req.getGroup());
        return ok("已暂停: " + req.getJobName());
    }

    /** 恢复任务 */
    @PutMapping("/resume")
    public Map<String, Object> resume(@RequestBody JobKeyRequest req) throws SchedulerException {
        schedulerService.resumeJob(req.getJobName(), req.getGroup());
        return ok("已恢复: " + req.getJobName());
    }

    /** 删除任务 */
    @DeleteMapping
    public Map<String, Object> delete(@RequestBody JobKeyRequest req) throws SchedulerException {
        boolean ok = schedulerService.deleteJob(req.getJobName(), req.getGroup());
        return ok(ok ? "已删除: " + req.getJobName() : "任务不存在: " + req.getJobName());
    }

    /** 立即触发一次 */
    @PostMapping("/trigger")
    public Map<String, Object> trigger(@RequestBody JobKeyRequest req) throws SchedulerException {
        schedulerService.triggerJobOnce(req.getJobName(), req.getGroup());
        return ok("已立即触发: " + req.getJobName());
    }

    /** 查询所有任务 */
    @GetMapping
    public Map<String, Object> list() throws SchedulerException {
        List<String> jobs = schedulerService.listJobs();
        Map<String, Object> result = ok("查询成功");
        result.put("data", jobs);
        return result;
    }

    private Map<String, Object> ok(String msg) {
        Map<String, Object> m = new HashMap<>(2);
        m.put("code", 200);
        m.put("msg", msg);
        return m;
    }
}
```

> 💡 **为什么用 JSON 请求体？**
>
> - 参数多时 URL 不会过长，也避免特殊字符（如 Cron 表达式里的空格、`*`）被转义或截断
> - 前端表单/Axios 统一发 `application/json`，更规范
> - 后续加字段不需要改 URL，扩展性更好
> - 方便配合 `@Valid` + JSR-303 做参数校验

---

## 第 7 步：编写监听器（可选但推荐）

### JobListener & TriggerListener + 注册

监听器用于监控任务执行全过程——日志、耗时统计、异常告警都靠它。Quartz 提供 3 种监听器，我们实现最常用的两种：

| 监听器 | 回调时机 | 用途 |
|---|---|---|
| `JobListener` | 执行前 / 被否决 / 执行后 | 日志、耗时、异常告警 |
| `TriggerListener` | 触发 / 否决 / misfire / 完成 | 条件控制、misfire 监控 |

**`src/main/java/com/example/quartz/listener/CustomJobListener.java`**

```java
package com.example.quartz.listener;

import lombok.extern.slf4j.Slf4j;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.quartz.JobListener;
import org.springframework.stereotype.Component;

/**
 * 自定义 Job 监听器（全局监听，监听所有 Job）。
 *
 * 三个回调时机：
 * - jobToBeExecuted：Job 即将执行前
 * - jobExecutionVetoed：被 TriggerListener 否决时
 * - jobWasExecuted：Job 执行完成后（含异常情况，jobException 非 null 表示出错）
 *
 * 典型用途：统一日志、耗时统计、异常告警、链路追踪。
 */
@Slf4j
@Component
public class CustomJobListener implements JobListener {

    @Override
    public String getName() {
        return "customJobListener";
    }

    @Override
    public void jobToBeExecuted(JobExecutionContext context) {
        log.debug("[JobListener] 任务即将执行: {}", context.getJobDetail().getKey());
    }

    @Override
    public void jobExecutionVetoed(JobExecutionContext context) {
        log.debug("[JobListener] 任务被否决: {}", context.getJobDetail().getKey());
    }

    @Override
    public void jobWasExecuted(JobExecutionContext context, JobExecutionException jobException) {
        if (jobException != null) {
            log.error("[JobListener] 任务执行异常: {}, 异常: {}",
                    context.getJobDetail().getKey(), jobException.getMessage());
        } else {
            log.debug("[JobListener] 任务执行完成: {}, 耗时={}ms",
                    context.getJobDetail().getKey(), context.getJobRunTime());
        }
    }
}
```

**`src/main/java/com/example/quartz/listener/CustomTriggerListener.java`**

```java
package com.example.quartz.listener;

import lombok.extern.slf4j.Slf4j;
import org.quartz.JobExecutionContext;
import org.quartz.Trigger;
import org.quartz.TriggerListener;
import org.springframework.stereotype.Component;

/**
 * 自定义 Trigger 监听器（全局监听）。
 *
 * 四个回调时机：
 * - triggerFired：触发器被触发
 * - vetoJobExecution：是否否决本次执行（返回 true 阻止 Job 执行）
 * - triggerMisfired：触发器发生 misfire（错过触发时间）
 * - triggerComplete：触发器完成本次触发
 */
@Slf4j
@Component
public class CustomTriggerListener implements TriggerListener {

    @Override
    public String getName() {
        return "customTriggerListener";
    }

    @Override
    public void triggerFired(Trigger trigger, JobExecutionContext context) {
        log.debug("[TriggerListener] 触发器触发: {}", trigger.getKey());
    }

    @Override
    public boolean vetoJobExecution(Trigger trigger, JobExecutionContext context) {
        // 返回 true 则阻止本次 Job 执行；可用于做条件控制（如灰度开关）
        return false;
    }

    @Override
    public void triggerMisfired(Trigger trigger) {
        log.warn("[TriggerListener] 触发器 misfire(错过触发时间): {}", trigger.getKey());
    }

    @Override
    public void triggerComplete(Trigger trigger, JobExecutionContext context,
                                Trigger.CompletedExecutionInstruction instruction) {
        log.debug("[TriggerListener] 触发器完成: {}", trigger.getKey());
    }
}
```

监听器写好后需要注册到 Scheduler。创建注册配置：

**`src/main/java/com/example/quartz/config/ListenerConfig.java`**

```java
package com.example.quartz.config;

import com.example.quartz.listener.CustomJobListener;
import com.example.quartz.listener.CustomTriggerListener;
import org.quartz.Scheduler;
import org.quartz.SchedulerException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;

import javax.annotation.PostConstruct;

/**
 * 监听器注册配置。
 * Scheduler 由 spring-boot-starter-quartz 自动创建并注入，
 * 这里只需在启动后把自定义监听器挂上去即可。
 */
@Configuration
public class ListenerConfig {

    @Autowired
    private Scheduler scheduler;

    @Autowired
    private CustomJobListener customJobListener;

    @Autowired
    private CustomTriggerListener customTriggerListener;

    @PostConstruct
    public void registerListeners() throws SchedulerException {
        // 不传 matcher = 全局监听（监听所有任务）
        scheduler.getListenerManager().addJobListener(customJobListener);
        scheduler.getListenerManager().addTriggerListener(customTriggerListener);
    }
}
```

> ⚠️ **性能注意**：监听器在 Scheduler 线程中**同步执行**，不要在里面做耗时操作（远程调用、大数据查询），否则会拖慢整个调度。耗时逻辑应异步投递到消息队列或线程池。

---

## 第 8 步：启动时自动注册任务

### CommandLineRunner：启动即调度

很多场景需要「应用启动后自动注册定时任务」。实现 `CommandLineRunner` 即可——它在 Spring 容器就绪后执行。

**为什么 catch 异常？** JDBC 持久化模式下，重启时任务已经存在于数据库，再次注册会抛 `ObjectAlreadyExistsException`，这里做了忽略处理。

**`src/main/java/com/example/quartz/config/StartupJobInit.java`**

```java
package com.example.quartz.config;

import com.example.quartz.service.SchedulerService;
import lombok.extern.slf4j.Slf4j;
import org.quartz.SchedulerException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

/**
 * 启动即注册演示任务。
 *
 * 演示「应用启动后自动调度」的常见写法：实现 CommandLineRunner，
 * 在应用就绪后通过 SchedulerService 注册一个 Cron 任务。
 *
 * JDBC 持久化模式下重启会抛 ObjectAlreadyExists，这里做了忽略处理。
 */
@Slf4j
@Component
public class StartupJobInit implements CommandLineRunner {

    @Autowired
    private SchedulerService schedulerService;

    @Override
    public void run(String... args) {
        try {
            // 每 30 秒执行一次的演示任务
            schedulerService.addCronJob("startupDemo", "SYSTEM", "0/30 * * * * ?", "启动自动注册演示任务");
            log.info("[Startup] 演示任务 startupDemo 已注册（每30秒一次）");
        } catch (SchedulerException e) {
            // JDBC 模式下任务已存在，属正常情况
            log.info("[Startup] 演示任务已存在，跳过注册: {}", e.getMessage());
        }
    }
}
```

---

## 第 9 步：运行与测试

### 9.1 内存模式（无需数据库，开箱即用）

在项目根目录执行：

```bash
# 进入项目目录
cd quartz-demo
# 启动（内存模式是默认 profile）
mvn spring-boot:run
```

启动成功后，用 curl 测试各接口。注意：除 GET 查询外，其他接口都需要 `-H "Content-Type: application/json"` 并以 JSON 作为请求体。

**① 查询所有任务**

```bash
curl "http://localhost:8080/jobs"
```

**② 注册 SimpleTrigger 任务：每 3 秒一次，重复 5 次**

```bash
curl -X POST "http://localhost:8080/jobs/simple" -H "Content-Type: application/json" -d "{\"jobName\":\"jobA\",\"intervalSeconds\":3,\"repeatCount\":5}"
```

**③ 注册 Cron 任务：每 10 秒一次**

```bash
curl -X POST "http://localhost:8080/jobs/cron" -H "Content-Type: application/json" -d "{\"jobName\":\"jobB\",\"cron\":\"0/10 * * * * ?\",\"desc\":\"测试Cron\"}"
```

**④ 注册有状态计数任务：每 4 秒，观察 count 自增**

```bash
curl -X POST "http://localhost:8080/jobs/datamap" -H "Content-Type: application/json" -d "{\"jobName\":\"jobC\",\"desc\":\"计数演示\",\"intervalSeconds\":4}"
```

**⑤ 立即触发一次 jobA**

```bash
curl -X POST "http://localhost:8080/jobs/trigger" -H "Content-Type: application/json" -d "{\"jobName\":\"jobA\"}"
```

**⑥ 暂停 jobB**

```bash
curl -X PUT "http://localhost:8080/jobs/pause" -H "Content-Type: application/json" -d "{\"jobName\":\"jobB\"}"
```

**⑦ 恢复 jobB**

```bash
curl -X PUT "http://localhost:8080/jobs/resume" -H "Content-Type: application/json" -d "{\"jobName\":\"jobB\"}"
```

**⑧ 删除 jobC**

```bash
curl -X DELETE "http://localhost:8080/jobs" -H "Content-Type: application/json" -d "{\"jobName\":\"jobC\"}"
```

> 💡 **验证 JobDataMap 有状态**：注册 jobC 后观察日志，`DataMapJob` 的 `count` 会从 0 逐次递增（0→1→2→3...）。这就是 `@PersistJobDataAfterExecution` 的效果。内存模式下进程重启归零；JDBC 模式下重启不丢失。

### 9.2 JDBC 持久化模式（生产推荐）

内存模式重启后任务全丢。生产环境需要切换到 JDBC 模式——把任务存进数据库，重启不丢、还支持集群。

#### 9.2.1 建库建表

```bash
# 登录 MySQL
mysql -u root -p
```

```sql
CREATE DATABASE quartz_demo DEFAULT CHARACTER SET utf8mb4;
USE quartz_demo;
SOURCE /path/to/quartz-demo/src/main/resources/sql/tables_mysql_innodb.sql;
SHOW TABLES;  -- 应看到 11 张 QRTZ_ 开头的表
```

建表脚本已包含在项目中：`src/main/resources/sql/tables_mysql_innodb.sql`（共 11 张表）。核心几张：

| 表名 | 作用 |
|---|---|
| `QRTZ_JOB_DETAILS` | 存储 JobDetail |
| `QRTZ_TRIGGERS` | 存储 Trigger |
| `QRTZ_CRON_TRIGGERS` | 存储 Cron 表达式 |
| `QRTZ_SCHEDULER_STATE` | 集群节点心跳 |
| `QRTZ_LOCKS` | 集群悲观锁 |

#### 9.2.2 添加 JDBC 配置文件

在 `src/main/resources/` 下创建 `application-jdbc.yml`：

**`src/main/resources/application-jdbc.yml`**

```yaml
# ===== JDBC 持久化 + 集群模式 =====
# 启动方式：java -jar quartz-demo.jar --spring.profiles.active=jdbc

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/quartz_demo?useUnicode=true&characterEncoding=utf-8&useSSL=false&serverTimezone=Asia/Shanghai
    username: root
    password: root
    driver-class-name: com.mysql.cj.jdbc.Driver

  quartz:
    # 改为数据库存储
    job-store-type: jdbc
    # never=不自动建表(手动执行SQL); embedded=仅内嵌库建表; always=总是建表
    jdbc:
      initialize-schema: never
    wait-for-jobs-to-complete-on-shutdown: true
    properties:
      org.quartz.scheduler.instanceName: QuartzScheduler
      org.quartz.scheduler.instanceId: AUTO
      org.quartz.threadPool.class: org.quartz.simpl.SimpleThreadPool
      org.quartz.threadPool.threadCount: 10
      org.quartz.threadPool.threadPriority: 5
      # ===== JobStore 切换为 JDBC =====
      org.quartz.jobStore.class: org.quartz.impl.jdbcjobstore.JobStoreTX
      # MySQL 使用 StdJDBCDelegate
      org.quartz.jobStore.driverDelegateClass: org.quartz.impl.jdbcjobstore.StdJDBCDelegate
      # false 允许 JobDataMap 存任意可序列化对象；true 仅允许 String
      org.quartz.jobStore.useProperties: false
      # Quartz 表前缀，默认 QRTZ_
      org.quartz.jobStore.tablePrefix: QRTZ_
      # ===== 开启集群 =====
      org.quartz.jobStore.isClustered: true
      # 节点心跳间隔(毫秒)
      org.quartz.jobStore.clusterCheckinInterval: 20000
      org.quartz.jobStore.misfireThreshold: 60000
```

#### 9.2.3 以 JDBC 模式启动

```bash
java -jar quartz-demo.jar --spring.profiles.active=jdbc

# 或开发阶段用 Maven
mvn spring-boot:run -Dspring-boot.run.profiles=jdbc
```

> 💡 **验证持久化**：启动后注册一个任务 → 查看数据库 `QRTZ_JOB_DETAILS` 表有记录 → **重启应用** → 任务依然在，继续按计划执行。这就是 JDBC 模式的核心价值。

#### 9.2.4 集群原理

开启集群只需 `isClustered: true`。原理：

1. 所有节点连**同一个数据库**，共享 Quartz 表
2. 每个节点有唯一 `instanceId: AUTO`，定期向 `QRTZ_SCHEDULER_STATE` 写心跳
3. 触发任务时通过 `QRTZ_LOCKS` 悲观锁竞争，**只有一个节点**执行
4. 某节点宕机后，其他节点检测到心跳超时，接管其任务

> ⚠️ **集群要点**：
> 1. 所有节点必须使用相同配置（同库、同表前缀）
> 2. 节点间无需直接通信，仅靠数据库协调
> 3. 节点时钟要同步（NTP）
> 4. 集群只保证不重复执行，不保证负载绝对均衡

---

## Cron 表达式速查

Quartz Cron 有 **6 或 7 个字段**（最后年份可选），空格分隔：

| 位置 | 字段 | 允许值 | 特殊字符 |
|---|---|---|---|
| 1 | 秒 | 0-59 | `, - * /` |
| 2 | 分 | 0-59 | `, - * /` |
| 3 | 时 | 0-23 | `, - * /` |
| 4 | 日 | 1-31 | `, - * / ? L W C` |
| 5 | 月 | 1-12 或 JAN-DEC | `, - * /` |
| 6 | 周 | 1-7 或 SUN-SAT | `, - * / ? L C #` |
| 7 | 年（可选） | 空 或 1970-2099 | `, - * /` |

常用示例：

| 表达式 | 含义 |
|---|---|
| `0/5 * * * * ?` | 每 5 秒 |
| `0 0/2 * * * ?` | 每 2 分钟 |
| `0 30 9 * * ?` | 每天 9:30 |
| `0 0 10,14,16 * * ?` | 每天 10:00、14:00、16:00 |
| `0 0 12 ? * WED` | 每周三 12:00 |
| `0 0 10 L * ?` | 每月最后一天 10:00 |
| `0 15 10 ? * 6L` | 每月最后一个周五 10:15 |

> ⚠️ **日与周互斥**：日（day-of-month）和周（day-of-week）不能同时用 `*`，其中一个必须用 `?`。这是 Cron 表达式最常见的报错原因。

---

## 最佳实践与避坑

| 最佳实践 | 说明 |
|---|---|
| **Job 必须幂等** | misfire 补偿、集群重试、手动触发都可能导致多次执行。用状态标记或去重表保证幂等 |
| **不要阻塞 execute()** | 阻塞会占线程池。耗时操作应异步化或限制并发 |
| **合理设线程池** | threadCount 默认 10。任务多且耗时时调大，但过大增加 DB 压力 |
| **JobDataMap 别存大对象** | JDBC 模式会序列化成 BLOB。复杂参数只存 ID，执行时再查 |
| **生产用 useProperties:true** | JobDataMap 只存基本类型，避免对象序列化的类版本不一致问题 |
| **优雅停机** | `wait-for-jobs-to-complete-on-shutdown: true`，避免任务执行到一半被中断 |

> ⚠️ **高危坑：Job 类变更与序列化**
>
> JDBC 模式 + `useProperties:false` 时，JobDataMap 中的对象按序列化字节存库。如果你修改了 Job 类的包名或字段，反序列化会失败导致任务无法执行！**强烈推荐 `useProperties:true`**。

---

## 项目完整文件清单

| 文件 | 作用 |
|---|---|
| `pom.xml` | Maven 依赖配置 |
| `QuartzDemoApplication.java` | 启动类 |
| `application.yml` | 内存模式配置（默认） |
| `application-jdbc.yml` | JDBC 持久化 + 集群配置 |
| `AutowiringSpringBeanJobFactory.java` | 解决 Job 依赖注入（第 3 步核心） |
| `QuartzConfig.java` | 注入自定义 JobFactory |
| `ListenerConfig.java` | 注册监听器 |
| `StartupJobInit.java` | 启动自动注册任务 |
| `SimpleJob.java` | 基础任务（验证依赖注入） |
| `CronJob.java` | Cron 表达式任务 |
| `DataMapJob.java` | 有状态计数任务 |
| `EmailService.java` | 被 Job 注入的业务服务 |
| `SchedulerService.java` | 调度核心服务（增删改查） |
| `JobController.java` | REST 接口 |
| `CustomJobListener.java` | Job 监听器 |
| `CustomTriggerListener.java` | Trigger 监听器 |
| `tables_mysql_innodb.sql` | MySQL 建表脚本（11 张表） |

---

*Quartz 调度框架完整教程 · 整合 Spring Boot*
*配套项目位于 `quartz-tutorial/quartz-demo` 目录，可直接运行*
