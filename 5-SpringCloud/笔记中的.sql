
create database spring_cloud_demo default charset=utf8;

create table tb_product (
	id int not null auto_increment,
	product_name varchar(40) default null comment '名称',
	status int default null comment '状态',
	price decimal(10,2) default null comment '单价',
	product_desc varchar(255) default null comment '标题',
	caption varchar(255) default null comment '标题',
	inventory int default null comment '库存',
	primary key(id)
)engine=innodb default charset=utf8;