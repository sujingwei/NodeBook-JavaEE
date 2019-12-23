# Spring Boot 启动配置原理

## 一、Spring Boot四种事件监听器(接口)

* SpringApplicationRunListener

* ApplicationRunner
* ApplicationContextinitializer
* commandLineRunner

## 二、Spring Boot自定义Starter

starter，也叫场境启动器。Spring Boot 默认已给我们写好了很多应用场景的配置，但时候我们需要自己编写配置。

### 1、添加依赖



### 2、编写自动配置

```java
@Configuration  // 指定这个类是一个配置类
@ConditionalOnXXX // 在指定条件成立的情况下自动配置类生效
@AutoconfigureAfter // 指定自动配置类的顺序
@Bean // 给容器中添加组件

@ConfigurationPropertie // 结合相关xxxProperties类来绑定相关的配置
@EnableConfigurationProperties // 让xxxProperties生效并加入到容器中

/*
自动配置类要加载，必须将需要启动就加载的自动配置类配置在：
	TODO resources/META-INF/spring.factories 文件中
*/
```

启动器 （starter）命名规范如：

`mybatis-springboot-starter`相当于`自动义启动器名-spring-boot-starter`