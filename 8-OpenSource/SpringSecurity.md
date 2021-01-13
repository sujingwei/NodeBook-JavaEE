# 垃圾笔记

# 一、Spring Security基本使用

Spring Security本质上就是一个过滤器链，通过不同的过滤器，对请求进行拦截。一些常用的过滤器如下：

| 过滤器                               | 描述                                                   |
| ------------------------------------ | ------------------------------------------------------ |
| FilterSecurityInterceptor            | 是一个方法级别的权限过滤器，位于过滤器链的最底部       |
| ExceptionTranslationFilter           | 是一个异常过滤器，用来处理在认证制授权过程中抛出的异常 |
| UsernamePasswordAuthenticationFilter | 对/login的POST请求做拦截，校验表单中的用户名、密码     |

## 1、过滤器是如何加载的呢？

- DelegatingFilterProxy
- FilterChainProxy

DelegatingFilterProxy类中有一个initDelegate方法

```java
protected Filter initDelegate(WebApplicationContext wac) throws ServletException {
    String targetBeanName = this.getTargetBeanName();
    Assert.state(targetBeanName != null, "No target bean name set");
  	// TODO 加截一个叫 filterChainProxy的Bean，就是FilterChainProxy这个类
    Filter delegate = (Filter)wac.getBean(targetBeanName, Filter.class);
    if (this.isTargetFilterLifecycle()) {
            delegate.init(this.getFilterConfig());
    }
    return delegate;
}
```

FilterChainProxy类的的doFilter最后会调用doFilterInternal方法

```java
private void doFilterInternal(
  ServletRequest request, 
  ServletResponse response,
  FilterChain chain) 
  throws IOException, ServletException {
        FirewalledRequest fwRequest = this.firewall
          .getFirewalledRequest((HttpServletRequest)request);
        HttpServletResponse fwResponse = this.firewall
          .getFirewalledResponse((HttpServletResponse)response);
  			// 在这里加载所有的过滤器
        List<Filter> filters = this.getFilters((HttpServletRequest)fwRequest);
        if (filters != null && filters.size() != 0) {
            FilterChainProxy.VirtualFilterChain vfc = new FilterChainProxy
              .VirtualFilterChain(fwRequest, chain, filters);
            vfc.doFilter(fwRequest, fwResponse);
        } else {
            if (logger.isDebugEnabled()) {
                logger.debug(UrlUtils.buildRequestUrl(fwRequest) + (filters == null ? " has no matching filters" : " has an empty filter list"));
            }

            fwRequest.reset();
            chain.doFilter(fwRequest, fwResponse);
        }
    }
```

## 2、两个重要的接口

### 1）UserDetailsService接口讲解

当什么也没有配置的时候，帐号和密码是由Spring Security定义生成的。而在实现项目中帐号和密码是从数据库中查询出来的，所以需要通过实现`UserDetailsService`接口实现数据库查询逻辑。

> 创建类继承UsernamePasswordAuthenticationFilter，重写三个方法
>
> 创建类实现UserDetailService，编写查询数据过程

### 2）PasswordEncoder接口讲解

Spring Security提供的一个对密码加密的接口。

> 用于返回User对象里密码加密的方式
>
> 接口的实现类: <b style="color:deeppink;">BCryptPasswordEncoder</b>

## 3、SpringBoot对Security的自动配置

在web项目中，如何使用security进行**认证**和**授权**？

### 1）认证

#### （1）第一种方式：通过配置文件

**application.properties:**

```properties
spring.security.user.name=aoae
spring.security.user.password=aoae
```

#### （2）第二种方式：通过配置类

```java
@Configuration
public class SecurityConfig extends WebSecurityConfigurerAdapter {
  	/**
  	* 配置系统使用的账号、密码及角色；
  	* 通过多次调用auth可以配置多个
  	*/
    @Override
    protected void configure(AuthenticationManagerBuilder auth) 
      throws Exception 
    {
        // 创建一个密码的加密类
        BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
        auth.inMemoryAuthentication().withUser("lucy")
                // 使用 passwordencoder设置密码
                .password(passwordEncoder.encode("123"))
                .roles("admin");
    }

    /**
     * 系统调用 configure中的 auth下的方法的时候，
     * 都需要在spring容器中有一个PasswordEncoder接口的Bean实例
     * @return
     */
    @Bean(name = "passwordEncoder")
    public PasswordEncoder getPasswordEncoder(){ 
        return new BCryptPasswordEncoder();
    }
}
```

#### （3）第三种方式：自定义编写实现类

前两种方法在实际开发中基本不会使用。实际开发中，是读数据库再进行操作，这个时候就需要实现`UserDetailsService`这个接口。

 ##### 第一步，定义UserDetailsService的实现类，并加入到IOC容器中

```java
@Service(value = "userDetailsService") // bean的名字是固定不变的
public class MyUserDetailsService implements UserDetailsService {
    @Override
    public UserDetails loadUserByUsername(String s) 
      throws UsernameNotFoundException {
				// 得到一个权限的集合
        List<GrantedAuthority> auths = AuthorityUtils
                .commaSeparatedStringToAuthorityList("role");
        /**
         * 第一个参数：用户名
         * 第二个参数：密码
         * 第三个参数：权限的集合，不允许为空
         */
        return new User("mary",
                new BCryptPasswordEncoder().encode("123"),
                auths);
    }
}
```

##### 第二步，定义配置类，把第一步的实现注入并配置

```java
@Configuration
public class SecurityConfigTest extends WebSecurityConfigurerAdapter {

    /**
     * 通过依赖注入的方式，注入第一步实现的UserDetailsService接口的实现类
     */
    @Autowired
    private UserDetailsService userDetailsService;


    @Override
    protected void configure(AuthenticationManagerBuilder auth) 
      throws Exception {
      	// 只要在这里配置一下，就可以了
        auth.userDetailsService(userDetailsService)
          .passwordEncoder(getPasswordEncoder());
    }

    /**
     * 系统调用 configure中的 auth下的方法的时候，
     * 都需要在spring容器中有一个PasswordEncoder接口的Bean实例
     * @return
     */
    @Bean(name = "passwordEncoder")
    public PasswordEncoder getPasswordEncoder(){
        return new BCryptPasswordEncoder();
    }
}
```

重新访问，输入用户名及密码就可以了

## 4、自定义登录页面

自定义登录页面，定义白名单路径，关闭csrf防护

```java
@Configuration
public class SecurityConfigTest extends WebSecurityConfigurerAdapter {

    /**
     * 通过依赖注入的方式，注入UserDetailsService接口的实现类
     */
    @Autowired
    private UserDetailsService userDetailsService;

    /**
     * 用于用户登录认证
     * @param auth
     * @throws Exception
     */
    @Override
    protected void configure(AuthenticationManagerBuilder auth) throws Exception {
        auth.userDetailsService(userDetailsService).passwordEncoder(getPasswordEncoder());
    }

    /**
     * TODO
     * 1\ 自定义登录页面
     * 2\ 白名单路径
     * 3\ 关闭csrf防护
     * @param http
     * @throws Exception
     */
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http.formLogin() // 自定义自己的登录页面
                .loginPage("/login.html")                        // 登录页面
                .loginProcessingUrl("/user/login")               // 登录访问路径，登录逻辑不需要写，由Security完成
                .defaultSuccessUrl("/test/index").permitAll()    // 登录成功后的路径的路径
                .and().authorizeRequests()                       // 配置过滤的路径
                    // 配置要过滤的路径，这些路径不需要认证
                    .antMatchers("/", "/test/hello", "/user/login").permitAll()
                .anyRequest().authenticated()
                // 关闭csrf防护
                .and().csrf().disable();
    }

    /**
     * 系统调用 configure中的 auth下的方法的时候，
     * 都需要在spring容器中有一个PasswordEncoder接口的Bean实例
     * @return
     */
    @Bean(name = "passwordEncoder")
    public PasswordEncoder getPasswordEncoder(){
        return new BCryptPasswordEncoder();
    }
}
```

## 5、基于角色权限访问

### 1)）基于权限控制

```java
@Override
protected void configure(HttpSecurity http) throws Exception {
    http.formLogin() // 自定义自己的登录页面
       // 登录页面
        .loginPage("/login.html")          
        // 登录访问路径，登录逻辑不需要写，由Security完成
        .loginProcessingUrl("/user/login") 
        // 登录成功后的路径的路径
        .defaultSuccessUrl("/test/index").permitAll()
       // 配置过滤的路径
        .and().authorizeRequests()
            // 配置要过滤的路径，这些路径不需要认证
            .antMatchers("/", "/test/hello", "/user/login").permitAll()

                 /** url通过权限限制 */
                // 1、当前登录用户，只有具有admin权限才可以访问这个路径
                // .antMatchers("/test/index").hasAuthority("admins")
                // 2、某个url有多个权限
                .antMatchers("/test/index").hasAnyAuthority("admins", "manager")

                .anyRequest().authenticated()
                // 关闭csrf防护
                .and().csrf().disable();
}
```

### 2）基于角色控制

```java
.antMatchers("/test/index").hasRole("sale")
.antMatchers("/test/index").hasAnyRole("sale", "base")
```

如果没有权限，访问页面，403错误:

> <h1>Whitelabel Error Page</h1><p>This application has no explicit mapping for /error, so you are seeing this as a fallback.</p><div id='created'>Fri Dec 11 16:08:07 CST 2020</div><div>There was an unexpected error (type=Forbidden, status=403).</div><div>Forbidden</div>

## 6、在配置类中配置没有权限访问跳转到的页面

在配置类的configure方法中加入如下代码：

```java
@Override 
protected void configure(HttpSecurity http) 
  throws Exception {
  		//没有权限要跳转的页面
        http.exceptionHandling().accessDeniedPage("/un-auth.html");
  	......
```

# 二、Spring Security进阶

## 1、Security的注解使用

开启注解

```java
// 开启 security 注解
@EnableGlobalMethodSecurity(
    securedEnabled = true,  // 开启@Secured注解
    prePostEnabled = true, // 开启@PreAuthorize和@PostAuthorize注解
  	post
)
```

### 1）@Secured

判断用户是否具有角色，另外需要注意的是这里匹配字符串需要添加前缀:"ROLE_" 

```java
@GetMapping("/update")
@Secured(value = {"ROLE_sale,ROLE_manager"})
public String update() {
    return "hello update";
}
```

访问：当前用户拥有`sale`或`manager`角色的时候就可以访问 

### 2） @PreAuthorize

进入方法前进行权限验证。

```java
@GetMapping("/update") 
@PreAuthorize("hasAnyAuthority('admins')")
public String update() {
    return "hello update";
}
```

### 3）@PostAuthorize

在方法调用后验证，通常用于返回值。那怕没有权限访问这个url，也会先执行这个方法，原后再校验。

```java
@GetMapping("/update")
@PostAuthorize("hasAnyAuthority('admins')")
public String update() {
    return "hello update";
}
```

### 4）@PreFilter

对请请参数进行过滤

```java
@GetMapping("/update")
@PreFilter("filterObject.username='admin1'")
public String update() {
    return "hello update";
}
```

### 5）@PostFilter

对响应数据进行过滤

```java
@GetMapping("/update")
@PostFilter("filterObject.username='admin1'")
public String update() {
    return "hello update";
}
```

## 2、退出/用户注销

```java
@Override
protected void configure(HttpSecurity http) throws Exception {
    // 设置没有权限，退出的地址
    http.logout().logoutUrl("/logout")
        .logoutSuccessUrl("/test/hello").permitAll();

    // 设置没有权限跳转的地址
    http.exceptionHandling().accessDeniedPage("/un-auth.html");
    http.formLogin() // 自定义自己的登录页面
        .loginPage("/login.html")           // 登录页面
        .loginProcessingUrl("/user/login")  // 登录访问路径，登录逻辑不需要写，由Security完成
        .defaultSuccessUrl("/success.html").permitAll()    // 登录成功后的路径的路径
        .and().authorizeRequests()                       // 配置过滤的路径
      // ......
```

## 3、CSRF

防止跨站请求伪造。csrf默认是开启的。可以通过下面代码关闭：

```java
@Override
    protected void configure(HttpSecurity http) throws Exception {
        // 设置没有权限，退出的地址
        		http.logout().logoutUrl("/logout").logoutSuccessUrl("/test/hello").permitAll();

        // 设置没有权限跳转的地址
        http.exceptionHandling().accessDeniedPage("/un-auth.html");
        http.formLogin() // 自定义自己的登录页面

        // TODO 打开下面代码，就关闭csrf
        // .and().csrf().disable();
        ;
```

Html:

```html
<input type="hidden" th:name="${_csrf.parameterName}" th:value="${_csrf.token}">
```

# 三、OAuth2.0

## 1、介绍

**Spring Security OAuth2**是对OAuth2的一种实现，OAuth2.0包含两个服务:授权服务(Authorization Service)、资源服务(Resource Service)

- 授权服务(Authorization Service)
  - AuthorizationEndopint 服务誰请求`/oauth/authorize`
  - TokenEndpoint 服务于访问令牌的请求，默认URL:`/oauth/token`
- 资源服务(Resource Service)

### 1)、分布式认证需求

分布式系统的每个服务都会有认证，制授权的需求，如果每个服务都实现一套认证制授权逻辑会非常冗余，考虑到分布式系统共享性特点，需要由独立的认证服务处理系统认证授权的请求；考虑分布式开放性的特点，不仅对系统内部提供认证，对第三方系统也要提供认证。分布式认证的需求总结如下：

- **统一认证授权**
  - 提供独立的认证服务，统一处理认证授权
  - 无论是不同类型的用户，还是不同类型的客户端，均采用一致的认证、权限、会话机制实现统一认证授权
  - 要实现统一则认证方式必须可扩展，支持各种认证需求，比如：用户名密码、短信验证码、二维码、人脸识别等待认证方式，并可以灵活切换
- **应用接入方式**
  - 应提供扩展和开放能力，提供安全的系统对接机制，并可开放部分API给接入第三方使用，一方应用(内部服务)和三方应用(第三方应用)均采用统一机制接入

### 2)、分布式认证方案

之前在单机应用中使用的认证方式是session、但在分分布式系统中不利于认证，所以推荐使用token的方式认证。它的优点：

1. 适合统一认证的机制，客户端、一方应用、三方应用都遵循一致的认证机制
2. token认证方式对第三方应用接入更适合，因为它更开放，可以使用当前有流行的开放协议OAuth2.0、  JWT等。
3. 一般情况服务端无需存储会话信息，减轻服务端的压力

### 3)、OAuth2.0

OAuth是一个开放授权标准，允许用户授权第三方应用访问他们存储在另外的服务提供者上的信息，而不需要将用户名和密码提供给第三方应用或分享他们数据的所有内容。OAuth2.0是OAuth协议的延续，不在向下兼容。

![OAuth2.0](./img/988462d90e33d26f79f47ff1ccc7ae8cd2c.jpg)

## 2、工程

### 1)、环境介绍

整个工程，包含两个服务：**授权服务**、及**资源服务**。

#### (1)、授权服务Authorization Server

- **AuthorizationEndpoint**服务于认证请求，默认URL: `/oauth/authorize`
- **TokenEndpoint**服务于令牌请求。默认URL:`/oauth/token`

#### (2)、资源服务Resource Server

- <b style="color:blue;">OAuth2AuthenticationProcessingFilter</b>用来对请求给出身份令牌解析最鉴权

应用分别创建`uaa`授权服务(也可以叫认证服务)和`order`订单服务(也就是资源服务)。

### 2)、创建工程

。。。

### 3)、授权工程

#### (1) AuthorizationServerConfigurerAdapter的实现类

##### A.用来配置客户端详情服务(ClientDetailsService)

##### B.用来配置令牌(token)

持久化令牌的几种方式

* InMemoryTokenStore 默认方式，存放在内存中
* JdbcTokenStore 基于JDBC实现版本，令牌保存进关系型数据库中
* JwtTokenStore 全称是JSON Web Token(JWT)，它可以把令牌的数据进行编码，但有一个缺点就是撒销一个已授权的令牌会非常困难，所以它通常用来处理一个生命周期较短的令牌以及撤销刷新新令牌(refresh_token)

##### C.用来配置令牌端点的安全约束(AuthorizationServerSecurityConfigurer)



### 4)、资源工程



## 3、基本操作

### 1)、授权模式：authorization_code

- 同一用户，获取的是一样的，过期后就刷新

#### (1)、请求授权码

GET:`/oauth/authorize?client_id=xiaoming&response_type=code`

因为在`AuthorizationServerConfigurerAdapter`实现类中`public void configure(ClientDetailsServiceConfigurer clients) `方法配置了`clients.inMemory().withClient("xiaoming")...autoApprove(false).redirectUris("http://www.baidu.com")`所以请求成功，会在浏览器中回调上面配置的url，并带上参数:`code=AYLnsD`，它的值就是授权码。

#### (2)、请求获取token

POST:`/oauth/token`

POST请求参数如下：

```
grant_type:authorization_code
code:AYLnsD # 这个就是上一节获取的授权码，每一个授权码，只能获取一次token
```

请求头：

```
下面的值是eGlhb21pbmc6MTIzNDU2是由 base64(client_id + : + secret) 得到的
Authorization: Basic eGlhb21pbmc6MTIzNDU2
```

请求结果

```json
{
    "access_token": "34f6c693-a425-43a7-9e0c-309cbb043781",// 同一用户，获取的是一样的，过期后就刷新
    "token_type": "bearer",
    "refresh_token": "c2cefef8-f4e5-43b1-9c3c-e92ab9f8b47e",
    "expires_in": 43199, // 令牌的有效时间
    "scope": "all"
}
```

### 2)、授权模式：password

#### (1)、AuthenticationManager的实例加入到容器中

`AuthenticationManager`在这实现已经在`WebSecurityConfigurerAdapter`里了

```java
/**
 * 安全配置类
 */
@EnableWebSecurity
public class SpringSecurityConfig extends WebSecurityConfigurerAdapter {
  	// ......
  
  	/**
     * 密码模式需要重写这个方法，并加入到容器中
     * @return
     * @throws Exception
     */
    @Bean
    @Override
    public AuthenticationManager authenticationManagerBean() throws Exception {
        return super.authenticationManagerBean(); // 调用父类，就可以获取
    }
```

#### (2)、在端点配置中配置AuthenticationManager

```java
/**
 * 认证服务器配置类
 */
@Configuration
@EnableAuthorizationServer // 开启认证服务器
public class AuthorizationServerConfig extends
        AuthorizationServerConfigurerAdapter {
		/** 加密 */
    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * 密码模式需要一个权限管理器
     */
    @Autowired
    private AuthenticationManager authenticationManager;

    @Override
    public void configure(ClientDetailsServiceConfigurer clients) throws Exception {
        // ......
    }

    /**
     * 访问配置端点
     * @param endpoints
     * @throws Exception
     */
    @Override
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
        // 密码模式需要它
        endpoints.authenticationManager(authenticationManager);
    }
```

#### (3)、请求获取token

密码模式<u>不需要获取授权码</u>，直接获取用户名及密码：

POST:`/oauth/token`

请求参数如下：

```
grant_type:password
username:admin
password:1234
```

请求头：

```
下面的值是eGlhb21pbmc6MTIzNDU2是由 base64(client_id + : + secret) 得到的
Authorization: Basic eGlhb21pbmc6MTIzNDU2
```

请求结果

```json
{
    "access_token": "b050e531-19e1-45fc-8658-b744f82099aa",
    "token_type": "bearer",
    "refresh_token": "b0e03635-b8f7-4104-88c5-a84dd0266944",
    "expires_in": 43199,
    "scope": "all"
}
```

### 3)、授权模式：implicit

简易模式操作比较简单：

#### (1)、获取token

第一个参数：client_id，就是配置的客户id

第二个参数：response_type的值为token

在浏览器上发请求:`/oauth/authorize?client_id=xiaoming&response_type=token`

跳转到登录页面，输入用户名及密码。

#### (2)、请求结果会封装到回调的URL上

查看URL

```
#access_token=b050e531-19e1-45fc-8658-b744f82099aa&token_type=bearer&expires_in=42725&scope=all
```

### 4)、授权模式：client_credentials

客户端模式，每次请求，都会有一个新的令牌，它没有令牌刷新的概念

#### (1)、直接发请求获取token

POST:`/oauth/token`

请求参数：

```
下面的值是eGlhb21pbmc6MTIzNDU2是由 base64(client_id + : + secret) 得到的
Authorization: Basic eGlhb21pbmc6MTIzNDU2
```

请求结果：

```json
{
    "access_token": "342e5174-152c-404f-9012-2ccacfa11219",
    "token_type": "bearer",
    "expires_in": 43199,
    "scope": "all"
}
```

### 5)、刷新令牌(token)

#### (1)、刷新令牌需要配置UserDetailsService到容器中

```java
@Component("customUserDetailsService")
public class CustomUserDetailsService implements UserDetailsService {
    @Autowired
    private PasswordEncoder passwordEncoder;
    @Override
    public UserDetails loadUserByUsername(String s) throws UsernameNotFoundException {
        // 仿：读数据库操作
        return new User("admin", passwordEncoder.encode("1234"),
                AuthorityUtils.commaSeparatedStringToAuthorityList("product"));
    }
}
```

#### (2)、安全配置类，使用数据库查询到的用户信息

`WebSecurityConfigurerAdapter`的实现类设置`auth.userDetailsService(userDetailsService);`

```java
/**
 * 安全配置类
 */
@EnableWebSecurity
public class SpringSecurityConfig extends WebSecurityConfigurerAdapter {

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    @Qualifier(value = "customUserDetailsService")
    private UserDetailsService userDetailsService;

    @Override
    protected void configure(AuthenticationManagerBuilder auth) throws Exception {
        /** 这是内存保存用户名及密码方式
        auth.inMemoryAuthentication()
                .withUser("admin")
                .password(passwordEncoder.encode("1234"))
                .authorities("product");
         */
        /** 读数据库连接信息，获取用户名、密码及权限信息 */
        auth.userDetailsService(userDetailsService);
    }

    /**
     * 密码模式需要重写这个方法，并加入到容器中
     * @return
     * @throws Exception
     */
    @Bean
    @Override
    public AuthenticationManager authenticationManagerBean() throws Exception {
        return super.authenticationManagerBean(); // 必需
    }
}
```

#### (3)、在认证端点里配置UserDetailService

```java
/**
 * 认证服务器配置类
 */
@Configuration
@EnableAuthorizationServer // 开启认证服务器
public class AuthorizationServerConfig extends
        AuthorizationServerConfigurerAdapter {

    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * 密码模式需要一个权限管理器
     */
    @Autowired
    private AuthenticationManager authenticationManager;
  
    /**
     * userDetailsService
     */
    @Autowired
    @Qualifier(value = "customUserDetailsService") // 这是定义义的名称
    private UserDetailsService userDetailsService;

    /**
     * 访问配置端点
     * @param endpoints
     * @throws Exception
     */
    @Override
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
        // 密码模式需要它
        endpoints.authenticationManager(authenticationManager);

        // 刷新token需要配置userDetailsService
        endpoints.userDetailsService(userDetailsService);
    }
  	// ......
}

```

## 4、令牌存储策略

默认情况下，令牌randomUUID产生32位随机数来进行填充，而产生的令牌是默认的存储是存储在内存中

- (默认)内存存储采用的是TokenStore接口的默认实现类`InKemoryTokenStore`，开发时方便调试，适用单机版。
- `RedisTokenStore`将令牌信息存储到Redis中
- `JdbcTokenStore`基于JDBC将令牌存储到关系型数据库中
- `JwtTokenStore`将用户信息直接编码到令牌中，这样后端可以不用存储它，前端拿到令牌可以直接解析出用户信息。

### 1)、Redis管理令牌

#### (1)、引入Redis依赖

```xml
 <!-- redis -->
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

- 在application.yml文件上不需要配置redis，使用它的默认配置就可以了

#### (2)、创建TokenStore接口的实现类

```java
/**
 * 通过Redis管理令牌
 */
@Configuration
public class TokenStoreConfig {
    /**
     * 注入redis连接工厂
     */
    @Autowired
    private RedisConnectionFactory redisConnectionFactory;
		
  	/** TODO 返回这个Bean */
    @Bean(name = "tokenStore")
    public TokenStore tokenStore(){
        // 如果使用Redis的话，需要使用RedisConnectionFactory来创建这个类
        RedisTokenStore tokenStore = new RedisTokenStore(redisConnectionFactory);
        return tokenStore;
    }
}
```

#### (3)、配置端点使用TokenStore

```java
@Configuration
@EnableAuthorizationServer // 开启认证服务器
public class AuthorizationServerConfig extends
        AuthorizationServerConfigurerAdapter {

    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * 密码模式需要一个权限管理器
     */
    @Autowired
    private AuthenticationManager authenticationManager;

    /**
     * userDetailsService
     */
    @Autowired
    @Qualifier(value = "customUserDetailsService")
    private UserDetailsService userDetailsService;
		
  	/** 引入token */
    @Autowired
    private TokenStore tokenStore;

    /**
     * 访问配置端点
     * @param endpoints
     * @throws Exception
     */
    @Override
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
        // 密码模式需要它
        endpoints.authenticationManager(authenticationManager);

        // 刷新token需要配置userDetailsService
        endpoints.userDetailsService(userDetailsService);

        // TODO 配置使用redis来管理token
        endpoints.tokenStore(tokenStore);
    }
}
```

#### (4)、测试使用

参考基本操作，密码授权模式，发送POST请求，获取token，后查看Redis如下：

```
127.0.0.1:6379> keys *
1) "auth_to_access:bb735ba4114d38c49f7bc7f27e714a2f"
2) "access_to_refresh:e3076079-56b7-4371-91ed-cc0b5be19fc8"
3) "auth:e3076079-56b7-4371-91ed-cc0b5be19fc8"
4) "refresh_auth:e1473939-37a4-492f-b1a9-84cb614e4906"
5) "uname_to_access:xiaoming:admin"
6) "refresh:e1473939-37a4-492f-b1a9-84cb614e4906"
7) "access:e3076079-56b7-4371-91ed-cc0b5be19fc8"
8) "refresh_to_access:e1473939-37a4-492f-b1a9-84cb614e4906"
9) "client_id_to_access:xiaoming"
```

不管是请求令牌、刷新令牌、或校验令牌，都不需要我们手动对令牌信息进行维护，交给spring security来维护令牌信息。

### 2)、JDBC管理令牌

Spring官方提供了存储OAuth2相关的数据库表结构，下载地址：

https://github.com/spring-projects/spring-security-oauth/blob/master/spring-security-oauth2/src/test/resources/schema.sql

#### (1)、引入依赖

```xml
<!-- spring jdbc -->
<dependency>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter-jdbc</artifactId>
</dependency>
<!--druid连接池 -->
<dependency>
   <groupId>com.alibaba</groupId>
   <artifactId>druid</artifactId>
</dependency>
<!-- mysql -->
<dependency>
   <groupId>mysql</groupId>
   <artifactId>mysql-connector-java</artifactId>
</dependency>
```

配置数据库源：

```yaml
spring:
  datasource:
    driver-class-name: com.mysql.cj.jdbc.Driver
    username: root
    password: root
    url: jdbc:mysql://localhost:3306/test_security?useUnicode=true&characterEncoding=UTF8&useSSL=true
    type: com.alibaba.druid.pool.DruidDataSource
```

#### (2)、创建TokenStore接口的实现类

不需要创建了，在原来的上面改

```java
/**
 * 通过Jdbc管理令牌
 */
@Configuration
public class TokenStoreConfig {
    /**
     * 注入redis连接工厂
     */
    @Autowired
    private RedisConnectionFactory redisConnectionFactory;
		/** 数据源 */
    @Autowired
    private DataSource dataSource;

    @Bean(name = "tokenStore")
    public TokenStore tokenStore() {
        TokenStore tokenStore = null;
        // 如果使用Redis的话，需要使用RedisConnectionFactory来创建这个类
        // tokenStore = new RedisTokenStore(redisConnectionFactory);

        // 配置Jdbc来保存和操作token
        tokenStore = new JdbcTokenStore(dataSource);
        return tokenStore;
    }
}
```

#### (3)、配置端点使用TokenStore

这一步不需要配置了。所用之前的配置就可以

#### (4)、测试使用

参考基本操作，密码授权模式，发送POST请求，获取token，后查看mysql如下：

```mysql
mysql> select token_id,authentication_id,user_name,client_id,refresh_token from oauth_access_token \G;
*************************** 1. row ***************************
         token_id: f1bd8df10f3c00d11a44a8ea55c2b525
authentication_id: bb735ba4114d38c49f7bc7f27e714a2f
        user_name: admin
        client_id: xiaoming
    refresh_token: d44d5f59186a83a44cb5a0ba62e40ebd
1 row in set (0.00 sec)
```

### 3)、Jdbc管理授权码

只有使用授权码模式`authorization_code`才会有授权码。默认的情况下，授权码是放在内存中的，原因是`JdbcAuthorizationCodeService`没有添加到容器中，开启后，会将授权码放到`auth_code`表，授权后就会删除它。

#### (1)、创建AuthorizationCodeServices接口的Bean实现

```java
@Configuration
public class SpringSecurityBean {

    @Autowired
    private DataSource dataSource;
  
    /**
     * 创建AuthorizationCodeServices的Bean实现
     * @return
     */
    @Bean
    public AuthorizationCodeServices jdbcAuthorizationCodeServices(){
        return new JdbcAuthorizationCodeServices(dataSource);
    }
  	// ......
}
```

#### (2)、把它配置到端点上

```java
/**
 * 认证服务器配置类
 */
@Configuration
@EnableAuthorizationServer // 开启认证服务器
public class AuthorizationServerConfig extends
        AuthorizationServerConfigurerAdapter {

    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * 密码模式需要一个权限管理器
     */
    @Autowired
    private AuthenticationManager authenticationManager;

    /**
     * userDetailsService
     */
    @Autowired
    @Qualifier(value = "customUserDetailsService")
    private UserDetailsService userDetailsService;

    /**
     * 保存token的方式 内存(默认)、redis、jdbc、jwt
     */
    @Autowired
    private TokenStore tokenStore;

    /**
     * 只有使用authorization_code模式才会创建【授权码】
     * 通过AuthorizationCodeServices，把授权码保存到jdbc的oauth_code表中
     * 使用完授权码后，会删除行记录
     */
    @Autowired
    private AuthorizationCodeServices jdbcAuthorizationCodeServices;

    /**
     * 访问配置端点
     * @param endpoints
     * @throws Exception
     */
    @Override
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
        // 密码模式需要它
        endpoints.authenticationManager(authenticationManager);

        // 刷新token需要配置userDetailsService
        endpoints.userDetailsService(userDetailsService);

        // 配置使用redis来管理token
        endpoints.tokenStore(tokenStore);

        // 配置授权码管理策略，把授权码保存到jdbc中
        endpoints.authorizationCodeServices(jdbcAuthorizationCodeServices);
    }
  	// ......
}
```

#### (3)、测试

只有使用授权码模式才会有授权码：

POST:`/oauth/authorize?client_id=xiaoming&response_type=code`获取授权码，输入用户登录信息后查看数据库的OAuth_code表：

```mysql
mysql> select code from oauth_code;
+--------+
| code   |
+--------+
| 4YD0QE |
+--------+
```

可以看到保存了授权码信息了。<u>通过授权码去换取token后，就会删除当前记录</u>：

```mysql
mysql> select code from oauth_code;
Empty set (0.00 sec)
```

### 4)、使用JDBC保存客户端client的信息

#### (1)、在oauth_client_details表上创建一个客户端(client)的信息

```mysql
mysql> select * from oauth_client_details \G;
*************************** 1. row ***************************
              client_id: product
           resource_ids: product-server
          client_secret: $2a$10$jTl585C3Yimq6Q5LaopwCeQyYe.HhKsOupZWueqXY0jCS87waWs4y
                  scope: all,PRODUCT_API
 authorized_grant_types: authorization_code,password,implicit,client_credentials,refresh_token
web_server_redirect_uri: http://www.baidu.com
            authorities: NULL
  access_token_validity: 1000        # 这里设置token的过期时间
 refresh_token_validity: NULL
 additional_information: NULL
            autoapprove: false
1 row in set (0.00 sec)
```

#### (2)、添加JdbcClientDetailsService的实例到容器中

```java
@Configuration
public class SpringSecurityBean {

    @Autowired
    private DataSource dataSource;

    /**
     * 通过Jdbc管理客户端信息
     * @return
     */
    @Bean
    public JdbcClientDetailsService jdbcClientDetailsService(){
        return new JdbcClientDetailsService(dataSource);
    }
  	// .......
}
```

#### (3)、修改“认证服务器配置类”中的客户端信息信息

客户端信息信息从原来的基于内存的配置改为基于jdbc的配置：

```java
/**
 * 认证服务器配置类
 */
@Configuration
@EnableAuthorizationServer // 开启认证服务器
public class AuthorizationServerConfig extends
        AuthorizationServerConfigurerAdapter {

    /**
     * 通过Jdbc管理客户端信息
     * 客户端的数据会保存到oauth_client_details表上
     */
    @Autowired
    private JdbcClientDetailsService jdbcClientDetailsService;

    @Override
    public void configure(ClientDetailsServiceConfigurer clients) throws Exception {
        /** TODO 使用内存对客户端信息进行管理
        // 基于内存的管理不再使用
        clients.inMemory().withClient("xiaoming")
                .secret(passwordEncoder.encode("123456"))
                // 资源ID，针对微服务，就是服务的名称, 可以限制当前用户访问的服务
                .resourceIds("product-server")
                // 配置授权模式，可以配置多种
                .authorizedGrantTypes("authorization_code", "password", "implicit", "client_credentials", "refresh_token")
                // 可以访问资源的标识，这个标识可以是任意字符
                .scopes("all")
                // false: 跳转到一个制授权页面；true：不需要手动授权，直接响应一个授权码
                .autoApprove(false)
                // TODO 这是客户端回调地址，请求成功，并且上面配置为false，在下面的URL上带上 ?code=AYLnsD的参数回调客户端浏览器
                // TODO 请求的URL地址为：oauth/authorize?client_id=xiaoming&response_type=code
                // 需要带上client_id及response_type两个参数
                .redirectUris("http://www.baidu.com")
                // 默认令牌的使用时间为12小时，可以通过下面配置令牌的使用时间
                .accessTokenValiditySeconds(60*60*2)
                // TODO 如果有多个客户端
                // .and().withClient("").resourceIds("").authorities("").authorizedGrantTypes().scopes("").autoApprove(false).redirectUris("")
        ;
        */

        /** TODO 通过Jdbc的方式管理客户端信息 */
        clients.withClientDetails(jdbcClientDetailsService);
    }
  	// .......
```

- 对比一下内存的配置，可以看到与表字段相同

#### (4)、测试

参考基本操作，密码授权模式，发送POST请求，获取token：

```json
{
    "access_token": "5b609d87-c1d1-4304-bbeb-be38016e4e91",
    "token_type": "bearer",
    "refresh_token": "2e744e97-0b3f-4c7e-ae2d-a6f13b4e5f1e",
    "expires_in": 999,    // token的过期时间少于数据库里配置的时间
    "scope": "all PRODUCT_API"
}
```

 token的过期时间少于数据库里配置的时间，可见使用了数据库保存的客户端信息。

### 5)、令牌安全策略

- `/oauth/authorize`： 申请授权码code涉及的类`AuthorizationEndpoint`
- `/oauth/token`：获取令牌token，涉及的类`TokenEndpoint`

- `/oauth/check_token`：检查令牌是否有效，涉及的类`CheckTokenEndpoint`

- `/oauth/confirm_access`，用户确认授权提交，涉及的类`WhitelabelApprovalEndpoint`

- `/oauth/error`：授权服务错误信息，涉及的类`WhitelabelErrorEndpoint`
- `/oauth/token_key`：提供公有的密匙端点，使用JWT令牌时会使用，涉及的类`TokenKeyEndpoint`



<sapn style="color:blue;">默认情况下<b>/oauth/check_token</b>和<b>/oauth/token_key</b>端点默认是<b>denyALl()</b>不允许访问。</span>



> Spring Security 允许我们使用 Spring EL 表达式，来进行用户权限的控制，如果对应的表达式结果返回true，则表示拥有对应的权限，反之则无。
>
> Spring Security 可用表达式对象的基类是 SecurityExpressionRoot 参见此类即可。
>

**注意****:** **表达式以下面为准****,** **黄色标注的** **is** **在使用时是要加上的**

|表达式|描述|
|---|---|
|permitAll() |总是返回true，表示允许所有访问（认证不认证都可访问 URL或方法）|
|denyAll()| 总是返回false，表示拒绝所有访问（永远访问不到指定的 URL或方法）|
|isAnonymous()|  当前用户是一个匿名用户（未登录用户）允许访问，返回true |
|isRememberMe()| 当前用户是通过Remember-Me自动登录的允许访问，返回true |
|isAuthenticated()  |当前用户是已经登录认证成功的允许访问（包含了rememberMe自动登录的），返回true|
|isFullyAuthenticated()| 如果当前用户既不是一个匿名用户，同时也不是通过Remember-Me自动登录的，则允许访问（可以理解为通过页面输入帐户信息认证的）。|
| hasRole(String role)|当前用户拥有指定角色权限的允许访问，返回true。注意: 指定的角色名(如： ADMIN ) SpringSecurity 底层会在前面拼接 ROLE_ 字符串，所以在UserDetailsService实现类，数据库返回的角色名要有ROLE_ADMIN|
|hasAnyRole([role1, role2])| 多个角色以逗号分隔的字符串。如果当前用户拥有指定角色中的任意一个则允许访问，返回true。|
|hasAuthority(String authority) |当前用户拥有指定权限标识的允许访问，返回true。注意：和 hasRole。区别是， hasAuthority 不会在前面拼接 ROLE_ 字符串。|
|hasAnyAuthority([auth1,auth2]) |多个权限标识是以逗号分隔的字符串。如果当前用户拥有指定权限标识中的任意一个则允许访问，返回true|
|hasIpAddress("192.168.1.1/29")| 限制指定IP或指定范围内的IP才可以访问|

#### (1)、打开访问站点权限配置

```java
package top.aoae.server.oauth2;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.config.annotation.configurers.ClientDetailsServiceConfigurer;
import org.springframework.security.oauth2.config.annotation.web.configuration.AuthorizationServerConfigurerAdapter;
import org.springframework.security.oauth2.config.annotation.web.configuration.EnableAuthorizationServer;
import org.springframework.security.oauth2.config.annotation.web.configurers.AuthorizationServerEndpointsConfigurer;
import org.springframework.security.oauth2.config.annotation.web.configurers.AuthorizationServerSecurityConfigurer;
import org.springframework.security.oauth2.provider.client.JdbcClientDetailsService;
import org.springframework.security.oauth2.provider.code.AuthorizationCodeServices;
import org.springframework.security.oauth2.provider.token.TokenStore;

/**
 * 认证服务器配置类
 */
@Configuration
@EnableAuthorizationServer // 开启认证服务器
public class AuthorizationServerConfig extends
        AuthorizationServerConfigurerAdapter {

    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * 密码模式需要一个权限管理器
     */
    @Autowired
    private AuthenticationManager authenticationManager;

    /**
     * userDetailsService
     */
    @Autowired
    @Qualifier(value = "customUserDetailsService")
    private UserDetailsService userDetailsService;

    /**
     * 保存token的方式 内存(默认)、redis、jdbc、jwt
     */
    @Autowired
    private TokenStore tokenStore;

    /**
     * 只有使用authorization_code模式才会创建【授权码】
     * 通过AuthorizationCodeServices，把授权码保存到jdbc的oauth_code表中
     * 使用完授权码后，会删除行记录
     */
    @Autowired
    private AuthorizationCodeServices jdbcAuthorizationCodeServices;

    /**
     * 通过Jdbc管理客户端信息
     * 客户端的数据会保存到oauth_client_details表上
     */
    @Autowired
    private JdbcClientDetailsService jdbcClientDetailsService;

    @Override
    public void configure(ClientDetailsServiceConfigurer clients) throws Exception {
        /** 通过Jdbc的方式管理客户端信息 */
        clients.withClientDetails(jdbcClientDetailsService);
    }

    /**
     * 访问配置端点
     * @param endpoints
     * @throws Exception
     */
    @Override
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
        // 密码模式需要它
        endpoints.authenticationManager(authenticationManager);

        // 刷新token需要配置userDetailsService
        endpoints.userDetailsService(userDetailsService);

        // 配置使用redis来管理token
        endpoints.tokenStore(tokenStore);

        // 配置授权码管理策略，把授权码保存到jdbc中
        endpoints.authorizationCodeServices(jdbcAuthorizationCodeServices);
    }

    /**
     * TODO，在这里打开,令牌端点的安全配置
     * @param security
     * @throws Exception
     */
    @Override
    public void configure(AuthorizationServerSecurityConfigurer security) throws Exception {
        // 配置所有人都可以访问，/oauth/token_key，默认不允许访问
        security.tokenKeyAccess("permitAll()");
        // 配置认证后可以访问，/oauth/check_token，默认不允许访问
        security.checkTokenAccess("isAuthenticated()");
    }
}
```

就下面两行代码：

```java
// 配置所有人都可以访问，/oauth/token_key，默认不允许访问
security.tokenKeyAccess("permitAll()");
// 配置认证后可以访问，/oauth/check_token，默认不允许访问
security.checkTokenAccess("isAuthenticated()");
```

#### (2)、测试

POST:`/oauth/check_token`

请求头：

```
下面的值是eGlhb21pbmc6MTIzNDU2是由 base64(client_id + : + secret) 得到的
Authorization: Basic eGlhb21pbmc6MTIzNDU2
```

请求参数：

```
token:8b63d2d2-27d8-4b73-8a9c-7eccdcf024f1
```

请求结果：

```json
{
    "aud": [
        "product-server"
    ],
    "user_name": "admin",
    "scope": [
        "all",
        "PRODUCT_API"
    ],
    "active": true,
    "exp": 1610455381,
    "authorities": [
        "product"
    ],
    "client_id": "product"
}
```

