import 'bootstrap.dart';
import 'core/config/flavor.dart';

/// prod(リリース)環境のエントリーポイント
void main() => bootstrap(Flavor.prod);
