# Apache Shiro

## 一、简介

### 1、Shiro的核心架构

`shiro`是`apache`一个开源框架，它将软件系统的安全认证相关的功能抽出，实现用户身份认证，权限限制授权，加密、会话管理等功能。组成一个能用的安全认证框架。

### 2、Shiro的核心架构图

![Shiro的核心架构图](https://shiro.apache.org/assets/images/ShiroArchitecture.png)

- Secourity Manager 安全管理器，得到安全管理器，就可以执行以下操作
- Authenticator 用户认证
- Authorizer 授权
- Session Manager 用户会话管理
- Session DAO 用于管理用户权限数据
- Cache Manger 用户缓存用户权限数据
- Pluggable Realms 获取授权数据，完成认证
- Cryptography 加密组件（MD5、HASH）

### 3、shiro中的认证

身份认证，就是判断一个用户是否为合法用户的处理过程，shiro中认证的关键对应有：

- <span style="color:green;">Subject：主体</span>，访问系统的用户，主体可以是用户、应用程序
- <span style="color:green;">Principal：身份信息</span>，是主体进行身份认证的标识，具有`唯一性`，如用户名、手机号、邮箱地址等，一个主体可以有多个身份，但必须有一个主身份(Primary Principal)
- <span style="color:green;">Credential：凭证信息</span>，是只有主体自己知道的安全信息，如：密码

```flow
start=>start: Subject主体
end1=>end: 进入系统
end2=>end: 认证失败
token1=>condition: token
ce=>condition: 是否合法

start->token1
token1(yes)->ce
ce(yes)->end1
ce(no)->end2
```

## 二、Shiro的Hello World

### 1、引入依赖

```xml
<dependency>
    <groupId>org.apache.shiro</groupId>
    <artifactId>shiro-core</artifactId>
    <version>1.5.3</version>
</dependency>
```

### 2、shiro的配置文件

shiro.ini，ini配置文件是用来学习shiro过程中书写系统中相关权限权限数据，整合后不需要使用这一份ini文件

```ini
[users]
# 配置用户信息,key表示用户名，value表示密码
xiaochen=123
zhangsan=123456
lisi=789
```

### 3、用户认证(登录)

```java
public class TestAuthenticator {
    public static void main(String[] args) {
        // 1. 创建安全管理器
        DefaultSecurityManager securityManager = new DefaultSecurityManager();
        // 2. 给安全管理器设置realm，realm使用shiro配置文件的方式读取数据
        securityManager.setRealm(new IniRealm("classpath:shiro.ini"));
        // 3. 给全局安全工具类SecurityUtils，设置安全管理器
        SecurityUtils.setSecurityManager(securityManager);
        // 4. 获取主体对对象
        Subject subject = SecurityUtils.getSubject();
        // 用户认证，需要一个token令牌
        try {
            System.out.println("认证状态：" + subject.isAuthenticated());
            subject.login(new UsernamePasswordToken("xiaochen", "12311"));
            // TODO 登录成功，不抛出异常，并且查看登录状态为 true
            System.out.println("认证状态：" + subject.isAuthenticated());
        } catch (UnknownAccountException e) {
            // 用户名不存在
            e.printStackTrace();
        } catch (IncorrectCredentialsException e) {
          // 密码错误
            e.printStackTrace();
        }
    }
}
```

## 三、基本认证

### 1、自定义Realm的实现

- 自定义Realm的实现，将认证/授权数据的来源转为数据库的实现

```java
/**
 * 自定义Realm的实现，将认证/授权数据的来源转为数据库的实现
 */
public class CustomerRealm extends AuthorizingRealm {
    /**
     * 认证
     * @param token
     * @return
     * @throws AuthenticationException
     */
    @Override
    protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken token) throws AuthenticationException {
        // 可以通过token参数获取用户名
        String username = (String) token.getPrincipal();
        if ("xiaochen".equalsIgnoreCase(username)) {
            /**
             * 查询数据库操作
             * 第一个参数，数据库中的用户名
             * 第二个参数，数据库中的密码
             * 第三个参数，realm的名称，可以使用父类方法得
             */
            SimpleAuthenticationInfo simpleAuthenticationInfo = 
              new SimpleAuthenticationInfo("xiaochen", "123", this.getName());
            return simpleAuthenticationInfo;
        }
        return null;
    }

    /**
     * 授权
     * @param principals
     * @return
     */
    @Override
    protected AuthorizationInfo doGetAuthorizationInfo(PrincipalCollection principals) {
        return null;
    }
}
```

测试类:

```java
@Test
public void testAuthenticator () {
    DefaultSecurityManager securityManager = new DefaultSecurityManager();
    Subject subject = SecurityUtils.getSubject();
    try {
            subject.login(new UsernamePasswordToken("xiaochen", "123"));
    } catch (UnknownAccountException e) {
        // 用户名不存在
        e.printStackTrace();
    } catch (IncorrectCredentialsException e) {
        // 密码错误
        e.printStackTrace();
    }
}
```

### 2、MD5+Salt 加密

#### 1）MD5 + Salt 加密方式

```java
Test
public void testMd5Salt() {
    // 普通md5
    Md5Hash md5Hash = new Md5Hash("123");
    System.out.println(md5Hash.toHex());

    // md5 + salt 加salt的意思就是给密钥加上私钥
    Md5Hash md5Hash1 = new Md5Hash("123" , "X0*7ps");
    System.out.println(md5Hash1.toHex());

    // md5 + salt + hash散列
    Md5Hash md5Hash2 = new Md5Hash("123" , "X0*7ps", 1024);
    System.out.println(md5Hash2.toHex());
}
```

#### 2）Shiro普通MD5加密认证

测试类的写法:

```java
@Test
public void testCustomerMd5(){
        DefaultSecurityManager securityManager = new DefaultSecurityManager();
        CustomerMd5Realm realm = new CustomerMd5Realm();

        // 创建散列加密方式
        HashedCredentialsMatcher hashedCredentialsMatcher = 
          new HashedCredentialsMatcher();
        // 当前散列加密方式为md5
        hashedCredentialsMatcher.setHashAlgorithmName("md5");
        // 设置 realm 使用散列 加密方式
        realm.setCredentialsMatcher(hashedCredentialsMatcher);

        securityManager.setRealm(realm);
        SecurityUtils.setSecurityManager(securityManager);
        Subject subject = SecurityUtils.getSubject();
        try {
            subject.login(new UsernamePasswordToken("xiaochen", "123"));
            System.out.println("登录成功");
        } catch (UnknownAccountException e) {
            // 用户名不存在
            e.printStackTrace();
        } catch (IncorrectCredentialsException e) {
            // 密码错误
            e.printStackTrace();
        }
}
```

自定义Realm:

```java
@Override
protected AuthenticationInfo doGetAuthenticationInfo
  (AuthenticationToken token) throws AuthenticationException {
        String username =(String) token.getPrincipal();
        if ("xiaochen".equals(username)) {
            /**
             * 参数一：数据库中的用户名
             * 参数二：md5 之后的密码
             * 参数三：realm的名称，可以使用父类方法得
             */
            return new SimpleAuthenticationInfo("xiaochen",
                    "202cb962ac59075b964b07152d234b70",
                    this.getName());
        }
        return null;
}
```

#### 3）Shiro、MD5+Salt加密认证

测试类的写法和第二小节写法一样

```java
@Override
protected AuthenticationInfo doGetAuthenticationInfo
  (AuthenticationToken token) throws AuthenticationException {
        String username =(String) token.getPrincipal();
        if ("xiaochen".equals(username)) {
            /**
             * 参数一：数据库中的用户名
             * 参数二：md5+salt之后的密码
             * 参数三：读数据库得到的，随机salt的值 （多了这个参数）
             * 参数四：realm的名称，可以使用父类方法得
             */
            return new SimpleAuthenticationInfo("xiaochen",
                    "8a83592a02263bfe6752b2b5b03a4799",
                    // 读数据库得到的Salt值
                    ByteSource.Util.bytes("X0*7ps"),
                    this.getName());
        }
        return null;
}
```

#### 4）Shiro、MD5+Salt+hash散列

自定义Realm和第三小节写法一样

测试类写法:

```JAVA
@Test
public void testCustomerMd5(){
        DefaultSecurityManager securityManager = 
          new DefaultSecurityManager();
        CustomerMd5Realm realm = new CustomerMd5Realm();

        // 创建散列加密方式
        HashedCredentialsMatcher hashedCredentialsMatcher = new HashedCredentialsMatcher();
        // 当前散列加密方式为md5
        hashedCredentialsMatcher.setHashAlgorithmName("md5");
        // TODO 设置散列次数，多了这一步
        hashedCredentialsMatcher.setHashIterations(1024);
        // 设置 realm 使用散列 加密方式
        realm.setCredentialsMatcher(hashedCredentialsMatcher);

        securityManager.setRealm(realm);
        SecurityUtils.setSecurityManager(securityManager);
        Subject subject = SecurityUtils.getSubject();
        try {
            subject.login(new UsernamePasswordToken("xiaochen", "123"));
            System.out.println("登录成功");
        } catch (UnknownAccountException e) {
            // 用户名不存在
            e.printStackTrace();
        } catch (IncorrectCredentialsException e) {
            // 密码错误
            e.printStackTrace();
        }
}
```

## 四、基本授权

主体进行身份认证后需要分配权限方可访问系统的资源，对于某些资源没有权限是无法访问的。

- <span style="color:green;">Who：主体(Subject)</span>，主体需要访问系统中的资源
- <span style="color:green;">What：资源(Resource)</span>，如系统菜单、页面、按钮、系统商品信息等。资源包括`类型`和`资源实例`
- <span style="color:green;">How：权限(Permission)</span>，规定了主体对资源的操作许可，权限离开资源没有意义，如用户查询权限、添加权限……等

```flow
start=>start: Subject主体
main=>operation: 进入系统
end1=>end: 认证失败
token1=>condition: token
ce=>condition: 是否合法
per=>condition: 是否具有权限
end2=>end: 没有权限
dev=>operation: 用户管理,商品管理,类别管理

start->token1
token1(yes)->ce
ce(yes)->main
ce(no)->end1
main->per
per(no)->end2
per(yes)->dev


```

授权方式

- 基本角色访问控制

  - RBAC(Role-Based Access Control)是以角色为中心进行访问控制

  ```java
  if(subject.hasRole("admin")){
    // 操作什么资源
  }
  ```

- 基于资源的访问控制

  - RBAC(Resource-Based Access Control)以资源为中心访问控制

  ```java
  if (subject.isPermission("user:find:*")) {
    // 判断用户是否有权限操作某些资源
  }
  ```


### 1、Shiro中授权编程实现方式

CustomerMd5Realm，Realm类完整：

```java
package top.aoae.shiro_demo.shiro.realm;

import org.apache.shiro.authc.AuthenticationException;
import org.apache.shiro.authc.AuthenticationInfo;
import org.apache.shiro.authc.AuthenticationToken;
import org.apache.shiro.authc.SimpleAuthenticationInfo;
import org.apache.shiro.authc.credential.CredentialsMatcher;
import org.apache.shiro.authz.AuthorizationInfo;
import org.apache.shiro.authz.SimpleAuthorizationInfo;
import org.apache.shiro.realm.AuthorizingRealm;
import org.apache.shiro.subject.PrincipalCollection;
import org.apache.shiro.util.ByteSource;

public class CustomerMd5Realm extends AuthorizingRealm {
    @Override
    protected AuthorizationInfo doGetAuthorizationInfo(PrincipalCollection principals) {
        String primaryPrincipal = (String) principals.getPrimaryPrincipal();
        // System.out.println("身份信息: " + primaryPrincipal);

        SimpleAuthorizationInfo simpleAuthorizationInfo = 
          new SimpleAuthorizationInfo();
        // 将数据据查询角色信息赋值给权限
        simpleAuthorizationInfo.addRole("admin");
        simpleAuthorizationInfo.addRole("user");

        // 把数据库中查询权限信息赋值给对象
        simpleAuthorizationInfo.addStringPermission("user:*:01");
        simpleAuthorizationInfo.addStringPermission("product:create");

        return simpleAuthorizationInfo;
    }

    @Override
    protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken token) throws AuthenticationException {
        String username =(String) token.getPrincipal();
        if ("xiaochen".equals(username)) {
            /**
             * 参数一：数据库中的用户名
             * 参数二：md5+salt之后的密码
             * 参数三：读数据库得到的，随机salt的值
             * 参数四：realm的名称，可以使用父类方法得
             */
            return new SimpleAuthenticationInfo("xiaochen",
                    "e4f9bf3e0c58f045e62c23c533fcf633",
                    ByteSource.Util.bytes("X0*7ps"),
                    this.getName());
        }
        return null;
    }
}

```

主体操作：

```java
@Test
    public void testCustomerMd5Permission(){
        DefaultSecurityManager securityManager = new DefaultSecurityManager();
        CustomerMd5Realm realm = new CustomerMd5Realm();

        // 创建散列加密方式
        HashedCredentialsMatcher hashedCredentialsMatcher = 
          new HashedCredentialsMatcher();
        // 当前散列加密方式为md5
        hashedCredentialsMatcher.setHashAlgorithmName("md5");
        // 设置散列次数
        hashedCredentialsMatcher.setHashIterations(1024);
        // 设置 realm 使用散列 加密方式
        realm.setCredentialsMatcher(hashedCredentialsMatcher);

        securityManager.setRealm(realm);
        SecurityUtils.setSecurityManager(securityManager);
        Subject subject = SecurityUtils.getSubject();
        try {
            subject.login(new UsernamePasswordToken("xiaochen", "123"));
            System.out.println("登录成功");
        } catch (UnknownAccountException e) {
            // 用户名不存在
            e.printStackTrace();
        } catch (IncorrectCredentialsException e) {
            // 密码错误
            e.printStackTrace();
        }

        if (subject.isAuthenticated()) {
            // 通过用户验证，判断用户角色
            System.out.println(subject.hasRole("super"));

            // 一个用户也可以有多个角色
            System.out.println(subject.hasAllRoles(Arrays.asList("admin", "user")));

            boolean[] booleans = subject.hasRoles(Arrays.asList("admin", "super", "user"));
            for (boolean b:booleans) {
                System.out.print(b + "\t");
            }
            System.out.println();
            System.out.println();

            // 权限字符串访问控制 资源标识符:操作:资源类型
            System.out.println("权限：" + subject.isPermitted("user:update:01"));
            System.out.println("权限：" + subject.isPermitted("product:update"));
            System.out.println("权限：" + subject.isPermitted("product:create:01"));
            System.out.println("权限：" + subject.isPermitted("product:create"));

            // 同时具有哪些权限
            System.out.println("是否同时包含多个权限" +
                               subject.isPermittedAll("user:*01", "product:"));

        }
```

## 五、SpringBoot整合Shiro

```flow
start=>start: Request
shiroFilter=>operation: ShiroFilter
springboot=>operation: springboot
securityManager=>operation: securityManager

start->shiroFilter
shiroFilter->springboot
```

ShiroConfig类：

```java
@Configuration
public class ShiroConfig {

    @Bean
    public ShiroFilterFactoryBean getShiroFilterFactoryBean
      (DefaultWebSecurityManager defaultWebSecurityManager) {
        ShiroFilterFactoryBean shiroFilterFactoryBean = 
          new ShiroFilterFactoryBean();
        // 设置filter安全管理器
        shiroFilterFactoryBean.setSecurityManager(defaultWebSecurityManager);

        /**
         * 配置系统中的受限资源
         */
        Map<String, String> map = new HashMap<>();
        map.put("/index.jsp", "authc"); // authc 请求这个资源需要认证和授权
        shiroFilterFactoryBean.setFilterChainDefinitionMap(map);

        /**
         * 配置系统中的公共资源
         */


        /**
         * 配置默认认证路径
         * 其实默认就是login.jsp，可以改为别的
         */
        shiroFilterFactoryBean.setLoginUrl("/login.jsp");

        return shiroFilterFactoryBean;
    }

    @Bean
    public DefaultWebSecurityManager getDefaultWebSecurityManager(Realm realm) {
        DefaultWebSecurityManager defaultWebSecurityManager = new DefaultWebSecurityManager();
        defaultWebSecurityManager.setRealm(realm);
        return defaultWebSecurityManager;
    }

    @Bean
    public Realm getRealm(){
        return new CustomerRealm();
    }

}

```

Shiro常见的过滤器

| 配置缩写          | 过滤器                         | 功能                                                         |
| ----------------- | ------------------------------ | ------------------------------------------------------------ |
| anon              | AnonymousFilter                | 指定url可以匿名访问                                          |
| authc             | FormAuthenticationFilter       | 指定url需要form表单登录，默认会从请求中获取username、password、rememberMe等参数并尝试登录，如果登录不了就跳转到loginUrl代表团的路径。我们也可以用这个过滤器做默认的登录逻辑，但是一般都是我们自己在控制器写登录逻辑的，自己写的话出错返回的信息都可以定制。 |
| authcBasic        | BasicHttpAuthenticationFilter  | 指定Url需要basic登录                                         |
| logout            | LogoutFilter                   | 登录过滤器，配置指定url就可以实现退出功能，非常方便          |
| noSessionCreation | NoSessionCreationFilter        | 禁止创建会话                                                 |
| perms             | PermissionsAuthorizationFilter | 需要指定权限才能访问                                         |
| port              | PortFilter                     | 需要指定端口才能访问                                         |
| rest              | HttpMethodPermissionFilter     | 将http请求方式转化成相应的动词来构造一个权限字符串           |
| roles             | RolesAuthorizationFilter       | 需要指定角色才能访问                                         |                          

