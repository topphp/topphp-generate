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
