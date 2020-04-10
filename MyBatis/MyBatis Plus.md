# MyBatis Plus

### 1、引入依赖

```xml
<properties>
        <spring.version>5.1.6.RELEASE</spring.version>
    </properties>

<dependencies>
        <dependency>
            <groupId>com.baomidou</groupId>
            <artifactId>mybatis-plus</artifactId>
            <version>3.3.1</version>
        </dependency>
        <dependency>
            <groupId>mysql</groupId>
            <artifactId>mysql-connector-java</artifactId>
            <version>5.1.47</version>
        </dependency>
        <dependency>
            <groupId>com.alibaba</groupId>
            <artifactId>druid</artifactId>
            <version>1.0.11</version>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.4</version>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.12</version>
        </dependency>
        <dependency>
            <groupId>org.slf4j</groupId>
            <artifactId>slf4j-log4j12</artifactId>
            <version>1.7.5</version>
        </dependency>
    <!--spring相关-->
     <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-webmvc</artifactId>
            <version>${spring.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-jdbc</artifactId>
            <version>${spring.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-test</artifactId>
            <version>${spring.version}</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <source>1.8</source>
                    <target>1.8</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
```

### 2、spring bean.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:tx="http://www.springframework.org/schema/context"
       xmlns:context="http://www.springframework.org/schema/context"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
        http://www.springframework.org/schema/beans/spring-beans.xsd http://www.springframework.org/schema/context http://www.springframework.org/schema/context/spring-context.xsd">
    <!--扫描配置文件-->
    <context:property-placeholder location="classpath:*.properties" />
    <!--自定义数据源-->
    <bean id="dataSource" class="com.alibaba.druid.pool.DruidDataSource" destroy-method="close">
        <property name="url" value="${jdbc.url}"/>
        <property name="username" value="${jdbc.username}"/>
        <property name="password" value="${jdbc.password}"/>
        <property name="driverClassName" value="${jdbc.driver}"/>
        <property name="maxActive" value="10"/>
        <property name="minIdle" value="5"/>
    </bean>
    <!--sqlSessionFactory-->
    <bean id="sqlSessionFactory" class="com.baomidou.mybatisplus.extension.spring.MybatisSqlSessionFactoryBean">
        <property name="dataSource" ref="dataSource"/>
    </bean>

    <!--指定扫描的包-->
    <bean class="org.mybatis.spring.mapper.MapperScannerConfigurer">
        <property name="basePackage" value="top.aoae.simple.mapper"/>
    </bean>

    <!--分布配置-->
    <bean id="paginationInterceptor" class="com.baomidou.mybatisplus.extension.plugins.PaginationInterceptor">
        <property name="countSqlParser">
            <bean class="com.baomidou.mybatisplus.extension.plugins.pagination.optimize.JsqlParserCountOptimize">
            <constructor-arg value="true"></constructor-arg>
        </bean>
        </property>
    </bean>
</beans>
```

### 3、pojo类

```java
@Data
@NoArgsConstructor
@AllArgsConstructor
@TableName("tb_user")
public class User {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String userName;
    // 查询时不返回这个字段的值
    @TableField(select = false)
    private String password;
    private String name;
    private Integer age;
    @TableField(value = "email")
    private String mail;
    @TableField(exist = false)  // 数据库里不存在的字段
    private String address;
}
```

### 4、Mapper接口

```java
public interface UserMapper extends BaseMapper<User> {
}
```

### 5、Test类

```java
@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(locations = "classpath:application.xml")
public class TestMyBatisSpring {

    @Autowired
    private UserMapper userMapper;

    @Test
    public void testSelectList() {
//        List<User> users = userMapper.selectList(null);
//        for (User user : users)
//            System.out.println(user);

        QueryWrapper<User> w = new QueryWrapper<>();
        w.like("user_name", "li");
        List<User> users = userMapper.selectList(w);
        for (User user : users)
            System.out.println(user);
    }

    @Test
    public void testInster() {
        User u = new User();
        u.setMail("1@qq.com");
        u.setAge(30);
        u.setUserName("caocao1");
        u.setName("曹操1");
        u.setPassword("123456");
        u.setAddress("北京");
        int insert = userMapper.insert(u);
        System.out.println("result > " + insert);
        System.out.println("id > " + u.getId());
    }

    @Test
    public void testSelectById() {
        System.out.println(userMapper.selectById(1));
    }

    @Test
    public void testUpdateById() {
        User u = new User();
        u.setId(1L);
        u.setAge(19);
        u.setPassword("666666");
        int i = userMapper.updateById(u);
        System.out.println("result > " + i);
    }

    @Test
    public void testUpdate() {
        User u = new User();
        u.setAge(20);
        u.setPassword("9999");
        QueryWrapper<User> wrapper = new QueryWrapper<>();
        wrapper.eq("user_name", "zhangsan");
        userMapper.update(u, wrapper);
    }

    @Test
    public void testUpdate2() {
        UpdateWrapper<User> wrapper = new UpdateWrapper<>();
        wrapper.set("age", 21).set("password", "99999999")
                .eq("user_name", "zhangsan");
        userMapper.update(null, wrapper);
    }

    @Test
    public void testDeleteById() {
        int i = userMapper.deleteById(9L);
        System.out.println("delete > " + i);
    }

    @Test
    public void testDeleteByMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("user_name", "zhangsan");
        map.put("password", "9999");
        int i = userMapper.deleteByMap(map);
        System.out.println("delete > " + i);
    }

    @Test
    public void testDelete() {
//        QueryWrapper<User> w = new QueryWrapper<>();
//        w.eq("user_name", "caocao1").eq("password", "123456");
//        int delete = userMapper.delete(w);

        User u = new User();
        u.setUserName("caocao");
        u.setPassword("123456");
        int delete1 = userMapper.delete(new QueryWrapper<User>(u));

        System.out.println("result > " + delete1);
    }

    @Test
    public void testDeleteBatchIds() {
        userMapper.deleteBatchIds(Arrays.asList(11L, 12L));
    }

    @Test
    public void testSelectBatchIds() {
        List<User> users = userMapper.selectBatchIds(Arrays.asList(2, 3, 4));
        System.out.println(users);
    }

    @Test
    public void testSelectOne() {
        QueryWrapper<User> w = new QueryWrapper<>();
        w.eq("user_name", "lisi");
        User user = userMapper.selectOne(w); // 有多条结果，报错
        System.out.println(user);
    }

    @Test
    public void testSelectCount() {
        QueryWrapper<User> w = new QueryWrapper<>();
        w.gt("age", 20);
        //Integer integer = userMapper.selectCount(w);
        Integer integer = userMapper.selectCount(null);
        System.out.println("count > " + integer);
    }

    @Test
    public void testSelectPage(){
        QueryWrapper<User> w = new QueryWrapper<>();
        w.like("user_name", "li");

        Page<User> page = new Page<>(1, 2);
        Page<User> userPage = userMapper.selectPage(page, w);
        System.out.println(userPage.getTotal());
        System.out.println(userPage.getPages());
        System.out.println(userPage.getCurrent());
        for (User user : userPage.getRecords())
            System.out.println(user);
    }

}
```

