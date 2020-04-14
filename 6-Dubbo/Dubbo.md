# Dubbo入门

## 一、Zookeeper服务注册中心

Zookeeper是Apache Hadoop的子项目，是一个树型目录服务，支持变更推送，适合作为Dubbo服务的注册中心，工业强度较高，并推荐使用

流程说明：

- 服务提供者启动时，向`/dubbo/con.fo.BarService/providers`目录写入自己的URL地址
- 服务消息者(Consumer)启动时，订阅`/dubbo/com.foo.BarService/providers`目录下提供者URL地址，并向`/dubbo/com.foo.BarService/consumers`目录写入自己的URL地址
- 监控中心(Monitor)启动时，订阅`/dubbo/com.foo.BarService`目录下的所有提供者和消费者URL地址

### 1、安装Zookeeper

下载地址：http://zookeeper.apache.org/

- 安装jdk

- 上传zoopeeker并解压到 /opt 目录

- 解压zookeeper，并创建 data（可以是别的名字或目录）目录
- 进入conf目录，把zoo_sample.cfg复制为zoo.cfg
- 修改zoo.cfg文件，修改dataDir属性的值，指定data目录

### 2、启动、停止Zookeeper

/bin/zkServer.sh start 启动

/bin/zkServer.sh stop 停止

/bin/zkServer.sh status 查看服务状

## 二、使用Dubbo

### 1、创建服务提供者 dubbodemo_provider项目（SpringMVC项目）

#### 1）导入依赖

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>top.aoae</groupId>
  <artifactId>dubbodemo_provider</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>war</packaging>

  <name>dubbodemo_provider Maven Webapp</name>
  <!-- FIXME change it to the project's website -->
  <url>http://www.example.com</url>

  <properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <maven.compiler.source>1.8</maven.compiler.source>
    <maven.compiler.target>1.8</maven.compiler.target>
    <spring.version>5.0.5.RELEASE</spring.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-context</artifactId>
      <version>${spring.version}</version>
    </dependency>
    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-beans</artifactId>
      <version>${spring.version}</version>
    </dependency>
    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-webmvc</artifactId>
      <version>${spring.version}</version>
    </dependency>
    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-jdbc</artifactId>
      <version>${spring.version}</version>
    </dependency>
    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-aspects</artifactId>
      <version>${spring.version}</version>
    </dependency>
    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-jms</artifactId>
      <version>${spring.version}</version>
    </dependency>
    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-context-support</artifactId>
      <version>${spring.version}</version>
    </dependency>

    <dependency>
      <groupId>com.alibaba</groupId>
      <artifactId>dubbo</artifactId>
      <version>2.6.0</version>
    </dependency>
    <!--Zookeeper的连接-->
    <dependency>
      <groupId>org.apache.zookeeper</groupId>
      <artifactId>zookeeper</artifactId>
      <version>3.4.7</version>
    </dependency>
    <!--Zookeeper的客户端-->
    <dependency>
      <groupId>com.github.sgroschupf</groupId>
      <artifactId>zkclient</artifactId>
      <version>0.1</version>
    </dependency>

    <dependency>
      <groupId>javassist</groupId>
      <artifactId>javassist</artifactId>
      <version>3.12.1.GA</version>
    </dependency>

   <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>4.12</version>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <finalName>dubbodemo_provider</finalName>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>2.3.2</version>
        <configuration>
          <source>${maven.compiler.source}</source>
          <target>${maven.compiler.target}</target>
        </configuration>
      </plugin>
      <plugin>
        <groupId>org.apache.tomcat.maven</groupId>
        <artifactId>tomcat7-maven-plugin</artifactId>
        <version>2.2</version>
        <configuration>
          <port>8081</port>
          <path>/</path>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```

#### 2）web.xml

```xml
<!DOCTYPE web-app PUBLIC
 "-//Sun Microsystems, Inc.//DTD Web Application 2.3//EN"
 "http://java.sun.com/dtd/web-app_2_3.dtd" >

<web-app>
  <display-name>Archetype Created Web Application</display-name>
  
  <context-param>
    <param-name>contextConfigLocation</param-name>
    <param-value>classpath:applicationContext*.xml</param-value>
  </context-param>
  <listener>
    <listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>
  </listener>
</web-app>
```

#### 3）applicationContext-service.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:dubbo="http://code.alibabatech.com/schema/dubbo"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd http://code.alibabatech.com/schema/dubbo http://code.alibabatech.com/schema/dubbo/dubbo.xsd">
    <!-- 每个dubbo应用都必须指定一个唯一的名称 -->
    <dubbo:application name="dubbodemo_provider" />
    <!-- 指定zookeeper的注册中心-->
    <dubbo:registry address="zookeeper://192.168.25.64:2181" />
    <!-- 配置协议及端口，固定的，但可以配置 -->
    <dubbo:protocol name="dubbo" port="20880" />
    <!-- 指定要扫描的包 -->
    <dubbo:annotation package="top.aoae.service.impl" />
</beans>
```

#### 4）创建服务HelloService接口及其实现类

**HelloService:**

```java
public interface HelloService {
    String sayHello(String name);
}
```

注意：接口可以作为一个单独项目，方便引入

**HelloServiceImpl**

```java
/**
 * 发布为服务
 * 使用Dubbo提供的Service服务
 */
@com.alibaba.dubbo.config.annotation.Service
public class HelloServiceImpl implements HelloService {
    @Override
    public String sayHello(String name) {
        return "Hello " + name;
    }
}
```

### 2、创建服务消费者dubbodemo_comsumer (SpringMVC)项目

#### 1）导入依赖

和dubbodemo_provider项目是一样的，唯一不同的是tomcat插件的配置这里使用的端口是`8082`

#### 2）web.xml

```xml
<!DOCTYPE web-app PUBLIC
 "-//Sun Microsystems, Inc.//DTD Web Application 2.3//EN"
 "http://java.sun.com/dtd/web-app_2_3.dtd" >

<web-app>
  <display-name>Archetype Created Web Application</display-name>

  <servlet>
    <servlet-name>springmvc</servlet-name>
    <servlet-class>org.springframework.web.servlet.DispatcherServlet</servlet-class>
    <init-param>
      <param-name>contextConfigLocation</param-name>
      <param-value>classpath:applicationContext-web.xml</param-value>
    </init-param>
    <load-on-startup>1</load-on-startup>
  </servlet>
  <servlet-mapping>
    <servlet-name>springmvc</servlet-name>
    <url-pattern>*.do</url-pattern>
  </servlet-mapping>
</web-app>
```

#### 3）applicationContext-web.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:buddo="http://code.alibabatech.com/schema/dubbo"
       xmlns:dubbo="http://code.alibabatech.com/schema/dubbo"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd http://code.alibabatech.com/schema/dubbo http://code.alibabatech.com/schema/dubbo/dubbo.xsd">
    <!-- 服务名称 -->
    <dubbo:application name="dubbodemo_consumer"/>
    <!--zookeeper注册中心-->
    <dubbo:registry address="zookeeper://192.168.25.64:2181"/>
    <!--包扫描-->
    <dubbo:annotation package="top.aoae.controller"/>
</beans>
```

#### 4）创建HelloController项目，并调用dubbodemo_provider项目里的HelloService服务

```java
@Controller
@RequestMapping("/hello")
public class HelloController {
    
	// 使用#Reference注解引入服务
    @com.alibaba.dubbo.config.annotation.Reference
    private HelloService helloService;

    @RequestMapping("/sayHello")
    @ResponseBody
    public String sayHello(String name) {
        return helloService.sayHello(name);
        //return "aa" + name;
    }
}
```

### 3、分别启动两个项目，并访问接口

GET: `http://localhost:8082/hello/sayHello.do?name=aoae`，输出：

```
Hello aoae
```

## 三、Dubbo管理控制器

下载地址：https://github.com/apache/dubbo/tree/2.5.x

也搜索可以下载war包下载。

修改`src/main/webapp/WEB-INF/dubbo.properties`文件，指定zookeeper的地址及登录信息

```properties
dubbo.registry.address=zookeeper://192.168.25.64:2181
dubbo.admin.root.password=root
dubbo.admin.guest.password=guest
```

复制tomcat的webapp目录下启动，访问以下连接，输入`root`及`root`登录

```
http://localhost:8080/dubbo-admin-2.6.0
```

## 四、使用Log4j

1、加入log4j.properties

```properties
log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.Target=System.err
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=$d{ABSOLUTE} %5p %c{1}:%L - %m%n

log4j.rootLogger=debug, stdout
```

## 五、Dubbo的配置说明

### 1、包扫描

```xml
<!--包扫描-->
<dubbo:annotation package="top.aoae.service" />
```

服务提供者和服务消费者都需要配置，表示 包扫描，作用是扫描指定包（包括子包）下的类。如果不使用包扫描，也可以通过下面配置完成服务发布：

```xml
<bean id="helloService" class="top.aoae.service.impl.HelloServiceImp;"/>
<dubbo:service interface="top.aoae.service.HelloService" ref="helloService"/>
```

为作消费者，可以通过如下配置来引用服务：

```xml
<dubbo:reference id="helloService" interface="top.aoae.service.HelloService">
```

### 2、协议

协议通常会在服务提供者中配置：

```xml
<!-- 配置协议及端口，固定的 -->
<dubbo:protocol name="dubbo" port="20880" />
<!--
	name有以下几种
		- dubbo 推荐使用，单一长连接，NIO异步通信
		- rmi
		- hessian
		- http
		- webservice
		- rest
		- redis
-->
```

多个协议及不同服务配置不同协议

```xml
<dubbo:protocol name="dubbo" port="20880" />
<dubbo:protocol name="rmi" port="1099" />
<dubbo:service interface="top.aoae.service.HelloService" ref="helloService" protocol="dubbo" />
<dubbo:service interface="top.aoae.service.HelloService" ref="helloService" protocol="rmi" />
```

### 3、启动检查

在开发时使用

```xml
<!-- 启动时不检查依赖的服务是否启动 -->
<dubbo:consumer check="false"/>
```

## 六、负载均衡

Dubbo提供多种均衡策略（包括随机[random]、轮询、最少活跃调用数、一致性Hash），缺省为随机(random)调用。

配置负载均衡策略，既可以在服务提供者一方配置，也可以在服务消费者一方配置，如下：

### 1、消费者配置

```java
@Controller
@RequestMapping("/hello")
public class HelloController {
    @com.alibaba.dubbo.config.annotation.Reference(
        check = false,
        loadbalance = "random"  // 负载均衡策略
    )
    private HelloService helloService;

    @RequestMapping("/sayHello")
    @ResponseBody
    public String sayHello(String name) {
        return helloService.sayHello(name);
        //return "aa" + name;
    }
}
```

### 2、提供者配置

```java
/**
 * 发布为服务
 * 使用Dubbo提供的Service服务
 */
@com.alibaba.dubbo.config.annotation.Service(
    loadbalance = "random"  // 配置负载均衡策略
)
public class HelloServiceImpl implements HelloService {
    @Override
    public String sayHello(String name) {
        return "Hello " + name;
    }
}
```

## 七、Dubbo无法发布被事务代理的Service问题

通过Dubbo提供的标签配置就可以进行包扫描，扫描到`@Service`注解的类就可以被发布为服务。但是如果在服务提供者上加入`@Transaction`事务控制注解后，服务就发布不成功，原因是事务控制的底层原理是为服务提供者类创建代理对象，而默认情况下Spring是基于JDK动态代理方式创建代理对象，而此代理对象的完整类名为com.sun.proxy.$Proxy42(最后两位数字不是固定的)，导致Dubbo在发布服务进行匹配时无法完成匹配，进而没有进行服务的发布。

### 第一步：

```xml
<!--
	- proxy-target-class="true",作用是使用cglib代理方式为Service类创建代理对象，
	- 这样子生成的代理对象就和发布的服务对象一致
-->
<tx:annotation-driven transaction-manager="transationManager" proxy-target-class="true"/>
```

### 第二步：

```java
@com.alibaba.dubbo.config.annotation.Service(
    interfaceClass = HelloService.class  // 强制指定接口类型
)
@Transactional
public class HelloServiceImpl implements HelloService {
    @Override
    public String sayHello(String name) {
        return "Hello " + name;
    }
}
```

实现以上两步后`@Transactional`注解就可以使用了