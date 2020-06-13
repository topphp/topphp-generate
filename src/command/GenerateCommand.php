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
            ->addOption('base_model', 'b', Option::VALUE_OPTIONAL, '指定生成实体类的表名,默认为所有表格', 'yes')
            ->setDescription('生成数据库实体模型');
    }

    public function handle()
    {
        try {
            $baseModel = $this->createBaseModel('BaseModel');
            // 获取数据库名称
            $database = $this->app->config->get('database.connections.mysql.database');
            // 获取表前缀
            $prefix = $this->app->config->get('database.connections.mysql.prefix');
            // 显示全部表名
            $tables = Db::query("SHOW TABLES");
            // 每次生成前先清空一下目录（已做win系统兼容）
            if ($this->isWin()) {
                $files = $this->fileList(app_path() . "model" . DIRECTORY_SEPARATOR . "entity");
                if (!empty($files)) {
                    foreach ($files as $f) {
                        @unlink(app_path() . "model" . DIRECTORY_SEPARATOR . "entity" . DIRECTORY_SEPARATOR . $f);
                    }
                }
            } else {
                shell_exec('rm -rf ./app/model/entity/*');
            }
            // 获取app目录下所有二级model目录
            $appDir = $this->isExistDir($this->queryDir(app_path()), "model");
            if (!empty($appDir)) {
                unset($appDir[array_search("model\\", $appDir)]);
            }
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
                    ->addUse(Model::class)
                    ->addUse("app\model\\{$baseModel}");
                // 生成类并继承 think\Model
                $class = $namespace
                    ->addClass($className)
                    ->addExtend(Model::class);
                // 遍历类中的字段属性
                $schema = [];   // 设置模型的 schema 字段信息
                foreach ($columns as $column) {
                    // 类头添加字段注释
                    $class->addTrait("app\model\\{$baseModel}")
                        ->addComment("@property {$this->checkType($column['DATA_TYPE'])} \${$column['COLUMN_NAME']} {$column['COLUMN_COMMENT']}");
                    // 判断字段为主键则定义 $pk属性.
                    if ($column['COLUMN_KEY'] === 'PRI') {
                        $class->addProperty('pk', $column['COLUMN_NAME'])->setProtected();
                    }
                    $class->addProperty('table', $column['TABLE_NAME'])->setProtected();
                    $schema[$column['COLUMN_NAME']] = $column['DATA_TYPE'];
                }
                $class->addProperty('schema', $schema)->setProtected();
                // 生成完整文件路径
                $path = app_path() . 'model/entity/' . $className . '.php';
                $this->output->info('正在生成实体类: ' . $className);
                $dirName = dirname($path);
                // 判断是否有文件夹 没有则创建
                if (!is_dir($dirName)) {
                    mkdir($dirName, 0755, true);
                }
                // 每次重新覆盖生成新文件
                @file_put_contents($path, $file);
                // 检查多模块是否存在model文件夹，存在则添加Dao
                if (!empty($appDir)) {
                    $this->createDao($appDir, $className, "app\model\\entity\\{$className}");
                }
            }
            exec('composer fix-style');
        } catch (\Throwable $e) {
            $this->output->error("操作失败，请检查数据库是否连接");
            $this->output->error($e->getMessage());
        }
    }

    private function createBaseModel(string $modelName): String
    {
        if ($this->input->hasOption('base_model') && $this->input->getOption('base_model') === 'yes') {
            $baseModelFile = dirname(dirname(__FILE__)) . DIRECTORY_SEPARATOR
                . "data" . DIRECTORY_SEPARATOR . "BaseModel.tpl";
            $file          = @file_get_contents($baseModelFile);
            $path          = app_path() . "model/{$modelName}.php";
            $installDir    = app_path() . "model/";
            !is_dir($installDir) && @mkdir($installDir, 0755, true);
            if (!file_exists($path)) {
                @file_put_contents($path, $file);
            }
            return $modelName;
        } else {
            $modelName = Str::studly($modelName);
            $file      = new PhpFile();
            $file->setStrictTypes(true)
                ->addComment("@copyright 凯拓软件 [临渊羡鱼不如退而结网,凯拓与你一同成长]")
                ->addComment("@author sleep <sleep@kaituocn.com>");
            $namespace = $file->addNamespace('app\model');
            $class     = $namespace
                ->addTrait($modelName);
            $path      = app_path() . "model/{$modelName}.php";
            $dir       = app_path() . "model/";
            !is_dir($dir) && @mkdir($dir, 0755, true);
            if (!file_exists($path)) {
                @file_put_contents($path, $file);
            }
            return $class->getName();
        }
    }

    private function isWin()
    {
        return DIRECTORY_SEPARATOR == '\\' ? true : false;
    }

    private function fileList($dir)
    {
        $list   = [];
        $handle = opendir($dir);
        $i      = 0;
        while (!!$file = readdir($handle)) {
            if (($file != ".") and ($file != "..")) {
                $list[$i] = $file;
                $i        = $i + 1;
            }
        }
        closedir($handle);
        return $list;
    }

    private function queryDir($dir, $limit = 2, $deep = 0)
    {
        $array   = [];
        $handler = scandir($dir);
        $deep++;
        foreach ($handler as $v) {
            if (is_dir($dir . "/" . $v) && $v != "." && $v != "..") {
                if ($limit == 0 || $limit >= $deep) {
                    $array[$v] = $this->queryDir($dir . "/" . $v, $limit, $deep);
                }
            }
        }
        return $array;
    }

    private function isExistDir($dirArr, $existDir)
    {
        $array = [];
        if (!empty($dirArr) && is_array($dirArr)) {
            foreach ($dirArr as $k1 => $v1) {
                $returnDir1 = $k1 . "\\";
                if ($k1 == $existDir) {
                    array_push($array, $returnDir1);
                }
                if (!empty($v1) && is_array($v1)) {
                    foreach ($v1 as $k2 => $v2) {
                        $returnDir2 = $returnDir1 . $k2;
                        if ($k2 == $existDir) {
                            array_push($array, $returnDir2);
                        }
                    }
                }
            }
        }
        return $array;
    }

    private function createDao($appDir, $className, $use)
    {
        foreach ($appDir as $app) {
            // 删除骨架DemoDao文件
            $delPath = app_path() . str_replace("\\", DIRECTORY_SEPARATOR, $app) . DIRECTORY_SEPARATOR . 'DemoDao.php';
            @unlink($delPath);
            // 生成完整文件路径
            $path = app_path() . str_replace(
                "\\",
                DIRECTORY_SEPARATOR,
                $app
            ) . DIRECTORY_SEPARATOR . $className . 'Dao.php';
            if (!file_exists($path)) {
                $this->output->info('正在生成Dao层: ' . str_replace(
                    "\\",
                    DIRECTORY_SEPARATOR,
                    'app\\' . $app
                ) . DIRECTORY_SEPARATOR . $className . 'Dao.php');
                $file = new PhpFile();
                $file->setStrictTypes(true)
                    ->addComment("@copyright 凯拓软件 [临渊羡鱼不如退而结网,凯拓与你一同成长]")
                    ->addComment("@author sleep <sleep@kaituocn.com>");
                $namespace = $file->addNamespace('app\\' . $app)
                    ->addUse($use);
                $class     = $namespace
                    ->addClass($className . "Dao")
                    ->addExtend($use);
                @file_put_contents($path, $file);
            }
        }
    }
}
