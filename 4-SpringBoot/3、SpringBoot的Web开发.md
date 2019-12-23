## 1、spring boot 对静态资源的映射规则

**参考WebMvcAutoConfigation类**

```java
class WebMvcAutoConfigation{
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
            if (!this.resourceProperties.isAddMappings()) {
                logger.debug("Default resource handling disabled");
            } else {
                Duration cachePeriod = this.resourceProperties.getCache().getPeriod();
                CacheControl cacheControl = this.resourceProperties
                    .getCache()
                    .getCachecontrol()
                    .toHttpCacheControl();
                if (!registry.hasMappingForPattern("/webjars/**")) {              
                  
                this.customizeResourceHandlerRegistration(registry.addResourceHandler(new String[]{"/webjars/**"}).addResourceLocations(new String[]{"classpath:/META-INF/resources/webjars/"}).setCachePeriod(this.getSeconds(cachePeriod)).setCacheControl(cacheControl));
                }

                String staticPathPattern = this.mvcProperties.getStaticPathPattern();
                if (!registry.hasMappingForPattern(staticPathPattern)) {
                    this.customizeResourceHandlerRegistration(registry.addResourceHandler(new String[]{staticPathPattern}).addResourceLocations(WebMvcAutoConfiguration.getResourceLocations(this.resourceProperties.getStaticLocations())).setCachePeriod(this.getSeconds(cachePeriod)).setCacheControl(cacheControl));
                }

            }
        }
	}
```

能过上面代码可以看出：

* 所有webjars/**，都去lasspath:/META-INF/resources/webjars/ 找资源
* 访问当前前项目的任何资源会到以下目录中找

```
访问： http://localhost:8080/css/style.css ，不用加静态资源目录
{"classpath:/META-INF/resources/", "classpath:/resources/", "classpath:/static/", "classpath:/public/"}
```

#### 通过pom.xml方式引入jquery

```xml
<!-- 
 - 所有webjars/**，都去lasspath:/META-INF/resources/webjars/ 找资源 
 - 访问：http://localhost:8080/webjars/jquery/3.3.1/jquery.js
-->
<!--引入jquery-webjar，这样也行-->
<dependency>
    <groupId>org.webjars</groupId>
    <artifactId>jquery</artifactId>
    <version>3.3.1</version>
</dependency>
```

#### 配置静态资源目录

```properties
# 指定静态资源目录
spring.resources.static-locations=classpath:/static,classpath:/resource/hello
```

## 2、Thymelaf 模板引擎

### （1）pom.xml引入

```xml
<!-- 引入模板引擎 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-thymeleaf</artifactId>
</dependency>
```

### （2）thymelaf语法

```java
/**
* 这个类指定了 thymelaf 模板的使用规则
*/
@ConfigurationProperties(
    prefix = "spring.thymeleaf"
)
public class ThymeleafProperties {
    private static final Charset DEFAULT_ENCODING;
    public static final String DEFAULT_PREFIX = "classpath:/templates/";
    public static final String DEFAULT_SUFFIX = ".html";
    private boolean checkTemplate = true;
    private boolean checkTemplateLocation = true;
    private String prefix = "classpath:/templates/";
    private String suffix = ".html";
    private String mode = "HTML";
```

**调用视图**

```java
@Controller
public class HelloController {
    /**
     * 跳转到视图，跳转到 classpath:resources/template/success.html
     * @return
     */
    @RequestMapping("/success")
    public String success(){
        return "success";
    }
```

**相关语法**

###### 导入名称空间

```html
<!--导入thymeleaf名称空间，有代码提示-->
<html lang="en" xmlns:th="http://www.thymeleaf.org">
```

###### 语法

***th:xxxxx***

> 如th:id, th:class, th:style ..... 用于改变前端的属性

```html
<div th:id="${id-name}" th:class="${class-name}" ....
```

***th:text***

> 改变当前元素里面的文本内容，转义特殊字符

```html
<!-- 将div里的文件内容设置为 -->
<div th:text="${hello}"></div>
```

***th:utext***

> 改变当前元素里面的文本内容，不转义特殊字符

```html
<!-- 将div里的文件内容设置为 -->
<div th:utext="${hello}"></div>
```

***th:replace && th:insert***

> 类似于 jsp:include 的用法，包含其它

```html

```

***th:each***

> foreach

```html
<h4 th:each="user:${users}" th:text="${user}"></h4>
<hr>
<h4>
    <span th:each="user:${users}">[(${user})]</span>
</h4>
```

***th:if***

> if

```html

```

***自定义属性 th:attr***

> 用于定义html标签的自定义属性

```html
<button th:attr="data-url=@{/employee/delete/}+${emp.id}" type="button" class="btn btn-sm btn-danger deleteBtn">删除</button>
```

## 3、引入静态资源

```html
<link rel="stylesheet" th:href="@{/webjars/bootstrap/4.1.0/css/bootstrap.css}">
<script th:src="@{/webjars/jquery/3.3.1/jquery.js}"></script>
```

## 4、国际化

### 第一步、编写国际化配置文件，抽取页面需要显示的国际化消息

在resources目录建立i18n目录，并创建以下文件

**默认login.properties**

```properties
login.btn=登录
login.password=密码
login.remember=记住我
login.tip=请登陆
login.username=用户名
```

**默认login_zh_CN.properties**

```properties
login.btn=登录
login.password=密码
login.remember=记住我
login.tip=请登陆
login.username=用户名
```

**默认login_en_US.properties**

```properties
login.btn=Sign In
login.password=Password
login.remember=Remember
login.tip=Please sign in
login.username=Username
```

### 第二步、配置

```properties
# 指定国际化资源文件，不指定，使用类路径下的message.properties
spring.messages.basename=i18n.login
```

### 第三步、在页面中得到国际化的值

```html
<!DOCTYPE html>
<html lang="en" xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <title>Title</title>
    <link rel="stylesheet" th:href="@{/webjars/bootstrap/4.1.0/css/bootstrap.css}">
    <script th:src="@{/webjars/jquery/3.3.1/jquery.js}"></script>
</head>
<body>
<h3>后台登录</h3>
    <!--TODO 使用 #{} 表达式就可以-->
<form>
    <p th:text="#{login.tip}">登录信息....</p>
    <p>
        <input th:placeholder="#{login.username}" type="text" name="username" />
    </p>
    <p>
        <input th:placeholder="#{login.password}" type="password" name="password" />
    </p>
    <p>
        <input type="checkbox" name="remember" /> [[#{login.remember}]]
    </p>
    <p>
        <button th:text="#{login.btn}" class="btn btn-lg btn-primary"></button>
    </p>
</form>
</body>
```

## 5、图际化（带上URL参数的国际化）

**html页面**

```html
<div>
    <!-- 生成 /index.html?language=zh_CN 的URL -->
    <a th:href="@{/index.html(language='zh_CN')}">中文版</a> |
    <!-- 生成 /index.html?language=en_US 的URL -->
    <a th:href="@{/index.html(language='en_US')}">English</a>
</div>
```

**区域解释器**

```java
public class MyLocaleResolver implements LocaleResolver {
    /**
     * 解析区域信息
     * @param request
     * @return
     */
    @Override
    public Locale resolveLocale(HttpServletRequest request) {
        String l = request.getParameter("language");
        Locale locale = null;
        if(l != null && !l.equals("")){
            // 不为空
            String[] split = l.split("_"); // zh_CN / en_US
            locale = new Locale(split[0], split[1]);
        }else{
            // 如果请求参数没有带上 l ，就使用 默认 中文
            locale = new Locale("zh", "CN");
        }
        return locale;
    }

    @Override
    public void setLocale(HttpServletRequest httpServletRequest, HttpServletResponse httpServletResponse, Locale locale) {

    }
}
```

**SpringMVC扩展配置文件MyMvcConfig**

```java
/**
 * 配置类，MyMvcConfig
 * 通过这个配置类，可以扩展SpringMVC的功能，
 */
@Configuration
public class MyMvcConfig implements WebMvcConfigurer {
	
    // ......
	
    /**
     * 配置 LocaleResolver 解析 区域信息
     * @return
     */
    @Bean
    public LocaleResolver localeResolver(){
        return new MyLocaleResolver();
    }

}
```

## 6、登录拦截器

**请求拦截器**

```java
public class LoginHandlerInterceptor implements HandlerInterceptor {
    @Override
    public boolean preHandle(HttpServletRequest request, 
                             HttpServletResponse response, 
                             Object handler) throws Exception 
    {
        Object user = request.getSession().getAttribute("loginUser");
        if(null == user){
            // 未登录
            response.sendRedirect(request.getContextPath() + "/");
            return false;
        }else{
            // 放行请求
            return true;
        }
    }
}
```

**配置拦截到SpringMVC扩展中**

```java
/**
 * 配置类，MyMvcConfig
 * 通过这个配置类，可以扩展SpringMVC的功能，
 */
@Configuration
public class MyMvcConfig implements WebMvcConfigurer {

    // ......

    /**
     * 扩展SpringMVC的拦截器
     * @param registry
     */
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // 配置登录拦截器
        registry.addInterceptor(new LoginHandlerInterceptor())
                .addPathPatterns("/**")  // 要拦截的请求
                .excludePathPatterns("/index.html", "/", "/user/login"); // 不要拦截的请求
    }
```

