# 一、maven的依赖特性

maven项目不同的阶段引入到classpath中的路径是不同的。例如：编译时，maven会将编译相关的依赖引入到classpath中；测试时会将测试相关的依赖加入到classpath中，运行时，maven会将与运行相关的依赖加入到classpath中，而依赖范围就是用来控制这三种classpath的关系。如：

```xml
<dependency>
	<groupId>junit</groupId>
	<artifactId>junit</artifactId>
	<version>4.1.1</version>
  <!--在测试的时候引入-->
	<scope>test</scope>
</dependency>
```

## 1、编译依赖范围

这个范围是<b style="color:deeppink;">默认范围，编译、测试、运行三种classpath都有效</b>，如项目中的spring-core

## 2、测试依赖范围(test)

只对<b style="color:deeppink;">测试时的classpath有效</b>。使用`<scope>test</scope>`

```xml
<dependency>
	<groupId>junit</groupId>
	<artifactId>junit</artifactId>
	<version>4.1.1</version>
  <!--在测试的时候引入-->
	<scope>test</scope>
</dependency>
```

## 3、已提供依赖范围(provided)

<b style="color:deeppink;">编译和测试的时候classpath有效，但运行时无效</b>。如servlet-api

```xml
<dependency>
	<groupId>javax</groupId>
	<artifactId>javaee-api</artifactId>
	<version>7.0</version>
  <!--对编译和测试的classpath有效，运行的时候使用tomcat提供的api-->
	<scope>provided</scope>
</dependency>
```

## 4、运行时依赖范围(runtime)

使用依赖范围的maven依赖，只对<b style="color:deeppink;">测试和运行的classpath有效</b>，对编译的classpath无效，典型例子是jdbc驱动实现，项目主代码编译时只需要JDK提供接口，只有在测试和运行时才需要实现上术接口的具体JDBC驱动。

```xml
<dependency>
	<groupId>mysql</groupId>
	<artifactId>mysql-connector-java</artifactId>
	<version>5.1.47</version>
  <!---->
	<scope>runtime</scope>
</dependency>
```

## 5、系统依赖范围(system)

<b style="color:deeppink;">编译和测试的时候classpath有效，但运行时无效</b>。系统依赖范围必需通过配置systemPath元素来显示指定依赖文件的路径，此类依赖不是由maven仓库解析的，往往与本机系统绑定，可能造成构件不可行色移植，需谨慎使用，systemPath元素可以引用 环境变量。

## 6、导入依赖范围(import)

依赖范围不会对三种classpath产生影响，只能与`dependencyManagement`配置使用，其功能**将目标pom文件中的dependencymanagement的配置导入合并到当前pom的dependencyManagement中**。

```xml
<dependency>
	<groupId>org.springframework</groupId>
	<artifactId>spring-framework-bom</artifactId>
	<version>4.3.10.RELEASE</version>
	<scope>import</scope>
  <type>pom</type>
</dependency>
```

# 二、Maven的常用命令

 ## 1、mvn compile

编译，将java源程序译成class字节码文件

## 2、mvn test

测试，生成测试报告

## 3、mvn clean 

将之前编译得到的class字节码文件删除

## 4、mvn package

打包，动态web工程打war包;java工程打jar包

## 5、同时使用多个命令

```sh
mvn clear package
mvn clear install -Dmaven.test.skip=true
```

# 三、Maven的插件

