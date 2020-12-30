## 1、市面上的日志框架比较

市面上的日志框架：JUL、JCL、Jboss-logging、log4j、log4j2、slf4j.....

| 日志门面   | 日志实现                    |
| ---------- | --------------------------- |
| JCL, SLF4j | Log4j, JUL, Log4j2, Logback |

选择：

日志门面：SLF4j

日志实现：Logback

SpringBoot：底层是Spring，Spring框架默认是JCL;

​	SpringBoot选择的是SLF4j 和Logback

## 2、SLF4j使用

开发中，日志记录方法的调用，不应该直接调用日志实现类，而是调用日志抽象层里面的方法。

在Java项目中，不同的框架依赖的日志实现都是不一样的，而SpringBoot为了让所有的框架统一使用slf4j需要做以下操作：

* 将系统中其他日志框架先排除出去；
* 用中间包来替换原有的日志框架；
* 我们导入slf4其他实现

## 3、SpringBoot日志使用

​	springboot依赖了spring-boot-starter的jar包，这个包又依赖了spring-boot-starter-logging的jar包，这个包又依赖了logback-classic, jul-to-slf4j, log4j-over-slf4j, jcl-over-slf4j 等jar包，这些包的作用就是把各框架的日志转为slf4j的日志。

* SpringBoot选择的是SLF4j 和Logback进行日志记录
* SpringBoot也把其它的日志都替换成了slf4j
* 如果我们要引入其他框架，一定要把这个框架的日志依赖移除掉

> 在引入新的框架的时候，为了让SpringBoot能自动适配所有的日志，而且底层使用slf4j + logback的方法记录日志，引入其他框架的时候，只需要把这个框架依赖日志的框架排除掉

SpringBoot默认已配置好日志了，我们直接使用就行。

```java
@RunWith(SpringRunner.class)
@SpringBootTest
public class SpringBootLoggingApplicationTests {

    // 记录器
    Logger logger = LoggerFactory.getLogger(this.getClass());
    
    @Test
    public void contextLoads() {
        // 日志级别，从低到高，日志框架可以调整输出的日志级别
        logger.trace("这是trace日志...");
        logger.debug("这是debug日志...");
        logger.info("这是info日志..."); // spring boot 给我们设置的是 info 级别的日志
        logger.warn("这是warn日志...");
        logger.error("这是error日志...");
    }
}
```

**application.properties**

```properties
logging.level.com.atguigu=trace

# 不指定这个配置，只会在控制台输出，默认当前项目下生成springboot.log日志
logging.file=springboot.log

# 在d盘下生成日志
# logging.file=D:/springboot.log

# logging.path和logging.file只能指定一个，不能同时出现
# 在当前磁盘的根路径下创建spring/log/文件夹，使用spring.log作为默认文件
# logging.path=/spring/log

# 在控制台输出日志的格式
logging.pattern.console=%d{yyyy-M-dd HH:mm:ss.SSS} [%thread] %-5level %logger-{50} - %msg%n
logging.pattern.file=%d{yy
```

**配置格式**

```properties
%d 表示日期
%thread表示线程名称
%-5level 级别从左显示5个字符宽度
%logger{50} 表示logger名字最长50个字符否则按照句点分割
%msg 日志消息
%n 换行符
如下：
%d{yyyy-M-dd HH:mm:ss.SSS} [%thread] %-5level %logger-{50} - %msg%n
```

## 4、自定义日志配置文件

略。