# 一、SpringBoot自动装配原理

## 1、依赖管理

SpringBoot默认使用了以下依赖：

```xml
<parent>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-parent</artifactId>
		<version>2.1.5.RELEASE</version>
</parent>
```

Spring-boot-starter-parent又继承以下依赖：

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-dependencies</artifactId>
    <version>2.1.5.RELEASE</version>
    <relativePath>../../spring-boot-dependencies</relativePath>
</parent>
```

在`spring-boot-dependencies`工程里定义了企业应用常用的开发包及它的版本信息。而在`spring-boot-starter-parent`项目中加载配置(资源文件)文件。

 ## 2、自动装配的原理

### 1）@SpringBootApplication

```java
/** Java原生注解 */
// 定义注解的作用范围，类、方法、属性
@Target(ElementType.TYPE)
// 定义注解的生命周期，编译期或运行期起作用，如:@override 是在编译的时候起作用的，运行代码时没有任何作用
@Retention(RetentionPolicy.RUNTIME)
// javadoc，代码提示，配置@param @see(超链接)
@Documented
// 修饰的自定义注解可以被子类继承
@Inherited

/** Spring自定义注解 */
// @SpringBootConfiguration注解相当于@Configuration注解，看第2小节
@SpringBootConfiguration

@EnableAutoConfiguration
@ComponentScan(excludeFilters = {
		@Filter(type = FilterType.CUSTOM, classes = TypeExcludeFilter.class),
		@Filter(type = FilterType.CUSTOM,
				classes = AutoConfigurationExcludeFilter.class) })
public @interface SpringBootApplication {
```

### 2）@SpringBootConfiguration

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Configuration // TODO看这里
public @interface SpringBootConfiguration {

}
```

这就是`@SpringBootConfiguration`的源码，可以看出，`@SpringBootConfiguration`注解实际上就是一个`@Configuration`注解。`@Configuration`注解代码如下：

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component // TODO 看这里
public @interface Configuration {
	@AliasFor(annotation = Component.class)
	String value() default "";
}
```

可以看出`@Configuration`注解继承了`@Compoment`注解，其实这两个注解装配的类里都可以定义Bean标签。它们有什么区别？`@Configuration`默认会使用`CGLIB`代理这个`Bean`，`@Compoment`不会。

- `@Configuration`里定义的`Bean`可以保证例

### 3）@EnableAutoConfiguration

#### (1) 先看@Import注解

先看一下`@Import`注解，它是SpringBoot自动装配的核心注解。它有三种用法：

- 参数如果是普通类，将这个类交给IOC容器管理
- 如果是`ImportBeanDefinitionRegistrar`的实现类，动持手工注册Bean
- 参数如果是`ImportSelector`的实现类，注册selectImports返回的数组(类的全路径)到IOC容器，批量注册

 那就是说`@Import`里的参数(类)会加入到IOC容器中。如:

```java
// 下面代码会把HelloController类的实现注册到IOC容器中
@Import(top.aoae.HelloController.class) 
```



#### (2) @EnableAutoConfiguration注解

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
// 
@AutoConfigurationPackage
// 导入参数类到IOC中
@Import(AutoConfigurationImportSelector.class)
public @interface EnableAutoConfiguration {

	String ENABLED_OVERRIDE_PROPERTY = "spring.boot.enableautoconfiguration";

	/**
	 * Exclude specific auto-configuration classes such that they will never be applied.
	 * @return the classes to exclude
	 */
	Class<?>[] exclude() default {};

	/**
	 * Exclude specific auto-configuration class names such that they will never be
	 * applied.
	 * @return the class names to exclude
	 * @since 1.3.0
	 */
	String[] excludeName() default {};

}
```

可以看到`@EnableAutoConfiguration`里继承了`@AutoConfigurationPackage`，它的代码如下：

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
// Registrar.class 是保存扫描包的路径，提供给spring-data-jpa来使用的， @Entity
@Import(AutoConfigurationPackages.Registrar.class)
public @interface AutoConfigurationPackage {
}
```

`@EnableAutoConfiguration`下有通过@Import注册一个类：`@Import(AutoConfigurationImportSelector.class)`，查看这个类的源码：

```java
	// 看到其中一段代码如下：
	@Override
	public String[] selectImports(AnnotationMetadata annotationMetadata) {
		if (!isEnabled(annotationMetadata)) {
			return NO_IMPORTS;
		}
		AutoConfigurationMetadata autoConfigurationMetadata = AutoConfigurationMetadataLoader
				.loadMetadata(this.beanClassLoader);
     // TODO重点是这里的getAutoConfigurationEntry这里
		AutoConfigurationEntry autoConfigurationEntry = getAutoConfigurationEntry(
				autoConfigurationMetadata, annotationMetadata);
		return StringUtils.toStringArray(autoConfigurationEntry.getConfigurations());
  }
```

上面方法返回的是一个String[]，其中最主要是通过`getAutoConfigurationEntry`来加载，下面看一下`getAutoConfigurationEntry`的代码：

```java
protected AutoConfigurationEntry getAutoConfigurationEntry(
			AutoConfigurationMetadata autoConfigurationMetadata,
			AnnotationMetadata annotationMetadata) {
		if (!isEnabled(annotationMetadata)) {
			return EMPTY_ENTRY;
		}
  	// 获取注解属性
		AnnotationAttributes attributes = getAttributes(annotationMetadata);
  	// TODO 从META-INF/spring.factories加载EnableAutoConfiguration类
		List<String> configurations = getCandidateConfigurations(annotationMetadata,
				attributes);
		configurations = removeDuplicates(configurations);
		Set<String> exclusions = getExclusions(annotationMetadata, attributes);
		checkExcludedClasses(configurations, exclusions);
		configurations.removeAll(exclusions);
		configurations = filter(configurations, autoConfigurationMetadata);
		fireAutoConfigurationImportEvents(configurations, exclusions);
		return new AutoConfigurationEntry(configurations, exclusions);
}
```

查看`getCandidateConfigurations`方法

```java
protected List<String> getCandidateConfigurations(AnnotationMetadata metadata,
			AnnotationAttributes attributes) {
  	// TODO，这个方法从本地加载类名
		List<String> configurations = SpringFactoriesLoader.loadFactoryNames(
				getSpringFactoriesLoaderFactoryClass(), getBeanClassLoader());
		Assert.notEmpty(configurations,
				"No auto configuration classes found in META-INF/spring.factories. If you "
						+ "are using a custom packaging, make sure that file is correct.");
		return configurations;
}
```

查看`SpringFactoriesLoader.loadFactoryNames`这个方法，看到下面两个方法：

```java
public static List<String> loadFactoryNames(Class<?> factoryClass, @Nullable ClassLoader classLoader) {
		String factoryClassName = factoryClass.getName();
		return loadSpringFactories(classLoader).getOrDefault(factoryClassName, Collections.emptyList());
	}

	private static Map<String, List<String>> loadSpringFactories(@Nullable ClassLoader classLoader) {
		MultiValueMap<String, String> result = cache.get(classLoader);
		if (result != null) {
			return result;
		}

		try {
			Enumeration<URL> urls = (classLoader != null ?
          // 从FACTORIES_RESOURCE_LOCATION这个常量可以看到最终还是通过
          // META-INF/spring.factories文件来加载
					classLoader.getResources(FACTORIES_RESOURCE_LOCATION) :
					ClassLoader.getSystemResources(FACTORIES_RESOURCE_LOCATION));
			result = new LinkedMultiValueMap<>();
			while (urls.hasMoreElements()) {
				URL url = urls.nextElement();
				UrlResource resource = new UrlResource(url);
				Properties properties = PropertiesLoaderUtils.loadProperties(resource);
				for (Map.Entry<?, ?> entry : properties.entrySet()) {
					String factoryClassName = ((String) entry.getKey()).trim();
					for (String factoryName : StringUtils.commaDelimitedListToStringArray((String) entry.getValue())) {
						result.add(factoryClassName, factoryName.trim());
					}
				}
			}
			cache.put(classLoader, result);
			return result;
		}
		catch (IOException ex) {
			throw new IllegalArgumentException("Unable to load factories from location [" +
					FACTORIES_RESOURCE_LOCATION + "]", ex);
		}
	}
```

> 最终`EnableAutoConfiguration`就是通过`@Import`注解，把类加载到IOC容器中。

# 二、自定义starter开发

## 1、创建starter工程

创建my-springboot-starter工程

### 1)、引入依赖

```xml
<dependencies>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-autoconfigure</artifactId>
		</dependency>

		<!-- spring默认使用yml中的配置，但有时候要用传统的xml或properties配置，就需要使用spring-boot-configuration-processor了 -->
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-configuration-processor</artifactId>
			<optional>true</optional>
		</dependency>
		
		<!-- 用于计算不同时区的时间精度 -->
		<dependency>
			<groupId>joda-time</groupId>
			<artifactId>joda-time</artifactId>
			<version>2.9.4</version>
		</dependency>
	</dependencies>
```

### 2)、创建UtilProperties类

这个类可以接收application.yml的配置信息

```java
@ConfigurationProperties(prefix = "util.date") // 根记yml文件配置
public class UtilProperties {
	// 经度
	private Double latitude = 120d;
	// 时区
	private int zone;
	
	private String patternString = "yyyy-MM-dd hh:mm:ss";

	public Double getLatitude() {
		return latitude;
	}

	public void setLatitude(Double latitude) {
		this.latitude = latitude;
	}

	public int getZone() {
		return zone;
	}

	public void setZone(int zone) {
		this.zone = zone;
	}

	public String getPatternString() {
		return patternString;
	}

	public void setPatternString(String patternString) {
		this.patternString = patternString;
	}	
}
```

其实它就是一个简单的javaBean，通过`@ConfigurationProperties`来接收配置信息

### 3)、创建业务实现类DateUtil

DateUtil类的作用是用于实现业务逻辑

```java
public class DateUtil {
	
	@Autowired
	private UtilProperties utilProperties;
	
	public String getLocalTime() {
		int zone = 0;
		if (utilProperties.getLatitude() != null) {
			// 计算出时区
			zone = (int)Math.round((utilProperties.getLatitude() * DateTimeConstants.HOURS_PER_DAY) / 360);
		}
		DateTimeZone dZone = DateTimeZone.forOffsetHours(zone);
		return new DateTime(dZone).toString(utilProperties.getPatternString());
	}
}
```

### 4)、创建配置类

在这个配置类中把刚才创建的类加入到Ioc容器中

```java
@Configuration
@EnableConfigurationProperties(UtilProperties.class)
public class DateConfig {
	
	/**
	 * 在这里返回上一小节的类实例
	 * @return
	 */
	@Bean
	public DateUtil getDateUtil() {
		return new DateUtil();
	}
}
```

### 5)、创建META-INF/spring.factories

SpringBoot会自动加载下面配置的类，并加入到IOC容器中

```properties
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
top.aoae.my_springboot_start.DateConfig
```

完了。

## 2、在其它项目中引入Starter

### 1)、创建一个新的项目，并引入依赖：

```xml
 <dependency>
  <groupId>top.aoae</groupId>
  <artifactId>my-springboot-starter</artifactId>
  <version>0.0.1-SNAPSHOT</version>
 </dependency>
```

### 2)、直接使用

```java
@RestController
public class HelloController {
	/** 通过Autowired可以直接使用 */
	@Autowired
	private DateUtil dateUtil;
  
	@RequestMapping("/test")
	public String test(String str) {
		return dateUtil.getLocalTime();
	}
}
```

完了。

## 3、使用EanbleXXX的方式引入

### 1)、创建ImportSelector的实现类

```java
public class MyImport implements ImportSelector {

	@Override
	public String[] selectImports(AnnotationMetadata importingClassMetadata) {
		// 包含配置类的全类名
    return new String[] {DateConfig.class.getName()};
	}
}
```

### 2)、创建@EnableUtil注解

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
// 通过Import把上一节返回的全类名，加入到IOC容器中
@Import(MyImport.class)
public @interface EnableUtil {
}
```

### 3)、使用方式

在项目项目中引入这个项目的依赖，并在springboot的启动类上加入：

```java
@SpringBootApplication
@EnableUtil // 在这里使用就可以了
public class UsedStarterApplication {

	public static void main(String[] args) {
		SpringApplication.run(UsedStarterApplication.class, args);
	}

}
```

