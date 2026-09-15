import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/station_repository_impl.dart';
import '../../domain/repositories/station_repository.dart';

final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return StationRepositoryImpl();
});
