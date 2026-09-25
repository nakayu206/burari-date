// flutter run を引数なしで起動したときのデフォルトエントリポイント
// 通常は main_dev / main_stg / main_prod を使う
import 'main_dev.dart' as dev;

void main() => dev.main();
