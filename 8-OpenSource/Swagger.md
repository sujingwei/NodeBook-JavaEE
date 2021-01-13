# Swagger

swagger的作用

1. 接口文档的在线自动生成
2. 功能测试

包含主要的项目：

1. Swagger-tools，提供各种与Swagger集成和交互的工具。如模式检验、Swagger1.2文档转2.0文档
2. Swagger-core，用于Java/Scala的Swagger实现。与JAX-RS(Jersey、Resteasy、CXF...)、Servlets和Play框架进行集成。
3. Swagger-Js，用于JavaScritp的Swagger实现
4. Swagger-node-express，Swagger模块，用于Node.js的Express web应用
5. Swagger-ui，一个无依赖的HTML、JS和CSS集合，可以为Swagger兼容API动态生成优雅的文档
6. Swagger-codegen，一个模板驱动引擎

## 1、引入依赖

```xml
<dependency>
   <groupId>io.springfox</groupId>
   <artifactId>springfox-swagger-ui</artifactId>
   <version>2.7.0</version>
</dependency>
<dependency>
   <groupId>io.springfox</groupId>
   <artifactId>springfox-swagger2</artifactId>
   <version>2.7.0</version>
</dependency>
<dependency>
   <groupId>com.fasterxml.jackson.core</groupId>
   <artifactId>jackson-databind</artifactId>
   <version>2.9.8</version>
</dependency>
```

## 2、编写SwaggerConfig

```java
@Configuration
@EnableSwagger2
@EnableWebMvc
// 扫描API Controller包
@ComponentScan(basePackages = {"top.aoae.swagger.controller"})
public class SwaggerConfig {

    @Bean
    public Docket customDocket(){
        return new Docket(DocumentationType.SWAGGER_2)
                .apiInfo(apiInfo());
    }

    private ApiInfo apiInfo() {
        springfox.documentation.service.Contact contact =
            new springfox.documentation.service.Contact("ZED", "http://www.ly058.com", "348149047@qq.com");
        return new ApiInfoBuilder()
                .title("博客项目API接口")
                .description("博客项目API接口的描述")
                .contact(contact)
                .version("1.1.0")
                .build();
    }
}
```

## 3、配置SpringMVC的资源映射

```java
/** spring资源映射 */
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {
    /**
     * 资源映射，配置访问op.springfor-swagger-ui包下的html文件
     * @param registry
     */
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("swagger-ui.html")
            .addResourceLocations("classpath:/META-INF/resources/");
        registry.addResourceHandler("/webjars/**")
            .addResourceLocations("classpath:/META-INF/resources/webjars/");
    }
}
```

配置完后，启动项目，访问：`/swagger-ui.html`

## 4、编写Controller

```java
package top.aoae.swagger.controller;

import io.swagger.annotations.Api;
import io.swagger.annotations.ApiImplicitParam;
import io.swagger.annotations.ApiOperation;
import org.springframework.web.bind.annotation.*;
import top.aoae.swagger.pojo.User;

import javax.websocket.server.PathParam;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Api(value = "用户模块", description = "用户模块的接口信息", tags = {"user-server:UserController"})
@RestController
public class UserController {
    /**
     * 模拟数据
     */
    public static List<User> users = new ArrayList<>();

    static {
        users.add(new User("张三", "123456"));
        users.add(new User("李四", "1234"));
    }

    // 获取用户列表的方法
    @ApiOperation(value = "获取用户列表", notes = "获取所有用户的列表")
    @GetMapping(value = {"users"})
    public Object users() {
        Map<String, Object> map = new HashMap<>();
        map.put("users", users);
        return map;
    }

    @ApiOperation(value = "获取单个用户", notes = "根据ID查询单个用户的信息")
    @ApiImplicitParam(value = "用户的ID", paramType = "path", name = "用户的ID")
    @GetMapping(value = "/user/{id}")
    public User getUserById(@PathVariable("id") int id){
        return users.get(id);
    }

    @ApiOperation(value = "添加用户", notes = "根据传入的用户信息添加用户")
    @ApiImplicitParam(value = "用户对象", paramType = "query")
    @PostMapping("/user")
    public Object add(User user) {
        return users.add(user);
    }

    @ApiOperation(value = "删除用户", notes = "根据传入的用户ID删除用户")
    @ApiImplicitParam(value = "用户的ID", paramType = "path", name = "用户的ID")
    @DeleteMapping("/user/{id}")
    public Object del(@PathVariable("id") int id){
        return users.remove(id);
    }
}
```

- 访问：`/swagger-ui.html`，就可以查看接口信息，并测试接口

