import 'package:flutter/material.dart';
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
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondary, width: 1.5),
              ),
              child: Icon(
                candidate.category == CandidateCategory.gourmet
                    ? Icons.ramen_dining_rounded
                    : Icons.park_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              candidate.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.titleMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'AI: ${candidate.catchCopy}',
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
            if (location != null)
              _CandidateMap(location: location, label: candidate.name)
            else
              const _MapUnavailable(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '住所: ${candidate.address ?? '(外部API連携後に表示)'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.labelSmall,
              ),
            ),
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

/// 地図表示(flutter_map + CARTOの無料タイル。APIキー・課金設定は不要)。
/// Google Maps SDKはAPIキー発行・課金設定が別途必要なため(Issue #5コメント
/// 参照)、無料で完結するこちらを採用した。
class _CandidateMap extends StatelessWidget {
  const _CandidateMap({required this.location, required this.label});

  final LatLng location;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 160,
        child: FlutterMap(
          options: MapOptions(initialCenter: location, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.buraridate.burari_date',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: location,
                  width: 36,
                  height: 36,
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
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
                TextSourceAttribution('CARTO'),
              ],
            ),
          ],
        ),
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
