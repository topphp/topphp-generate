<?php
/**
 * 凯拓软件 [临渊羡鱼不如退而结网,凯拓与你一同成长]
 * @package topphp-generate
 * @date 2020/2/20 16:17
 * @author sleep <sleep@kaituocn.com>
 */
declare(strict_types=1);

namespace Topphp\TopphpGenerate\command;

use Nette\PhpGenerator\PhpFile;
use think\console\Command;
use think\console\input\Option;
use think\facade\Db;
use think\helper\Str;
use think\Model;

class GenerateCommand extends Command
{
    // mysql数据类型转换为php数据类型
    private $typeMaps = [
        'int'    => ['int', 'tinyint', 'smallint', 'mediumint'],
        'string' => ['timestamp', 'char', 'varchar', 'text'],
        'float'  => ['decimal', 'double', 'float'],
    ];

    // 检测当前数据库字段类型转化为php类型
    private function checkType($type = ''): string
    {
        $phpType = 'string';
        foreach ($this->typeMaps as $key => $typeMap) {
            if (in_array($type, $typeMap)) {
                $phpType = $key;
                break;
            }
        }
        return $phpType;
    }

    protected function configure()
    {
        $this->setName('gen:db')
            ->addOption('table', 't', Option::VALUE_OPTIONAL, '指定生成实体类的表名,默认为所有表格', 'all')
            ->setDescription('生成数据库实体模型');
    }

    public function handle()
    {
        $baseModel = $this->createBaseModel('BaseModel');
        var_dump($baseModel);
        // 获取数据库名称
        $database = $this->app->config->get('database.connections.mysql.database');
        // 获取表前缀
        $prefix = $this->app->config->get('database.connections.mysql.prefix');
        // 显示全部表名
        $tables = Db::query("SHOW TABLES");
        // 每次生成前先清空一下目录 todo 此处可优化
        shell_exec('rm -rf ./app/model/entity/*');
        // 遍历所有表
        foreach ($tables as $key => $table) {
            // 获取每个表中的列
            $columns = Db::query(
                'SELECT COLUMN_NAME,COLUMN_COMMENT,DATA_TYPE ,COLUMN_KEY,TABLE_NAME
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=? AND TABLE_SCHEMA=?',
                [current($table), $database]
            );
            // 去掉表前缀
            $tableName = str_replace($prefix, '', current($table));
            // 生成大驼峰规则类名
            $className = Str::studly($tableName);
            // 创建一个php文件
            $file = new PhpFile();
            // 设置严格模式
            $file->setStrictTypes()
                ->addComment("@copyright 凯拓软件 [临渊羡鱼不如退而结网,凯拓与你一同成长]")
                ->addComment("@author sleep <sleep@kaituocn.com>");
            // 定义命名空间 todo 这里以后可以优化(自动获取或者通过配置来定义)
            $namespace = $file
                ->addNamespace('app\model\entity')
                ->addUse("app\model\\{$baseModel}");
            // 生成类并继承 think\Model
            $class = $namespace
                ->addClass($className)
                ->addExtend("app\model\\{$baseModel}");
            // 遍历类中的字段属性
            foreach ($columns as $column) {
                // 类头添加字段注释
                $class->addComment("@property {$this->checkType($column['DATA_TYPE'])} \${$column['COLUMN_NAME']} {$column['COLUMN_COMMENT']}");
                // 判断字段为主键则定义 $pk属性.
                if ($column['COLUMN_KEY'] === 'PRI') {
                    $class->addProperty('pk', $column['COLUMN_NAME'])->setProtected();
                    $class->addProperty('table', $column['TABLE_NAME'])->setProtected();
                }
            }
            // 生成完整文件路径
            $path = app_path() . 'model/entity/' . $className . '.php';
            $this->output->info('正在生成实体类: ' . $className);
            $dirName = dirname($path);
            // 判断是否有文件夹 没有则创建
            if (!is_dir($dirName)) {
                mkdir($dirName, 0777, true);
            }
            // 每次重新覆盖生成新文件
            @file_put_contents($path, $file);
        }
        exec('composer fix-style');
    }

    private function createBaseModel(string $modelName): String
    {
        $modelName = Str::studly($modelName);
        $file      = new PhpFile();
        $file->setStrictTypes(true)
            ->addComment("@copyright 凯拓软件 [临渊羡鱼不如退而结网,凯拓与你一同成长]")
            ->addComment("@author sleep <sleep@kaituocn.com>");
        $namespace = $file->addNamespace('app\model')->addUse(Model::class);
        /** @var Model $class */
        $class = $namespace
            ->addClass($modelName)
            ->addExtend(Model::class);
        $path  = app_path() . "model/{$modelName}.php";
        if (!file_exists($path)) {
            @file_put_contents($path, $file);
        }
        return $class->getName();
    }
}
