// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'At-Tijaniya';

  @override
  String get languageChoiceTitle => 'Choisissez votre langue';

  @override
  String get languageChoiceSubtitle =>
      'Vous pourrez la changer à tout moment dans les paramètres.';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get imagePickerAdd => 'Ajouter une image';

  @override
  String get imagePickerChange => 'Changer l\'image';

  @override
  String get imagePickerRemove => 'Retirer l\'image';

  @override
  String get imagePickerGallery => 'Galerie';

  @override
  String get imagePickerCamera => 'Appareil photo';

  @override
  String get imagePickerUploadError => 'Impossible de téléverser l\'image.';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue sur At-Tijaniya';

  @override
  String get onboardingWelcomeBody =>
      'Votre compagnon numérique pour la pratique quotidienne, en français et en arabe.';

  @override
  String get onboardingWirdTitle => 'Vos wirds, guidés pas à pas';

  @override
  String get onboardingWirdBody =>
      'Lazim, Wazifa et Hadratou-l-Jouma : texte, translittération, traduction et tasbih digital pour réciter sereinement.';

  @override
  String get onboardingKhadaraTitle => 'Khadara : évènements et diffusions';

  @override
  String get onboardingKhadaraBody =>
      'Calendrier des évènements, annuaire des zawiyas et diffusions en direct pour rester connecté à la communauté.';

  @override
  String get onboardingCommunityTitle => 'Une communauté de disciples';

  @override
  String get onboardingCommunityBody =>
      'Retrouvez votre entourage spirituel et suivez l\'actualité de votre zawiya.';

  @override
  String get authTabLogin => 'Connexion';

  @override
  String get authTabSignup => 'Créer un compte';

  @override
  String get authTitle => 'Bienvenue';

  @override
  String get authSubtitle => 'Connectez-vous pour retrouver votre communauté.';

  @override
  String get authSignupTitle => 'Créer un compte';

  @override
  String get authSignupSubtitle =>
      'Rejoignez la communauté et commencez à réciter vos wirds.';

  @override
  String get authFullNameLabel => 'Nom complet';

  @override
  String get authFullNameRequired => 'Le nom complet est obligatoire.';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPhoneLabel => 'Téléphone';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authPasswordMinCharsHint => '8 caractères minimum';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authResetPasswordSent =>
      'E-mail de réinitialisation envoyé. Vérifiez votre boîte mail.';

  @override
  String get authSignInAction => 'Se connecter';

  @override
  String get authSignUpAction => 'Créer un compte';

  @override
  String get authContinueWithoutAccount =>
      'Continuer sans compte (pratique du Wird uniquement)';

  @override
  String get authEmailRequired => 'L\'adresse e-mail est obligatoire.';

  @override
  String get authEmailInvalid => 'Adresse e-mail invalide.';

  @override
  String get authPasswordRequired => 'Le mot de passe est obligatoire.';

  @override
  String get authPasswordTooShort =>
      'Le mot de passe doit contenir au moins 6 caractères.';

  @override
  String get authPasswordTooShortSignup =>
      'Le mot de passe doit contenir au moins 8 caractères.';

  @override
  String get authInvalidCredentials =>
      'Adresse e-mail ou mot de passe incorrect.';

  @override
  String get authEmailAlreadyRegistered =>
      'Un compte existe déjà avec cette adresse e-mail.';

  @override
  String get authWeakPassword =>
      'Mot de passe trop faible. Utilisez au moins 6 caractères.';

  @override
  String get authEmailNotConfirmed =>
      'Confirmez votre e-mail avant de vous connecter (lien envoyé à votre adresse).';

  @override
  String get authRateLimited =>
      'Trop de tentatives. Réessayez dans quelques instants.';

  @override
  String get authGenericError => 'Une erreur est survenue. Réessayez.';

  @override
  String get authCheckEmailToConfirm =>
      'Compte créé. Vérifiez votre boîte mail pour confirmer votre adresse avant de vous connecter.';

  @override
  String get authLegalPrefix => 'En créant un compte, vous acceptez nos ';

  @override
  String get authLegalTerms => 'Conditions d\'utilisation';

  @override
  String get authLegalMiddle => ' et notre ';

  @override
  String get authLegalPrivacy => 'Politique de confidentialité';

  @override
  String get authLegalSuffix => '.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navWird => 'Wird';

  @override
  String get navKhadara => 'Khadara';

  @override
  String get navFigures => 'Figures';

  @override
  String get navCommunity => 'Communauté';

  @override
  String get homeGreeting => 'Salam, disciple';

  @override
  String get homeGreetingPrefix => 'Salam,';

  @override
  String homeDateLine(String weekday, int day, String month, int year,
      int hijriDay, String hijriMonth, int hijriYear) {
    return '$weekday $day $month $year · $hijriDay $hijriMonth $hijriYear';
  }

  @override
  String get homeDateWeekdayMonday => 'Lundi';

  @override
  String get homeDateWeekdayTuesday => 'Mardi';

  @override
  String get homeDateWeekdayWednesday => 'Mercredi';

  @override
  String get homeDateWeekdayThursday => 'Jeudi';

  @override
  String get homeDateWeekdayFriday => 'Vendredi';

  @override
  String get homeDateWeekdaySaturday => 'Samedi';

  @override
  String get homeDateWeekdaySunday => 'Dimanche';

  @override
  String get homeDateMonthJanuary => 'janvier';

  @override
  String get homeDateMonthFebruary => 'février';

  @override
  String get homeDateMonthMarch => 'mars';

  @override
  String get homeDateMonthApril => 'avril';

  @override
  String get homeDateMonthMay => 'mai';

  @override
  String get homeDateMonthJune => 'juin';

  @override
  String get homeDateMonthJuly => 'juillet';

  @override
  String get homeDateMonthAugust => 'août';

  @override
  String get homeDateMonthSeptember => 'septembre';

  @override
  String get homeDateMonthOctober => 'octobre';

  @override
  String get homeDateMonthNovember => 'novembre';

  @override
  String get homeDateMonthDecember => 'décembre';

  @override
  String get homeDateHijriMonth1 => 'Mouharram';

  @override
  String get homeDateHijriMonth2 => 'Safar';

  @override
  String get homeDateHijriMonth3 => 'Rabi al-Awwal';

  @override
  String get homeDateHijriMonth4 => 'Rabi ath-Thani';

  @override
  String get homeDateHijriMonth5 => 'Joumada al-Oula';

  @override
  String get homeDateHijriMonth6 => 'Joumada ath-Thania';

  @override
  String get homeDateHijriMonth7 => 'Rajab';

  @override
  String get homeDateHijriMonth8 => 'Chaabane';

  @override
  String get homeDateHijriMonth9 => 'Ramadan';

  @override
  String get homeDateHijriMonth10 => 'Chawwal';

  @override
  String get homeDateHijriMonth11 => 'Dhoul Qi\'da';

  @override
  String get homeDateHijriMonth12 => 'Dhoul Hijja';

  @override
  String get homeLoadError => 'Impossible de charger votre tableau de bord.';

  @override
  String get homeRetry => 'Réessayer';

  @override
  String get homeStatusAllDone => 'Tous les wirds du jour sont accomplis';

  @override
  String get homeStatusNoneDone =>
      'Aucun wird accompli aujourd\'hui pour l\'instant';

  @override
  String homeStatusPartial(int done, int total) {
    return '$done sur $total wirds accomplis aujourd\'hui';
  }

  @override
  String get homeSectionToday => 'Aujourd\'hui';

  @override
  String homeStreakDaily(int count) {
    return '$count jours de suite';
  }

  @override
  String homeStreakWeekly(int count) {
    return '$count vendredis de suite';
  }

  @override
  String get homeWirdSubtitlePendingDaily => 'Non commencé aujourd\'hui';

  @override
  String get homeWirdSubtitlePendingFridayToday => 'Aujourd\'hui, vendredi';

  @override
  String get homeWirdSubtitleWeeklyInfo => 'Hebdomadaire — vendredi';

  @override
  String get homeSectionNextMoment => 'Prochain moment';

  @override
  String get homeResumeTasbihTitle => 'Reprendre le Tasbih';

  @override
  String homeResumeTasbihSubtitle(String pillar, int count, int target) {
    return '$pillar — $count / $target';
  }

  @override
  String get homeResumeTasbihCta => 'Continuer';

  @override
  String homeNextReminderSubtitle(String wird, String time) {
    return '$wird — aujourd\'hui à $time';
  }

  @override
  String get homeSectionQuickAccess => 'Accès rapide';

  @override
  String get homeQuickTasbihLabel => 'Tasbih libre';

  @override
  String get homeSectionKhadara => 'Khadara à venir';

  @override
  String get homeSectionFeaturedFigure => 'Figure de la semaine';

  @override
  String get wirdListTitle => 'Mes Wirds';

  @override
  String get wirdLazim => 'Lazim';

  @override
  String get wirdWazifa => 'Wazifa';

  @override
  String get wirdHadratouJouma => 'Hadratou-l-Jouma';

  @override
  String get wirdFreeTitle => 'Wird libre';

  @override
  String get wirdFreeSubtitle => 'Paramétrez votre propre compteur';

  @override
  String get wirdFreeSetupTitle => 'Nouveau compteur libre';

  @override
  String get wirdFreeLabelFieldLabel => 'Que récitez-vous ? (optionnel)';

  @override
  String get wirdFreeTargetFieldLabel => 'Nombre de répétitions';

  @override
  String get wirdFreeTargetRequired =>
      'Indiquez un nombre de répétitions supérieur à 0.';

  @override
  String get wirdFreeStartButton => 'Commencer';

  @override
  String get wirdFreeManualMode => 'Tape manuel';

  @override
  String get wirdFreeVoiceMode => 'Voix';

  @override
  String get wirdFreeUndo => 'Corriger -1';

  @override
  String get wirdFreeReset => 'Réinitialiser';

  @override
  String get wirdFreeFinishButton => 'Terminer';

  @override
  String get wirdFreeTapToCount => 'Toucher pour compter';

  @override
  String get wirdFreeListeningActive =>
      'À l\'écoute — récitez, une pause de silence = +1';

  @override
  String get wirdFreeListeningPaused => 'Micro en pause';

  @override
  String get wirdFreeVoiceUnavailable =>
      'Reconnaissance vocale indisponible sur cet appareil.';

  @override
  String get wirdFreeStartListening => 'Démarrer l\'écoute';

  @override
  String get wirdFreeStopListening => 'Mettre en pause';

  @override
  String get wirdFreeCompletedTitle => 'Compteur terminé';

  @override
  String get wirdFreeCompletedBody =>
      'Vous avez atteint l\'objectif de répétitions fixé.';

  @override
  String get wirdFreeNewCounterButton => 'Nouveau compteur';

  @override
  String get wirdRecitationsReviewButton => 'Récitations à valider';

  @override
  String get wirdRecitationsReviewTitle => 'Récitations à valider';

  @override
  String get wirdRecitationsReviewEmpty =>
      'Aucune récitation en attente de validation.';

  @override
  String get wirdRecitationsReviewLoadError =>
      'Impossible de charger les récitations en attente.';

  @override
  String get wirdRecitationsReviewRetry => 'Réessayer';

  @override
  String get wirdRecitationsReviewValidate => 'Valider';

  @override
  String get wirdRecitationsReviewConfirmTitle => 'Valider cette récitation ?';

  @override
  String get wirdRecitationsReviewConfirmBody =>
      'Elle deviendra audible par tous les disciples dans l\'app.';

  @override
  String get wirdRecitationsReviewConfirmAction => 'Valider';

  @override
  String get wirdRecitationsReviewCancel => 'Annuler';

  @override
  String get wirdRecitationsReviewSuccess => 'Récitation validée et publiée.';

  @override
  String get wirdRecitationsReviewPreviewError =>
      'Lecture impossible — vérifiez votre connexion.';

  @override
  String get wirdRecitationsReviewDelete => 'Supprimer';

  @override
  String get wirdRecitationsReviewDeleteConfirmTitle =>
      'Supprimer ce brouillon ?';

  @override
  String get wirdRecitationsReviewDeleteConfirmBody =>
      'Cette action est définitive.';

  @override
  String get wirdRecitationsReviewDeleteError =>
      'Suppression impossible — vérifiez votre connexion.';

  @override
  String get wirdRecitationsReviewDeleteSuccess => 'Brouillon supprimé.';

  @override
  String get wirdRecitationsReviewManageButton =>
      'Gérer tous les enregistrements';

  @override
  String get wirdRecitationsManageTitle => 'Gestion des récitations audio';

  @override
  String get wirdRecitationsManageCardSubtitle =>
      'Ajouter ou supprimer un audio de pilier';

  @override
  String get wirdRecitationsManageLoadError =>
      'Impossible de charger les récitations.';

  @override
  String get wirdRecitationsManageEmpty =>
      'Aucun enregistrement pour ce pilier.';

  @override
  String get wirdRecitationsManageStatusDraft => 'Brouillon';

  @override
  String get wirdRecitationsManageStatusValidated => 'Validé';

  @override
  String get wirdRecitationsManageAddButton => 'Ajouter un enregistrement';

  @override
  String get wirdRecitationsManageDeleteConfirmTitle =>
      'Supprimer cet enregistrement ?';

  @override
  String get wirdRecitationsManageDeleteConfirmBodyDraft =>
      'Ce brouillon sera définitivement supprimé.';

  @override
  String get wirdRecitationsManageDeleteConfirmBodyLive =>
      'Cet audio est actuellement celui entendu par les disciples — il deviendra indisponible pour ce pilier jusqu\'à validation d\'un nouvel enregistrement.';

  @override
  String get wirdRecitationsManageDeleteError =>
      'Suppression impossible — vérifiez votre connexion.';

  @override
  String get wirdRecitationsManageDeleteSuccess => 'Enregistrement supprimé.';

  @override
  String get wirdRecitationsManageUploadReciterLabel => 'Nom du récitant';

  @override
  String get wirdRecitationsManageUploadPickFile => 'Choisir un fichier audio';

  @override
  String wirdRecitationsManageUploadFileChosen(String fileName) {
    return 'Fichier sélectionné : $fileName';
  }

  @override
  String get wirdRecitationsManageUploadHint =>
      'Format recommandé : AAC, mono, 64 kbit/s.';

  @override
  String get wirdRecitationsManageUploadSubmit => 'Téléverser';

  @override
  String get wirdRecitationsManageUploadError =>
      'Téléversement impossible — réessayez.';

  @override
  String get wirdRecitationsManageUploadSuccess =>
      'Enregistrement ajouté (brouillon).';

  @override
  String get wirdRecitationsManageValidate => 'Valider';

  @override
  String get tariqaConditionsCardTitle => 'Conditions de la Tariqa';

  @override
  String get tariqaConditionsCardSubtitle =>
      'Les 23 conditions du wird et de l\'affiliation';

  @override
  String get tariqaConditionsTitle => 'Conditions de la Tariqa';

  @override
  String get tariqaConditionsLoadError => 'Impossible de charger les données.';

  @override
  String get tariqaConditionsRetry => 'Réessayer';

  @override
  String get tariqaConditionsEmptyTitle => 'Contenu en cours de compilation';

  @override
  String get tariqaConditionsEmptyBody =>
      'Ce contenu sera publié une fois validé par un moqaddam ou érudit reconnu du projet.';

  @override
  String get tariqaConditionsCategoryValiditeTalqin => 'Validité du talqîn';

  @override
  String get tariqaConditionsCategoryCompagnonnage =>
      'Compagnonnage envers le Cheikh';

  @override
  String get tariqaConditionsCategoryConditionsGenerales =>
      'Conditions générales';

  @override
  String get tariqaConditionsCategoryValiditeRecitation =>
      'Validité de la récitation';

  @override
  String get tariqaConditionsCategoryConditionsComplementaires =>
      'Conditions complémentaires';

  @override
  String get tariqaConditionEditTitle => 'Modifier la condition';

  @override
  String get tariqaConditionFormCategoryLabel => 'Catégorie';

  @override
  String get tariqaConditionFormTextFrLabel => 'Texte (français)';

  @override
  String get tariqaConditionFormTextFrRequired =>
      'Le texte en français est requis.';

  @override
  String get tariqaConditionFormTextArLabel => 'Texte (arabe)';

  @override
  String get tariqaConditionFormSourceNoteLabel => 'Source';

  @override
  String get tariqaConditionFormSave => 'Enregistrer';

  @override
  String get tariqaConditionFormSaveError =>
      'Impossible d\'enregistrer la modification.';

  @override
  String get khadaraEventsTab => 'Évènements';

  @override
  String get khadaraZawiyasTab => 'Zawiyas';

  @override
  String get khadaraNoEvents => 'Aucun évènement à venir pour le moment.';

  @override
  String get khadaraNoZawiyas => 'Aucune zawiya renseignée pour le moment.';

  @override
  String get khadaraLoadError => 'Impossible de charger les données.';

  @override
  String get khadaraRetry => 'Réessayer';

  @override
  String get khadaraOpenInMaps => 'Ouvrir dans Maps';

  @override
  String get khadaraEventTypeZiyara => 'Ziyara';

  @override
  String get khadaraEventTypeHadra => 'Hadra';

  @override
  String get khadaraEventTypeOther => 'Autre';

  @override
  String get khadaraCreateEventButton => 'Créer un évènement';

  @override
  String get khadaraEditEventTooltip => 'Modifier';

  @override
  String get khadaraDeleteEventTooltip => 'Supprimer';

  @override
  String get khadaraDeleteEventConfirmTitle => 'Supprimer cet évènement ?';

  @override
  String get khadaraDeleteEventConfirmBody =>
      'Cette action est définitive. Les figures historiques associées à cet évènement seront également dissociées.';

  @override
  String get khadaraDeleteEventConfirmAction => 'Supprimer';

  @override
  String get khadaraDeleteEventBlockedByLiveStream =>
      'Impossible de supprimer cet évènement : un direct y est encore rattaché.';

  @override
  String get khadaraDeleteEventError =>
      'Impossible de supprimer cet évènement.';

  @override
  String get eventFormCreateTitle => 'Nouvel évènement';

  @override
  String get eventFormEditTitle => 'Modifier l\'évènement';

  @override
  String get eventFormTitleLabel => 'Titre';

  @override
  String get eventFormTitleRequired => 'Le titre est obligatoire.';

  @override
  String get eventFormDescriptionLabel => 'Description';

  @override
  String get eventFormTypeLabel => 'Type d\'évènement';

  @override
  String get eventFormStartsAtLabel => 'Date et heure de début';

  @override
  String get eventFormStartsAtRequired => 'La date de début est obligatoire.';

  @override
  String get eventFormPickDateTime => 'Choisir une date et une heure';

  @override
  String get eventFormEndsAtLabel => 'Date et heure de fin (optionnel)';

  @override
  String get eventFormEndsAtInvalid =>
      'La date de fin doit être postérieure à la date de début.';

  @override
  String get eventFormImageLabel => 'Image de couverture';

  @override
  String get eventFormZawiyaLabel => 'Zawiya';

  @override
  String get eventFormSave => 'Enregistrer';

  @override
  String get eventFormSaveError => 'Impossible d\'enregistrer l\'évènement.';

  @override
  String get khadaraUpcomingEventsAtZawiya => 'Prochains évènements';

  @override
  String get khadaraNoUpcomingEventsAtZawiya =>
      'Aucun évènement à venir dans cette zawiya.';

  @override
  String get khadaraAddressLabel => 'Adresse';

  @override
  String get khadaraContactLabel => 'Contact';

  @override
  String get khadaraAddZawiyaButton => 'Ajouter une zawiya';

  @override
  String get khadaraEditZawiyaTooltip => 'Modifier';

  @override
  String get khadaraDeleteZawiyaTooltip => 'Supprimer';

  @override
  String get khadaraDeleteZawiyaConfirmTitle => 'Supprimer cette zawiya ?';

  @override
  String get khadaraDeleteZawiyaConfirmBody => 'Cette action est définitive.';

  @override
  String get khadaraDeleteZawiyaConfirmAction => 'Supprimer';

  @override
  String get khadaraDeleteZawiyaBlockedByReferences =>
      'Impossible de supprimer cette zawiya : elle est encore utilisée (disciples rattachés, évènements, publications ou groupes).';

  @override
  String get khadaraDeleteZawiyaError =>
      'Impossible de supprimer cette zawiya.';

  @override
  String get zawiyaFormCreateTitle => 'Nouvelle zawiya';

  @override
  String get zawiyaFormEditTitle => 'Modifier la zawiya';

  @override
  String get zawiyaFormNameLabel => 'Nom';

  @override
  String get zawiyaFormNameRequired => 'Le nom est obligatoire.';

  @override
  String get zawiyaFormDescriptionLabel => 'Description';

  @override
  String get zawiyaFormAddressLabel => 'Adresse';

  @override
  String get zawiyaFormContactLabel => 'Contact';

  @override
  String get zawiyaFormLatitudeLabel => 'Latitude (optionnel)';

  @override
  String get zawiyaFormLongitudeLabel => 'Longitude (optionnel)';

  @override
  String get zawiyaFormCoordinateInvalid => 'Doit être un nombre valide.';

  @override
  String get zawiyaFormSave => 'Enregistrer';

  @override
  String get zawiyaFormSaveError => 'Impossible d\'enregistrer la zawiya.';

  @override
  String get khadaraUnderstandingTooltip => 'Comprendre la Khadara';

  @override
  String get khadaraUnderstandingTitle => 'Comprendre la Khadara';

  @override
  String get khadaraUnderstandingEmptyTitle =>
      'Contenu en cours de compilation';

  @override
  String get khadaraUnderstandingEmptyBody =>
      'Ce contenu pédagogique sera publié une fois validé par un moqaddam ou érudit reconnu du projet.';

  @override
  String get khadaraUnderstandingCta =>
      'En attendant, découvrir le calendrier et les zawiyas';

  @override
  String get khadaraLiveTab => 'Directs';

  @override
  String get khadaraLiveNowSection => 'En direct maintenant';

  @override
  String get khadaraReplaysSection => 'Rediffusions';

  @override
  String get khadaraNoLiveNow => 'Aucun direct en cours actuellement.';

  @override
  String get khadaraNoReplays => 'Aucune rediffusion pour le moment.';

  @override
  String get khadaraLiveBadge => 'En direct';

  @override
  String get khadaraJoinLive => 'Rejoindre le direct';

  @override
  String get khadaraStartLive => 'Démarrer un direct';

  @override
  String get khadaraStartLiveTitle => 'Démarrer un direct';

  @override
  String get khadaraStartLiveBody =>
      'Choisissez la plateforme sur laquelle vous diffusez déjà et collez le lien : il sera partagé avec les disciples pour qu\'ils rejoignent le direct.';

  @override
  String get khadaraSourceYoutube => 'YouTube';

  @override
  String get khadaraSourceFacebook => 'Facebook';

  @override
  String get khadaraSourceOther => 'Autre lien';

  @override
  String get khadaraSourceNative => 'Natif (diffuser depuis l\'app)';

  @override
  String get khadaraSourceNativeUnavailable =>
      'Nécessite un prestataire de streaming, pas encore disponible.';

  @override
  String get khadaraExternalUrlLabel => 'Lien du direct';

  @override
  String get khadaraExternalUrlRequired => 'Le lien est obligatoire.';

  @override
  String get khadaraStartLiveButton => 'Démarrer';

  @override
  String get khadaraStartLiveError => 'Impossible de démarrer ce direct.';

  @override
  String get khadaraWatchOn => 'Regarder le direct';

  @override
  String get khadaraEndLiveButton => 'Terminer';

  @override
  String get khadaraEndLiveConfirmTitle => 'Terminer ce direct ?';

  @override
  String get khadaraEndLiveConfirmBody =>
      'Les disciples ne pourront plus le rejoindre.';

  @override
  String get khadaraEndLiveConfirmAction => 'Terminer';

  @override
  String get khadaraLiveEnded => 'Ce direct est terminé.';

  @override
  String get khadaraChatHint => 'Écrire un message…';

  @override
  String get khadaraChatSignInToWrite =>
      'Connectez-vous pour écrire dans le chat.';

  @override
  String get khadaraChatEmpty => 'Aucun message pour le moment.';

  @override
  String get khadaraNativeNotAvailable =>
      'Le direct natif n\'est pas encore disponible — aucun prestataire de streaming n\'a encore été choisi pour l\'app.';

  @override
  String get khadaraOpenReplayError => 'Impossible d\'ouvrir ce lien.';

  @override
  String get khadaraAddReplayTooltip => 'Ajouter une rediffusion';

  @override
  String get khadaraAddReplayTitle => 'Ajouter une rediffusion';

  @override
  String get khadaraAddReplayUrlLabel => 'Lien de la vidéo';

  @override
  String get khadaraAddReplayUrlInvalid => 'Entrez un lien valide.';

  @override
  String get khadaraAddReplayDurationLabel => 'Durée en minutes (optionnel)';

  @override
  String get khadaraAddReplaySave => 'Enregistrer';

  @override
  String get khadaraAddReplaySuccess => 'Rediffusion ajoutée.';

  @override
  String get khadaraAddReplayError =>
      'Impossible d\'ajouter cette rediffusion.';

  @override
  String get figuresSectionFounders => 'Fondateurs';

  @override
  String get figuresSectionFamilies => 'Familles religieuses';

  @override
  String get figuresEmptyTitle => 'Biographies en cours de compilation';

  @override
  String get figuresEmptyBody =>
      'Ce contenu, sensible, ne sera publié qu\'après validation par un moqaddam ou érudit reconnu du projet.';

  @override
  String get figuresLoadError => 'Impossible de charger les données.';

  @override
  String get figuresRetry => 'Réessayer';

  @override
  String get figuresReviewButton => 'Contenu à valider';

  @override
  String get featuredFigureAdminButton => 'Figure de la semaine';

  @override
  String get featuredFigureAdminTitle => 'Figure de la semaine';

  @override
  String get featuredFigureAdminIntro =>
      'Sans épinglage pour une semaine, l\'app choisit automatiquement une figure valide dotée d\'un portrait.';

  @override
  String get featuredFigureAdminPinnedLabel => 'Épinglée pour cette semaine';

  @override
  String get featuredFigureAdminClear => 'Retirer';

  @override
  String get featuredFigureAdminNoPin =>
      'Aucune figure épinglée — la rotation automatique choisira.';

  @override
  String get featuredFigureAdminNoEligible =>
      'Aucune figure valide n\'a encore de portrait. Ajoutez-en un depuis la fiche d\'une figure pour pouvoir l\'épingler ici.';

  @override
  String get featuredFigureAdminPickLabel => 'Choisir une figure';

  @override
  String get featuredFigureAdminPinCta => 'Épingler pour cette semaine';

  @override
  String get featuredFigureAdminSaveError =>
      'Une erreur est survenue. Réessayez.';

  @override
  String get figuresReviewTitle => 'Figures à valider';

  @override
  String get figuresReviewEmpty => 'Aucune figure en attente de validation.';

  @override
  String get figuresReviewValidate => 'Valider';

  @override
  String get figuresReviewConfirmTitle => 'Valider cette biographie ?';

  @override
  String get figuresReviewConfirmBody =>
      'Elle deviendra visible par tous les disciples dans l\'app.';

  @override
  String get figuresReviewConfirmAction => 'Valider';

  @override
  String get figuresReviewCancel => 'Annuler';

  @override
  String get figuresReviewSuccess => 'Figure validée et publiée.';

  @override
  String get figureBiographySectionTitle => 'Biographie';

  @override
  String get figureTabSilsila => 'Silsila';

  @override
  String get figureCitationsSectionTitle => 'Citations';

  @override
  String get figureZawiyaSectionTitle => 'Zawiya';

  @override
  String get figureBiographyPending => 'Biographie en attente de validation.';

  @override
  String get figureSilsilaPending =>
      'La silsila historique de cette figure n\'est pas encore disponible.';

  @override
  String get figureSilsilaLoadError =>
      'Impossible de charger la silsila historique.';

  @override
  String get figureSilsilaFounderLabel => 'Fondateur de la tarikha';

  @override
  String get figureSilsilaAddButton => 'Ajouter à la silsila';

  @override
  String get figureSilsilaEditButton => 'Modifier la position';

  @override
  String get figureSilsilaRemoveButton => 'Retirer de la silsila';

  @override
  String get figureSilsilaRemoveConfirmTitle =>
      'Retirer cette figure de la silsila ?';

  @override
  String get figureSilsilaRemoveConfirmBody =>
      'La chaîne affichée pour toute figure descendante de celle-ci s\'arrêtera à ce maillon.';

  @override
  String get figureSilsilaRemoveConfirmAction => 'Retirer';

  @override
  String get figureSilsilaRemoveError => 'Impossible de retirer ce maillon.';

  @override
  String get figureSilsilaFormCreateTitle => 'Ajouter à la silsila';

  @override
  String get figureSilsilaFormEditTitle => 'Modifier la position';

  @override
  String get figureSilsilaFormIntro =>
      'La figure parente et le rang déterminent la place de cette figure dans la chaîne historique affichée aux disciples.';

  @override
  String get figureSilsilaFormParentLabel => 'Figure parente';

  @override
  String get figureSilsilaFormParentNone =>
      'Aucune — racine de la chaîne (fondateur)';

  @override
  String get figureSilsilaFormOrderLabel => 'Rang dans la chaîne';

  @override
  String get figureSilsilaFormOrderHint =>
      '0 pour le fondateur, puis en augmentant à chaque génération — généralement le rang de la figure parente + 1.';

  @override
  String get figureSilsilaFormOrderRequired => 'Le rang est requis.';

  @override
  String get figureSilsilaFormOrderInvalid =>
      'Le rang doit être un nombre entier.';

  @override
  String get figureSilsilaFormSave => 'Enregistrer';

  @override
  String get figureSilsilaFormSaveError =>
      'Impossible d\'enregistrer cette position.';

  @override
  String get figureCitationsEmpty =>
      'Aucune citation renseignée pour le moment.';

  @override
  String get figureWorksSectionTitle => 'Œuvres';

  @override
  String get figureZiyarasPending =>
      'Aucune ziyara associée n\'est encore renseignée.';

  @override
  String get figureZiyarasAddButton => 'Lier un évènement';

  @override
  String get figureZiyarasLinkError => 'Impossible de lier cet évènement.';

  @override
  String get figureZiyarasLinkPickerTitle => 'Choisir un évènement';

  @override
  String get figureZiyarasLinkPickerEmpty =>
      'Aucun évènement disponible à lier.';

  @override
  String get figureZiyarasUnlinkConfirmTitle => 'Délier cet évènement ?';

  @override
  String get figureZiyarasUnlinkConfirmBody =>
      'L\'évènement ne sera plus associé à cette figure.';

  @override
  String get figureZiyarasUnlinkConfirmAction => 'Délier';

  @override
  String get figureZiyarasUnlinkError => 'Impossible de délier cet évènement.';

  @override
  String get figureZawiyasSectionTitle => 'Zawiyas rattachées';

  @override
  String get figureZawiyasPending =>
      'Aucune zawiya rattachée n\'est encore renseignée.';

  @override
  String get figureZawiyasAddButton => 'Lier une zawiya';

  @override
  String get figureZawiyasLinkError => 'Impossible de lier cette zawiya.';

  @override
  String get figureZawiyasPickerTitle => 'Choisir une zawiya';

  @override
  String get figureZawiyasPickerEmpty => 'Aucune zawiya disponible à lier.';

  @override
  String get figureZawiyasUnlinkConfirmTitle => 'Délier cette zawiya ?';

  @override
  String get figureZawiyasUnlinkConfirmBody =>
      'La zawiya ne sera plus associée à cette figure.';

  @override
  String get figureZawiyasUnlinkConfirmAction => 'Délier';

  @override
  String get figureZawiyasUnlinkError => 'Impossible de délier cette zawiya.';

  @override
  String get figureZawiyaEventsSectionTitle => 'Évènements liés';

  @override
  String get figureKhalifaChainSectionTitle => 'Chaîne de khalifas';

  @override
  String get figureKhalifaFounderLabel => 'Fondateur';

  @override
  String get figureKhalifaChainPending =>
      'La chaîne de succession de cette zawiya n\'est pas encore renseignée.';

  @override
  String get figureKhalifaChainLoadError =>
      'Impossible de charger la chaîne de khalifas.';

  @override
  String get figureKhalifaAddButton => 'Ajouter un khalife';

  @override
  String get figureKhalifaEditButton => 'Modifier';

  @override
  String get figureKhalifaRemoveButton => 'Retirer';

  @override
  String get figureKhalifaRemoveConfirmTitle =>
      'Retirer ce khalife de la chaîne ?';

  @override
  String get figureKhalifaRemoveConfirmBody => 'Cette action est définitive.';

  @override
  String get figureKhalifaRemoveConfirmAction => 'Retirer';

  @override
  String get figureKhalifaRemoveError => 'Impossible de retirer ce khalife.';

  @override
  String get figureKhalifaFormCreateTitle => 'Ajouter un khalife';

  @override
  String get figureKhalifaFormEditTitle => 'Modifier ce khalife';

  @override
  String get figureKhalifaFormFigureLabel => 'Figure du khalife';

  @override
  String get figureKhalifaFormFigureNone => 'Choisir une figure';

  @override
  String get figureKhalifaFormOrderLabel => 'Rang dans la chaîne';

  @override
  String get figureKhalifaFormOrderHint =>
      '1 pour le premier khalife après le fondateur, puis en augmentant à chaque succession.';

  @override
  String get figureKhalifaFormOrderRequired => 'Le rang est requis.';

  @override
  String get figureKhalifaFormOrderInvalid =>
      'Le rang doit être un nombre entier.';

  @override
  String get figureKhalifaFormPeriodLabel => 'Période (optionnel)';

  @override
  String get figureKhalifaFormPeriodHint =>
      'Texte libre, ex. 1902-1922 ou vers 1950.';

  @override
  String get figureKhalifaFormSave => 'Enregistrer';

  @override
  String get figureKhalifaFormSaveError =>
      'Impossible d\'enregistrer ce khalife.';

  @override
  String get figuresCreateButton => 'Créer une figure';

  @override
  String get figureEditTooltip => 'Modifier';

  @override
  String get figureDeleteTooltip => 'Supprimer';

  @override
  String get figureDeleteConfirmTitle => 'Supprimer cette figure ?';

  @override
  String get figureDeleteConfirmBody =>
      'Cette action est définitive. Ses citations, œuvres et son maillon de silsila seront également supprimés.';

  @override
  String get figureDeleteConfirmAction => 'Supprimer';

  @override
  String get figureDeleteBlockedBySilsila =>
      'Impossible de supprimer cette figure : elle est encore référencée dans la silsila d\'une autre figure.';

  @override
  String get figureDeleteBlockedByKhalifaChain =>
      'Impossible de supprimer cette figure : elle est encore référencée comme khalife dans une chaîne de succession.';

  @override
  String get figureDeleteError => 'Impossible de supprimer cette figure.';

  @override
  String get figureCitationsAddButton => 'Ajouter une citation';

  @override
  String get figureCitationEditTooltip => 'Modifier';

  @override
  String get figureCitationDeleteTooltip => 'Supprimer';

  @override
  String get figureCitationDeleteConfirmTitle => 'Supprimer cette citation ?';

  @override
  String get figureCitationDeleteConfirmBody => 'Cette action est définitive.';

  @override
  String get figureCitationDeleteConfirmAction => 'Supprimer';

  @override
  String get figureCitationDeleteError =>
      'Impossible de supprimer cette citation.';

  @override
  String get figureCitationFormCreateTitle => 'Nouvelle citation';

  @override
  String get figureCitationFormEditTitle => 'Modifier la citation';

  @override
  String get figureCitationFormArabicLabel => 'Texte arabe (optionnel)';

  @override
  String get figureCitationFormFrenchLabel => 'Traduction française';

  @override
  String get figureCitationFormTextRequired =>
      'Renseignez au moins le texte arabe ou la traduction.';

  @override
  String get figureCitationFormSourceLabel => 'Source';

  @override
  String get figureCitationFormSourceRequired => 'La source est obligatoire.';

  @override
  String get figureCitationFormSave => 'Enregistrer';

  @override
  String get figureCitationFormSaveError =>
      'Impossible d\'enregistrer cette citation.';

  @override
  String get figureWorksAddButton => 'Ajouter une œuvre';

  @override
  String get figureWorkEditTooltip => 'Modifier';

  @override
  String get figureWorkDeleteTooltip => 'Supprimer';

  @override
  String get figureWorkDeleteConfirmTitle => 'Supprimer cette œuvre ?';

  @override
  String get figureWorkDeleteConfirmBody => 'Cette action est définitive.';

  @override
  String get figureWorkDeleteConfirmAction => 'Supprimer';

  @override
  String get figureWorkDeleteError => 'Impossible de supprimer cette œuvre.';

  @override
  String get figureWorkFormCreateTitle => 'Nouvelle œuvre';

  @override
  String get figureWorkFormEditTitle => 'Modifier l\'œuvre';

  @override
  String get figureWorkFormTitleLabel => 'Titre';

  @override
  String get figureWorkFormTitleRequired => 'Le titre est obligatoire.';

  @override
  String get figureWorkFormDescriptionLabel => 'Description (optionnel)';

  @override
  String get figureWorkFormSave => 'Enregistrer';

  @override
  String get figureWorkFormSaveError =>
      'Impossible d\'enregistrer cette œuvre.';

  @override
  String get figureFormCreateTitle => 'Nouvelle figure';

  @override
  String get figureFormEditTitle => 'Modifier la figure';

  @override
  String get figureFormNameArabicLabel => 'Nom (arabe)';

  @override
  String get figureFormNameArabicRequired => 'Le nom en arabe est obligatoire.';

  @override
  String get figureFormNameFrenchLabel => 'Nom (français)';

  @override
  String get figureFormNameFrenchRequired =>
      'Le nom en français est obligatoire.';

  @override
  String get figureFormCategoryLabel => 'Catégorie';

  @override
  String get figureFormCategoryFounder => 'Fondateur';

  @override
  String get figureFormCategoryFamily => 'Famille religieuse';

  @override
  String get figureFormFoyerLabel => 'Foyer (optionnel)';

  @override
  String get figureFormFoyerNone => '—';

  @override
  String get figureFormBirthYearHijriLabel =>
      'Année de naissance (hégirienne, optionnel)';

  @override
  String get figureFormBirthYearHijriInvalid =>
      'Doit être un nombre entier valide.';

  @override
  String get figureFormBioTextLabel => 'Biographie';

  @override
  String get figureFormBioTextHint =>
      'Paragraphes séparés par une ligne vide. Une section finale \"SOURCES CONSULTÉES\" est possible (traçabilité interne, jamais montrée au disciple).';

  @override
  String get figureFormSave => 'Enregistrer';

  @override
  String get figureFormSaveError => 'Impossible d\'enregistrer la figure.';

  @override
  String get communityFeedEmpty => 'Aucune publication pour le moment.';

  @override
  String get communityLoadError => 'Impossible de charger les publications.';

  @override
  String get communityRetry => 'Réessayer';

  @override
  String get communityDefaultAuthor => 'Disciple';

  @override
  String get communitySignInToInteract =>
      'Connectez-vous pour aimer ou commenter une publication.';

  @override
  String get communityCommentsTitle => 'Commentaires';

  @override
  String get communityNoComments => 'Aucun commentaire pour le moment.';

  @override
  String get communityCommentHint => 'Ajouter un commentaire...';

  @override
  String get communityCommentSignInHint => 'Connectez-vous pour commenter.';

  @override
  String get communitySend => 'Envoyer';

  @override
  String get communityCreatePostButton => 'Publier';

  @override
  String get communityCreatePostTitle => 'Nouvelle publication';

  @override
  String get communityCreatePostContentLabel => 'Votre message';

  @override
  String get communityCreatePostContentRequired =>
      'Le message est obligatoire.';

  @override
  String get communityCreatePostSubmit => 'Publier';

  @override
  String get communityCreatePostZawiyaNote =>
      'Publié au nom de votre zawiya de rattachement.';

  @override
  String get communityCreatePostSignInRequired =>
      'Connectez-vous pour publier.';

  @override
  String get communityCreatePostNeedsZawiya =>
      'Seuls les comptes rattachés à une zawiya peuvent publier pour le moment. Renseignez votre zawiya de rattachement depuis votre profil.';

  @override
  String get communityFeedTab => 'Fil';

  @override
  String get communityGroupsTab => 'Groupes';

  @override
  String get communityGroupsEmpty => 'Aucun groupe pour le moment.';

  @override
  String get communityGroupsLoadError => 'Impossible de charger les groupes.';

  @override
  String get communityGroupsRetry => 'Réessayer';

  @override
  String get communityGroupsCreateButton => 'Créer un groupe';

  @override
  String get communityGroupsCreateTitle => 'Créer un groupe';

  @override
  String get communityGroupsNameLabel => 'Nom du groupe';

  @override
  String get communityGroupsNameRequired => 'Le nom du groupe est obligatoire.';

  @override
  String get communityGroupsDescriptionLabel => 'Description (optionnel)';

  @override
  String get communityGroupsZawiyaLabel => 'Zawiya (optionnel)';

  @override
  String get communityGroupsRegionLabel => 'Région (optionnel)';

  @override
  String get communityGroupsCreateSubmit => 'Créer';

  @override
  String get communityGroupsSignInToCreate =>
      'Connectez-vous pour créer un groupe.';

  @override
  String get communityGroupsJoin => 'Rejoindre le groupe';

  @override
  String get communityGroupsLeave => 'Quitter le groupe';

  @override
  String get communityGroupsLeaveConfirmTitle => 'Quitter ce groupe ?';

  @override
  String get communityGroupsLeaveConfirmBody =>
      'Vous ne verrez plus ses discussions tant que vous ne l\'aurez pas rejoint à nouveau.';

  @override
  String get communityGroupsLeaveConfirmAction => 'Quitter';

  @override
  String get communityGroupsSignInToJoin =>
      'Connectez-vous pour rejoindre un groupe.';

  @override
  String get communityGroupsNotMemberTitle => 'Rejoignez ce groupe';

  @override
  String get communityGroupsNotMemberBody =>
      'Les discussions d\'un groupe ne sont visibles que pour ses membres.';

  @override
  String get communityGroupsPostsEmpty =>
      'Aucune discussion pour le moment. Soyez le premier à écrire !';

  @override
  String get communityGroupsPostHint => 'Écrire un message...';

  @override
  String get communityGroupsLoadPostsError =>
      'Impossible de charger les discussions.';

  @override
  String get communityGroupsEditTooltip => 'Modifier';

  @override
  String get communityGroupsEditTitle => 'Modifier le groupe';

  @override
  String get communityGroupsEditSubmit => 'Enregistrer';

  @override
  String get communityGroupsEditError => 'Impossible de modifier ce groupe.';

  @override
  String get communityGroupsDeleteTooltip => 'Supprimer';

  @override
  String get communityGroupsDeleteConfirmTitle => 'Supprimer ce groupe ?';

  @override
  String get communityGroupsDeleteConfirmBody =>
      'Cette action est définitive : les discussions et les membres seront perdus.';

  @override
  String get communityGroupsDeleteConfirmAction => 'Supprimer';

  @override
  String get communityGroupsDeleteError => 'Impossible de supprimer ce groupe.';

  @override
  String get communityGroupsDeleteBlockedByLiveStream =>
      'Impossible de supprimer ce groupe : un direct y est encore rattaché. Consultez « Directs passés » pour le supprimer d\'abord.';

  @override
  String get communityGroupsPastStreamsLink => 'Directs passés';

  @override
  String get communityGroupsPastStreamsTitle => 'Directs passés';

  @override
  String get communityGroupsPastStreamsEmpty =>
      'Aucun direct passé pour ce groupe.';

  @override
  String get communityGroupsPastStreamsLoadError =>
      'Impossible de charger les directs passés.';

  @override
  String get communityGroupsDeleteStreamTooltip => 'Supprimer';

  @override
  String get communityGroupsDeleteStreamConfirmTitle => 'Supprimer ce direct ?';

  @override
  String get communityGroupsDeleteStreamConfirmBody =>
      'Cette action est définitive : la rediffusion et les messages associés seront aussi supprimés.';

  @override
  String get communityGroupsDeleteStreamConfirmAction => 'Supprimer';

  @override
  String get communityGroupsDeleteStreamError =>
      'Impossible de supprimer ce direct.';

  @override
  String get communityGroupsEditPostTooltip => 'Modifier';

  @override
  String get communityGroupsEditPostTitle => 'Modifier le message';

  @override
  String get communityGroupsEditPostContentLabel => 'Votre message';

  @override
  String get communityGroupsEditPostContentRequired =>
      'Le message est obligatoire.';

  @override
  String get communityGroupsEditPostSubmit => 'Enregistrer';

  @override
  String get communityGroupsEditPostError =>
      'Impossible de modifier ce message.';

  @override
  String get communityGroupsDeletePostTooltip => 'Supprimer';

  @override
  String get communityGroupsDeletePostConfirmTitle => 'Supprimer ce message ?';

  @override
  String get communityGroupsDeletePostConfirmBody =>
      'Cette action est définitive.';

  @override
  String get communityGroupsDeletePostConfirmAction => 'Supprimer';

  @override
  String get communityGroupsDeletePostError =>
      'Impossible de supprimer ce message.';

  @override
  String get communityMessagesTooltip => 'Messages';

  @override
  String get communityConversationsTitle => 'Conversations';

  @override
  String get communityConversationsEmpty =>
      'Aucune conversation pour le moment.';

  @override
  String get communityConversationsLoadError =>
      'Impossible de charger les conversations.';

  @override
  String get communityConversationsRetry => 'Réessayer';

  @override
  String get communityConversationsNoMessages =>
      'Aucun message pour le moment. Écrivez le premier !';

  @override
  String get communitySendMessageButton => 'Envoyer un message';

  @override
  String get communityDeletePostTooltip => 'Supprimer';

  @override
  String get communityDeletePostConfirmTitle => 'Supprimer cette publication ?';

  @override
  String get communityDeletePostConfirmBody => 'Cette action est définitive.';

  @override
  String get communityDeletePostConfirmAction => 'Supprimer';

  @override
  String get communityDeletePostError =>
      'Impossible de supprimer cette publication.';

  @override
  String get communityEditPostTooltip => 'Modifier';

  @override
  String get communityEditPostTitle => 'Modifier la publication';

  @override
  String get communityEditPostContentLabel => 'Votre message';

  @override
  String get communityEditPostContentRequired => 'Le message est obligatoire.';

  @override
  String get communityEditPostSubmit => 'Enregistrer';

  @override
  String get communityEditPostError =>
      'Impossible de modifier cette publication.';

  @override
  String get communityDeleteCommentTooltip => 'Supprimer le commentaire';

  @override
  String get communityDeleteCommentConfirmTitle => 'Supprimer ce commentaire ?';

  @override
  String get communityDeleteCommentConfirmBody =>
      'Cette action est définitive.';

  @override
  String get communityDeleteCommentConfirmAction => 'Supprimer';

  @override
  String get communityDeleteCommentError =>
      'Impossible de supprimer ce commentaire.';

  @override
  String get profileTitle => 'Mon profil';

  @override
  String get profileMyLineage => 'Ma lignée spirituelle';

  @override
  String get profileSettings => 'Paramètres';

  @override
  String get profileSignOut => 'Se déconnecter';

  @override
  String get profileSignInRequired =>
      'Connectez-vous pour accéder à votre profil.';

  @override
  String get profileLoadError => 'Impossible de charger votre profil.';

  @override
  String get profileRetry => 'Réessayer';

  @override
  String get profileEditTooltip => 'Modifier mon profil';

  @override
  String get profileNoBio => 'Aucune présentation renseignée.';

  @override
  String get profileZawiyaNoneLabel => 'Aucune zawiya renseignée.';

  @override
  String get profileEditTitle => 'Modifier mon profil';

  @override
  String get profileDisplayNameLabel => 'Nom affiché';

  @override
  String get profileDisplayNameRequired => 'Le nom affiché est obligatoire.';

  @override
  String get profileBioLabel => 'À propos (optionnel)';

  @override
  String get profileZawiyaLabel => 'Zawiya';

  @override
  String get profileZawiyaNone => 'Aucune zawiya';

  @override
  String get profileSave => 'Enregistrer';

  @override
  String get profileUpdateError =>
      'Impossible d\'enregistrer les modifications.';

  @override
  String get profileSignOutConfirmTitle => 'Se déconnecter ?';

  @override
  String get profileSignOutConfirmBody =>
      'Vous devrez vous reconnecter pour retrouver votre communauté.';

  @override
  String get profileSignOutConfirmAction => 'Se déconnecter';

  @override
  String get profileDeleteAccount => 'Supprimer mon compte';

  @override
  String get profileDeleteAccountConfirmTitle =>
      'Supprimer définitivement votre compte ?';

  @override
  String get profileDeleteAccountConfirmBody =>
      'Cette action est irréversible. Votre profil, vos wirds enregistrés, votre lignée spirituelle et vos messages seront supprimés. Vos publications et évènements créés seront conservés, mais ne seront plus associés à votre compte.';

  @override
  String get profileDeleteAccountConfirmInstruction =>
      'Tapez SUPPRIMER pour confirmer.';

  @override
  String get profileDeleteAccountConfirmWord => 'SUPPRIMER';

  @override
  String get profileDeleteAccountConfirmAction => 'Supprimer mon compte';

  @override
  String get profileDeleteAccountError =>
      'Impossible de supprimer votre compte pour le moment. Réessayez plus tard.';

  @override
  String get profileCancel => 'Annuler';

  @override
  String get lineageTitle => 'Ma lignée spirituelle';

  @override
  String get lineagePrivacyNote =>
      'Ces informations restent strictement privées : visibles uniquement par vous, jamais dans un annuaire public.';

  @override
  String get lineageFoyerLabel => 'Foyer';

  @override
  String get lineageFoyerTivaouane => 'Tivaouane';

  @override
  String get lineageFoyerKaolack => 'Kaolack';

  @override
  String get lineageFoyerMedinaBaye => 'Médina Baye';

  @override
  String get lineageFoyerAutre => 'Autre';

  @override
  String get lineageFoyerAutreLabel => 'Précisez le foyer';

  @override
  String get lineageFoyerAutreRequired => 'Merci de préciser le foyer.';

  @override
  String get lineageMoqaddamNameLabel => 'Nom du moqaddam';

  @override
  String get lineageMoqaddamNameRequired =>
      'Le nom du moqaddam est obligatoire.';

  @override
  String get lineageYearLabel => 'Année de transmission (optionnel)';

  @override
  String get lineageYearInvalid => 'Année invalide (entre 1900 et 2100).';

  @override
  String get lineageZawiyaLabel => 'Zawiya / lieu de transmission (optionnel)';

  @override
  String get lineageSave => 'Enregistrer';

  @override
  String get lineageSaveSuccess => 'Lignée spirituelle enregistrée.';

  @override
  String get lineageSaveError => 'Impossible d\'enregistrer ces informations.';

  @override
  String get lineageDelete => 'Supprimer mes informations';

  @override
  String get lineageDeleteConfirmTitle => 'Supprimer ces informations ?';

  @override
  String get lineageDeleteConfirmBody =>
      'Votre lignée spirituelle sera définitivement supprimée.';

  @override
  String get lineageDeleteConfirmAction => 'Supprimer';

  @override
  String get lineageDeleteSuccess => 'Lignée spirituelle supprimée.';

  @override
  String get lineageLoadError =>
      'Impossible de charger votre lignée spirituelle.';

  @override
  String get lineageRetry => 'Réessayer';

  @override
  String get lineageFindDisciplesCta => 'Retrouver mes condisciples';

  @override
  String get lineageMatchesTitle => 'Retrouver mes condisciples';

  @override
  String get lineageMatchesLoadError =>
      'Impossible de charger ces informations.';

  @override
  String get lineageMatchesRetry => 'Réessayer';

  @override
  String get lineageMatchesNoLineageTitle => 'Renseignez d\'abord votre lignée';

  @override
  String get lineageMatchesNoLineageBody =>
      'Pour retrouver vos condisciples, indiquez d\'abord le foyer et le moqaddam qui vous a transmis le Wird.';

  @override
  String get lineageMatchesGoToLineageCta => 'Renseigner ma lignée';

  @override
  String get lineageMatchesNotVisibleTitle => 'Rendez votre lignée visible';

  @override
  String get lineageMatchesNotVisibleBody =>
      'Activez « Visibilité de ma lignée spirituelle » dans les paramètres de confidentialité pour retrouver vos condisciples.';

  @override
  String get lineageMatchesGoToPrivacyCta => 'Paramètres de confidentialité';

  @override
  String get lineageMatchesEmptyTitle => 'Aucune correspondance pour le moment';

  @override
  String get lineageMatchesEmptyBody =>
      'Nous vous montrerons ici tout condisciple ayant la même lignée et ayant lui aussi activé la visibilité.';

  @override
  String get lineageMatchesReceivedSection => 'Demandes reçues';

  @override
  String get lineageMatchesResultsSection => 'Condisciples correspondants';

  @override
  String get lineageMatchesAccept => 'Accepter';

  @override
  String get lineageMatchesDecline => 'Refuser';

  @override
  String get lineageMatchesRespondError =>
      'Impossible de répondre à cette demande.';

  @override
  String get lineageMatchesConnectButton => 'Se mettre en relation';

  @override
  String get lineageMatchesConnectError => 'Impossible d\'envoyer la demande.';

  @override
  String get lineageMatchesStatusPending => 'Demande envoyée';

  @override
  String get lineageMatchesStatusAccepted => 'Connecté';

  @override
  String get lineageMatchesStatusDeclined => 'Demande refusée';

  @override
  String get profileBecomeMouqaddam => 'Devenir Mouqaddam';

  @override
  String get profileSponsorshipRequests => 'Demandes de parrainage';

  @override
  String get profileMyIjazaChain => 'Ma silsila d\'ijaza';

  @override
  String get mouqaddamBecomeTitle => 'Devenir Mouqaddam';

  @override
  String get mouqaddamIntro =>
      'Le statut de mouqaddam vérifié n\'est jamais auto-proclamé : votre parrain doit confirmer qu\'il vous a transmis l\'ijaza.';

  @override
  String get mouqaddamLoadError => 'Impossible de charger votre demande.';

  @override
  String get mouqaddamRetry => 'Réessayer';

  @override
  String get mouqaddamChooseSponsorButton => 'Choisir un parrain';

  @override
  String get mouqaddamChangeSponsorButton => 'Changer de parrain';

  @override
  String get mouqaddamNoSponsorChosen =>
      'Aucun parrain choisi pour l\'instant.';

  @override
  String get mouqaddamSelectedSponsorLabel => 'Parrain choisi';

  @override
  String get mouqaddamYearFieldLabel =>
      'Année de transmission de l\'ijaza (optionnel)';

  @override
  String get mouqaddamYearInvalid => 'Année invalide (entre 1200 et 2100).';

  @override
  String get mouqaddamSubmitButton => 'Envoyer la demande';

  @override
  String get mouqaddamSponsorRequiredError =>
      'Choisissez un parrain avant d\'envoyer la demande.';

  @override
  String get mouqaddamSubmitError => 'Impossible d\'envoyer la demande.';

  @override
  String get mouqaddamPendingTitle => 'Demande en attente';

  @override
  String get mouqaddamPendingSponsorLabel => 'Parrain sollicité';

  @override
  String get mouqaddamPendingCancelButton => 'Annuler la demande';

  @override
  String get mouqaddamPendingCancelConfirmTitle => 'Annuler cette demande ?';

  @override
  String get mouqaddamPendingCancelConfirmBody =>
      'Vous pourrez en soumettre une nouvelle à tout moment.';

  @override
  String get mouqaddamPendingCancelConfirmAction => 'Annuler la demande';

  @override
  String get mouqaddamCancelError => 'Impossible d\'annuler la demande.';

  @override
  String get mouqaddamRejectedNote =>
      'Votre dernière demande a été refusée. Vous pouvez en soumettre une nouvelle.';

  @override
  String get mouqaddamSearchTitle => 'Rechercher un parrain';

  @override
  String get mouqaddamSearchFieldHint => 'Rechercher par nom...';

  @override
  String get mouqaddamSearchEmpty =>
      'Aucun mouqaddam disponible comme parrain pour le moment.';

  @override
  String get mouqaddamSearchNoResults => 'Aucun résultat pour cette recherche.';

  @override
  String get mouqaddamSearchLoadError => 'Impossible de charger les résultats.';

  @override
  String get mouqaddamRequestsTitle => 'Demandes de parrainage';

  @override
  String get mouqaddamRequestsEmpty =>
      'Aucune demande de parrainage en attente.';

  @override
  String get mouqaddamRequestsLoadError =>
      'Impossible de charger les demandes.';

  @override
  String get mouqaddamRequestsYearLabel => 'Année d\'ijaza indiquée';

  @override
  String get mouqaddamRequestsAccept => 'Accepter';

  @override
  String get mouqaddamRequestsReject => 'Refuser';

  @override
  String get mouqaddamRequestsAcceptConfirmTitle => 'Accepter cette demande ?';

  @override
  String get mouqaddamRequestsAcceptConfirmBody =>
      'Le statut de mouqaddam vérifié sera confirmé pour ce disciple.';

  @override
  String get mouqaddamRequestsRejectConfirmTitle => 'Refuser cette demande ?';

  @override
  String get mouqaddamRequestsRejectConfirmBody =>
      'Le disciple pourra soumettre une nouvelle demande à tout moment.';

  @override
  String get mouqaddamRequestsConfirmAction => 'Confirmer';

  @override
  String get mouqaddamRequestsSuccessAccepted => 'Demande acceptée.';

  @override
  String get mouqaddamRequestsSuccessRejected => 'Demande refusée.';

  @override
  String get mouqaddamRequestsError => 'Impossible de traiter cette demande.';

  @override
  String get mouqaddamChainTitle => 'Ma silsila d\'ijaza';

  @override
  String get mouqaddamChainLoadError => 'Impossible de charger votre silsila.';

  @override
  String get mouqaddamChainEmpty =>
      'Votre silsila n\'est pas encore disponible.';

  @override
  String get mouqaddamChainYouLabel => 'Vous';

  @override
  String get mouqaddamChainCompleteTitle =>
      'Compléter la chaîne au-delà de l\'app';

  @override
  String get mouqaddamChainCompleteBody =>
      'Si votre parrain n\'a jamais utilisé l\'application, ajoutez ici le prochain maillon connu (nom et date approximative), jusqu\'à Cheikh Ahmed Tijani.';

  @override
  String get mouqaddamChainNameFieldLabel => 'Nom';

  @override
  String get mouqaddamChainNameRequired => 'Le nom est obligatoire.';

  @override
  String get mouqaddamChainYearTextFieldLabel =>
      'Date approximative (optionnel)';

  @override
  String get mouqaddamChainAddButton => 'Ajouter ce maillon';

  @override
  String get mouqaddamChainAddError => 'Impossible d\'ajouter ce maillon.';

  @override
  String get mouqaddamChainAddSuccess => 'Maillon ajouté.';

  @override
  String get mouqaddamChainUltimateSourceQuestion =>
      'Cette personne est-elle Cheikh Ahmed Tijani, à l\'origine de la tarikha ?';

  @override
  String get mouqaddamChainCompleteDone =>
      'Votre silsila remonte déjà jusqu\'à Cheikh Ahmed Tijani — aucun maillon supplémentaire à ajouter.';

  @override
  String get mouqaddamChainReplayButton => 'Revivre l\'ascension';

  @override
  String get mouqaddamChainShareButton => 'Partager ma silsila';

  @override
  String get mouqaddamChainShareCardLockedNode => 'Maillon privé';

  @override
  String get mouqaddamChainShareCardFooter =>
      'Reconstruite via At-Tijaniya — retrouvez votre lignée spirituelle';

  @override
  String get mouqaddamChainShareCardAction => 'Partager l\'image';

  @override
  String get mouqaddamChainShareError =>
      'Impossible de générer l\'image à partager.';

  @override
  String get mouqaddamChainShareCardClose => 'Fermer';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsLanguageSection => 'Langue';

  @override
  String get settingsNotificationsSection => 'Notifications';

  @override
  String get settingsNotificationsBody =>
      'Les rappels de récitation se gèrent depuis chaque Wird (icône cloche sur l\'écran du Wird).';

  @override
  String get settingsPrivacySection => 'Confidentialité';

  @override
  String get settingsPrivacyTileSubtitle =>
      'Visibilité de votre lignée, de votre statut mouqaddam, qui peut vous contacter';

  @override
  String get settingsDonationSection => 'Faire un don';

  @override
  String get settingsDonationTileSubtitle =>
      'At-Tijaniya reste gratuite grâce à vous.';

  @override
  String get settingsAccessibilitySection => 'Accessibilité';

  @override
  String get settingsHighContrastTitle => 'Contraste renforcé';

  @override
  String get settingsHighContrastSubtitle =>
      'Texte et bordures plus marqués, plus faciles à lire.';

  @override
  String get settingsAboutSection => 'À propos';

  @override
  String get aboutVersionLabel => 'Version';

  @override
  String get privacyTitle => 'Confidentialité';

  @override
  String get privacyLineageVisibleLabel =>
      'Visibilité de ma lignée spirituelle';

  @override
  String get privacyLineageVisibleDescription =>
      'Vous rendre visible aux disciples de votre moqaddam.';

  @override
  String get privacyMouqaddamVisibleLabel =>
      'Visibilité de mon statut Mouqaddam';

  @override
  String get privacyMouqaddamVisibleDescription =>
      'Rendre visible votre statut et votre silsila d\'ijaza.';

  @override
  String get privacyAvailableAsSponsorLabel => 'Disponible comme parrain';

  @override
  String get privacyAvailableAsSponsorDescription =>
      'Être trouvable par des candidats mouqaddam cherchant un parrain.';

  @override
  String get privacyWhoCanContactLabel => 'Qui peut vous contacter';

  @override
  String get privacyWhoCanContactEveryone => 'Tout le monde';

  @override
  String get privacyWhoCanContactMatchesOnly =>
      'Uniquement les correspondances';

  @override
  String get privacyLoadError =>
      'Impossible de charger vos réglages de confidentialité.';

  @override
  String get privacyRetry => 'Réessayer';

  @override
  String get privacyUpdateError => 'Impossible d\'enregistrer ce réglage.';

  @override
  String get donationTitle => 'Faire un don';

  @override
  String get donationSubtitle => 'At-Tijaniya reste gratuite grâce à vous.';

  @override
  String get donationCustomAmountLabel => 'Montant libre';

  @override
  String get donationCustomAmountHint => 'Autre montant…';

  @override
  String get donationAmountInvalid =>
      'Merci de choisir ou saisir un montant valide.';

  @override
  String get donationSubmitButton => 'Faire un don';

  @override
  String get donationSubmitError =>
      'Impossible d\'enregistrer votre don pour le moment.';

  @override
  String get donationOpenCheckoutError =>
      'Impossible d\'ouvrir la page de paiement — réessayez.';

  @override
  String get donationRecordedTitle => 'Merci pour votre soutien';

  @override
  String get donationRecordedBody =>
      'La page de paiement s\'est ouverte dans votre navigateur. Complétez-y le règlement (Orange Money, Wave, carte…) pour finaliser votre don.';

  @override
  String get donationRecordedBackButton => 'Retour';

  @override
  String get moderationReportAction => 'Signaler';

  @override
  String get moderationReportDialogTitle => 'Signaler ce contenu';

  @override
  String get moderationReportDialogBody =>
      'Un administrateur examinera votre signalement.';

  @override
  String get moderationReportReasonLabel => 'Raison (optionnel)';

  @override
  String get moderationReportSubmit => 'Signaler';

  @override
  String get moderationReportSuccess => 'Signalement envoyé, merci.';

  @override
  String get moderationReportAlreadyReported =>
      'Vous avez déjà signalé ce contenu.';

  @override
  String get moderationReportError => 'Impossible d\'envoyer le signalement.';

  @override
  String get profileModerationReports => 'Signalements';

  @override
  String get moderationScreenTitle => 'Signalements';

  @override
  String get moderationEmptyState => 'Aucun signalement en attente.';

  @override
  String get moderationLoadError => 'Impossible de charger les signalements.';

  @override
  String get moderationRetry => 'Réessayer';

  @override
  String get moderationTypeLiveStream => 'Direct Khadara';

  @override
  String get moderationTypeLineageRequest => 'Mise en relation';

  @override
  String moderationReasonPrefix(String reason) {
    return 'Raison signalée : $reason';
  }

  @override
  String get moderationHideStreamAction => 'Masquer';

  @override
  String get moderationBlockRequestAction => 'Bloquer';

  @override
  String get moderationDismissAction => 'Rejeter le signalement';

  @override
  String get moderationConfirmHideStreamTitle => 'Masquer ce direct ?';

  @override
  String get moderationConfirmHideStreamBody =>
      'Le direct sera terminé et retiré de l\'application pour tous les disciples. Cette action est définitive.';

  @override
  String get moderationConfirmBlockRequestTitle =>
      'Bloquer cette mise en relation ?';

  @override
  String get moderationConfirmBlockRequestBody =>
      'La demande sera marquée refusée pour les deux disciples. Cette action est définitive.';

  @override
  String get moderationResolveSuccess => 'Signalement traité.';

  @override
  String get moderationResolveError => 'Impossible de traiter ce signalement.';

  @override
  String get notificationsTooltip => 'Notifications';

  @override
  String get notificationsScreenTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'Aucune notification pour l\'instant.';

  @override
  String get notificationsLoadError =>
      'Impossible de charger les notifications.';

  @override
  String get notificationStreamLiveTitle => 'Un direct vient de commencer';

  @override
  String get notificationStreamLiveBody => 'Touchez pour rejoindre le direct.';

  @override
  String get notificationContentReportTitle => 'Nouveau signalement';

  @override
  String get notificationContentReportBody =>
      'Un contenu a été signalé, à examiner.';

  @override
  String get notificationStreamUnavailable =>
      'Ce direct n\'est plus disponible.';
}
