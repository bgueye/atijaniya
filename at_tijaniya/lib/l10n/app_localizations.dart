import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('ar')
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'At-Tijaniya'**
  String get appName;

  /// No description provided for @languageChoiceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre langue'**
  String get languageChoiceTitle;

  /// No description provided for @languageChoiceSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez la changer à tout moment dans les paramètres.'**
  String get languageChoiceSubtitle;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageArabic.
  ///
  /// In fr, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @authTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get authTitle;

  /// No description provided for @authSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour retrouver votre communauté, ou continuez sans compte pour réciter vos wirds.'**
  String get authSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get authEmailLabel;

  /// No description provided for @authPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get authPhoneLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authPasswordLabel;

  /// No description provided for @authSignInAction.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authSignInAction;

  /// No description provided for @authSignUpAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authSignUpAction;

  /// No description provided for @authContinueWithoutAccount.
  ///
  /// In fr, this message translates to:
  /// **'Continuer sans compte (pratique du Wird uniquement)'**
  String get authContinueWithoutAccount;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navWird.
  ///
  /// In fr, this message translates to:
  /// **'Wird'**
  String get navWird;

  /// No description provided for @navKhadara.
  ///
  /// In fr, this message translates to:
  /// **'Khadara'**
  String get navKhadara;

  /// No description provided for @navFigures.
  ///
  /// In fr, this message translates to:
  /// **'Figures'**
  String get navFigures;

  /// No description provided for @navCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get navCommunity;

  /// No description provided for @homeGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Salam, disciple'**
  String get homeGreeting;

  /// No description provided for @homeTodayStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut du jour'**
  String get homeTodayStatus;

  /// No description provided for @wirdListTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes Wirds'**
  String get wirdListTitle;

  /// No description provided for @wirdLazim.
  ///
  /// In fr, this message translates to:
  /// **'Lazim'**
  String get wirdLazim;

  /// No description provided for @wirdWazifa.
  ///
  /// In fr, this message translates to:
  /// **'Wazifa'**
  String get wirdWazifa;

  /// No description provided for @wirdHadratouJouma.
  ///
  /// In fr, this message translates to:
  /// **'Hadratou-l-Jouma'**
  String get wirdHadratouJouma;

  /// No description provided for @khadaraComingSoonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Khadara'**
  String get khadaraComingSoonTitle;

  /// No description provided for @khadaraComingSoonBody.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier des évènements et diffusions — à venir.'**
  String get khadaraComingSoonBody;

  /// No description provided for @figuresComingSoonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Figures et enseignements'**
  String get figuresComingSoonTitle;

  /// No description provided for @figuresComingSoonBody.
  ///
  /// In fr, this message translates to:
  /// **'Biographies des figures fondatrices — à venir.'**
  String get figuresComingSoonBody;

  /// No description provided for @communityComingSoonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get communityComingSoonTitle;

  /// No description provided for @communityComingSoonBody.
  ///
  /// In fr, this message translates to:
  /// **'Fil d\'actualité et lignée spirituelle — à venir.'**
  String get communityComingSoonBody;

  /// No description provided for @profileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get profileTitle;

  /// No description provided for @profileMyLineage.
  ///
  /// In fr, this message translates to:
  /// **'Ma lignée spirituelle'**
  String get profileMyLineage;

  /// No description provided for @profileSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get profileSettings;

  /// No description provided for @profileSignOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get profileSignOut;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
