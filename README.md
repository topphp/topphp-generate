# topphp-generate

[![Latest Version on Packagist][ico-version]][link-packagist]
[![Software License][ico-license]](LICENSE.md)
[![Build Status][ico-travis]][link-travis]
[![Coverage Status][ico-scrutinizer]][link-scrutinizer]
[![Quality Score][ico-code-quality]][link-code-quality]
[![Total Downloads][ico-downloads]][link-downloads]

# 生成器
可快速生成thinkphp的模型类,继承自 think\Model

# 版本说明
现代的PHP组件都使用语义版本方案(http://semver.org), 版本号由三个点(.)分数字组成(例如:1.13.2).第一个数字是主版本号,如果PHP组件更新破坏了向后兼容性,会提升主版本号.
第二个数字是次版本号,如果PHP组件小幅更新了功能,而且没有破坏向后兼容性,会提升次版本号.
第三个数字(即最后一个数字)是修订版本号,如果PHP组件修正了向后兼容的缺陷,会提升修订版本号.

## Structure
> 组件结构

```
bin/        
build/
docs/
config/
src/
tests/
vendor/
```


## Install

Via Composer

``` bash
$ composer require topphp/topphp-generate
```

## Usage
需要先配置数据库信息 `config/database.php` 后进行命令行生成
``` shell
php think gen:db
注意事项：
    1、自动生成：在topphp骨架里，多应用情况下，gen:db组件会根据你是否创建了对应的应用模块（如admin）下的model的文件夹来判断是否自动创建对应的model文件
    2、创建规范：应用模块（如admin）下的model文件统一会继承app/model/entity下的模型实体类,并全部以Dao.php结尾（此Dao层主要用于编写数据库业务）
    3、添加新的表：如果开发过程中需要添加新的数据表，可以执行 php think gen:db 进行自动更新模型实体类与模型Dao
    4、特别说明：
          a、每次执行 php think gen:db 模型实体类都会重置一遍，所以请不要直接编辑操作模型实体类
          b、每次执行 php think gen:db 对于已存在的模型Dao不会清空代码，对于不存在的模型Dao会自动创建（例如中途添加新的数据表场景）。
          c、每次执行 php think gen:db 以后使用传统环境（apache或nginx）部署在Linux系统下的注意统一修改一次文件夹权限（如：chown -R www:www www.domain.com/）
          
BaseModel 基础模型操作类
  Tips：提供模型操作的基本快捷方法，提升模型操作代码复用率，方便开发，包含如下方法：
       a、分页配置（用于自动构造TP6分页参数）protected getPaginateConfig()
       b、获取资源数据指定列的数组 protected getSourceColumn()
       c、数组分页 protected dataPage()
       
       // 以下为公共方法
       a、获取模型抛出的异常报错 getModelError()
       b、获取当前模型表所有字段名 getTableFieldName()
       c、新增数据 add()
       d、批量新增数据 addAll()
       e、大数据量批量新增（支持分批插入，一般应用于插入数据超千条场景） addLimitAll()
       f、编辑数据 edit()
       g、更新指定字段值（支持主键更新） updateField()
       h、指定字段自增（支持主键查询） fieldInc()
       i、指定字段自减（支持主键查询） fieldDec()
       j、指定字段自增/自减（支持主键查询，支持多字段步进处理） fieldStep()
       k、多条件批量更新（支持主键批量更新） updateAll()
       l、多条件批量更新（原生where查询） updateAllRaw()
       m、删除数据（支持主键删除，支持多条件删除，支持软删除） remove()
       n、删除数据（原生where查询，不支持直接传入主键id值删除，其他规则同remove） removeRaw()
       o、查询链式（支持主键查询，支持TP链式操作，融合软删除） queryChain()
       p、查询字段值（支持主键查询，支持select查询返回二维数组，默认find查询） findField()
       q、查询一条（支持主键查询，支持select查询返回二维数组，默认select查询） selectOne()
       r、查询所有（支持主键查询，支持排除字段） selectAll()
       s、查询排序（支持主键查询，支持原生SQL语句Order排序，支持Limit限制条数） selectSort()
       t、查询首条数据（支持前Limit条） selectFirst()
       u、查询最后一条数据（支持后Limit条） selectEnd()
       v、满足条件的数据随机返回（支持随机取Limit条） selectRand()
       w、查询某个字段的值相同的数据（同一张表指定字段值相同的数据，支持结果排序） selectSameField()
       x、查询指定字段值重复的记录（支持多字段匹配，支持结果排序） selectRepeat()
       y、查询指定字段值不重复的记录【仅查询不重复的】（支持多字段匹配，支持结果排序） selectNoRepeat()
       z、FIND_IN_SET查询（查询指定字段包含指定的值或字符串的数据集合） selectFieldInSet()
       I、FIND_IN_SET查询（查询指定字段在指定的集合的数据集合，效果类似于 field in (1,2,3,4,5) 的用法） selectFieldInList()
       II、查询List（支持分页，支持each回调） selectList()
       III、查询列（支持指定字段的值作为索引） selectColumn()
       
       // 以下为联查方法
       a、设置基础查询条件（用于简化基础alias、join和主表field） setBaseQuery()
       b、Join联查(innerJoin，如果表中有至少一个匹配，则返回行) selectJoin()
       c、leftJoin联查（即使右表中没有匹配，也从左表返回所有的行） selectLeftJoin()
       d、rightJoin联查（即使左表中没有匹配，也从右表返回所有的行） selectRightJoin()
       e、fullJoin联查（只要其中一个表中存在匹配，就返回行，Mysql数据库不支持） selectFullJoin()
       f、一对多子查询（支持分页，支持主表、子表字段过滤，返回值类似TP的with查询返回） selectChild()          
```

## Change log

Please see [CHANGELOG](CHANGELOG.md) for more information on what has changed recently.

## Testing

``` bash
$ composer test
```

## Contributing

Please see [CONTRIBUTING](CONTRIBUTING.md) and [CODE_OF_CONDUCT](CODE_OF_CONDUCT.md) for details.

## Security

If you discover any security related issues, please email sleep@kaituocn.com instead of using the issue tracker.

## Credits

- [topphp][link-author]
- [All Contributors][link-contributors]

## License

The MIT License (MIT). Please see [License File](LICENSE.md) for more information.

[ico-version]: https://img.shields.io/packagist/v/topphp/topphp-generate.svg?style=flat-square
[ico-license]: https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square
[ico-travis]: https://img.shields.io/travis/topphp/topphp-generate/master.svg?style=flat-square
[ico-scrutinizer]: https://img.shields.io/scrutinizer/coverage/g/topphp/topphp-generate.svg?style=flat-square
[ico-code-quality]: https://img.shields.io/scrutinizer/g/topphp/topphp-generate.svg?style=flat-square
[ico-downloads]: https://img.shields.io/packagist/dt/topphp/topphp-generate.svg?style=flat-square

[link-packagist]: https://packagist.org/packages/topphp/topphp-generate
[link-travis]: https://travis-ci.org/topphp/topphp-generate
[link-scrutinizer]: https://scrutinizer-ci.com/g/topphp/topphp-generate/code-structure
[link-code-quality]: https://scrutinizer-ci.com/g/topphp/topphp-generate
[link-downloads]: https://packagist.org/packages/topphp/topphp-generate
[link-author]: https://github.com/topphp
[link-contributors]: ../../contributors
