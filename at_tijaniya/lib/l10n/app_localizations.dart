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

  /// No description provided for @figureBiographySectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Biographie'**
  String get figureBiographySectionTitle;

  /// No description provided for @figureCitationsSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Citations'**
  String get figureCitationsSectionTitle;

  /// No description provided for @figureZiyaraSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ziyara associée'**
  String get figureZiyaraSectionTitle;

  /// No description provided for @figureBiographyPending.
  ///
  /// In fr, this message translates to:
  /// **'Biographie en attente de validation.'**
  String get figureBiographyPending;

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

  /// No description provided for @privacyNoEffectYetNote.
  ///
  /// In fr, this message translates to:
  /// **'Ce réglage n\'a pas encore d\'effet visible : la fonctionnalité correspondante n\'est pas encore disponible dans l\'app.'**
  String get privacyNoEffectYetNote;

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
