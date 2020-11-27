# Apollo 配置中心

## 1、安装

在github上下载apollo的运行文件

| 应用                                  | 描述 |
| ------------------------------------- | ---- |
| apollo-quick-start-1.7.1.zip          |      |
| apolloconfigdb.sql                    |      |
| apolloportaldb.sql                    |      |

### 1）、执行sql脚本

把`apolloconfigdb.sql`和`apolloportaldb.sql`导入到mysql数库中

```
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| ApolloConfigDB     |
| ApolloPortalDB     |
+--------------------+
```

### 2）、运行项目

```
./demo.sh start
```

参考：https://github.com/ctripcorp/apollo/wiki/Quick-Start

## 2、使用

java脚本：

```java
public class GetConfigTest {
    public static void main(String[] args) {
        Config appConfig = ConfigService.getAppConfig();
        while (true) {
            // 休眠1s
            try {
              Thread.sleep(1000);
            } catch (InterruptedException e) {e.printStackTrace();}
            // 读配置
            String value = appConfig.getProperty("sms.enable", null);
            System.out.printf("now: %s, sms.enable: %s \n", LocalDateTime.now().toString(), value);
        }
    }
}
```

运行脚本：

通过在支持参数中加入apollo的配置

- app.id
- env
- dev_meta

```java
java -Dapp.id=apollo-quickstart -Denv=DEV -Ddev_meta=http://localhost:8080 -jar GetConfigTest.jar
```

## 3、核心概念

>  应用(application) -> 环境(env) -> 集群(cluster) -> 命名空间(namespace)

![](http://notebook-1.aoae.top/16023934988179)

保存成功后，需要退出再登录一下才会生效。

### 1) namespace

namespace有`共公`和`私有`的概念。

#### (1)、私有配置

![](http://notebook-1.aoae.top/16023947303833)

添加完成后如下图：

![](http://notebook-1.aoae.top/16023948131308)

多出了一个`spring-rocketmq`的namespace

读取命名空间下的配置：

```java
public class GetConfigTest {
    public static void main(String[] args) {
        // Config appConfig = ConfigService.getAppConfig();
        // TODO 读取指定命名空间下的配置
        Config appConfig = ConfigService.getConfig("spring-rocketmq");
        while (true) {
            // 休眠1s
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            // 读配置
            String value = appConfig.getProperty("rocketmq.name-server", null);
            System.out.printf("now: %s, rocketmq.name-server: %s \n", LocalDateTime.now().toString(), value);
        }
    }
}
```

#### (2)、公共配置及关联公共配置

公共配置通常用于被其它项目的全名空间继承(关联)

![](http://notebook-1.aoae.top/16023961132200)

这样子就可以使用别的项目下的公共配置，如图：

![](http://notebook-1.aoae.top/16023962354396)

使用代码：

```java
public class GetConfigTest {
    public static void main(String[] args) {
        // Config appConfig = ConfigService.getAppConfig();
        // 读取指定命名空间下的配置，这个命名空间就是关联命名空间
        Config appConfig = ConfigService.getConfig("micro_service.spring-boot-http");
        while (true) {
            // 休眠1s
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            // 读配置
            String value = appConfig.getProperty("server.servlet.context-path", null);
            System.out.printf("now: %s, server.servlet.context-path: %s \n", LocalDateTime.now().toString(), value);
        }
    }
}
```

### 2) cluster

集群的创建比较简单，点击**添加集群**就可以了，在`default`集群中可以把**配置同步**到新添加的集群中，否则新建的集群是没有配置项的

- apollo.cluster 通过环境变量指定运行集群的名称 
- apollo.cacheDir 配置缓存目录

```sh
java -Dapp.id=apollo-quickstart -Denv=DEV -Dapollo.cluster=SHAJQ -Dapollo.cacheDir=/tmp/apollo-config -Ddev_meta=http://localhost:8080 -jar GetConfigTest.jar
```

