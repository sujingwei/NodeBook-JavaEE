# Spring Boot 嵌入式Servlet

## 1、Spring Boot 服务端配置

SpringBoot默认是用嵌入式的Servlet容器(Tomcat)

问题？

* 如何定义和修改Servlet容器的相关配置？
* SpringBoot能不能支持其他的Servlet容器

`ServerProperties`包含服务相关的配置和Tomcat设置

方法一：

```properties
server.port=8080
server.context-path=/crud

// Tomcat的设置
service.tomcat.xxx
```

方法二：编写一个EmbededservletContainerCustomizer 嵌入式的Servlet容器定制器；来修改Servlet的容器配置。

```java
/**
 * 配置类，MyMvcConfig
 * 通过这个配置类，可以扩展SpringMVC的功能，
 */
@Configuration
public class MyMvcConfig implements WebMvcConfigurer {

    // ......

    /**
     * 配置服务端配置
     * @return
     */
    @Bean
    public WebServerFactoryCustomizer<ConfigurableWebServerFactory> myCustomizer(){
        return new WebServerFactoryCustomizer<ConfigurableWebServerFactory>() {
            @Override
            public void customize(ConfigurableWebServerFactory factory) {
                // 修改访问端口
                factory.setPort(8084);
            }
        };
    }

}

```

## 2、Spring Boot 注册Servlet三大组件

### (1) 注册Servlet

***定义一个Servlet***

```java
public class MyServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        doPost(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        resp.getWriter().write("Hello MyServlet");
    }
}
```

***使用ServletRegistrationBean注册Servlet到SpringBoot容器中***

```java
/**
 * 配置类，MyServerConfig
 * 通过这个配置类，可以扩展SpringMVC的功能，
 */
@Configuration
public class MyServerConfig {

    @Bean
    public ServletRegistrationBean myServlet(){
        ServletRegistrationBean register = new ServletRegistrationBean(new MyServlet(), "/myservlet");
        return register;
    }
}
```

### (2) 注册Filter

***定义Filter***

```java
public class MyFilter implements Filter {
    @Override
    public void init(FilterConfig filterConfig) throws ServletException {}

    @Override
    public void destroy() {}

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        System.out.println("MyFilter 执行了...");
        filterChain.doFilter(servletRequest, servletResponse);
    }
}
```

***使用FilterRegistrationBean注册Filter到SpringBoot中***

```java
/**
 * 配置类，MyServerConfig
 * 通过这个配置类，可以扩展SpringMVC的功能，
 */
@Configuration
public class MyServerConfig {

    /**
     * 注册 Servlet 的 Filter
     * @return
     */
    @Bean
    public FilterRegistrationBean myFilter(){
        FilterRegistrationBean register = new FilterRegistrationBean();
        register.setFilter(new MyFilter());
        register.setUrlPatterns(Arrays.asList("/hello","/myservlet"));
        return register;
    }
}
```

### (3) 注册Listener

***定义Listener***

```java
public class MyListener implements ServletContextListener {
    @Override
    public void contextInitialized(ServletContextEvent sce) {
        System.out.println("web应用启动了");
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        System.out.println("web应用关闭了");
    }
}
```

***使用ServletListenerRegistrationBean注册Listener到SpringBoot中***

```java
/**
 * 配置类，MyServerConfig
 * 通过这个配置类，可以扩展SpringMVC的功能，
 */
@Configuration
public class MyServerConfig {

    /**
     * 注册 Servlet 的 Listener
     * @return
     */
    @Bean
    public ServletListenerRegistrationBean myListener(){
        ServletListenerRegistrationBean register = new ServletListenerRegistrationBean();
        register.setListener(new MyListener());
        return register;
    }
```

## 3、使用jetty或Undertow来代替Tomcat

### (1) 使用jetty

```xml
<dependencies>
        <!-- 引入web模块 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <exclusions>
                <!-- 排除tomcat依赖 -->
                <exclusion>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-starter-tomcat</artifactId>
                </exclusion>
            </exclusions>
        </dependency>

        <!--引入其它Servlet容器-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-jetty</artifactId>
        </dependency>
```

### (2) 使用Undertow

```xml
<dependencies>
    <!-- 引入web模块 -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
        <exclusions>
            <!-- 排除tomcat依赖 -->
            <exclusion>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter-tomcat</artifactId>
            </exclusion>
        </exclusions>
    </dependency>

    <!--引入其它Servlet容器-->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-undertow</artifactId>
    </dependency>
```

