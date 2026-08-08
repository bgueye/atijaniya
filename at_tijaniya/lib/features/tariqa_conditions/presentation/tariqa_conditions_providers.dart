import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tariqa_conditions_repository.dart';
import '../domain/tariqa_condition_models.dart';

final tariqaConditionsRepositoryProvider = Provider<TariqaConditionsRepository>(
  (ref) => const TariqaConditionsRepository(),
);

final tariqaConditionsProvider = FutureProvider<List<TariqaCondition>>((ref) {
  return ref.watch(tariqaConditionsRepositoryProvider).fetchConditions();
});
