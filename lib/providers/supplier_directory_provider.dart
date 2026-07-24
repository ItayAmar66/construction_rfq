import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/supplier_directory_service.dart';

final supplierDirectoryServiceProvider = Provider<SupplierDirectoryService>(
  (ref) => SupplierDirectoryService(),
);

final supplierDirectoryProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.watch(supplierDirectoryServiceProvider).listSuppliers();
});
