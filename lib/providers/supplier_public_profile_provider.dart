import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'providers.dart';

/// Public supplier profile for trust cards (compare / quote detail).
final supplierPublicProfileProvider =
    FutureProvider.family<AppUser?, String>((ref, supplierId) async {
  if (supplierId.isEmpty) return null;
  return ref.read(authServiceProvider).getUserById(supplierId);
});
