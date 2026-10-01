/// 利用規約・プライバシーポリシーへの同意を、保存・読み込みする(Issue #96)。
///
/// どの版の規約に同意したかを、番号で保存する。規約を変更して、版の番号を上げたとき、
/// 古い版に同意した利用者は、新しい版に、同意していないものとして扱う。
abstract interface class ConsentRepository {
  /// 同意した規約の版。まだ同意していない場合はnull。
  Future<int?> loadAcceptedVersion();

  /// [version]に同意したことを保存する。
  Future<void> saveAcceptedVersion(int version);
}
