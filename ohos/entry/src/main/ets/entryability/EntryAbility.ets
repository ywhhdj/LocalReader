import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { kLocalReaderPlugins } from '../plugins/PlatformPlugins';

/**
 * module.json5 一直引用 ./ets/entryability/EntryAbility.ets，但仓库里没有这个文件，
 * 鸿蒙端因此连启动入口都缺失。这里补上，并把 LocalReader 的全部平台通道挂到引擎。
 *
 * flutter 工具生成的第三方插件注册表由 super.configureFlutterEngine 处理；
 * 自定义插件在这里显式挂载，不引用仓库里不存在的生成文件。
 */
export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    const registry = flutterEngine.getPlugins();
    kLocalReaderPlugins.forEach((plugin) => {
      registry?.add(plugin);
    });
  }
}
