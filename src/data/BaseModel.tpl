<?php

/**
 * @copyright 凯拓软件 [临渊羡鱼不如退而结网,凯拓与你一同成长]
 * @author sleep <sleep@kaituocn.com>
 */

declare(strict_types=1);

namespace app\model;

use app\common\enumerate\MethodEnum;
use app\common\enumerate\PaginateEnum;
use ReflectionClass;
use think\facade\Db;

trait BaseModel
{
    /**
     * 错误信息
     * @var string $modelError
     */
    protected $modelError = "";

    /**
     * 原始数据
     * @var array $modelData
     */
    private $modelData = [];

    //************************************ --- Trait内部方法 --- ****************************************//

    /**
     * 返回秒级时间
     * @param string $time
     * @return mixed
     */
    private function formatTime($time)
    {
        if (preg_match("/./", (string)$time)) {
            $time = @explode(".", (string)$time)[0];
        }
        return $time;
    }

    /**
     * 微秒时间
     * @return string
     */
    private function dateMicrotime()
    {
        [$usec, $sec] = explode(" ", microtime());
        $usec = sprintf("%.6f", $usec);
        return date("Y-m-d H:i:s.") . explode(".", $usec)[1];
    }

    /**
     * 生成时间
     * @param string $datetimeType
     * @return false|int|string
     */
    private function genDateTime(string $datetimeType)
    {
        switch ($datetimeType) {
            case "timestamp":
            case "datetime":
                $time = $this->dateMicrotime();
                break;
            case "year":
                $time = date("Y");
                break;
            case "date":
                $time = date("Y-m-d");
                break;
            case "time":
                $time = date("H:i:s");
                break;
            default:
                $time = time();
        }
        return $time;
    }

    /**
     * 隐藏字段
     * @param array $data
     * @param bool $isItem
     * @return mixed
     */
    private function hiddenField(array $data, $isItem = false)
    {
        if ($isItem) {
            $this->modelData[] = $data;
        } else {
            $this->modelData = $data;
        }
        if (!empty($this->hidden)) {
            $level = $this->arrayLevel($data);
            if ($level == 1) {
                foreach ($data as $key => $val) {
                    if (in_array((string)$key, $this->hidden)) {
                        unset($data[$key]);
                    }
                }
            } elseif ($level > 1) {
                foreach ($data as $key => &$val) {
                    if (is_array($val)) {
                        foreach ($val as $k => $v) {
                            if (in_array((string)$k, $this->hidden)) {
                                unset($val[$k]);
                            }
                        }
                    }
                }
            }
        }
        return $data;
    }

    /**
     * 过滤字段
     * @param array $data
     * @param bool $isUpdate
     * @return array
     */
    private function filterField(array $data, bool $isUpdate = false)
    {
        if (isset($this->schema) && is_array($this->schema)) {
            foreach ($data as $k => $v) {
                if (!array_key_exists($k, $this->schema)) {
                    unset($data[$k]);
                }
            }
        }
        if ($isUpdate && isset($this->schema['update_time'])) {
            $data['update_time'] = $this->genDateTime($this->schema['update_time']);
        }
        return $data;
    }

    /**
     * 格式化新增数据
     * @param array $list
     * @param bool $filter
     * @return array
     */
    private function formatList(array $list, bool $filter = false)
    {
        $resList = [];
        $idName  = $this->getPk();
        foreach ($list as $item) {
            unset($item[$idName]);
            if ($filter) {
                $item = $this->filterField($item);
            }
            $resList[] = $item;
        }
        return $resList;
    }

    /**
     * 大数据PUSH字段值
     * @param array $array
     * @param array $keys
     * @param int $limit
     * @param array $returnArray
     * @return array
     */
    private function addField(array $array, array $keys, int $limit = 100, $returnArray = [])
    {
        $initTimeKeys = [
            "create_time",
            "update_time"
        ];
        $limitArray   = array_slice($array, 0, $limit, true);
        if (!empty($limitArray)) {
            foreach ($limitArray as $u => &$item) {
                foreach ($keys as $k => $v) {
                    if (in_array($k, $initTimeKeys) && $v === true) {
                        $item[$k] = $this->genDateTime($this->schema[$k]);
                    } else {
                        $item[$k] = $v;
                    }
                }
                unset($array[$u]);
                array_push($returnArray, $item);
            }
            return $this->addField($array, $keys, $limit, $returnArray);
        } else {
            return $returnArray;
        }
    }

    /**
     * 获取Trait类
     * @return array
     * @throws \ReflectionException
     */
    private function getTraitName()
    {
        return (new ReflectionClass(static::class))->getTraitNames();
    }

    /**
     * 下划线转驼峰
     * @param string $str
     * @return string|string[]|null
     */
    private function toHumpScore(string $str)
    {
        $str = preg_replace_callback('/([-_]+([a-z]{1}))/i', function ($matches) {
            return strtoupper($matches[2]);
        }, $str);
        return $str;
    }

    /**
     * 查询表达式
     * @return array
     */
    private function getWhereExp()
    {
        return [
            "=",
            "<>",
            ">",
            ">=",
            "<",
            "<=",
            "like",
            "between",
            "between time",
            "in",
            "> time",
            "< time",
            ">= time",
            "<= time",
            "exists",
            "exp",
            "find in set",
        ];
    }

    /**
     * parseWhere
     * @param $where
     * @return array
     */
    private function parseWhere($where)
    {
        $levelWhere = $this->arrayLevel($where);
        if (is_array($where) && ($levelWhere == 1 || $levelWhere == 2)
            && !empty($where[1]) && is_string($where[1])) {
            if (in_array(strtolower($where[1]), $this->getWhereExp())) {
                $where[1] = strtoupper($where[1]);
                $where    = [$where];
            }
        } elseif ($where === "*" || empty($where)) {
            $where = [];
        }
        $whereNotNull = [];
        $whereExp     = [];
        if (is_array($where) && !empty($where) && $this->arrayLevel($where) >= 2) {
            $isParse = false;
            foreach ($where as $wk => $exps) {
                switch (strtolower($exps[1])) {
                    case "<>":
                        if ($exps[2] === null || $exps[2] === 'null') {
                            $whereNotNull[] = $exps[0];
                            unset($where[$wk]);
                            $isParse = true;
                        }
                        break;
                    case "exp":
                        if (is_string($exps[2])) {
                            $whereExp[] = [$exps[0], 'exp', Db::raw($exps[2])];
                            unset($where[$wk]);
                            $isParse = true;
                        }
                        break;
                }
            }
            if ($isParse) {
                $where = array_values($where);
            }
        }
        return [
            "where"        => $where,
            "whereNotNull" => $whereNotNull,
            "whereExp"     => $whereExp
        ];
    }

    /**
     * parsePk
     * @return string
     */
    private function parsePk()
    {
        $idName = $this->getPk();
        if (!isset($this->schema[$idName]) && !empty($this->schema)) {
            $idName = "";
        }
        return $idName;
    }

    /**
     * genBaseModel
     * @param array|string|int|callable $where
     * @param string $pkName
     * @param string $isOr
     * @return \think\Model
     */
    private function genBaseModel($where, string $pkName, string $isOr = "and")
    {
        $this->modelData = [];
        /**
         * @var mixed $where
         * @var array $whereNotNull
         * @var array $whereExp
         */
        extract($this->parseWhere($where));
        if (strtolower($isOr) === "or") {
            if (is_array($where) || $where instanceof \Closure) {
                $model = static::where(function ($query) use ($where, $whereNotNull, $whereExp) {
                    $query->whereOr($where);
                    if (!empty($whereNotNull)) {
                        foreach ($whereNotNull as $w) {
                            $query->whereOrRaw("`" . $w . '` IS NOT NULL');
                        }
                    }
                    if (!empty($whereExp)) {
                        $query->whereOr($whereExp);
                    }
                });
            } else {
                $model = empty($pkName) ? static::where([]) : static::where($pkName, $where);
            }
        } else {
            if (is_array($where) || $where instanceof \Closure) {
                $model = static::where($where);
                if (!empty($whereNotNull)) {
                    foreach ($whereNotNull as $w) {
                        $model->whereNotNull($w);
                    }
                }
                if (!empty($whereExp)) {
                    $model->where($whereExp);
                }
            } else {
                $model = empty($pkName) ? static::where([]) : static::where($pkName, $where);
            }
        }
        return $model;
    }

    /**
     * genStepModel
     * @param $where
     * @param string $field
     * @param $step
     * @return array|bool
     */
    private function genStepModel($where, string $field, $step)
    {
        if (empty($where) || empty($field)) {
            $this->modelError = "where OR field is not empty";
            return false;
        }
        $allowType = ['tinyint', 'smallint', 'mediumint', 'int', 'integer', 'bigint', 'float', 'double', 'decimal'];
        if (!empty($this->schema[$field])) {
            if (!in_array($this->schema[$field], $allowType)) {
                $this->modelError = "field format error, must be numeric type";
                return false;
            }
        }
        if (!is_numeric($step)) {
            $this->modelError = "step must be numeric";
            return false;
        }
        if ((float)$step == 0) {
            $this->modelError = "step:0";
            return false;
        } else {
            $step = (float)$step;
        }
        $idName = $this->parsePk();
        return [
            "model" => $this->genBaseModel($where, $idName),
            "step"  => $step
        ];
    }

    /**
     * 过滤软删除数据
     * @param \think\Model $model
     * @param string $queryType 过滤条件 excludeSoft（默认排除软删除数据）withSoft（包含软删除数据）onlySoft（仅查询软删除数据）
     * @param string $alias 表别名
     * @param null $relationModel
     * @return \think\Model
     * @throws \ReflectionException
     */
    private function filterSoftDelData(
        $model,
        string $queryType = MethodEnum::EXCLUDE_SOFT,
        string $alias = '',
        $relationModel = null
    ) {
        $deleteTimeField = "";
        if (!in_array('think\model\concern\SoftDelete', $this->getTraitName())) {
            // 联查表软删除判断
            if (!empty($relationModel)) {
                $relationField = $relationModel->getTableFieldName();
                if (!empty($relationModel->deleteTime) && is_string($relationModel->deleteTime)) {
                    $deleteTimeField = $alias ? $alias . '.' . $relationModel->deleteTime : $relationModel->deleteTime;
                } elseif (in_array("delete_time", $relationField)) {
                    $deleteTimeField = $alias ? $alias . '.delete_time' : 'delete_time';
                }
            } else {
                // 主表软删除判断
                if (!empty($this->deleteTime) && is_string($this->deleteTime)) {
                    $deleteTimeField = $alias ? $alias . '.' . $this->deleteTime : $this->deleteTime;
                } elseif (isset($this->schema['delete_time'])) {
                    $deleteTimeField = $alias ? $alias . '.delete_time' : 'delete_time';
                }
            }
        }
        return empty($deleteTimeField) ? $model : $model->where(function ($query) use ($deleteTimeField, $queryType) {
            switch ($queryType) {
                case MethodEnum::WITH_SOFT:
                    break;
                case MethodEnum::ONLY_SOFT:
                    $query->whereNotNull($deleteTimeField);
                    break;
                default:
                    $query->where($deleteTimeField, null);
                    $query->whereOr($deleteTimeField, 0);
            }
        });
    }

    /**
     * base join
     * @param array|string|callable $where
     * @param string|array $fields
     * @param array $join
     * @param string $isOr
     * @param string $type
     * @return bool|\think\Model
     */
    private function baseJoin($where, $fields, array $join, string $isOr = "and", string $type = "join")
    {
        if (empty($where)) {
            $this->modelError = "where is not empty";
            return false;
        }
        $this->modelData = [];
        /**
         * @var mixed $where
         * @var array $whereNotNull
         * @var array $whereExp
         */
        extract($this->parseWhere($where));
        // 过滤主表字段
        $alias     = "this";
        $mainField = [];
        if (is_array($fields) && !empty($fields) && $this->arrayLevel($fields) == 1) {
            foreach ($fields as $k => $field) {
                if ($field !== "this.*") {
                    $aliasStr = @substr($field, 0, 5);
                    if ($aliasStr === "this.") {
                        array_push($mainField, substr($field, 5));
                        unset($fields[$k]);
                    } elseif (!preg_match("/\./", $field) && isset($this->schema) && in_array(
                        $field,
                        array_keys($this->schema)
                    )) {
                        // 区分是否是主表字段
                        array_push($mainField, $field);
                        unset($fields[$k]);
                    }
                } else {
                    array_push($mainField, "*");
                    unset($fields[$k]);
                }
            }
        } elseif (empty($fields)) {
            $mainField = [];
        } elseif (!is_string($fields)) {
            $this->modelError = "fields error";
            return false;
        }
        $selectField = $fields;
        // 附表字段自动加别名去重
        $allAlias = [];
        if (!empty($selectField) && is_array($selectField)) {
            if ($this->arrayLevel($join) == 1) {
                if (preg_match("/( |　|\s)/", $join[0])) {
                    // 带别名
                    $tb      = @explode(" ", $join[0])[0];
                    $tbAlias = @explode(" ", $join[0])[1];
                } else {
                    // 不带别名
                    $tb = $tbAlias = $join[0];
                }
                $allField  = [];
                $className = "app\\model\\entity\\" . ucfirst($this->toHumpScore($tb));
                if (class_exists($className)) {
                    ${$tb . "Class"} = new $className;
                    $allField        = ${$tb . "Class"}->getTableFieldName();
                }
                foreach ($selectField as $k => &$v) {
                    if ($v === $tbAlias . ".*" || $v === $tb . ".*") {
                        // 附表全部数据别名处理（存在实体映射$schema有效）
                        if (!empty($allField)) {
                            foreach ($allField as $f) {
                                if (empty($this->hidden) || !in_array($f, $this->hidden)) {
                                    array_push($allAlias, $tbAlias . "." . $f . " as " . $tbAlias . "_" . $f);
                                }
                            }
                            unset($selectField[$k]);
                        }
                    } elseif (!preg_match("/ as | AS /", $v) && preg_match("/\./", $v)) {
                        $v = $v . " as " . $tbAlias . "_" . @explode(".", $v)[1];
                    }
                }
            } else {
                foreach ($join as $item) {
                    if (preg_match("/( |　|\s)/", $item[0])) {
                        // 带别名
                        $tb      = @explode(" ", $item[0])[0];
                        $tbAlias = @explode(" ", $item[0])[1];
                    } else {
                        // 不带别名
                        $tb = $tbAlias = $item[0];
                    }
                    $allField  = [];
                    $className = "app\\model\\entity\\" . ucfirst($this->toHumpScore($tb));
                    if (class_exists($className)) {
                        ${$tb . "Class"} = new $className;
                        $allField        = ${$tb . "Class"}->getTableFieldName();
                    }
                    foreach ($selectField as $k => &$v) {
                        if ($v === $tbAlias . ".*" || $v === $tb . ".*") {
                            // 附表全部数据别名处理（存在实体映射$schema有效）
                            if (!empty($allField)) {
                                foreach ($allField as $f) {
                                    if (empty($this->hidden) || !in_array($f, $this->hidden)) {
                                        array_push($allAlias, $tbAlias . "." . $f . " as " . $tbAlias . "_" . $f);
                                    }
                                }
                                unset($selectField[$k]);
                            }
                        } elseif (!preg_match("/ as | AS /", $v) && preg_match("/" . $tbAlias . "\./", $v)) {
                            $v = $v . " as " . $tbAlias . "_" . @explode(".", $v)[1];
                        }
                    }
                }
            }
            $selectField = array_merge($selectField, $allAlias);
        }
        if (is_string($selectField) && strpos($selectField, 'this.') !== false) {
            $mainField = false;
        }
        $model = $this->setBaseQuery($alias, $mainField, $join, $type)->field($selectField);
        if (strtolower($isOr) === "or") {
            $model->whereOr($where);
            if (!empty($whereNotNull)) {
                foreach ($whereNotNull as $w) {
                    $model->whereOrRaw("`" . $w . '` IS NOT NULL');
                }
            }
            if (!empty($whereExp)) {
                $model->whereOr($whereExp);
            }
        } else {
            $model->where($where);
            if (!empty($whereNotNull)) {
                foreach ($whereNotNull as $w) {
                    $model->whereNotNull($w);
                }
            }
            if (!empty($whereExp)) {
                $model->where($whereExp);
            }
        }
        return $model;
    }

    /**
     * setModelData
     * @param $source
     * @param bool $isFind
     */
    private function setModelData($source, $isFind = false)
    {
        if ($isFind) {
            if ($source !== null) {
                $this->modelData = $source->getData();
            }
        } else {
            if (count($source) > 0) {
                foreach ($source as $item) {
                    $this->modelData[] = $item->getData();
                }
            }
        }
    }

    /**
     * buildReturn
     * @param $data
     * @return array
     */
    private function buildReturn($data)
    {
        return $data ? $data->toArray() : [];
    }

    /**
     * 获取资源数据指定列的数组
     * @param $source
     * @param string $column
     * @return array
     */
    protected function getSourceColumn($source, string $column)
    {
        $columnArr = [];
        foreach ($source as $item) {
            $columnArr[] = $item[$column];
        }
        return $columnArr;
    }

    /**
     * 分页配置
     * @param int $pageLimit
     * @return array
     */
    protected function getPaginateConfig($pageLimit = 0)
    {
        if ((int)$pageLimit <= 0) {
            $app                 = app('http')->getName();
            $controller          = request()->controller();
            $action              = request()->action();
            $pageConfigList      = PaginateEnum::ONE_PAGE_LIMIT;
            $pageConfigListKeys  = array_keys($pageConfigList);
            $operateToApp        = $app . "/*/*";
            $operateToController = $app . "/" . $controller . "/*";
            $operateToAction     = $app . "/" . $controller . "/" . $action;
            if (in_array($operateToAction, $pageConfigListKeys)) {
                // 精确到操作
                $pageLimit = $pageConfigList[$operateToAction];
            } elseif (in_array($operateToController, $pageConfigListKeys)) {
                // 精确到控制器
                $pageLimit = $pageConfigList[$operateToController];
            } elseif (in_array($operateToApp, $pageConfigListKeys)) {
                // 精确到应用
                $pageLimit = $pageConfigList[$operateToApp];
            } else {
                // 默认
                $pageLimit = isset($pageConfigList['default']) ? $pageConfigList['default'] : 15;
            }
        }
        $pageConfig = [
            "list_rows" => $pageLimit,
            'var_page'  => 'page',
            "query"     => request()->param()
        ];
        return $pageConfig;
    }

    /**
     * 数组分页
     * @param array $array
     * @param int $page
     * @param int $limit
     * @return array
     */
    protected function dataPage(array $array, int $page = 1, int $limit = 10)
    {
        $allPages = ceil(count($array) / $limit);
        if ($page > 1 && $page < $allPages) {
            $start = ($page * $limit) - $limit;
        } elseif ($page >= $allPages) {
            $start = ($allPages * $limit) - $limit;
        } else {
            $start = 0;
        }
        return array_slice($array, $start, $limit, true);
    }

    /**
     * 返回数组的维度数（1维 2维 ...）
     * @param $array
     * @param int $level
     * @return mixed
     */
    protected function arrayLevel($array, int $level = 1)
    {
        if (!is_array($array)) {
            return 0;
        }
        foreach ($array as $v) {
            if (is_array($v)) {
                $level++;
                return self::arrayLevel($v, $level);
            }
        }
        return $level;
    }

    //************************************ --- Trait公共方法 --- ****************************************//

    /**
     * 获取模型抛出的异常报错
     * @return mixed|string
     */
    public function getModelError()
    {
        return $this->modelError;
    }

    /**
     * 获取模型原始数据
     * @return mixed|array
     */
    public function getModelData()
    {
        return !empty($this->getData()) ? $this->getData() : $this->modelData;
    }

    /**
     * 获取表所有字段名
     * @return array
     */
    public function getTableFieldName()
    {
        return isset($this->schema) ? array_keys($this->schema) : [];
    }

    /**
     * 新增数据
     *
     * @param array $data 数据数组
     * @param bool $isModel 是否返回模型对象
     * @param bool $isMillisecond 返回create_time，update_time是否为毫秒级
     * @return $this|array|bool 默认返回带ID的新增数据数组
     */
    public function add(array $data, bool $isModel = false, bool $isMillisecond = false)
    {
        try {
            $idName = $this->getPk();
            unset($data[$idName]);
            $this->save($data);
            if ($isModel) {
                return $this;
            }
            if ($isMillisecond) {
                return $this->hiddenField($this->getData());
            } else {
                $data = $this->hiddenField($this->getData());
                if (isset($data['create_time'])) {
                    $data['create_time'] = $this->formatTime($data['create_time']);
                }
                if (isset($data['update_time'])) {
                    $data['update_time'] = $this->formatTime($data['update_time']);
                }
                return $data;
            }
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 批量新增数据
     *
     * @param array $list 数据二维数组
     * @param bool $isModel 是否返回模型对象
     * @param bool $isMillisecond 返回create_time，update_time是否为毫秒级
     * @return $this|array|bool 默认返回带ID的新增数据数组
     */
    public function addAll(array $list, bool $isModel = false, bool $isMillisecond = false)
    {
        try {
            if ($this->arrayLevel($list) != 2) {
                $this->modelError = "新增数据 list 结构必须是 2维数组";
                return false;
            }
            $list = $this->formatList($list);
            if ($isModel) {
                $this->saveAll($list);
                return $this;
            } else {
                $res  = $this->saveAll($list);
                $data = [];
                foreach ($res as &$item) {
                    if ($isMillisecond) {
                        array_push($data, $this->hiddenField($item->getData(), true));
                    } else {
                        $item = $this->hiddenField($item->getData(), true);
                        if (isset($item['create_time'])) {
                            $item['create_time'] = $this->formatTime($item['create_time']);
                        }
                        if (isset($item['update_time'])) {
                            $item['update_time'] = $this->formatTime($item['update_time']);
                        }
                        array_push($data, $item);
                    }
                }
                return $data;
            }
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 大数据量批量新增（支持分批插入，一般应用于插入数据超千条场景）
     *
     * @param array $list 数据二维数组
     * @param int $limit 指定每次插入的数量限制
     * @param bool $autoTime 是否自动时间 （仅数据表存在 create_time 或 update_time 字段有效）
     * @return int 返回插入成功的记录数
     */
    public function addLimitAll(array $list, int $limit = 100, $autoTime = true)
    {
        try {
            if ($this->arrayLevel($list) != 2) {
                $this->modelError = "新增数据 list 结构必须是 2维数组";
                return false;
            }
            $list = $this->formatList($list, true);
            if ($autoTime) {
                if (isset($this->schema['create_time']) || isset($this->schema['update_time'])) {
                    $addField = [];
                    !isset($this->schema['create_time']) ?: $addField['create_time'] = true;
                    !isset($this->schema['update_time']) ?: $addField['update_time'] = true;
                    $list = $this->addField($list, $addField, $limit);
                }
            }
            return static::limit($limit)->insertAll($list);
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 编辑数据
     *
     * @param array $data 要编辑的数据字段=》值
     * @param string $queryType 过滤条件 excludeSoft（默认排除软删除数据）withSoft（包含软删除数据）onlySoft（仅查询软删除数据）
     * @param bool $isModel 是否返回模型对象
     * @return $this|array|bool 默认返回编辑以后的数据全部内容
     */
    public function edit(
        array $data,
        string $queryType = MethodEnum::EXCLUDE_SOFT,
        bool $isModel = false
    ) {
        try {
            // 验证主键是否存在
            $idName = $this->getPk();
            if (!array_key_exists($idName, $data)) {
                $this->modelError = "请传入主键id";
                return false;
            }
            if (count($data) === 1) {
                $res = $this->queryChain($data[$idName], 'and', $queryType)->find();
            } else {
                if ($queryType === MethodEnum::EXCLUDE_SOFT) {
                    $res = $this->queryChain($data[$idName], 'and', $queryType)->find();
                    if (empty($res)) {
                        $this->modelError = "数据不存在";
                        return false;
                    }
                }
                $data = $this->filterField($data);
                static::where($idName, $data[$idName])->update($data);
                if (!$isModel) {
                    $res = $this->queryChain($data[$idName], 'and', $queryType)->find();
                } else {
                    return $this;
                }
            }
            if (empty($res)) {
                return [];
            }
            $data = $this->hiddenField($res->getData());
            if (isset($data['create_time'])) {
                $data['create_time'] = $this->formatTime($data['create_time']);
            }
            if (isset($data['update_time'])) {
                $data['update_time'] = $this->formatTime($data['update_time']);
            }
            return $data;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 更新指定字段值（支持主键更新）
     *
     * @param array|string|int|callable $where 条件数组 或 主键id值
     * @param string|array $field 字段名 或 字段数组[field1=>value1, field2=>value2]
     * @param null|string $value 字段值（更新单一字段时有效）
     * @return bool
     */
    public function updateField($where = [], $field = "", $value = null)
    {
        try {
            if (empty($where) || empty($field)) {
                $this->modelError = "where OR field is not empty";
                return false;
            }
            $idName = $this->parsePk();
            if (empty($idName) && !(is_array($where) || $where instanceof \Closure) && $where !== "*") {
                $this->modelError = "未设置主键，无法根据主键更新";
                return false;
            }
            $model = $this->genBaseModel($where, $idName);
            if (is_array($field)) {
                $res = $model->update($field);
            } else {
                $res = $model->update([$field => $value]);
            }
            if ($res) {
                return true;
            } elseif ($model->find()) {
                return true;
            }
            $this->modelError = "查询不到相关数据";
            return false;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 指定字段自增（支持主键查询）
     *
     * @param array|string|int|callable $where 条件数组 或 主键id值
     * @param string $field 字段名
     * @param int|float $step 自增/步进值 默认1
     * @return bool
     */
    public function fieldInc($where = [], string $field = "", $step = 1)
    {
        try {
            $model = $this->genStepModel($where, $field, $step);
            if ($model === false) {
                return false;
            }
            $res = $model['model']->inc($field, $model['step'])->update();
            if ($res) {
                return true;
            }
            $this->modelError = "步进处理失败";
            return false;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 指定字段自减（支持主键查询）
     *
     * @param array|string|int|callable $where 条件数组 或 主键id值
     * @param string $field 字段名
     * @param int|float $step 自增/步进值 默认1
     * @return bool
     */
    public function fieldDec($where = [], string $field = "", $step = 1)
    {
        try {
            $model = $this->genStepModel($where, $field, $step);
            if ($model === false) {
                return false;
            }
            $res = $model['model']->dec($field, $model['step'])->update();
            if ($res) {
                return true;
            }
            $this->modelError = "步进处理失败";
            return false;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 多字段自增/自减（支持主键查询，支持多字段步进处理）
     *
     * @param array|string|int|callable $where 条件数组 或 主键id值
     * @param array $fields 字段二维数组 [[field1,inc,step1],[field2,dec,step2]]
     * @return bool
     */
    public function fieldStep($where = [], array $fields = [])
    {
        try {
            if (empty($where) || empty($fields)) {
                $this->modelError = "where OR field is not empty";
                return false;
            }
            $stepAllow = ["inc", "dec"];
            $allowType = [
                'tinyint',
                'smallint',
                'mediumint',
                'int',
                'integer',
                'bigint',
                'float',
                'double',
                'decimal'
            ];
            $idName    = $this->parsePk();
            if (empty($idName) && !(is_array($where) || $where instanceof \Closure) && $where !== "*") {
                $this->modelError = "未设置主键，无法根据主键更新";
                return false;
            }
            $model      = $this->genBaseModel($where, $idName);
            $fieldLevel = $this->arrayLevel($fields);
            if ($fieldLevel == 1) {
                if (empty($fields[1]) || !in_array($fields[1], $stepAllow)) {
                    $this->modelError = "fields param error";
                    return false;
                }
                if (empty($fields[2]) || !is_numeric($fields[2]) || (float)$fields[2] <= 0) {
                    $this->modelError = "step must be numeric and > 0";
                    return false;
                }
                if (!empty($this->schema[$fields[0]])) {
                    if (!in_array($this->schema[$fields[0]], $allowType)) {
                        $this->modelError = "field format error, must be numeric type";
                        return false;
                    }
                }
                $field       = $fields[0];
                $stepOperate = $fields[1];
                $step        = (float)$fields[2];
                $res         = $model->$stepOperate($field, $step)->update();
                if ($res) {
                    return true;
                }
            } elseif ($fieldLevel == 2) {
                foreach ($fields as $item) {
                    if (empty($item[1]) || !in_array($item[1], $stepAllow)) {
                        $this->modelError = "fields param error";
                        return false;
                    }
                    if (empty($item[2]) || !is_numeric($item[2]) || (float)$item[2] <= 0) {
                        $this->modelError = "step must be numeric and > 0";
                        return false;
                    }
                    if (!empty($this->schema[$item[0]])) {
                        if (!in_array($this->schema[$item[0]], $allowType)) {
                            $this->modelError = "field format error, must be numeric type";
                            return false;
                        }
                    }
                    $field       = $item[0];
                    $stepOperate = $item[1];
                    $step        = (float)$item[2];
                    $model       = $model->$stepOperate($field, $step);
                }
                $res = $model->update([]);
                if (!$res) {
                    $this->modelError = "步进处理失败";
                    return false;
                }
                return true;
            }
            $this->modelError = "步进处理失败";
            return false;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 多条件批量更新（支持主键批量更新）
     *
     * @param array|string|int|callable $where 1、条件数组 条件闭包 或 主键id值【多条件批量更新】
     *                                         2、带主键id的待更新二维数组（data不传时有效）【主键批量更新】
     *
     * @param array $data 1、需要更新的字段键值对数组['field1'=>'value1','field2'=>'value2'] 【多条件批量更新】
     *                    2、不传【主键批量更新】
     *
     * @param string $isOr 是否是 OR 查询 默认 AND（多条件批量更新有效）
     * @return bool|int|\think\Model|void 成功·返回更新成功的记录数，失败·返回false
     */
    public function updateAll($where = [], array $data = [], string $isOr = "and")
    {
        try {
            $this->modelData = [];
            if (empty($where) && empty($data)) {
                $this->modelError = "where OR data is not empty";
                return false;
            } elseif (empty($where) && !empty($data)) {
                $this->modelError = "where is not empty";
                return false;
            } elseif (!empty($where) && is_array($where) && empty($data)) {
                // 主键批量更新
                $level = $this->arrayLevel($where);
                if ($level == 2) {
                    $idName = $this->getPk();
                    $ids    = [];
                    foreach ($where as $item) {
                        if (!array_key_exists($idName, $item)) {
                            $this->modelError = "请传入主键id";
                            return false;
                        }
                        array_push($ids, $item[$idName]);
                    }
                    // 校验数据是否存在
                    $exist = self::where($idName, "in", $ids)->column($idName);
                    if (empty($exist)) {
                        $this->modelError = "更新失败，查询不到相关数据";
                        return false;
                    }
                    $saveData = [];
                    foreach ($where as $item) {
                        if (in_array($item[$idName], $exist)) {
                            array_push($saveData, $item);
                        }
                    }
                    return self::saveAll($saveData)->count();
                }
                $this->modelError = "data is not empty";
                return false;
            }
            // 多条件批量更新
            $idName = $this->getPk();
            $level  = $this->arrayLevel($data);
            $model  = $this->genBaseModel($where, $idName, $isOr);
            if ($level == 1) {
                if (is_array($where)) {
                    $ids = $model->column($idName);
                    if (empty($ids)) {
                        $this->modelError = "更新失败，查询不到相关数据";
                        return false;
                    }
                    $saveData = [];
                    foreach ($ids as $id) {
                        $data[$idName] = $id;
                        array_push($saveData, $data);
                    }
                    return self::saveAll($saveData)->count();
                } else {
                    $data = $this->filterField($data, true);
                    return $model->update($data);
                }
            }
            $this->modelError = "更新失败，请检查data数据格式";
            return false;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 多条件批量更新（原生where查询）
     *
     * @param string $where 查询条件原生SQL字符串
     * @param array $data 需要更新的字段键值对数组['field1'=>'value1','field2'=>'value2']
     * @param array $bind 参数绑定
     * @return bool|int|void 成功·返回更新成功的记录数，失败·返回false
     */
    public function updateAllRaw(string $where = "", array $data = [], array $bind = [])
    {
        try {
            $this->modelData = [];
            if (empty($where) || empty($data)) {
                $this->modelError = "where OR data is not empty";
                return false;
            }
            $idName = $this->getPk();
            $level  = $this->arrayLevel($data);
            if ($level == 1) {
                $model = self::whereRaw($where, $bind);
                $ids   = $model->column($idName);
                if (empty($ids)) {
                    $this->modelError = "更新失败，查询不到相关数据";
                    return false;
                }
                $saveData = [];
                foreach ($ids as $id) {
                    $data[$idName] = $id;
                    array_push($saveData, $data);
                }
                return self::saveAll($saveData)->count();
            }
            $this->modelError = "更新失败，请检查data数据格式";
            return false;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 删除数据（支持主键删除，支持多条件删除，支持软删除）
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值
     *
     * @param bool $isTrueDel 是否是真删除 默认 false
     *                     软删除说明：1、优先根据对应的模型层配置的软删除字段名 protected $deleteTime = 'delete_time' 判断；
     *                                   并需要在对应的模型层配置软删除字段数据类型 protected $deleteTimeType = 'timestamp'；
     *                                   软删除字段类型支持：timestamp datetime year date time int 数据库字段类型；
     *                                   【注意：以上两个参数不设置 且 数据表也不存在delete_time字段，将默认真实删除】
     *
     *                                2、【推荐】你的数据库定义软删除字段名为 delete_time 骨架会自动根据模型实体类判断时间类型；
     *                                   并自动写入软删除数据，并不需要配置以上 $deleteTime 和 $deleteTimeType；（除非你有自定义软删除字段名的需求）
     *
     *                                3、特别声明：使用remove方法，并不需要 添加引用tp自带的软删除Trait use SoftDelete；（除非你需要使用其中的方法）
     *
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @return bool 返回删除成功的记录数
     * @throws \Exception
     */
    public function remove($where = [], bool $isTrueDel = false, string $isOr = "and")
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $idName = $this->parsePk();
            if (empty($idName) && !(is_array($where) || $where instanceof \Closure) && $where !== "*") {
                $this->modelError = "未设置主键，无法根据主键删除";
                return false;
            }
            $deleteTimeField = '';
            $time            = '';
            $dbTimeType      = ['timestamp', 'datetime', 'year', 'date', 'time', 'int'];
            $model           = $this->genBaseModel($where, $idName, $isOr);
            // 软删除判断
            if (!empty($this->deleteTime) && is_string($this->deleteTime) && !$isTrueDel) {
                $deleteTimeField = $this->deleteTime;
                if (!empty($this->deleteTimeType) && is_string($this->deleteTimeType)) {
                    $time = $this->genDateTime($this->deleteTimeType);
                } else {
                    if (in_array('think\model\concern\SoftDelete', $this->getTraitName())) {
                        $data   = $model->select();
                        $delNum = $data->count();
                        $data->delete();
                        return $delNum;
                    } elseif (isset($this->schema[$deleteTimeField]) && in_array(
                        $this->schema[$deleteTimeField],
                        $dbTimeType
                    )) {
                        $time = $this->genDateTime($this->schema[$deleteTimeField]);
                    } elseif (isset($this->schema['delete_time'])) {
                        $deleteTimeField = 'delete_time';
                        $time            = $this->genDateTime($this->schema['delete_time']);
                    } else {
                        $this->modelError = "请查看是否配置 deleteTimeType 属性";
                        return false;
                    }
                }
            } elseif (isset($this->schema['delete_time']) && !$isTrueDel) {
                $deleteTimeField = 'delete_time';
                $time            = $this->genDateTime($this->schema['delete_time']);
            } else {
                $isTrueDel = true;
            }
            if (!$isTrueDel) {
                // 软删除
                return $model->useSoftDelete($deleteTimeField, $time)->delete();
            } else {
                // 强制删除（删除数据的范围包含已经软删除过的数据）
                if (in_array('think\model\concern\SoftDelete', $this->getTraitName())) {
                    $modelName = static::class;
                    $baseModel = $modelName::withTrashed();
                    if (strtolower($isOr) === "or") {
                        $model = is_array($where) || $where instanceof \Closure ? $baseModel->whereOr($where)
                            : $baseModel->where($idName, $where);
                    } else {
                        $model = is_array($where) || $where instanceof \Closure ? $baseModel->where($where)
                            : $baseModel->where($idName, $where);
                    }
                    $ids    = $model->column($idName);
                    $delNum = count($ids);
                    if (!empty($this->table) && is_string($this->table) && $delNum > 0) {
                        $idsStr = implode("','", $ids);
                        Db::execute("DELETE FROM {$this->table} WHERE {$idName} IN ('{$idsStr}')");
                        return $delNum;
                    } else {
                        return 0;
                    }
                }
                return $model->delete();
            }
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 恢复软删除数据
     *
     * @param array $where
     * @param string $isOr
     * @return bool|int|\think\Model
     */
    public function recoverDel($where = [], string $isOr = "and")
    {
        try {
            $idName = $this->getPk();
            $ids    = $this->queryChain($where, $isOr, MethodEnum::ONLY_SOFT)->column($idName);
            if (count($ids) > 0) {
                $deleteTimeField = "";
                if (!empty($this->deleteTime) && is_string($this->deleteTime)) {
                    $deleteTimeField = $this->deleteTime;
                } elseif (isset($this->schema['delete_time'])) {
                    $deleteTimeField = 'delete_time';
                }
                if (!empty($deleteTimeField)) {
                    return static::where($idName, "in", $ids)->update([$deleteTimeField => null]);
                }
            }
            return 0;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 删除数据（原生where查询，不支持直接传入主键id值删除，其他规则同remove）
     *
     * @param string $where 查询条件原生SQL字符串
     * @param bool $isTrueDel 是否是真删除 默认 false
     * @param array $bind 参数绑定
     * @return bool|int|void 返回删除成功的记录数
     */
    public function removeRaw(string $where = "", $isTrueDel = false, array $bind = [])
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $idName          = $this->getPk();
            $deleteTimeField = '';
            $time            = '';
            $dbTimeType      = ['timestamp', 'datetime', 'year', 'date', 'time', 'int'];
            $model           = self::whereRaw($where, $bind);
            // 软删除判断
            if (!empty($this->deleteTime) && is_string($this->deleteTime) && !$isTrueDel) {
                $deleteTimeField = $this->deleteTime;
                if (!empty($this->deleteTimeType) && is_string($this->deleteTimeType)) {
                    $time = $this->genDateTime($this->deleteTimeType);
                } else {
                    if (in_array('think\model\concern\SoftDelete', $this->getTraitName())) {
                        $data   = $model->select();
                        $delNum = $data->count();
                        $data->delete();
                        return $delNum;
                    } elseif (isset($this->schema[$deleteTimeField]) && in_array(
                        $this->schema[$deleteTimeField],
                        $dbTimeType
                    )) {
                        $time = $this->genDateTime($this->schema[$deleteTimeField]);
                    } elseif (isset($this->schema['delete_time'])) {
                        $deleteTimeField = 'delete_time';
                        $time            = $this->genDateTime($this->schema['delete_time']);
                    } else {
                        $this->modelError = "请查看是否配置 deleteTimeType 属性";
                        return false;
                    }
                }
            } elseif (isset($this->schema['delete_time']) && !$isTrueDel) {
                $deleteTimeField = 'delete_time';
                $time            = $this->genDateTime($this->schema['delete_time']);
            } else {
                $isTrueDel = true;
            }
            if (!$isTrueDel) {
                // 软删除
                return $model->useSoftDelete($deleteTimeField, $time)->delete();
            } else {
                // 强制删除（删除数据的范围包含已经软删除过的数据）
                if (in_array('think\model\concern\SoftDelete', $this->getTraitName())) {
                    $modelName = static::class;
                    $baseModel = $modelName::withTrashed();
                    $model     = $baseModel->whereRaw($where, $bind);
                    $ids       = $model->column($idName);
                    $delNum    = count($ids);
                    if (!empty($this->table) && is_string($this->table) && $delNum > 0) {
                        $idsStr = implode("','", $ids);
                        Db::execute("DELETE FROM {$this->table} WHERE {$idName} IN ('{$idsStr}')");
                        return $delNum;
                    } else {
                        return 0;
                    }
                }
                return $model->delete();
            }
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询链式（支持主键查询，支持TP链式操作，融合软删除）
     *
     * Tips：如果使用BaseModel的remove软删除，可以不需要引用TP的use SoftDelete；
     *       但使用原始的TP链式操作时会默认返回包含软删除的数据，所以提供此前置链式查询操作来自动过滤软删除数据；
     *       我们只需要在对应的Model使用 $this->queryChain() 开头进行链式操作，即可自动过滤软删除数据；
     *       同样还提供 queryType 类型参数来帮助我们判断过滤条件
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param string $queryType 过滤条件 excludeSoft（默认排除软删除数据）withSoft（包含软删除数据）onlySoft（仅查询软删除数据）
     * @return bool|\think\Model 返回当前Model对象，可使用TP的链式操作继续构造查询
     */
    public function queryChain($where = [], string $isOr = "and", string $queryType = MethodEnum::EXCLUDE_SOFT)
    {
        try {
            $idName = $this->getPk();
            $model  = $this->genBaseModel($where, $idName, $isOr);
            $model  = $this->filterSoftDelData($model, $queryType);
            return $model;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询字段值（支持主键查询，支持select查询返回二维数组，默认find查询）
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值
     * @param array $field 查询的字段数组 或 原生SQL过滤字段语句（支持原生SQL函数，此参数不传默认查询所有）
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $withSoft 是否查询包含软删除的数据
     * @param bool $isSelect 是否是 select 查询 默认 false
     * @return array|string|bool|null 返回结果数组或NULL（如果是find查询的field仅为一个字段，将直接返回该字段的值，相当于TP的value方法）
     */
    public function findField($where = [], $field = [], string $isOr = "and", $withSoft = false, bool $isSelect = false)
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $idName    = $this->getPk();
            $model     = $this->genBaseModel($where, $idName, $isOr);
            $queryType = MethodEnum::EXCLUDE_SOFT;
            if ($withSoft) {
                $queryType = MethodEnum::WITH_SOFT;
            }
            $model = $this->filterSoftDelData($model, $queryType);
            $model = is_array($field) || $field === true ? $model->field($field) : $model->fieldRaw((string)$field);
            if ($isSelect) {
                $data = $model->limit(1)->select();
                $this->setModelData($data);
                $all = $this->buildReturn($data);
            } else {
                $data = $model->find();
                if ($data !== null) {
                    $this->setModelData($data, true);
                    $all = $data->toArray();
                    if (count($all) == 1 && count($this->modelData) == 1) {
                        $all = $all[array_keys($all)[0]];
                    }
                    if (empty($all)) {
                        $all = null;
                    }
                } else {
                    $all = null;
                }
            }
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询一条（支持主键查询，支持select查询返回二维数组，默认select查询）
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值
     * @param array $order 原生排序SQL语句 或 数组 如：['price','id'=>'desc'] 生成的SQL为 ORDER BY `price`,`id` desc
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isFind 是否是 find 查询 默认 false
     * @return array|bool|null 返回结果数组
     */
    public function selectOne($where = [], $order = [], string $isOr = "and", bool $isFind = false)
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $model = $this->queryChain($where, $isOr);
            $model = is_array($order) ? $model->order($order)->limit(1) : $model->orderRaw((string)$order)->limit(1);
            if (!$isFind) {
                $data = $model->select();
                $this->setModelData($data);
                $all = $this->buildReturn($data);
            } else {
                $data = $model->find();
                $this->setModelData($data, true);
                $all = $this->buildReturn($data);
            }
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询所有（支持主键查询，支持排除字段）
     *
     * Tips：如果我希望获取排除数据表中的content字段（文本字段的值非常耗内存）之外的所有字段值，
     *       我们就可以使用$withoutField参数传入需要排除的字段
     *       注意：字段排除功能不支持跨表和join操作。
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值
     * @param array $withoutField 需要排除的字段名（支持数组或字符串"field1,field2"形式）
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false ，一般此查询用于查全部数据的，我们已经提供了带分页的查询快捷方法 selectList）
     * @return array|bool|\think\Model 返回结果数组
     */
    public function selectAll($where = [], $withoutField = [], string $isOr = "and", bool $isModel = false)
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $model = $this->queryChain($where, $isOr);
            $model = $model->withoutField($withoutField);
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询排序（支持主键查询，支持原生SQL语句Order排序，支持Limit限制条数）
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值
     * @param array $order 原生排序SQL语句 或 数组 如：['price','id'=>'desc'] 生成的SQL为 ORDER BY `price`,`id` desc
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param string $limit 限制条数 默认 * 不限制
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回结果数组
     */
    public function selectSort($where = [], $order = [], string $isOr = "and", $limit = "*", bool $isModel = false)
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $model = $this->queryChain($where, $isOr);
            $model = is_array($order) ? $model->order($order) : $model->orderRaw((string)$order);
            if ($limit === "*") {
            } else {
                $model = $model->limit((int)$limit);
            }
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询List（支持分页，支持each回调）
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array|string $order 原生排序SQL语句 或 数组 如：['price','id'=>'desc'] 生成的SQL为 ORDER BY `price`,`id` desc
     * @param callable|null $each 闭包回调函数（有些情况下我们需要对于查询出来的分页数据进行循环处理，通过each传入闭包处理函数即可）
     * @param int $pageLimit 分页每页显示记录数  默认 0 自动取 PaginateEnum 枚举类配置的条数
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @return array|bool 返回 查询后的分页数据
     */
    public function selectList(
        $where = [],
        $order = [],
        callable $each = null,
        int $pageLimit = 0,
        string $isOr = "and"
    ) {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $model      = $this->queryChain($where, $isOr);
            $model      = is_array($order) ? $model->order($order) : $model->orderRaw((string)$order);
            $pageConfig = $this->getPaginateConfig($pageLimit);
            if (!empty($each)) {
                $data = $model->paginate($pageConfig, false)->each($each);
            } else {
                $data = $model->paginate($pageConfig, false);
            }
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询首条数据（支持前Limit条）
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值（如果需要查询整张表全部数据的首条，可以传*）
     * @param int $limit 限制条数 默认 1
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @return array|bool 返回首条数据或前N条数据，如果Limit一条数据将直接返回该条数据的值
     */
    public function selectFirst($where = [], int $limit = 1, string $isOr = "and")
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $idName = $this->parsePk();
            $model  = $this->queryChain($where, $isOr);
            if (!empty($idName)) {
                $order = [$idName => "asc"];
            } else {
                $order = [];
            }
            if (isset($this->schema['create_time'])) {
                $order['create_time'] = "asc";
            }
            $data = $model->order($order)->limit((int)$limit)->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            if (!empty($all) && count($all) == 1 && $limit == 1) {
                $this->modelData = isset($this->modelData[0]) ? $this->modelData[0] : [];
                $all             = $all[0];
            }
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询最后一条数据（支持后Limit条）
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值（如果需要查询整张表全部数据的最后一条，可以传*）
     * @param int $limit 限制条数 默认 1
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @return array|bool 返回结果的最后一条数据或后N条数据，如果Limit一条数据将直接返回该条数据的值
     */
    public function selectEnd($where = [], int $limit = 1, string $isOr = "and")
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $idName = $this->parsePk();
            $model  = $this->queryChain($where, $isOr);
            if (!empty($idName)) {
                $order = [$idName => "desc"];
            } else {
                $order = [];
            }
            if (isset($this->schema['create_time'])) {
                $order['create_time'] = "desc";
            }
            if (isset($this->schema['update_time'])) {
                $order['update_time'] = "desc";
            }
            if (empty($order)) {
                if (!empty($this->schema) && is_array($this->schema)) {
                    $order = [array_keys($this->schema)[0] => "desc"];
                } else {
                    $this->modelError = "未设置主键，无法根据主键排序";
                    return false;
                }
            }
            $data = $model->order($order)->limit((int)$limit)->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            if (!empty($all) && count($all) == 1 && $limit == 1) {
                $this->modelData = isset($this->modelData[0]) ? $this->modelData[0] : [];
                $all             = $all[0];
            }
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 满足条件的数据随机返回（支持随机取Limit条）
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值（如果需要查询整张表全部数据的随机条数，可以传*）
     * @param int $limit 限制条数 默认 1
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @return array|bool 返回结果的随机N条数据，如果Limit一条数据将直接返回该条数据的值
     */
    public function selectRand($where = [], int $limit = 1, string $isOr = "and")
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $model = $this->queryChain($where, $isOr);
            $order = "RAND()";
            $data  = $model->orderRaw($order)->limit((int)$limit)->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            if (!empty($all) && count($all) == 1 && $limit == 1) {
                $this->modelData = isset($this->modelData[0]) ? $this->modelData[0] : [];
                $all             = $all[0];
            }
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询某个字段的值相同的数据（同一张表指定字段值相同的数据，支持结果排序）
     *
     * @param string|int $whereId 主键id
     * @param string $field 指定字段名
     * @param array|string $order 原生排序SQL语句 或 数组 如：['price','id'=>'desc'] 生成的SQL为 ORDER BY `price`,`id` desc
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回与主键id对应的字段值数据相同的数据（包含主键id数据）
     */
    public function selectSameField($whereId = "", string $field = "", $order = [], bool $isModel = false)
    {
        try {
            if (empty($whereId) || is_array($whereId) || empty($field)) {
                $this->modelError = "where OR field error";
                return false;
            }
            $idName    = $this->getPk();
            $baseWhere = [
                [
                    $field,
                    "in",
                    function ($query) use ($whereId, $idName, $field) {
                        $query->table($this->getTable())->field($field)->where($idName, $whereId)->find();
                    }
                ]
            ];
            $model     = static::where($baseWhere);
            $model     = $this->filterSoftDelData($model);
            $model     = is_array($order) ? $model->order($order) : $model->orderRaw((string)$order);
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询指定字段值重复的记录（支持多字段匹配，支持结果排序）
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array $field 字段数组[field1,field2...]
     * @param array|string $order 原生排序SQL语句 或 数组 如：['price','id'=>'desc'] 生成的SQL为 ORDER BY `price`,`id` desc
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回重复的记录数据
     */
    public function selectRepeat(
        $where = [],
        array $field = [],
        $order = [],
        string $isOr = "and",
        bool $isModel = false
    ) {
        try {
            if (empty($where) || empty($field)) {
                $this->modelError = "where OR field is not empty";
                return false;
            }
            $idName = $this->getPk();
            $model  = $this->genBaseModel($where, $idName, $isOr);
            if ($this->arrayLevel($field) == 1) {
                $field = implode(",", $field);
            } else {
                $this->modelError = "field error";
                return false;
            }
            $repeatWhere = "(" . $field . ") IN (SELECT " . $field . " FROM " . $this->getTable() . " GROUP BY " . $field . " HAVING COUNT(*)>1)";
            $model       = $this->filterSoftDelData($model)->whereRaw($repeatWhere);
            $model       = is_array($order) ? $model->order($order) : $model->orderRaw((string)$order);
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询指定字段值不重复的记录【仅查询不重复的】（支持多字段匹配，支持结果排序）
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array $field 字段数组[field1,field2...]
     * @param array|string $order 原生排序SQL语句 或 数组 如：['price','id'=>'desc'] 生成的SQL为 ORDER BY `price`,`id` desc
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回不重复的记录数据
     */
    public function selectNoRepeat(
        $where = [],
        array $field = [],
        $order = [],
        string $isOr = "and",
        bool $isModel = false
    ) {
        try {
            if (empty($where) || empty($field)) {
                $this->modelError = "where OR field is not empty";
                return false;
            }
            $idName = $this->getPk();
            $model  = $this->genBaseModel($where, $idName, $isOr);
            if ($this->arrayLevel($field) == 1) {
                $field = implode(",", $field);
            } else {
                $this->modelError = "field error";
                return false;
            }
            $repeatWhere = "(" . $field . ") IN (SELECT " . $field . " FROM " . $this->getTable() . " GROUP BY " . $field . " HAVING COUNT(*)=1)";
            $model       = $this->filterSoftDelData($model)->whereRaw($repeatWhere);
            $model       = is_array($order) ? $model->order($order) : $model->orderRaw((string)$order);
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * FIND_IN_SET查询（查询指定字段包含指定的值或字符串的数据集合）
     *
     * Tips：应用场景 常用于判断类型或筛选权限等场景，例如 有个文章表里面有个type字段，它存储的是文章类型，有 1头条、2推荐、3热点、4图文等等
     *               现在有篇文章他既是头条，又是热点，还是图文，type中以 1,3,4 的格式存储。我们就可以使用此方法进行查询所有type中有4的图文类型的文章。
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值（如果需要查询整张表全部数据，可以传*）
     * @param array $fieldAndVal 字段与值数组[field=>value]（value必须是string或int型）
     * @param array|string $order 原生排序SQL语句 或 数组 如：['price','id'=>'desc'] 生成的SQL为 ORDER BY `price`,`id` desc
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回满足条件的数组
     */
    public function selectFieldInSet(
        $where = [],
        array $fieldAndVal = [],
        $order = [],
        string $isOr = "and",
        bool $isModel = false
    ) {
        try {
            if (empty($where) || empty($fieldAndVal)) {
                $this->modelError = "where OR fieldAndVal is not empty";
                return false;
            }
            $idName = $this->getPk();
            $model  = $this->genBaseModel($where, $idName, $isOr);
            $field  = array_keys($fieldAndVal)[0];
            $value  = $fieldAndVal[$field];
            $model  = $this->filterSoftDelData($model)->whereFindInSet($field, $value);
            $model  = is_array($order) ? $model->order($order) : $model->orderRaw((string)$order);
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * FIND_IN_SET查询（查询指定字段在指定的集合的数据集合，效果类似于 field in (1,2,3,4,5) 的用法）
     *
     * @param array|string|int|callable $where 条件数组 条件闭包 或 主键id值（如果需要查询整张表全部数据，可以传*）
     * @param array $fieldAndVal 字段与值数组[field=>value]（value支持数组，如：[1,2,3,4,5]）
     * @param array|string $order 原生排序SQL语句 或 数组 如：['price','id'=>'desc'] 生成的SQL为 ORDER BY `price`,`id` desc
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回满足条件的数组
     */
    public function selectFieldInList(
        $where = [],
        array $fieldAndVal = [],
        $order = [],
        string $isOr = "and",
        bool $isModel = false
    ) {
        try {
            if (empty($where) || empty($fieldAndVal)) {
                $this->modelError = "where OR fieldAndVal is not empty";
                return false;
            }
            $idName = $this->getPk();
            $model  = $this->genBaseModel($where, $idName, $isOr);
            $field  = array_keys($fieldAndVal)[0];
            $value  = $fieldAndVal[$field];
            if (is_array($value)) {
                $value = implode(",", $value);
            }
            $whereRaw = "FIND_IN_SET(" . $field . ",:val)";
            $model    = $this->filterSoftDelData($model)->whereRaw($whereRaw, ["val" => $value]);
            $model    = is_array($order) ? $model->order($order) : $model->orderRaw((string)$order);
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 查询列（支持指定字段的值作为索引）
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array|string $field 要筛选的列数组 或 字符串（多个用逗号隔开）
     * @param string $index 指定用哪个字段当索引
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @return array|bool 返回 查询后的数据
     */
    public function selectColumn($where = [], $field = [], string $index = "", string $isOr = "and")
    {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $idName = $this->getPk();
            $model  = $this->queryChain($where, $isOr);
            if (is_array($field) && !empty($field)) {
                $field = implode(",", $field);
            } elseif (empty($field) && empty($index)) {
                $field = "*";
                $index = $idName;
            } elseif (empty($field)) {
                $field = "*";
            }
            return $this->hiddenField($model->column($field, $index));
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    // 联查相关

    /**
     * 设置基础查询条件（用于简化基础alias、join和主表field）
     *
     * @param string $alias 当前模型别名 示例：在order模型中联查order_goods表，此字段写 order
     * @param array|string $field 当前模型主表字段集合[field1,field2...]（主表字段不需要带别名，传 [] 或 * 都视为查询全部）
     *
     * @param array $join 连接的表 示例：此字段写二维数组 [['order_goods og', 'order_id', 'id'],...] 允许多个表联查
     *
     *                            参数说明：1、每个第二维的数组都表示一张联查表，下面的说明，括号为可选
     *                                        ['联查表 (别名)', '联查表外键字段', ('主表主键字段'), ('连接类型')]
     *
     *                                     2、如果你的主键与外键的字段名一致的话，可以省略第三个参数
     *                                        以上第三个【主表主键字段】参数不传，默认使用【联查表外键字段】进行联查
     *                                        第四个参数为【连接类型】，主要用于多张表不同连接类型的情况，优先级高于$type参数
     *
     *                                     3、完整调用示例
     *                                        $orderModel = new OrderDao();
     *                                        // 联查一张表（$join 可省略为一维数组）
     *                                        $res = $orderModel->setBaseQuery("a", "*", ["order_goods b","order_id","id"], "leftJoin")
     *                                                  ->where("a.id", ">", 1)->select();
     *                                        // 联查多张表
     *                                        $res = $orderModel->setBaseQuery("a", "*", [
     *                                            ["order_goods b", "order_id", "id"],
     *                                            ["user c", "user_id"],
     *                                        ], "leftJoin")->where("id", ">", 1)->select();
     *                                        // 还可以通过链式操作->field('b.goods_name')来筛选联查表的对应的字段值
     *                                        $res = $orderModel->setBaseQuery("a", "*", ["order_goods b","order_id","id"], "leftJoin")
     *                                                  ->field('b.goods_name')->where("a.id", ">", 1)->select();
     *
     * @param string $type 连接类型 join leftJoin rightJoin fullJoin 默认 join
     * @return bool|\think\Model 返回联查基本模型对象
     */
    public function setBaseQuery(string $alias = '', $field = [], array $join = [], string $type = "join")
    {
        try {
            // 设置别名
            $default    = !empty($this->table) ? $this->table : "this";
            $aliasValue = $alias ?: $default;
            if (is_array($field) && !empty($field)) {
                if (count($field) > 1) {
                    $field = $aliasValue . "." . implode("," . $aliasValue . ".", $field);
                } else {
                    $field = $aliasValue . "." . $field[0];
                }
            } elseif ($field === false) {
                $field = [];
            } else {
                $field = "{$aliasValue}.*";
            }
            $model = static::alias($aliasValue)->field($field);
            // join条件
            if (!empty($join)) {
                $allowType = ['join', 'leftJoin', 'rightJoin', 'fullJoin'];
                $type      = in_array((string)$type, $allowType) ? $type : 'join';
                if ($this->arrayLevel($join) == 1) {
                    if (preg_match("/( |　|\s)/", $join[0])) {
                        // 带别名
                        $tb      = @explode(" ", $join[0])[0];
                        $tbAlias = @explode(" ", $join[0])[1];
                    } else {
                        // 不带别名
                        $tb = $tbAlias = $join[0];
                    }
                    if (isset($join[3]) && in_array((string)$join[3], $allowType)) {
                        $type = $join[3];
                    }
                    $model->$type($join[0], "{$tbAlias}.{$join[1]}={$aliasValue}."
                        . (isset($join[2]) ? $join[2] : $join[1]));
                    // 联查表软删除过滤
                    $className = "app\\model\\entity\\" . ucfirst($this->toHumpScore($tb));
                    if (class_exists($className)) {
                        ${$tb . "Class"} = new $className;
                        $model           = $this->filterSoftDelData(
                            $model,
                            MethodEnum::EXCLUDE_SOFT,
                            $tbAlias,
                            ${$tb . "Class"}
                        );
                    }
                } else {
                    foreach ($join as $item) {
                        if (preg_match("/( |　|\s)/", $item[0])) {
                            // 带别名
                            $tb      = @explode(" ", $item[0])[0];
                            $tbAlias = @explode(" ", $item[0])[1];
                        } else {
                            // 不带别名
                            $tb = $tbAlias = $item[0];
                        }
                        if (isset($item[3]) && in_array((string)$item[3], $allowType)) {
                            $type = $item[3];
                        }
                        $model->$type($item[0], "{$tbAlias}.{$item[1]}={$aliasValue}."
                            . (isset($item[2]) ? $item[2] : $item[1]));
                        // 联查表软删除过滤
                        $className = "app\\model\\entity\\" . ucfirst($this->toHumpScore($tb));
                        if (class_exists($className)) {
                            ${$tb . "Class"} = new $className;
                            $model           = $this->filterSoftDelData(
                                $model,
                                MethodEnum::EXCLUDE_SOFT,
                                $tbAlias,
                                ${$tb . "Class"}
                            );
                        }
                    }
                }
            }
            // 主表软删除过滤
            $model = $this->filterSoftDelData($model, MethodEnum::EXCLUDE_SOFT, $aliasValue);
            return $model;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * Join联查(innerJoin，如果表中有至少一个匹配，则返回行)
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array|string $fields 字段数组 或 字段字符串（多个用逗号隔开，主表别名统一默认为字符串“this”，主表字段筛选，统一使用“this.字段名”）
     * @param array $join 连接的表 规则同上述 setBaseQuery 方法的参数 join
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回查询结果
     */
    public function selectJoin(
        $where = [],
        $fields = [],
        array $join = [],
        string $isOr = "and",
        bool $isModel = false
    ) {
        try {
            $model = $this->baseJoin($where, $fields, $join, $isOr);
            if ($model === false) {
                return false;
            }
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * leftJoin联查（即使右表中没有匹配，也从左表返回所有的行）
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array|string $fields 字段数组 或 字段字符串（多个用逗号隔开，主表别名统一默认为字符串“this”，主表字段筛选，统一使用“this.字段名”）
     * @param array $join 连接的表 规则同上述 setBaseQuery 方法的参数 join
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回查询结果
     */
    public function selectLeftJoin(
        $where = [],
        $fields = [],
        array $join = [],
        string $isOr = "and",
        bool $isModel = false
    ) {
        try {
            $model = $this->baseJoin($where, $fields, $join, $isOr, "leftJoin");
            if ($model === false) {
                return false;
            }
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * rightJoin联查（即使左表中没有匹配，也从右表返回所有的行）
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array|string $fields 字段数组 或 字段字符串（多个用逗号隔开，主表别名统一默认为字符串“this”，主表字段筛选，统一使用“this.字段名”）
     * @param array $join 连接的表 规则同上述 setBaseQuery 方法的参数 join
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回查询结果
     */
    public function selectRightJoin(
        $where = [],
        $fields = [],
        array $join = [],
        string $isOr = "and",
        bool $isModel = false
    ) {
        try {
            $model = $this->baseJoin($where, $fields, $join, $isOr, "rightJoin");
            if ($model === false) {
                return false;
            }
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * fullJoin联查（只要其中一个表中存在匹配，就返回行，Mysql数据库不支持）
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array|string $fields 字段数组 或 字段字符串（多个用逗号隔开，主表别名统一默认为字符串“this”，主表字段筛选，统一使用“this.字段名”）
     * @param array $join 连接的表 规则同上述 setBaseQuery 方法的参数 join
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isModel 是否返回Model对象（默认 false 如果返回Model对象，我们还可以链式调用TP的分页，进行分页操作）
     * @return array|bool|\think\Model 返回查询结果
     */
    public function selectFullJoin(
        $where = [],
        $fields = [],
        array $join = [],
        string $isOr = "and",
        bool $isModel = false
    ) {
        try {
            $model = $this->baseJoin($where, $fields, $join, $isOr, "fullJoin");
            if ($model === false) {
                return false;
            }
            if ($isModel) {
                return $model;
            }
            $data = $model->select();
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }

    /**
     * 一对多子查询（支持分页，支持主表、子表字段过滤，返回值类似TP的with查询返回）
     *
     * @param array|string|callable $where 条件数组 条件闭包（如果需要查询整张表全部数据，可以传*）
     * @param array $fields 字段数组（主表别名统一默认为字符串“this”，主表字段筛选，统一使用“this.字段名”）
     *
     * @param array $with 连接的子表 规则同上述 setBaseQuery 方法的参数 join 类似
     *                    释义：["子表名 (别名)", "子表关联字段", "(主表关联字段)"]
     *                    Tips：如果主表与子表关联字段名一样，第三个【主表关联字段名】参数可省略
     *
     * @param string $isOr 是否是 OR 查询 默认 AND
     * @param bool $isPaginate 是否分页
     * @param int $pageLimit 每页显示条数，默认 0 自动取 PaginateEnum 枚举类配置的条数
     * @return array|bool 返回关联查询数据结果数组，结构为二级关系，即子表数据会多条存放在以table_开头的字段中
     */
    public function selectChild(
        $where = [],
        array $fields = [],
        array $with = [],
        string $isOr = "and",
        bool $isPaginate = false,
        int $pageLimit = 0
    ) {
        try {
            if (empty($where)) {
                $this->modelError = "where is not empty";
                return false;
            }
            $alias    = "this";
            $idName   = $this->getPk();
            $isSelect = false;
            /**
             * @var mixed $where
             * @var array $whereNotNull
             * @var array $whereExp
             */
            extract($this->parseWhere($where));
            if (strtolower($isOr) === "or") {
                if (is_array($where) || $where instanceof \Closure) {
                    $model = static::alias($alias)->where(function ($query) use ($where, $whereNotNull, $whereExp) {
                        $query->whereOr($where);
                        if (!empty($whereNotNull)) {
                            foreach ($whereNotNull as $w) {
                                $query->whereOrRaw("`" . $w . '` IS NOT NULL');
                            }
                        }
                        if (!empty($whereExp)) {
                            $query->whereOr($whereExp);
                        }
                    });
                } else {
                    $model = static::alias($alias)->where("this." . $idName, $where);
                }
            } else {
                if (is_array($where) || $where instanceof \Closure) {
                    $model = static::alias($alias)->where($where);
                    if (!empty($whereNotNull)) {
                        foreach ($whereNotNull as $w) {
                            $model->whereNotNull($w);
                        }
                    }
                    if (!empty($whereExp)) {
                        $model->where($whereExp);
                    }
                } else {
                    $model = static::alias($alias)->where("this." . $idName, $where);
                }
            }
            if (!empty($with) && count($with) > 1) {
                // 过滤主表字段
                $mainField = [];
                if (is_array($fields) && !empty($fields) && $this->arrayLevel($fields) == 1) {
                    foreach ($fields as $k => $field) {
                        if ($field !== "this.*") {
                            $aliasStr = @substr($field, 0, 5);
                            if ($aliasStr === "this.") {
                                array_push($mainField, substr($field, 5));
                                unset($fields[$k]);
                            } elseif (!preg_match("/\./", $field) && isset($this->schema) && in_array(
                                $field,
                                array_keys($this->schema)
                            )) {
                                // 区分是否是主表字段
                                array_push($mainField, $field);
                                unset($fields[$k]);
                            }
                        } else {
                            array_push($mainField, "*");
                            unset($fields[$k]);
                        }
                    }
                } elseif (empty($fields)) {
                    $mainField = [];
                } elseif (!is_string($fields)) {
                    $this->modelError = "fields error";
                    return false;
                }
                $selectField = $fields;
                // 获取子表关联信息
                $foreignKey = is_string($with[1]) ? $with[1] : null;
                $mainKey    = isset($with[2]) && is_string($with[2]) ? $with[2] : $foreignKey;
                if (!in_array($mainKey, $mainField) && !in_array("this." . $mainKey, $mainField)) {
                    // 主表自动加入关联键
                    $mainField[] = "this." . $mainKey;
                }
                $with = is_string($with[0]) ? $with[0] : null;
                if (empty($with) || empty($foreignKey)) {
                    $this->modelError = "with error";
                    return false;
                }
                if (preg_match("/( |　|\s)/", $with)) {
                    // 带别名
                    $tb      = @explode(" ", $with)[0];
                    $tbAlias = @explode(" ", $with)[1];
                } else {
                    // 不带别名
                    $tb = $tbAlias = $with;
                }
                // 主查询
                $model = $model->field($mainField);
                $model = $this->filterSoftDelData($model, MethodEnum::EXCLUDE_SOFT, "this");
                if ($isPaginate) {
                    $pageConfig = $this->getPaginateConfig($pageLimit);
                    $mainObj    = $model->paginate($pageConfig, false);
                } else {
                    $mainObj = $model->select();
                }
                $isSelect = true;
                $child    = [];
                if (count($mainObj->toArray()) > 0) {
                    // 构造子查询
                    $mainKeyArray = array_filter($this->getSourceColumn($mainObj, $mainKey));
                    if (!empty($mainKeyArray)) {
                        $childClassDao = "app\\" . app('http')->getName() . "\\model\\" . ucfirst($this->toHumpScore($tb)) . "Dao";
                        if (class_exists($childClassDao)) {
                            $childClass = $childClassDao;
                        } else {
                            $childClass = "app\\model\\entity\\" . ucfirst($this->toHumpScore($tb));
                        }
                        if (class_exists($childClass)) {
                            if (!in_array($tbAlias . "." . $foreignKey, $selectField)
                                && !in_array($foreignKey, $selectField) && !empty($selectField)) {
                                $selectField[] = $tbAlias . "." . $foreignKey;
                            }
                            $child = $childClass::alias($tbAlias)->field($selectField)
                                ->where($foreignKey, "in", $mainKeyArray);
                            $child = $this->filterSoftDelData(
                                $child,
                                MethodEnum::EXCLUDE_SOFT,
                                $tbAlias,
                                new $childClass
                            );
                            $child = $child->select();
                            if (count($child->toArray()) > 0) {
                                // 拼装
                                $mainObj->each(function (&$item) use ($tb, $child, $foreignKey, $mainKey) {
                                    $ch = [];
                                    foreach ($child as $it) {
                                        if ($it[$foreignKey] === $item[$mainKey]) {
                                            array_push($ch, $it->toArray());
                                        }
                                    }
                                    $item["table_" . $tb] = $ch;
                                });
                            }
                        }
                    }
                    if (empty($child)) {
                        // 拼装
                        $mainObj->each(function (&$item) use ($tb, $child) {
                            $item["table_" . $tb] = $child;
                        });
                    }
                }
                $model = $mainObj;
            }
            if (!$isSelect) {
                if ($isPaginate) {
                    $model      = $model->field($fields);
                    $pageConfig = $this->getPaginateConfig($pageLimit);
                    $data       = $model->paginate($pageConfig, false);
                } else {
                    $model = $model->field($fields);
                    $data  = $model->select();
                }
            } else {
                $data = $model;
            }
            $this->setModelData($data);
            $all = $this->buildReturn($data);
            return $all;
        } catch (\Exception $e) {
            // 返回model错误
            $this->modelError = $e->getMessage();
            return false;
        }
    }
}
