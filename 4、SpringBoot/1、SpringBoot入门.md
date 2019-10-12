# 一、SpringBoot介绍

## 1、SpringBoot的特点

* 基于Spring的开发提供更快的入门体验
* 开箱就用，没有代码生成，也无需xml的配置。同时也可以修改默认值来满足需求
* 提供了一些大型项目中常见的非功能特性，如嵌入式服务器、安全、指标、健康检测、外部配置等
* SpringBoot不是对Spring功能上的增强，而是提供了一种快速使用Spring的方式

## 2、SpringBoot的核心功能

* 起步依赖

  起步依赖本质上是一个Maven项目对象模型(Project Object Model, POM) ，定义了对其他库的传递依赖，这些东西加在一起就支持某项功能。

* 自动配置

  SpringBoot的自动配置是一个运行时（更准确地说，是应用程序启动时）的过程，考虑了众多因素，才决定Spring配置应该用哪个。该是Spring自动完成的。

# 二、SpringBoot的快速入门

# 1、SpringBoot快速入门案例

### 第一步，创建一个普通的Maven项目，并导入依赖

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <!--所有的springboot工程都必须继承spring-boot-starter-parent-->
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.0.1.RELEASE</version>
    </parent>

    <groupId>com.itheima</groupId>
    <artifactId>srpingboot_quick</artifactId>
    <version>1.0-SNAPSHOT</version>

    <dependencies>
        <!--web功能的起步依赖-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>

</project>
```

### 第二步、编写SpringBoot引导类

```java
/**
 * 声明该类是一个SpringBoot的引导类
 */
@SpringBootApplication
public class MySpringBootApplication {
    /**
    * 这里有main方法，所以在这里运行项目就可以
    */
    public static void main(String[] args) {
        // run方法，表示运行SprngBoot的引导类，参数就是SpringBoot引导的字节码对象
        SpringApplication.run(MySpringBootApplication.class);
    }
}
```

### 第三步、编写Controller

```java
@Controller
public class QuickController {

    @RequestMapping("/quick")
    @ResponseBody
    public String quick() {
        return "hello springboot";
    }
}
// 访问 http://localhost:8080/quick 输出 hello springboot
```

通过以上三步，可以完成Spring项目的创建，但也可以通过idea的Spring工程来创建SpringBoot项目，在这里不在描述。

## 2、热部署

要pom.xml文件加入以下依赖就可以使用

```xml
<!--热部署配置-->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
</dependency>
```

idea热部署使用

* file -> settings -> Compiler  钩选 Build project automatically

* 在pom.xml文件中按 Ctrl +  Shift + Alt + / 快捷键，选择 Registry 钩选 compiler.automake.allow.when.app.running

# 三、SpringBoot原理分析

1、SpringBoot自动配置

SpringBoot引导类同级包及子包下的类，只要加入注解，都会扫描到IOC容器中。

***@SpringBootApplication注解***

@SpringBootApplication注解包含以下几个重要的注解：

* @SpringBootConfiguration 包含了(包含了@Configuration注解，是一个配置类)
* @EnableAutoConfiguration 自动配置
* @ComponentScan 指定要扫描的包路径

# 四、Spring Boot 配置文件

SpringBoot是基于约定的，所以很多配置都有默认值。但如果想要使用自己的配置替换默认配置的话，就可以使用application.properties或application.yml(application.yaml)文件

SpringBoot默认会从Resources目录下加载application.properties或application.yml文件。

## 1、properties配置

```shell
# application.properties

# 服务器的端口号
server.port = 8083
# 当前Web应用的名称
server.servlet.context-path=/demo
```

## 2、yml配置文件

yml文件格式是YAML编写的文件格式，YAML是一种直观的能够被电脑识别的数据序列化格式，并且容易被人类阅读，容易和脚本交互，可以被大部分编程语言支持。

```yaml
# application.yml

# 普通数据的配置
name: zhangsan

# 对象配置，语法类似Python
person:
  name: zhangsan
  age: 18
  addr: beijing

# 行内对象配置
person2: {name: zhangsan, age: 18, addr: beijing}

# 配置集合(list)
city:
  - beijing
  - tianjin
  - chongqing
  - shanghai
city2: [beijing,tianjin,chongqing,shanghai]
student:
  - name: tom
    age: 18
    addr: beijing
  - name: lucy
    age: 17
    addr: tianjin
student2: [{name: tom, age: 18, addr: beijing},{name: lucy, age: 17, addr: beijing}]

# 配置集合(map)
map:
  key1: value1
  key2: value2

server:
  port: 8082
```

## 3、读取配置(@Value)

```java
@Controller
public class Quick2Controller {
    /**
     * 从配置文件中得到name的值
     */
    @Value("${name}")
    private String name;
	// 从配置文件中得到persion对象下的addr属性值
    @Value("${person.addr}")
    private String addr;
```

## 4、读取配置(@ConfigurationProperties)

通过@ConfigurationProperties注解映射配置文件的属性到当前类的属性中

**pom.xml**

```xml
<!-- 映射@ConfigurationProperties执行器 -->
<!-- 当前依赖可以不用加入，但加入后会有提示，也不会报警告 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-configuration-processor</artifactId>
            <optional>true</optional>
        </dependency>
```

**java文件**

```java
@Controller
@ConfigurationProperties(prefix = "person2") // 读配置文件中的 person2对象到配置文件中
public class Quick3Controller {
    private String name;
    private String addr;
    
    public String getName() {
        return name;
    }
    public void setName(String name) {
        this.name = name;
    }
    public String getAddr() {
        return addr;
    }
    public void setAddr(String addr) {
        this.addr = addr;
    }
    @RequestMapping("/quick3")
    @ResponseBody
    public String quick3()
    {
        return "name: "+ name +", addr: " + addr;
    }
}
```

# 五、SpringBoot和其它技术的整合

## 1、SpringBoot整合Mybatis

**pom.xml导入 jar 包**

```xml
<!-- mybatis整合spring -->
        <dependency>
            <groupId>org.mybatis.spring.boot</groupId>
            <artifactId>mybatis-spring-boot-starter</artifactId>
            <version>1.1.1</version>
        </dependency>

        <!-- 不用指定版本 -->
        <dependency>
            <groupId>mysql</groupId>
            <artifactId>mysql-connector-java</artifactId>
        </dependency>
```

**application.properites配置数据源和mybatis扫描的包**

```
# 数据库连接信息
spring.datasource.driverClassName=com.mysql.jdbc.Driver
spring.datasource.url=jdbc:mysql://127.0.0.1:3306/test?useUnicode=true&characterEncoding=utf8
spring.datasource.username=root
spring.datasource.password=root

# 配置MyBatis信息
# 配置别名包
mybatis.type-aliases-package=com.itheima.domain
# 配置加载mapper文件
mybatis.mapper-locations=classpath:mapper/*Mapper.xml
```

**UserMapper.java接口**

```java
@Repository
@Mapper
public interface UserMapper {
    List<User> queryUserList();
}
```

**UserMapper.xml映射文件**

```xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-mapper.dtd" >
<mapper namespace="com.itheima.mapper.UserMapper">
    <select id="queryUserList" resultType="user">
        select * from user
    </select>
</mapper>
```

**控制器**

```java
@Controller
public class MybatisController {
    @Autowired
    private UserMapper userMapper;

    @RequestMapping("/query")
    @ResponseBody
    public List<User> queryUserList(){
        List<User> users = userMapper.queryUserList();
        return users;
    }
}
```

## 2、整合Junit

**pom.xml**

```xml
<!-- srpingboot集成junit的jar包-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
```

**java测试类**

```java
@RunWith(SpringRunner.class)
@SpringBootTest(classes = SpringbootMybatisApplication.class)
public class MyBatisTest {

    @Autowired
    private UserMapper userMapper;

    @Test
    public void test(){
        List<User> users = userMapper.queryUserList();
        System.out.println(users);
    }
}
```

## 3、整合Redis

**pom.xml**

```xml
<dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
```

**java测试类**

```java

@RunWith(SpringRunner.class)
@SpringBootTest(classes = SpringbootMybatisApplication.class)
public class RedisTest {

    @Autowired
    private RedisTemplate<String, String> redisTemplate;

    @Autowired
    private UserMapper userMapper;

    @Test
    public void test() throws JsonProcessingException {
        // 从redis中得到数据,数据格式为json字符串
        String userListJson = redisTemplate.boundValueOps("user.findAll").get();
        // redis中是否存在数据
        if(null == userListJson){
            // 不存在数据 从数据库查询
            List<User> users = userMapper.queryUserList();
            // 把数据保存到redis中，将list集合转为json格式，使用jackson转
            ObjectMapper objectMapper = new ObjectMapper();
            userListJson = objectMapper.writeValueAsString(users);
            // 把数据储存到Redis中
            redisTemplate.boundValueOps("user.findAll").set(userListJson);
            System.out.println("--- 从数据库查询，并保存到redis中 ---");
        }else{
            System.out.println("--- 从redis中查询 ---");
        }
        // 返回
        System.out.println(userListJson);
    }
}
```

