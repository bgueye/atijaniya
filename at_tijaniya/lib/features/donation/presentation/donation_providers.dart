import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/donation_repository.dart';

final donationRepositoryProvider = Provider<DonationRepository>((ref) => const DonationRepository());
