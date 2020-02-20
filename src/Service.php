<?php
/**
 * 凯拓软件 [临渊羡鱼不如退而结网,凯拓与你一同成长]
 * @package topphp-generate
 * @date 2020/2/20 16:23
 * @author sleep <sleep@kaituocn.com>
 */
declare(strict_types=1);

namespace Topphp\TopphpGenerate;

use Topphp\TopphpGenerate\command\GenerateCommand;

class Service extends \think\Service
{
    public function boot()
    {
        $this->commands([GenerateCommand::class]);
    }
}
