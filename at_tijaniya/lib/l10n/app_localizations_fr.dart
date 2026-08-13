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
  String get figureTabSilsila => 'Silsila';

  @override
  String get figureCitationsSectionTitle => 'Citations';

  @override
  String get figureZiyaraSectionTitle => 'Ziyaras';

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
  String get figureCitationsEmpty =>
      'Aucune citation renseignée pour le moment.';

  @override
  String get figureWorksSectionTitle => 'Œuvres';

  @override
  String get figureZiyarasPending =>
      'Aucune ziyara associée n\'est encore renseignée.';

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
  String get donationRecordedTitle => 'Merci pour votre soutien';

  @override
  String get donationRecordedBody =>
      'Le paiement en ligne n\'est pas encore disponible dans l\'application. Votre intention de don a bien été enregistrée.';

  @override
  String get donationRecordedBackButton => 'Retour';
}
