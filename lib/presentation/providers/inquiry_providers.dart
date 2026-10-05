import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/inquiry_repository_impl.dart';
import '../../domain/repositories/inquiry_repository.dart';

final inquiryRepositoryProvider = Provider<InquiryRepository>((ref) {
  return InquiryRepositoryImpl();
});
