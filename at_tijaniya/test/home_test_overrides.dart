// Contenu de l'accueil venu de Supabase, remplacé dans les tests : carrousel
// « Comprendre et rattraper » (trois pages de l'onglet Wird) et directs en
// cours. Vide par défaut, pour que les tests qui ne portent pas sur le
// carrousel n'aient ni carte ni message d'erreur réseau en plus.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/tariqa_benefits/data/tariqa_benefits_repository.dart';
import 'package:at_tijaniya/features/tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import 'package:at_tijaniya/features/tariqa_conditions/domain/tariqa_condition_models.dart';
import 'package:at_tijaniya/features/tariqa_conditions/presentation/tariqa_conditions_providers.dart';
import 'package:at_tijaniya/features/wird/domain/wird_repair_models.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_repair_providers.dart';

List<Override> homeContentOverrides({
  WirdRepairContent? repair,
  List<TariqaCondition> conditions = const [],
  TariqaBenefitsRows? benefits,
}) {
  return [
    wirdRepairContentProvider.overrideWith((ref) async => repair ?? WirdRepairContent(cases: const [], notes: const [])),
    tariqaConditionsProvider.overrideWith((ref) async => conditions),
    tariqaBenefitsRowsProvider.overrideWith((ref) async => benefits ?? (sections: const <Map<String, dynamic>>[], cards: const <Map<String, dynamic>>[])),
    allLiveStreamsProvider.overrideWith((ref) async => const []),
  ];
}
