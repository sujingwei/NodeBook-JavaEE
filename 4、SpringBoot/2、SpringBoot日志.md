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

* SpringBoot选择的是SLF4j 和Logback进行日志记录

* SpringBoot也把其它的日志都替换成了slf4j