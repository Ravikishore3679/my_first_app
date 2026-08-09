import 'package:get_it/get_it.dart';

import '../../services/expense_cloud_store.dart';
import '../../services/expense_local_store.dart';
import '../../viewmodels/expense_view_model.dart';

final serviceLocator = GetIt.instance;

Future<void> setupDependencies() async {
  if (serviceLocator.isRegistered<ExpenseCloudStore>()) {
    await serviceLocator.reset();
  }

  final cloudStore = await ExpenseCloudStore.create();

  serviceLocator.registerSingleton<ExpenseCloudStore>(cloudStore);
  serviceLocator.registerLazySingleton<ExpenseLocalStore>(() => const ExpenseLocalStore());
  serviceLocator.registerLazySingleton<ExpenseViewModel>(
    () => ExpenseViewModel(
      cloudStore: serviceLocator<ExpenseCloudStore>(),
      localStore: serviceLocator<ExpenseLocalStore>(),
    ),
  );
}
