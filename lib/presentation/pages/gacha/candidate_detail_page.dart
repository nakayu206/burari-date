import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/favorite.dart';
import '../../../domain/entities/station.dart';
import '../../providers/favorite_providers.dart';

/// launchUrlと同じ形の関数型。実機では実際のurl_launcher.launchUrlを使うが、
/// テストでは実プラットフォーム呼び出し(ブラウザ起動等)を避けるため差し替える。
typedef UrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// S-06 候補詳細画面
class CandidateDetailPage extends ConsumerWidget {
  const CandidateDetailPage({
    super.key,
    required this.candidate,
    this.fallbackStation,
    @visibleForTesting this.launchUrlOverride = launchUrl,
  });

  final Candidate candidate;

  /// 候補自体の緯度経度が未設定(店舗/観光地検索API接続Issue #3待ち)の間、
  /// 地図の中心として代わりに使う到着駅。
  final Station? fallbackStation;

  final UrlLauncher launchUrlOverride;

  /// 候補と到着駅の座標を混ぜて組み合わせない(例えば候補にlatitudeだけ設定
  /// されていた場合、そこにfallbackStationのlongitudeを組み合わせると
  /// 全く無関係な地点を指してしまう)。どちらかのペアをまるごと使う。
  LatLng? get _location {
    final candidateLat = candidate.latitude;
    final candidateLng = candidate.longitude;
    if (candidateLat != null && candidateLng != null) {
      return LatLng(candidateLat, candidateLng);
    }
    final stationLat = fallbackStation?.latitude;
    final stationLng = fallbackStation?.longitude;
    if (stationLat != null && stationLng != null) {
      return LatLng(stationLat, stationLng);
    }
    return null;
  }

  /// 候補自体の座標(取得できない場合はnull)。
  LatLng? get _placePoint {
    final lat = candidate.latitude;
    final lng = candidate.longitude;
    return lat != null && lng != null ? LatLng(lat, lng) : null;
  }

  /// 到着駅の座標(駅の情報がない、または座標がない場合はnull)。
  LatLng? get _stationPoint {
    final lat = fallbackStation?.latitude;
    final lng = fallbackStation?.longitude;
    return lat != null && lng != null ? LatLng(lat, lng) : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = _location;
    final isFavoriteAsync = ref.watch(isFavoriteProvider(candidate.id));

    return Scaffold(
      appBar: AppBar(title: const Text('候補詳細')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          children: [
            _CandidateImage(imageUrl: candidate.imageUrl),
            // 名前は、ほかのアプリで検索するために、すぐコピーできるようにする。
            Row(
              children: [
                _CategoryBadge(category: candidate.category),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    candidate.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFontSizes.titleMedium,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyName(context),
                  icon: const Icon(Icons.copy_rounded),
                  color: AppColors.secondary,
                  tooltip: '名前をコピー',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              candidate.catchCopy,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.labelSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              candidate.reason,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _InfoRow(
              icon: Icons.directions_walk_rounded,
              // 直線距離からの概算(バックエンドで徒歩80m/分として計算)。
              text: '駅から徒歩約${candidate.walkMinutes}分',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_stationPoint != null || _placePoint != null)
              _CandidateMap(
                station: _stationPoint,
                place: _placePoint,
                label: candidate.name,
              )
            else
              const _MapUnavailable(),
            // 住所を取得できない候補では、行ごと表示しない。
            if (candidate.address != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                '住所: ${candidate.address}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.labelSmall,
                ),
              ),
            ],
            if (candidate.category == CandidateCategory.gourmet) ...[
              SizedBox(
                height: candidate.address != null
                    ? AppSpacing.xs
                    : AppSpacing.lg,
              ),
              const _HotPepperCredit(),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (location != null)
              OutlinedButton.icon(
                onPressed: () => _openDirections(context, location),
                icon: const Icon(Icons.directions_rounded),
                label: const Text('経路案内を開く'),
              ),
            const SizedBox(height: AppSpacing.md),
            isFavoriteAsync.when(
              loading: () => const ElevatedButton(
                onPressed: null,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              // 取得に失敗しても未保存扱いで表示し、ボタン操作自体は続行できる
              // ようにする(受動的なロード失敗は画面内表示でよい)。
              error: (_, _) => ElevatedButton(
                onPressed: () => _toggleFavorite(context, ref, isSaved: false),
                child: const Text('保存する'),
              ),
              data: (isSaved) => ElevatedButton(
                onPressed: () =>
                    _toggleFavorite(context, ref, isSaved: isSaved),
                style: isSaved
                    ? ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                      )
                    : null,
                child: Text(isSaved ? '保存済み(解除する)' : '保存する'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyName(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: candidate.name));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('名前をコピーしました')));
  }

  Future<void> _openDirections(BuildContext context, LatLng location) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${location.latitude},${location.longitude}',
    );
    bool launched;
    try {
      launched = await launchUrlOverride(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      launched = false;
    }
    // 通信・外部連携エラーは見逃されないようダイアログで表示する(docs/コード規約.md)。
    if (!launched && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('地図アプリを開けませんでした'),
          content: const Text('地図アプリがインストールされていないか、開けない状態です。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref, {
    required bool isSaved,
  }) async {
    // ウィジェットが破棄されてもキャッシュ更新は行いたいので、refではなく
    // 破棄されないcontainer経由でinvalidateする(refはウィジェットと運命を共にする)。
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = ref.read(favoriteRepositoryProvider);
    String message;
    try {
      if (isSaved) {
        await repository.removeFavorite(candidate.id);
        message = 'お気に入りを解除しました';
      } else {
        await repository.addFavorite(Favorite.fromCandidate(candidate));
        message = 'お気に入りに保存しました';
      }
      container.invalidate(isFavoriteProvider(candidate.id));
      container.invalidate(favoritesProvider);
    } on Exception {
      message = isSaved ? '解除に失敗しました' : '保存に失敗しました';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars() // 連打時に古いSnackBarが表示待ちで詰まらないようにする。
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// アイコンと一行の情報(徒歩分数など)。
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

/// 候補の画像(ホットペッパー/Foursquareの写真)。
///
/// 写真がない・読み込みに失敗した場合は、空の枠を出さず、この部品ごと表示しない
/// (観光は、Foursquareの写真が有料の項目のため、写真がないことが多い)。その
/// 場合の目印は、名前の横のアイコン([_CategoryBadge])が担う。
class _CandidateImage extends StatefulWidget {
  const _CandidateImage({required this.imageUrl});

  final String? imageUrl;

  @override
  State<_CandidateImage> createState() => _CandidateImageState();
}

class _CandidateImageState extends State<_CandidateImage> {
  static const _height = 180.0;

  bool _hasFailed = false;

  void _markFailed() {
    if (_hasFailed) return;
    // 画像の読み込み中(ビルドの途中)にsetStateしないよう、描画のあとに行う。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || _hasFailed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            // 読み込み中は、枠だけ先に出して、画面が跳ねないようにする。
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const ColoredBox(color: AppColors.primaryLight),
            errorBuilder: (context, error, stackTrace) {
              _markFailed();
              return const ColoredBox(color: AppColors.primaryLight);
            },
          ),
        ),
      ),
    );
  }
}

/// カテゴリ(グルメ/観光)を示す、名前の横のアイコン。
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final CandidateCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary, width: 1.5),
      ),
      child: Icon(
        category == CandidateCategory.gourmet
            ? Icons.ramen_dining_rounded
            : Icons.park_rounded,
        size: 24,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// 「駅」と「場所」の位置関係を見せる地図(flutter_map + OpenStreetMapの標準
/// タイル。APIキー・課金設定は不要)。
///
/// 駅からどこにあるかがひと目で分かるよう、駅と場所の両方が入る範囲に合わせて
/// 表示する。標準タイルは色も情報も多く見づらいため、白に近い淡いグレーにして、
/// 駅と場所のマーカーだけが目立つ、シンプルな見た目にする。
///
/// Google Maps SDKはAPIキー発行・課金設定が別途必要なため(Issue #5コメント
/// 参照)、無料で完結するこちらを採用した。以前使っていたCARTOのベースマップは、
/// APIキーが必要になり、タイルの代わりに「API KEY REQUIRED」の画像が返るよう
/// になった(Issue #76)。OpenStreetMapの標準タイルサーバーは少量の利用向け
/// (利用ポリシーあり)のため、利用者が増える段階では、APIキー付きの地図
/// サービスへの切り替えを検討する。
///
/// [station]と[place]は、どちらか一方だけのこともある(場所の座標が取れない
/// 候補は駅だけ、駅の情報がない場合は場所だけ)。少なくとも一方は必要。
class _CandidateMap extends StatelessWidget {
  const _CandidateMap({this.station, this.place, required this.label})
    : assert(station != null || place != null);

  /// 地図の色を淡くする色変換の行列。彩度を60%に落とし(輝度の重みは
  /// 0.2126/0.7152/0.0722)、さらに全体を白に35%寄せる(255 × 0.35 ≒ 89)。
  /// 完全なグレーにはせず、公園の緑や道の色をほんのり残す。
  static const _paleMapMatrix = <double>[
    0.4453, 0.1859, 0.0188, 0, 89.25, //
    0.0553, 0.5760, 0.0188, 0, 89.25, //
    0.0553, 0.1859, 0.4088, 0, 89.25, //
    0, 0, 0, 1, 0, //
  ];

  /// 駅と場所が入るときの、地図の端との余白。
  static const _fitPadding = EdgeInsets.all(26);

  final LatLng? station;
  final LatLng? place;
  final String label;

  @override
  Widget build(BuildContext context) {
    final points = [?station, ?place];
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 160,
        child: FlutterMap(
          options: MapOptions(
            // 2点あるときは両方が入る範囲に合わせる。近い場所ほど、大きく
            // 拡大される(拡大しすぎないよう、上限を付ける)。1点だけのときは
            // その地点を中心にする。
            initialCameraFit: points.length == 2
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: _fitPadding,
                    maxZoom: 18,
                  )
                : null,
            initialCenter: points.first,
            initialZoom: 17,
            // 見せるだけの地図にする。操作できると、縦にスクロールする画面と
            // 指の動きが競合して使いにくい。経路は「経路案内を開く」で見られる。
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // 利用ポリシー上、アプリを識別できるUser-Agentを付ける。
              userAgentPackageName: 'com.buraridate.burari_date',
              tileBuilder: (context, tileWidget, tile) => ColorFiltered(
                colorFilter: const ColorFilter.matrix(_paleMapMatrix),
                child: tileWidget,
              ),
            ),
            if (points.length == 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 2.5,
                    color: AppColors.textSecondary,
                    pattern: StrokePattern.dashed(segments: const [6, 6]),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (station != null)
                  Marker(
                    point: station!,
                    width: 30,
                    height: 30,
                    child: const Tooltip(
                      message: '駅',
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.train_rounded,
                          color: AppColors.surface,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                if (place != null)
                  Marker(
                    point: place!,
                    width: 36,
                    height: 36,
                    // ピンの先が場所の位置を指すよう、下端を合わせる。
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: label,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ホットペッパーグルメAPIの利用規約上の表示義務(Issue #50)。
class _HotPepperCredit extends StatelessWidget {
  const _HotPepperCredit();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '情報提供: ホットペッパーグルメ',
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppFontSizes.caption,
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary, width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.map_rounded,
        size: 40,
        color: AppColors.textSecondary,
      ),
    );
  }
}
