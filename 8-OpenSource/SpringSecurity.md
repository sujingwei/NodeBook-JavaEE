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

