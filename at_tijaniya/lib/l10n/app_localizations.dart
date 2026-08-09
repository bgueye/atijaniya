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

  /// No description provided for @onboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingStart;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur At-Tijaniya'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre compagnon numérique pour la pratique quotidienne, en français et en arabe.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingWirdTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos wirds, guidés pas à pas'**
  String get onboardingWirdTitle;

  /// No description provided for @onboardingWirdBody.
  ///
  /// In fr, this message translates to:
  /// **'Lazim, Wazifa et Hadratou-l-Jouma : texte, translittération, traduction et tasbih digital pour réciter sereinement.'**
  String get onboardingWirdBody;

  /// No description provided for @onboardingKhadaraTitle.
  ///
  /// In fr, this message translates to:
  /// **'Khadara : évènements et diffusions'**
  String get onboardingKhadaraTitle;

  /// No description provided for @onboardingKhadaraBody.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier des évènements, annuaire des zawiyas et diffusions en direct pour rester connecté à la communauté.'**
  String get onboardingKhadaraBody;

  /// No description provided for @onboardingCommunityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une communauté de disciples'**
  String get onboardingCommunityTitle;

  /// No description provided for @onboardingCommunityBody.
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez votre entourage spirituel et suivez l\'actualité de votre zawiya.'**
  String get onboardingCommunityBody;

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

  /// No description provided for @authEmailRequired.
  ///
  /// In fr, this message translates to:
  /// **'L\'adresse e-mail est obligatoire.'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide.'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe est obligatoire.'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 6 caractères.'**
  String get authPasswordTooShort;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail ou mot de passe incorrect.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailAlreadyRegistered.
  ///
  /// In fr, this message translates to:
  /// **'Un compte existe déjà avec cette adresse e-mail.'**
  String get authEmailAlreadyRegistered;

  /// No description provided for @authWeakPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe trop faible. Utilisez au moins 6 caractères.'**
  String get authWeakPassword;

  /// No description provided for @authEmailNotConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre e-mail avant de vous connecter (lien envoyé à votre adresse).'**
  String get authEmailNotConfirmed;

  /// No description provided for @authRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez dans quelques instants.'**
  String get authRateLimited;

  /// No description provided for @authGenericError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get authGenericError;

  /// No description provided for @authCheckEmailToConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Compte créé. Vérifiez votre boîte mail pour confirmer votre adresse avant de vous connecter.'**
  String get authCheckEmailToConfirm;

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

  /// No description provided for @homeGreetingPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Salam,'**
  String get homeGreetingPrefix;

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

  /// No description provided for @wirdFreeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wird libre'**
  String get wirdFreeTitle;

  /// No description provided for @wirdFreeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramétrez votre propre compteur'**
  String get wirdFreeSubtitle;

  /// No description provided for @wirdFreeSetupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau compteur libre'**
  String get wirdFreeSetupTitle;

  /// No description provided for @wirdFreeLabelFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Que récitez-vous ? (optionnel)'**
  String get wirdFreeLabelFieldLabel;

  /// No description provided for @wirdFreeTargetFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de répétitions'**
  String get wirdFreeTargetFieldLabel;

  /// No description provided for @wirdFreeTargetRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un nombre de répétitions supérieur à 0.'**
  String get wirdFreeTargetRequired;

  /// No description provided for @wirdFreeStartButton.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get wirdFreeStartButton;

  /// No description provided for @wirdFreeManualMode.
  ///
  /// In fr, this message translates to:
  /// **'Tape manuel'**
  String get wirdFreeManualMode;

  /// No description provided for @wirdFreeVoiceMode.
  ///
  /// In fr, this message translates to:
  /// **'Voix'**
  String get wirdFreeVoiceMode;

  /// No description provided for @wirdFreeUndo.
  ///
  /// In fr, this message translates to:
  /// **'Corriger -1'**
  String get wirdFreeUndo;

  /// No description provided for @wirdFreeReset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get wirdFreeReset;

  /// No description provided for @wirdFreeFinishButton.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get wirdFreeFinishButton;

  /// No description provided for @wirdFreeTapToCount.
  ///
  /// In fr, this message translates to:
  /// **'Toucher pour compter'**
  String get wirdFreeTapToCount;

  /// No description provided for @wirdFreeListeningActive.
  ///
  /// In fr, this message translates to:
  /// **'À l\'écoute — récitez, une pause de silence = +1'**
  String get wirdFreeListeningActive;

  /// No description provided for @wirdFreeListeningPaused.
  ///
  /// In fr, this message translates to:
  /// **'Micro en pause'**
  String get wirdFreeListeningPaused;

  /// No description provided for @wirdFreeVoiceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Reconnaissance vocale indisponible sur cet appareil.'**
  String get wirdFreeVoiceUnavailable;

  /// No description provided for @wirdFreeStartListening.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer l\'écoute'**
  String get wirdFreeStartListening;

  /// No description provided for @wirdFreeStopListening.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause'**
  String get wirdFreeStopListening;

  /// No description provided for @wirdFreeCompletedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compteur terminé'**
  String get wirdFreeCompletedTitle;

  /// No description provided for @wirdFreeCompletedBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez atteint l\'objectif de répétitions fixé.'**
  String get wirdFreeCompletedBody;

  /// No description provided for @wirdFreeNewCounterButton.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau compteur'**
  String get wirdFreeNewCounterButton;

  /// No description provided for @tariqaConditionsCardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conditions de la Tariqa'**
  String get tariqaConditionsCardTitle;

  /// No description provided for @tariqaConditionsCardSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les 23 conditions du wird et de l\'affiliation'**
  String get tariqaConditionsCardSubtitle;

  /// No description provided for @tariqaConditionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conditions de la Tariqa'**
  String get tariqaConditionsTitle;

  /// No description provided for @tariqaConditionsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les données.'**
  String get tariqaConditionsLoadError;

  /// No description provided for @tariqaConditionsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get tariqaConditionsRetry;

  /// No description provided for @tariqaConditionsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contenu en cours de compilation'**
  String get tariqaConditionsEmptyTitle;

  /// No description provided for @tariqaConditionsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu sera publié une fois validé par un moqaddam ou érudit reconnu du projet.'**
  String get tariqaConditionsEmptyBody;

  /// No description provided for @tariqaConditionsCategoryValiditeTalqin.
  ///
  /// In fr, this message translates to:
  /// **'Validité du talqîn'**
  String get tariqaConditionsCategoryValiditeTalqin;

  /// No description provided for @tariqaConditionsCategoryCompagnonnage.
  ///
  /// In fr, this message translates to:
  /// **'Compagnonnage envers le Cheikh'**
  String get tariqaConditionsCategoryCompagnonnage;

  /// No description provided for @tariqaConditionsCategoryConditionsGenerales.
  ///
  /// In fr, this message translates to:
  /// **'Conditions générales'**
  String get tariqaConditionsCategoryConditionsGenerales;

  /// No description provided for @tariqaConditionsCategoryValiditeRecitation.
  ///
  /// In fr, this message translates to:
  /// **'Validité de la récitation'**
  String get tariqaConditionsCategoryValiditeRecitation;

  /// No description provided for @tariqaConditionsCategoryConditionsComplementaires.
  ///
  /// In fr, this message translates to:
  /// **'Conditions complémentaires'**
  String get tariqaConditionsCategoryConditionsComplementaires;

  /// No description provided for @khadaraEventsTab.
  ///
  /// In fr, this message translates to:
  /// **'Évènements'**
  String get khadaraEventsTab;

  /// No description provided for @khadaraZawiyasTab.
  ///
  /// In fr, this message translates to:
  /// **'Zawiyas'**
  String get khadaraZawiyasTab;

  /// No description provided for @khadaraNoEvents.
  ///
  /// In fr, this message translates to:
  /// **'Aucun évènement à venir pour le moment.'**
  String get khadaraNoEvents;

  /// No description provided for @khadaraNoZawiyas.
  ///
  /// In fr, this message translates to:
  /// **'Aucune zawiya renseignée pour le moment.'**
  String get khadaraNoZawiyas;

  /// No description provided for @khadaraLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les données.'**
  String get khadaraLoadError;

  /// No description provided for @khadaraRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get khadaraRetry;

  /// No description provided for @khadaraOpenInMaps.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir dans Maps'**
  String get khadaraOpenInMaps;

  /// No description provided for @khadaraEventTypeZiyara.
  ///
  /// In fr, this message translates to:
  /// **'Ziyara'**
  String get khadaraEventTypeZiyara;

  /// No description provided for @khadaraEventTypeHadra.
  ///
  /// In fr, this message translates to:
  /// **'Hadra'**
  String get khadaraEventTypeHadra;

  /// No description provided for @khadaraEventTypeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get khadaraEventTypeOther;

  /// No description provided for @khadaraUpcomingEventsAtZawiya.
  ///
  /// In fr, this message translates to:
  /// **'Prochains évènements'**
  String get khadaraUpcomingEventsAtZawiya;

  /// No description provided for @khadaraNoUpcomingEventsAtZawiya.
  ///
  /// In fr, this message translates to:
  /// **'Aucun évènement à venir dans cette zawiya.'**
  String get khadaraNoUpcomingEventsAtZawiya;

  /// No description provided for @khadaraAddressLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get khadaraAddressLabel;

  /// No description provided for @khadaraContactLabel.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get khadaraContactLabel;

  /// No description provided for @khadaraUnderstandingTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Comprendre la Khadara'**
  String get khadaraUnderstandingTooltip;

  /// No description provided for @khadaraUnderstandingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comprendre la Khadara'**
  String get khadaraUnderstandingTitle;

  /// No description provided for @khadaraUnderstandingEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contenu en cours de compilation'**
  String get khadaraUnderstandingEmptyTitle;

  /// No description provided for @khadaraUnderstandingEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu pédagogique sera publié une fois validé par un moqaddam ou érudit reconnu du projet.'**
  String get khadaraUnderstandingEmptyBody;

  /// No description provided for @khadaraUnderstandingCta.
  ///
  /// In fr, this message translates to:
  /// **'En attendant, découvrir le calendrier et les zawiyas'**
  String get khadaraUnderstandingCta;

  /// No description provided for @figuresSectionFounders.
  ///
  /// In fr, this message translates to:
  /// **'Fondateurs'**
  String get figuresSectionFounders;

  /// No description provided for @figuresSectionFamilies.
  ///
  /// In fr, this message translates to:
  /// **'Familles religieuses'**
  String get figuresSectionFamilies;

  /// No description provided for @figuresEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Biographies en cours de compilation'**
  String get figuresEmptyTitle;

  /// No description provided for @figuresEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu, sensible, ne sera publié qu\'après validation par un moqaddam ou érudit reconnu du projet.'**
  String get figuresEmptyBody;

  /// No description provided for @figuresLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les données.'**
  String get figuresLoadError;

  /// No description provided for @figuresRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get figuresRetry;

  /// No description provided for @figuresReviewButton.
  ///
  /// In fr, this message translates to:
  /// **'Contenu à valider'**
  String get figuresReviewButton;

  /// No description provided for @figuresReviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Figures à valider'**
  String get figuresReviewTitle;

  /// No description provided for @figuresReviewEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune figure en attente de validation.'**
  String get figuresReviewEmpty;

  /// No description provided for @figuresReviewValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get figuresReviewValidate;

  /// No description provided for @figuresReviewConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Valider cette biographie ?'**
  String get figuresReviewConfirmTitle;

  /// No description provided for @figuresReviewConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle deviendra visible par tous les disciples dans l\'app.'**
  String get figuresReviewConfirmBody;

  /// No description provided for @figuresReviewConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get figuresReviewConfirmAction;

  /// No description provided for @figuresReviewCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get figuresReviewCancel;

  /// No description provided for @figuresReviewSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Figure validée et publiée.'**
  String get figuresReviewSuccess;

  /// No description provided for @figureBiographySectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Biographie'**
  String get figureBiographySectionTitle;

  /// No description provided for @figureTabSilsila.
  ///
  /// In fr, this message translates to:
  /// **'Silsila'**
  String get figureTabSilsila;

  /// No description provided for @figureCitationsSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Citations'**
  String get figureCitationsSectionTitle;

  /// No description provided for @figureZiyaraSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ziyaras'**
  String get figureZiyaraSectionTitle;

  /// No description provided for @figureBiographyPending.
  ///
  /// In fr, this message translates to:
  /// **'Biographie en attente de validation.'**
  String get figureBiographyPending;

  /// No description provided for @figureSilsilaPending.
  ///
  /// In fr, this message translates to:
  /// **'La silsila historique de cette figure n\'est pas encore disponible.'**
  String get figureSilsilaPending;

  /// No description provided for @figureSilsilaLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la silsila historique.'**
  String get figureSilsilaLoadError;

  /// No description provided for @figureSilsilaFounderLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fondateur de la tarikha'**
  String get figureSilsilaFounderLabel;

  /// No description provided for @figureCitationsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune citation renseignée pour le moment.'**
  String get figureCitationsEmpty;

  /// No description provided for @figureWorksSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Œuvres'**
  String get figureWorksSectionTitle;

  /// No description provided for @figureZiyarasPending.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ziyara associée n\'est encore renseignée.'**
  String get figureZiyarasPending;

  /// No description provided for @communityFeedEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune publication pour le moment.'**
  String get communityFeedEmpty;

  /// No description provided for @communityLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les publications.'**
  String get communityLoadError;

  /// No description provided for @communityRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get communityRetry;

  /// No description provided for @communityDefaultAuthor.
  ///
  /// In fr, this message translates to:
  /// **'Disciple'**
  String get communityDefaultAuthor;

  /// No description provided for @communitySignInToInteract.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour aimer ou commenter une publication.'**
  String get communitySignInToInteract;

  /// No description provided for @communityCommentsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires'**
  String get communityCommentsTitle;

  /// No description provided for @communityNoComments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun commentaire pour le moment.'**
  String get communityNoComments;

  /// No description provided for @communityCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire...'**
  String get communityCommentHint;

  /// No description provided for @communityCommentSignInHint.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour commenter.'**
  String get communityCommentSignInHint;

  /// No description provided for @communitySend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get communitySend;

  /// No description provided for @communityFeedTab.
  ///
  /// In fr, this message translates to:
  /// **'Fil'**
  String get communityFeedTab;

  /// No description provided for @communityGroupsTab.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get communityGroupsTab;

  /// No description provided for @communityGroupsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe pour le moment.'**
  String get communityGroupsEmpty;

  /// No description provided for @communityGroupsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les groupes.'**
  String get communityGroupsLoadError;

  /// No description provided for @communityGroupsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get communityGroupsRetry;

  /// No description provided for @communityGroupsCreateButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe'**
  String get communityGroupsCreateButton;

  /// No description provided for @communityGroupsCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe'**
  String get communityGroupsCreateTitle;

  /// No description provided for @communityGroupsNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe'**
  String get communityGroupsNameLabel;

  /// No description provided for @communityGroupsNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom du groupe est obligatoire.'**
  String get communityGroupsNameRequired;

  /// No description provided for @communityGroupsDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get communityGroupsDescriptionLabel;

  /// No description provided for @communityGroupsZawiyaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Zawiya (optionnel)'**
  String get communityGroupsZawiyaLabel;

  /// No description provided for @communityGroupsRegionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Région (optionnel)'**
  String get communityGroupsRegionLabel;

  /// No description provided for @communityGroupsCreateSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get communityGroupsCreateSubmit;

  /// No description provided for @communityGroupsSignInToCreate.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour créer un groupe.'**
  String get communityGroupsSignInToCreate;

  /// No description provided for @communityGroupsJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre le groupe'**
  String get communityGroupsJoin;

  /// No description provided for @communityGroupsLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe'**
  String get communityGroupsLeave;

  /// No description provided for @communityGroupsLeaveConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter ce groupe ?'**
  String get communityGroupsLeaveConfirmTitle;

  /// No description provided for @communityGroupsLeaveConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne verrez plus ses discussions tant que vous ne l\'aurez pas rejoint à nouveau.'**
  String get communityGroupsLeaveConfirmBody;

  /// No description provided for @communityGroupsLeaveConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get communityGroupsLeaveConfirmAction;

  /// No description provided for @communityGroupsSignInToJoin.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour rejoindre un groupe.'**
  String get communityGroupsSignInToJoin;

  /// No description provided for @communityGroupsNotMemberTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez ce groupe'**
  String get communityGroupsNotMemberTitle;

  /// No description provided for @communityGroupsNotMemberBody.
  ///
  /// In fr, this message translates to:
  /// **'Les discussions d\'un groupe ne sont visibles que pour ses membres.'**
  String get communityGroupsNotMemberBody;

  /// No description provided for @communityGroupsPostsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune discussion pour le moment. Soyez le premier à écrire !'**
  String get communityGroupsPostsEmpty;

  /// No description provided for @communityGroupsPostHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un message...'**
  String get communityGroupsPostHint;

  /// No description provided for @communityGroupsLoadPostsError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les discussions.'**
  String get communityGroupsLoadPostsError;

  /// No description provided for @communityMessagesTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get communityMessagesTooltip;

  /// No description provided for @communityConversationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conversations'**
  String get communityConversationsTitle;

  /// No description provided for @communityConversationsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation pour le moment.'**
  String get communityConversationsEmpty;

  /// No description provided for @communityConversationsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les conversations.'**
  String get communityConversationsLoadError;

  /// No description provided for @communityConversationsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get communityConversationsRetry;

  /// No description provided for @communityConversationsNoMessages.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message pour le moment. Écrivez le premier !'**
  String get communityConversationsNoMessages;

  /// No description provided for @communitySendMessageButton.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un message'**
  String get communitySendMessageButton;

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

  /// No description provided for @profileSignInRequired.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour accéder à votre profil.'**
  String get profileSignInRequired;

  /// No description provided for @profileLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger votre profil.'**
  String get profileLoadError;

  /// No description provided for @profileRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get profileRetry;

  /// No description provided for @profileEditTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon profil'**
  String get profileEditTooltip;

  /// No description provided for @profileNoBio.
  ///
  /// In fr, this message translates to:
  /// **'Aucune présentation renseignée.'**
  String get profileNoBio;

  /// No description provided for @profileZawiyaNoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Aucune zawiya renseignée.'**
  String get profileZawiyaNoneLabel;

  /// No description provided for @profileEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon profil'**
  String get profileEditTitle;

  /// No description provided for @profileDisplayNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiché'**
  String get profileDisplayNameLabel;

  /// No description provided for @profileDisplayNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom affiché est obligatoire.'**
  String get profileDisplayNameRequired;

  /// No description provided for @profileBioLabel.
  ///
  /// In fr, this message translates to:
  /// **'À propos (optionnel)'**
  String get profileBioLabel;

  /// No description provided for @profileZawiyaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Zawiya'**
  String get profileZawiyaLabel;

  /// No description provided for @profileZawiyaNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune zawiya'**
  String get profileZawiyaNone;

  /// No description provided for @profileSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get profileSave;

  /// No description provided for @profileUpdateError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer les modifications.'**
  String get profileUpdateError;

  /// No description provided for @profileSignOutConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter ?'**
  String get profileSignOutConfirmTitle;

  /// No description provided for @profileSignOutConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous devrez vous reconnecter pour retrouver votre communauté.'**
  String get profileSignOutConfirmBody;

  /// No description provided for @profileSignOutConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get profileSignOutConfirmAction;

  /// No description provided for @profileCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get profileCancel;

  /// No description provided for @lineageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ma lignée spirituelle'**
  String get lineageTitle;

  /// No description provided for @lineagePrivacyNote.
  ///
  /// In fr, this message translates to:
  /// **'Ces informations restent strictement privées : visibles uniquement par vous, jamais dans un annuaire public.'**
  String get lineagePrivacyNote;

  /// No description provided for @lineageFoyerLabel.
  ///
  /// In fr, this message translates to:
  /// **'Foyer'**
  String get lineageFoyerLabel;

  /// No description provided for @lineageFoyerTivaouane.
  ///
  /// In fr, this message translates to:
  /// **'Tivaouane'**
  String get lineageFoyerTivaouane;

  /// No description provided for @lineageFoyerKaolack.
  ///
  /// In fr, this message translates to:
  /// **'Kaolack'**
  String get lineageFoyerKaolack;

  /// No description provided for @lineageFoyerMedinaBaye.
  ///
  /// In fr, this message translates to:
  /// **'Médina Baye'**
  String get lineageFoyerMedinaBaye;

  /// No description provided for @lineageFoyerAutre.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get lineageFoyerAutre;

  /// No description provided for @lineageFoyerAutreLabel.
  ///
  /// In fr, this message translates to:
  /// **'Précisez le foyer'**
  String get lineageFoyerAutreLabel;

  /// No description provided for @lineageFoyerAutreRequired.
  ///
  /// In fr, this message translates to:
  /// **'Merci de préciser le foyer.'**
  String get lineageFoyerAutreRequired;

  /// No description provided for @lineageMoqaddamNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du moqaddam'**
  String get lineageMoqaddamNameLabel;

  /// No description provided for @lineageMoqaddamNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom du moqaddam est obligatoire.'**
  String get lineageMoqaddamNameRequired;

  /// No description provided for @lineageYearLabel.
  ///
  /// In fr, this message translates to:
  /// **'Année de transmission (optionnel)'**
  String get lineageYearLabel;

  /// No description provided for @lineageYearInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Année invalide (entre 1900 et 2100).'**
  String get lineageYearInvalid;

  /// No description provided for @lineageZawiyaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Zawiya / lieu de transmission (optionnel)'**
  String get lineageZawiyaLabel;

  /// No description provided for @lineageSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get lineageSave;

  /// No description provided for @lineageSaveSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Lignée spirituelle enregistrée.'**
  String get lineageSaveSuccess;

  /// No description provided for @lineageSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer ces informations.'**
  String get lineageSaveError;

  /// No description provided for @lineageDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mes informations'**
  String get lineageDelete;

  /// No description provided for @lineageDeleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ces informations ?'**
  String get lineageDeleteConfirmTitle;

  /// No description provided for @lineageDeleteConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre lignée spirituelle sera définitivement supprimée.'**
  String get lineageDeleteConfirmBody;

  /// No description provided for @lineageDeleteConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get lineageDeleteConfirmAction;

  /// No description provided for @lineageDeleteSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Lignée spirituelle supprimée.'**
  String get lineageDeleteSuccess;

  /// No description provided for @lineageLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger votre lignée spirituelle.'**
  String get lineageLoadError;

  /// No description provided for @lineageRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get lineageRetry;

  /// No description provided for @lineageFindDisciplesCta.
  ///
  /// In fr, this message translates to:
  /// **'Retrouver mes condisciples'**
  String get lineageFindDisciplesCta;

  /// No description provided for @lineageMatchesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retrouver mes condisciples'**
  String get lineageMatchesTitle;

  /// No description provided for @lineageMatchesLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger ces informations.'**
  String get lineageMatchesLoadError;

  /// No description provided for @lineageMatchesRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get lineageMatchesRetry;

  /// No description provided for @lineageMatchesNoLineageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez d\'abord votre lignée'**
  String get lineageMatchesNoLineageTitle;

  /// No description provided for @lineageMatchesNoLineageBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour retrouver vos condisciples, indiquez d\'abord le foyer et le moqaddam qui vous a transmis le Wird.'**
  String get lineageMatchesNoLineageBody;

  /// No description provided for @lineageMatchesGoToLineageCta.
  ///
  /// In fr, this message translates to:
  /// **'Renseigner ma lignée'**
  String get lineageMatchesGoToLineageCta;

  /// No description provided for @lineageMatchesNotVisibleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rendez votre lignée visible'**
  String get lineageMatchesNotVisibleTitle;

  /// No description provided for @lineageMatchesNotVisibleBody.
  ///
  /// In fr, this message translates to:
  /// **'Activez « Visibilité de ma lignée spirituelle » dans les paramètres de confidentialité pour retrouver vos condisciples.'**
  String get lineageMatchesNotVisibleBody;

  /// No description provided for @lineageMatchesGoToPrivacyCta.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de confidentialité'**
  String get lineageMatchesGoToPrivacyCta;

  /// No description provided for @lineageMatchesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune correspondance pour le moment'**
  String get lineageMatchesEmptyTitle;

  /// No description provided for @lineageMatchesEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Nous vous montrerons ici tout condisciple ayant la même lignée et ayant lui aussi activé la visibilité.'**
  String get lineageMatchesEmptyBody;

  /// No description provided for @lineageMatchesReceivedSection.
  ///
  /// In fr, this message translates to:
  /// **'Demandes reçues'**
  String get lineageMatchesReceivedSection;

  /// No description provided for @lineageMatchesResultsSection.
  ///
  /// In fr, this message translates to:
  /// **'Condisciples correspondants'**
  String get lineageMatchesResultsSection;

  /// No description provided for @lineageMatchesAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get lineageMatchesAccept;

  /// No description provided for @lineageMatchesDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get lineageMatchesDecline;

  /// No description provided for @lineageMatchesRespondError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de répondre à cette demande.'**
  String get lineageMatchesRespondError;

  /// No description provided for @lineageMatchesConnectButton.
  ///
  /// In fr, this message translates to:
  /// **'Se mettre en relation'**
  String get lineageMatchesConnectButton;

  /// No description provided for @lineageMatchesConnectError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'envoyer la demande.'**
  String get lineageMatchesConnectError;

  /// No description provided for @lineageMatchesStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée'**
  String get lineageMatchesStatusPending;

  /// No description provided for @lineageMatchesStatusAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Connecté'**
  String get lineageMatchesStatusAccepted;

  /// No description provided for @lineageMatchesStatusDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get lineageMatchesStatusDeclined;

  /// No description provided for @profileBecomeMouqaddam.
  ///
  /// In fr, this message translates to:
  /// **'Devenir Mouqaddam'**
  String get profileBecomeMouqaddam;

  /// No description provided for @profileSponsorshipRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes de parrainage'**
  String get profileSponsorshipRequests;

  /// No description provided for @profileMyIjazaChain.
  ///
  /// In fr, this message translates to:
  /// **'Ma silsila d\'ijaza'**
  String get profileMyIjazaChain;

  /// No description provided for @mouqaddamBecomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Devenir Mouqaddam'**
  String get mouqaddamBecomeTitle;

  /// No description provided for @mouqaddamIntro.
  ///
  /// In fr, this message translates to:
  /// **'Le statut de mouqaddam vérifié n\'est jamais auto-proclamé : votre parrain doit confirmer qu\'il vous a transmis l\'ijaza.'**
  String get mouqaddamIntro;

  /// No description provided for @mouqaddamLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger votre demande.'**
  String get mouqaddamLoadError;

  /// No description provided for @mouqaddamRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get mouqaddamRetry;

  /// No description provided for @mouqaddamChooseSponsorButton.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un parrain'**
  String get mouqaddamChooseSponsorButton;

  /// No description provided for @mouqaddamChangeSponsorButton.
  ///
  /// In fr, this message translates to:
  /// **'Changer de parrain'**
  String get mouqaddamChangeSponsorButton;

  /// No description provided for @mouqaddamNoSponsorChosen.
  ///
  /// In fr, this message translates to:
  /// **'Aucun parrain choisi pour l\'instant.'**
  String get mouqaddamNoSponsorChosen;

  /// No description provided for @mouqaddamSelectedSponsorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Parrain choisi'**
  String get mouqaddamSelectedSponsorLabel;

  /// No description provided for @mouqaddamYearFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Année de transmission de l\'ijaza (optionnel)'**
  String get mouqaddamYearFieldLabel;

  /// No description provided for @mouqaddamYearInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Année invalide (entre 1200 et 2100).'**
  String get mouqaddamYearInvalid;

  /// No description provided for @mouqaddamSubmitButton.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get mouqaddamSubmitButton;

  /// No description provided for @mouqaddamSponsorRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un parrain avant d\'envoyer la demande.'**
  String get mouqaddamSponsorRequiredError;

  /// No description provided for @mouqaddamSubmitError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'envoyer la demande.'**
  String get mouqaddamSubmitError;

  /// No description provided for @mouqaddamPendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande en attente'**
  String get mouqaddamPendingTitle;

  /// No description provided for @mouqaddamPendingSponsorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Parrain sollicité'**
  String get mouqaddamPendingSponsorLabel;

  /// No description provided for @mouqaddamPendingCancelButton.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get mouqaddamPendingCancelButton;

  /// No description provided for @mouqaddamPendingCancelConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette demande ?'**
  String get mouqaddamPendingCancelConfirmTitle;

  /// No description provided for @mouqaddamPendingCancelConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez en soumettre une nouvelle à tout moment.'**
  String get mouqaddamPendingCancelConfirmBody;

  /// No description provided for @mouqaddamPendingCancelConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get mouqaddamPendingCancelConfirmAction;

  /// No description provided for @mouqaddamCancelError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'annuler la demande.'**
  String get mouqaddamCancelError;

  /// No description provided for @mouqaddamRejectedNote.
  ///
  /// In fr, this message translates to:
  /// **'Votre dernière demande a été refusée. Vous pouvez en soumettre une nouvelle.'**
  String get mouqaddamRejectedNote;

  /// No description provided for @mouqaddamSearchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un parrain'**
  String get mouqaddamSearchTitle;

  /// No description provided for @mouqaddamSearchFieldHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom...'**
  String get mouqaddamSearchFieldHint;

  /// No description provided for @mouqaddamSearchEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mouqaddam disponible comme parrain pour le moment.'**
  String get mouqaddamSearchEmpty;

  /// No description provided for @mouqaddamSearchNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour cette recherche.'**
  String get mouqaddamSearchNoResults;

  /// No description provided for @mouqaddamSearchLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les résultats.'**
  String get mouqaddamSearchLoadError;

  /// No description provided for @mouqaddamRequestsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demandes de parrainage'**
  String get mouqaddamRequestsTitle;

  /// No description provided for @mouqaddamRequestsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande de parrainage en attente.'**
  String get mouqaddamRequestsEmpty;

  /// No description provided for @mouqaddamRequestsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les demandes.'**
  String get mouqaddamRequestsLoadError;

  /// No description provided for @mouqaddamRequestsYearLabel.
  ///
  /// In fr, this message translates to:
  /// **'Année d\'ijaza indiquée'**
  String get mouqaddamRequestsYearLabel;

  /// No description provided for @mouqaddamRequestsAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get mouqaddamRequestsAccept;

  /// No description provided for @mouqaddamRequestsReject.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get mouqaddamRequestsReject;

  /// No description provided for @mouqaddamRequestsAcceptConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accepter cette demande ?'**
  String get mouqaddamRequestsAcceptConfirmTitle;

  /// No description provided for @mouqaddamRequestsAcceptConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Le statut de mouqaddam vérifié sera confirmé pour ce disciple.'**
  String get mouqaddamRequestsAcceptConfirmBody;

  /// No description provided for @mouqaddamRequestsRejectConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Refuser cette demande ?'**
  String get mouqaddamRequestsRejectConfirmTitle;

  /// No description provided for @mouqaddamRequestsRejectConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Le disciple pourra soumettre une nouvelle demande à tout moment.'**
  String get mouqaddamRequestsRejectConfirmBody;

  /// No description provided for @mouqaddamRequestsConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get mouqaddamRequestsConfirmAction;

  /// No description provided for @mouqaddamRequestsSuccessAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée.'**
  String get mouqaddamRequestsSuccessAccepted;

  /// No description provided for @mouqaddamRequestsSuccessRejected.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée.'**
  String get mouqaddamRequestsSuccessRejected;

  /// No description provided for @mouqaddamRequestsError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de traiter cette demande.'**
  String get mouqaddamRequestsError;

  /// No description provided for @mouqaddamChainTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ma silsila d\'ijaza'**
  String get mouqaddamChainTitle;

  /// No description provided for @mouqaddamChainLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger votre silsila.'**
  String get mouqaddamChainLoadError;

  /// No description provided for @mouqaddamChainEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Votre silsila n\'est pas encore disponible.'**
  String get mouqaddamChainEmpty;

  /// No description provided for @mouqaddamChainYouLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get mouqaddamChainYouLabel;

  /// No description provided for @mouqaddamChainCompleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compléter la chaîne au-delà de l\'app'**
  String get mouqaddamChainCompleteTitle;

  /// No description provided for @mouqaddamChainCompleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Si votre parrain n\'a jamais utilisé l\'application, ajoutez ici le prochain maillon connu (nom et date approximative), jusqu\'à Cheikh Ahmed Tijani.'**
  String get mouqaddamChainCompleteBody;

  /// No description provided for @mouqaddamChainNameFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get mouqaddamChainNameFieldLabel;

  /// No description provided for @mouqaddamChainNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est obligatoire.'**
  String get mouqaddamChainNameRequired;

  /// No description provided for @mouqaddamChainYearTextFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Date approximative (optionnel)'**
  String get mouqaddamChainYearTextFieldLabel;

  /// No description provided for @mouqaddamChainAddButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter ce maillon'**
  String get mouqaddamChainAddButton;

  /// No description provided for @mouqaddamChainAddError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter ce maillon.'**
  String get mouqaddamChainAddError;

  /// No description provided for @mouqaddamChainAddSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Maillon ajouté.'**
  String get mouqaddamChainAddSuccess;

  /// No description provided for @mouqaddamChainUltimateSourceQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne est-elle Cheikh Ahmed Tijani, à l\'origine de la tarikha ?'**
  String get mouqaddamChainUltimateSourceQuestion;

  /// No description provided for @mouqaddamChainCompleteDone.
  ///
  /// In fr, this message translates to:
  /// **'Votre silsila remonte déjà jusqu\'à Cheikh Ahmed Tijani — aucun maillon supplémentaire à ajouter.'**
  String get mouqaddamChainCompleteDone;

  /// No description provided for @mouqaddamChainReplayButton.
  ///
  /// In fr, this message translates to:
  /// **'Revivre l\'ascension'**
  String get mouqaddamChainReplayButton;

  /// No description provided for @mouqaddamChainShareButton.
  ///
  /// In fr, this message translates to:
  /// **'Partager ma silsila'**
  String get mouqaddamChainShareButton;

  /// No description provided for @mouqaddamChainShareCardLockedNode.
  ///
  /// In fr, this message translates to:
  /// **'Maillon privé'**
  String get mouqaddamChainShareCardLockedNode;

  /// No description provided for @mouqaddamChainShareCardFooter.
  ///
  /// In fr, this message translates to:
  /// **'Reconstruite via At-Tijaniya — retrouvez votre lignée spirituelle'**
  String get mouqaddamChainShareCardFooter;

  /// No description provided for @mouqaddamChainShareCardAction.
  ///
  /// In fr, this message translates to:
  /// **'Partager l\'image'**
  String get mouqaddamChainShareCardAction;

  /// No description provided for @mouqaddamChainShareError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de générer l\'image à partager.'**
  String get mouqaddamChainShareError;

  /// No description provided for @mouqaddamChainShareCardClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get mouqaddamChainShareCardClose;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguageSection;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsNotificationsBody.
  ///
  /// In fr, this message translates to:
  /// **'Les rappels de récitation se gèrent depuis chaque Wird (icône cloche sur l\'écran du Wird).'**
  String get settingsNotificationsBody;

  /// No description provided for @settingsPrivacySection.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get settingsPrivacySection;

  /// No description provided for @settingsPrivacyTileSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité de votre lignée, de votre statut mouqaddam, qui peut vous contacter'**
  String get settingsPrivacyTileSubtitle;

  /// No description provided for @settingsDonationSection.
  ///
  /// In fr, this message translates to:
  /// **'Faire un don'**
  String get settingsDonationSection;

  /// No description provided for @settingsDonationTileSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'At-Tijaniya reste gratuite grâce à vous.'**
  String get settingsDonationTileSubtitle;

  /// No description provided for @settingsAboutSection.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settingsAboutSection;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// No description provided for @privacyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get privacyTitle;

  /// No description provided for @privacyLineageVisibleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité de ma lignée spirituelle'**
  String get privacyLineageVisibleLabel;

  /// No description provided for @privacyLineageVisibleDescription.
  ///
  /// In fr, this message translates to:
  /// **'Vous rendre visible aux disciples de votre moqaddam.'**
  String get privacyLineageVisibleDescription;

  /// No description provided for @privacyMouqaddamVisibleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité de mon statut Mouqaddam'**
  String get privacyMouqaddamVisibleLabel;

  /// No description provided for @privacyMouqaddamVisibleDescription.
  ///
  /// In fr, this message translates to:
  /// **'Rendre visible votre statut et votre silsila d\'ijaza.'**
  String get privacyMouqaddamVisibleDescription;

  /// No description provided for @privacyAvailableAsSponsorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Disponible comme parrain'**
  String get privacyAvailableAsSponsorLabel;

  /// No description provided for @privacyAvailableAsSponsorDescription.
  ///
  /// In fr, this message translates to:
  /// **'Être trouvable par des candidats mouqaddam cherchant un parrain.'**
  String get privacyAvailableAsSponsorDescription;

  /// No description provided for @privacyWhoCanContactLabel.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut vous contacter'**
  String get privacyWhoCanContactLabel;

  /// No description provided for @privacyWhoCanContactEveryone.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde'**
  String get privacyWhoCanContactEveryone;

  /// No description provided for @privacyWhoCanContactMatchesOnly.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement les correspondances'**
  String get privacyWhoCanContactMatchesOnly;

  /// No description provided for @privacyLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos réglages de confidentialité.'**
  String get privacyLoadError;

  /// No description provided for @privacyRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get privacyRetry;

  /// No description provided for @privacyUpdateError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer ce réglage.'**
  String get privacyUpdateError;

  /// No description provided for @donationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Faire un don'**
  String get donationTitle;

  /// No description provided for @donationSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'At-Tijaniya reste gratuite grâce à vous.'**
  String get donationSubtitle;

  /// No description provided for @donationCustomAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant libre'**
  String get donationCustomAmountLabel;

  /// No description provided for @donationCustomAmountHint.
  ///
  /// In fr, this message translates to:
  /// **'Autre montant…'**
  String get donationCustomAmountHint;

  /// No description provided for @donationAmountInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Merci de choisir ou saisir un montant valide.'**
  String get donationAmountInvalid;

  /// No description provided for @donationSubmitButton.
  ///
  /// In fr, this message translates to:
  /// **'Faire un don'**
  String get donationSubmitButton;

  /// No description provided for @donationSubmitError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer votre don pour le moment.'**
  String get donationSubmitError;

  /// No description provided for @donationRecordedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre soutien'**
  String get donationRecordedTitle;

  /// No description provided for @donationRecordedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement en ligne n\'est pas encore disponible dans l\'application. Votre intention de don a bien été enregistrée.'**
  String get donationRecordedBody;

  /// No description provided for @donationRecordedBackButton.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get donationRecordedBackButton;
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
