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
  String get authTitle => 'Bienvenue';

  @override
  String get authSubtitle =>
      'Connectez-vous pour retrouver votre communauté, ou continuez sans compte pour réciter vos wirds.';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPhoneLabel => 'Téléphone';

  @override
  String get authPasswordLabel => 'Mot de passe';

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
  String get homeTodayStatus => 'Statut du jour';

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
  String get khadaraUpcomingEventsAtZawiya => 'Prochains évènements';

  @override
  String get khadaraNoUpcomingEventsAtZawiya =>
      'Aucun évènement à venir dans cette zawiya.';

  @override
  String get khadaraAddressLabel => 'Adresse';

  @override
  String get khadaraContactLabel => 'Contact';

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
  String get figureCitationsSectionTitle => 'Citations';

  @override
  String get figureZiyaraSectionTitle => 'Ziyara associée';

  @override
  String get figureBiographyPending => 'Biographie en attente de validation.';

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
  String get privacyNoEffectYetNote =>
      'Ce réglage n\'a pas encore d\'effet visible : la fonctionnalité correspondante n\'est pas encore disponible dans l\'app.';

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
}
