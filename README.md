# 配置
> 首先确保已配置好`aqueduct`相关环境

在 `~/.pub_cache/bin`下新建 `aqueduct_mysql`文件

``` shell
cd  ~/.pub_cache/bin
touch aquduct_mysql
```

在`aqueduct_mysql`中写入：

``` shell
# set aqueduct_mysql package's path
dart "xxxx/aqueduct_mysql/bin/aqueduct_mysql.dart" "$@"

# The VM exits with code 253 if the snapshot version is out-of-date.
# If it is, we need to delete it and run "pub global" manually.
exit_code=$?
if [ $exit_code != 253 ]; then
  exit $exit_code
fi
```

给予`aqueduct_mysql`执行权限:
``` shell
chmod +x aqueduct_mysql
```

# 使用

在项目中添加依赖：

``` yaml
dependencies:
  aqueduct: ^3.3.0
  aqueduct_mysql: ^0.0.1
```

## 使用`aqueduct_mysql`命令
1. 生成`migration`文件：

``` shell
aqueduct_mysql db generate
```

2. 生成数据库

``` shell
aqueduct_mysql db upgrade --connect mysql://username:password@host:port/databasename
```

3. 添加认证client

``` shell
aqueuct_mysql auth add-client --id newclient --connect mysql://username:password@host:port/databasename
```

4. 使用`MySqlPersistentStore`

``` DART
  final MySqlPersistentStore persistentStore = MySqlPersistentStore(
        _config.database.username,
        _config.database.password,
        _config.database.host,
        _config.database.port,
        _config.database.databaseName);

    context = ManagedContext(dataModel, persistentStore);
    /// ......
   final result= await Query(context, values: user).insert();

```


