import 'package:desktop_client/l10n/app_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class AppStrings {
  const AppStrings();

  // Onboarding – Welcome
  String get welcomeTitle;
  String get welcomeQuestion;
  String get welcomeCreate;
  String get welcomeJoin;
  String get welcomeHint;

  // Onboarding – Account
  String get accountHostTitle;
  String get accountHostSubtitle;
  String get accountHostButton;
  String get accountJoinTitleTemplate; // {project}
  String get accountJoinSubtitleTemplate; // {role}
  String get accountJoinButton;
  String get accountName;
  String get accountEmail;
  String get accountPassword;
  String get errorFillAllFields;
  String get errorPasswordTooShort;

  // Onboarding – Project
  String get projectTitle;
  String get projectSubtitle;
  String get projectLabel;
  String get projectHint;
  String get projectCreateButton;
  String get projectTunnelStarting;
  String get errorProjectName;
  String get errorTunnelNotReady;

  // Onboarding – Invite display
  String get inviteReadyTitle;
  String get inviteReadyBody;
  String get inviteCopyTooltip;
  String get inviteCopiedToast;
  String get inviteFooterHint;
  String get inviteFinishButton;

  // Onboarding – Join code
  String get joinTitle;
  String get joinSubtitle;
  String get joinCodeLabel;
  String get joinConnectButton;
  String get errorInvalidCode;
  String get back;

  // Errors / generic
  String get unknownError;

  // Global tooltips
  String get tooltipNewTask;
  String get tooltipQuickSearch;
  String get tooltipThemeSystem;
  String get tooltipThemeLight;
  String get tooltipThemeDark;
  String get tooltipLanguage;

  // Roles
  String get roleLead;
  String get roleMember;
  String get roleObserver;

  // Generic
  String get cancel;
  String get save;
  String get delete;
  String get close;
  String get retry;

  // Dashboard / login
  String get loginNameLabel;
  String get loginNameRequired;
  String get loginEmailLabel;
  String get loginEmailInvalid;
  String get loginPasswordLabel;
  String get loginPasswordTooShort;
  String get loginSignIn;
  String get loginRegister;
  String get loginSwitchToLogin;
  String get loginSwitchToRegister;
  String get dashboardOverviewTooltip;
  String get dashboardMessagesTooltip;
  String get dashboardNewProject;
  String get dashboardInviteMemberTooltip;
  String get dashboardEmptyProjects;

  // Task overview
  String get overviewTitle;
  String get overviewSectionTasks;
  String get overviewSectionDeadlines;
  String get overviewColumnEmpty;
  String get overviewDeadlineOverdue;
  String get overviewDeadlineToday;
  String get overviewListViewTooltip;
  String get overviewKanbanViewTooltip;
  String get overviewFilterAll;
  String get overviewSortDeadline;
  String get overviewSortNewest;
  String get overviewSortTitle;

  // Project list
  String get projectListTitle;
  String get projectListNewProject;
  String get projectListEmptyTitle;
  String get projectListEmptySubtitle;

  // Project detail
  String get projectDetailInviteTooltip;
  String get projectDetailTabTasks;
  String get projectDetailTabNotes;
  String get projectDetailTabMembers;
  String get projectDetailNewTask;
  String get projectDetailTasksEmptyTitle;
  String get projectDetailTasksEmptySubtitle;
  String get projectDetailNotesHint;
  String get projectDetailMembersEmptyTitle;
  String get projectDetailMembersEmptySubtitle;

  // Create project dialog
  String get createProjectTitle;
  String get createProjectNameLabel;
  String get createProjectNameHint;
  String get createProjectNameRequired;
  String get createProjectSubmit;

  // Create task dialog
  String get createTaskTitle;
  String get createTaskTitleLabel;
  String get createTaskTitleEmpty;
  String get createTaskPickDeadline;
  String get createTaskRemoveDeadline;
  String get createTaskAssigneeLabel;
  String get createTaskAssigneeUnassigned;
  String get createTaskSubmit;
  String get createTaskProjectLabel;
  String get createTaskProjectRequired;

  // Invite member dialog
  String get inviteMemberTitle;
  String get inviteMemberLabel;
  String get inviteMemberHint;
  String get inviteMemberRequired;
  String get inviteMemberRoleLabel;
  String get inviteMemberSubmit;

  // Task card
  String get taskOverdue;
  String get taskToday;
  String get taskTake;
  String get taskComplete;

  // DM
  String get dmTitle;
  String get dmNew;
  String get dmEmptyTitle;
  String get dmEmptySubtitle;
  String get dmYouPrefix;
  String get dmNewTitle;
  String get dmNoTeamMembers;
  String get dmChatEmptyTitle;
  String get dmChatEmptySubtitle;
  String get dmInputHint;

  // Quick search
  String get quickSearchHint;
  String get quickSearchSectionProjects;
  String get quickSearchSectionTasks;
  String get quickSearchNoResults;
  String get quickSearchPlaceholder;

  // Notifications
  String get notificationTaskAssignedTitle;
  String get notificationTaskAssignedFallback;
  String get notificationDeadlineTodayTitle;
  String get notificationDeadlineTodayBodyTemplate; // {title}

  // Task status labels
  String get taskStatusOpen;
  String get taskStatusTaken;
  String get taskStatusDone;
}

class _AppStringsDe extends AppStrings {
  const _AppStringsDe();

  @override String get welcomeTitle => 'Willkommen bei TeamLink';
  @override String get welcomeQuestion => 'Wie willst du starten?';
  @override String get welcomeCreate => 'Neuen Workspace erstellen';
  @override String get welcomeJoin => 'Einem Workspace beitreten';
  @override String get welcomeHint =>
      'Beim Erstellen läuft der Server auf deinem Rechner. '
      'Andere verbinden sich per Einladungscode automatisch über '
      'einen sicheren Cloudflare-Tunnel.';

  @override String get accountHostTitle => 'Account anlegen';
  @override String get accountHostSubtitle =>
      'Du legst deinen Workspace an und kannst andere einladen.';
  @override String get accountHostButton => 'Account erstellen & Weiter';
  @override String get accountJoinTitleTemplate => 'Beitritt zu "{project}"';
  @override String get accountJoinSubtitleTemplate =>
      'Lege deinen Account an – du wirst dem Workspace als '
      '"{role}" hinzugefügt.';
  @override String get accountJoinButton => 'Beitreten';
  @override String get accountName => 'Name';
  @override String get accountEmail => 'E-Mail';
  @override String get accountPassword => 'Passwort (mind. 8 Zeichen)';
  @override String get errorFillAllFields => 'Bitte alle Felder ausfüllen';
  @override String get errorPasswordTooShort =>
      'Passwort muss mindestens 8 Zeichen lang sein';

  @override String get projectTitle => 'Erstes Projekt anlegen';
  @override String get projectSubtitle => 'Gib deinem Projekt einen Namen.';
  @override String get projectLabel => 'Projektname';
  @override String get projectHint => 'z. B. Marketing Q3';
  @override String get projectCreateButton =>
      'Projekt erstellen & Tunnel starten';
  @override String get projectTunnelStarting =>
      'Cloudflare-Tunnel wird gestartet … (kann ~10 s dauern)';
  @override String get errorProjectName => 'Projektname erforderlich';
  @override String get errorTunnelNotReady =>
      'Tunnel ist noch nicht bereit – versuch es in ein paar Sekunden erneut.';

  @override String get inviteReadyTitle => 'Workspace ist bereit';
  @override String get inviteReadyBody =>
      'Teile diesen Einladungscode mit deinen Teammitgliedern. '
      'Sie geben ihn beim Start ein und sind sofort dabei.';
  @override String get inviteCopyTooltip => 'Kopieren';
  @override String get inviteCopiedToast => 'Code in Zwischenablage kopiert';
  @override String get inviteFooterHint =>
      'Hinweis: Der Tunnel läuft, solange TeamLink offen ist. '
      'Bei Neustart wird ein neuer Code generiert.';
  @override String get inviteFinishButton => 'Los geht\'s';

  @override String get joinTitle => 'Workspace beitreten';
  @override String get joinSubtitle =>
      'Füge den Einladungscode ein, den du erhalten hast.';
  @override String get joinCodeLabel => 'Einladungscode (TLK1...)';
  @override String get joinConnectButton => 'Verbinden';
  @override String get errorInvalidCode => 'Ungültiger Einladungscode';
  @override String get back => 'Zurück';

  @override String get unknownError => 'Unbekannter Fehler';

  @override String get tooltipNewTask => 'Neue Aufgabe (Strg+N)';
  @override String get tooltipQuickSearch => 'Schnellsuche (Strg+K)';
  @override String get tooltipThemeSystem => 'System-Standard';
  @override String get tooltipThemeLight => 'Hell';
  @override String get tooltipThemeDark => 'Dunkel';
  @override String get tooltipLanguage => 'Sprache (Deutsch)';

  @override String get roleLead => 'Lead';
  @override String get roleMember => 'Mitglied';
  @override String get roleObserver => 'Beobachter';

  @override String get cancel => 'Abbrechen';
  @override String get save => 'Speichern';
  @override String get delete => 'Löschen';
  @override String get close => 'Schließen';
  @override String get retry => 'Erneut versuchen';

  @override String get loginNameLabel => 'Name';
  @override String get loginNameRequired => 'Name erforderlich';
  @override String get loginEmailLabel => 'E-Mail';
  @override String get loginEmailInvalid => 'Gültige E-Mail erforderlich';
  @override String get loginPasswordLabel => 'Passwort';
  @override String get loginPasswordTooShort => 'Mind. 8 Zeichen';
  @override String get loginSignIn => 'Anmelden';
  @override String get loginRegister => 'Registrieren';
  @override String get loginSwitchToLogin => 'Schon ein Konto? Anmelden';
  @override String get loginSwitchToRegister => 'Noch kein Konto? Registrieren';
  @override String get dashboardOverviewTooltip => 'Übersicht';
  @override String get dashboardMessagesTooltip => 'Nachrichten';
  @override String get dashboardNewProject => 'Neues Projekt';
  @override String get dashboardInviteMemberTooltip => 'Mitglied einladen';
  @override String get dashboardEmptyProjects =>
      'Noch keine Projekte — erstelle dein erstes!';

  @override String get overviewTitle => 'Übersicht';
  @override String get overviewSectionTasks => 'Aufgaben';
  @override String get overviewSectionDeadlines => 'Deadlines — nächste 14 Tage';
  @override String get overviewColumnEmpty => 'Keine';
  @override String get overviewDeadlineOverdue => 'Überfällig';
  @override String get overviewDeadlineToday => 'Heute';
  @override String get overviewListViewTooltip => 'Listen-Ansicht';
  @override String get overviewKanbanViewTooltip => 'Kanban-Ansicht';
  @override String get overviewFilterAll => 'Alle';
  @override String get overviewSortDeadline => 'Deadline';
  @override String get overviewSortNewest => 'Neueste';
  @override String get overviewSortTitle => 'Titel';

  @override String get projectListTitle => 'Projekte';
  @override String get projectListNewProject => 'Neues Projekt';
  @override String get projectListEmptyTitle => 'Noch keine Projekte';
  @override String get projectListEmptySubtitle =>
      'Erstelle dein erstes Projekt über den Button unten.';

  @override String get projectDetailInviteTooltip => 'Mitglied einladen';
  @override String get projectDetailTabTasks => 'Aufgaben';
  @override String get projectDetailTabNotes => 'Notizen';
  @override String get projectDetailTabMembers => 'Mitglieder';
  @override String get projectDetailNewTask => 'Neue Aufgabe';
  @override String get projectDetailTasksEmptyTitle => 'Noch keine Aufgaben';
  @override String get projectDetailTasksEmptySubtitle =>
      'Füge die erste Aufgabe über den Button unten hinzu.';
  @override String get projectDetailNotesHint => 'Projektnotizen…';
  @override String get projectDetailMembersEmptyTitle => 'Noch keine Mitglieder';
  @override String get projectDetailMembersEmptySubtitle =>
      'Lade Teammitglieder über das Symbol oben rechts ein.';

  @override String get createProjectTitle => 'Neues Projekt';
  @override String get createProjectNameLabel => 'Projektname';
  @override String get createProjectNameHint => 'z. B. Marketing Q3';
  @override String get createProjectNameRequired => 'Name erforderlich';
  @override String get createProjectSubmit => 'Erstellen';

  @override String get createTaskTitle => 'Neue Aufgabe';
  @override String get createTaskTitleLabel => 'Titel';
  @override String get createTaskTitleEmpty => 'Titel darf nicht leer sein';
  @override String get createTaskPickDeadline => 'Deadline wählen (optional)';
  @override String get createTaskRemoveDeadline => 'Deadline entfernen';
  @override String get createTaskAssigneeLabel => 'Zuweisen (optional)';
  @override String get createTaskAssigneeUnassigned => 'Offen lassen';
  @override String get createTaskSubmit => 'Anlegen';
  @override String get createTaskProjectLabel => 'Projekt';
  @override String get createTaskProjectRequired => 'Bitte ein Projekt wählen';

  @override String get inviteMemberTitle => 'Mitglied einladen';
  @override String get inviteMemberLabel => 'E-Mail oder Benutzername';
  @override String get inviteMemberHint => 'z. B. max@example.com';
  @override String get inviteMemberRequired => 'Eingabe erforderlich';
  @override String get inviteMemberRoleLabel => 'Rolle';
  @override String get inviteMemberSubmit => 'Einladen';

  @override String get taskOverdue => 'Überfällig';
  @override String get taskToday => 'Heute';
  @override String get taskTake => 'Übernehmen';
  @override String get taskComplete => 'Erledigen';

  @override String get dmTitle => 'Nachrichten';
  @override String get dmNew => 'Neue Nachricht';
  @override String get dmEmptyTitle => 'Noch keine Nachrichten';
  @override String get dmEmptySubtitle =>
      'Starte ein Gespräch über den Button unten.';
  @override String get dmYouPrefix => 'Du: ';
  @override String get dmNewTitle => 'Nachricht senden an…';
  @override String get dmNoTeamMembers =>
      'Keine Teammitglieder gefunden. Tritt zuerst einem Projekt bei.';
  @override String get dmChatEmptyTitle => 'Noch keine Nachrichten';
  @override String get dmChatEmptySubtitle => 'Schreibe die erste Nachricht.';
  @override String get dmInputHint => 'Nachricht…';

  @override String get quickSearchHint => 'Suchen…';
  @override String get quickSearchSectionProjects => 'Projekte';
  @override String get quickSearchSectionTasks => 'Aufgaben';
  @override String get quickSearchNoResults => 'Keine Ergebnisse';
  @override String get quickSearchPlaceholder => 'Tippe um zu suchen…';

  @override String get notificationTaskAssignedTitle => 'Aufgabe zugewiesen';
  @override String get notificationTaskAssignedFallback => 'Neue Aufgabe';
  @override String get notificationDeadlineTodayTitle => 'Deadline heute';
  @override String get notificationDeadlineTodayBodyTemplate =>
      '"{title}" ist in weniger als 24 Stunden fällig';

  @override String get taskStatusOpen => 'Offen';
  @override String get taskStatusTaken => 'Übernommen';
  @override String get taskStatusDone => 'Erledigt';
}

class _AppStringsEn extends AppStrings {
  const _AppStringsEn();

  @override String get welcomeTitle => 'Welcome to TeamLink';
  @override String get welcomeQuestion => 'How would you like to start?';
  @override String get welcomeCreate => 'Create new workspace';
  @override String get welcomeJoin => 'Join a workspace';
  @override String get welcomeHint =>
      'When creating, the server runs on your machine. '
      'Others connect via invite code automatically through '
      'a secure Cloudflare tunnel.';

  @override String get accountHostTitle => 'Create account';
  @override String get accountHostSubtitle =>
      'You\'ll set up the workspace and can invite others.';
  @override String get accountHostButton => 'Create account & continue';
  @override String get accountJoinTitleTemplate => 'Join "{project}"';
  @override String get accountJoinSubtitleTemplate =>
      'Create your account – you\'ll be added to the workspace as '
      '"{role}".';
  @override String get accountJoinButton => 'Join';
  @override String get accountName => 'Name';
  @override String get accountEmail => 'Email';
  @override String get accountPassword => 'Password (min. 8 chars)';
  @override String get errorFillAllFields => 'Please fill in all fields';
  @override String get errorPasswordTooShort =>
      'Password must be at least 8 characters long';

  @override String get projectTitle => 'Create first project';
  @override String get projectSubtitle => 'Give your project a name.';
  @override String get projectLabel => 'Project name';
  @override String get projectHint => 'e.g. Marketing Q3';
  @override String get projectCreateButton =>
      'Create project & start tunnel';
  @override String get projectTunnelStarting =>
      'Starting Cloudflare tunnel… (can take ~10 s)';
  @override String get errorProjectName => 'Project name required';
  @override String get errorTunnelNotReady =>
      'Tunnel is not ready yet – please try again in a few seconds.';

  @override String get inviteReadyTitle => 'Workspace is ready';
  @override String get inviteReadyBody =>
      'Share this invite code with your team. '
      'They paste it at startup and are in immediately.';
  @override String get inviteCopyTooltip => 'Copy';
  @override String get inviteCopiedToast => 'Code copied to clipboard';
  @override String get inviteFooterHint =>
      'Note: The tunnel runs while TeamLink is open. '
      'On restart a new code is generated.';
  @override String get inviteFinishButton => 'Let\'s go';

  @override String get joinTitle => 'Join workspace';
  @override String get joinSubtitle =>
      'Paste the invite code you received.';
  @override String get joinCodeLabel => 'Invite code (TLK1...)';
  @override String get joinConnectButton => 'Connect';
  @override String get errorInvalidCode => 'Invalid invite code';
  @override String get back => 'Back';

  @override String get unknownError => 'Unknown error';

  @override String get tooltipNewTask => 'New task (Ctrl+N)';
  @override String get tooltipQuickSearch => 'Quick search (Ctrl+K)';
  @override String get tooltipThemeSystem => 'System default';
  @override String get tooltipThemeLight => 'Light';
  @override String get tooltipThemeDark => 'Dark';
  @override String get tooltipLanguage => 'Language (English)';

  @override String get roleLead => 'Lead';
  @override String get roleMember => 'Member';
  @override String get roleObserver => 'Observer';

  @override String get cancel => 'Cancel';
  @override String get save => 'Save';
  @override String get delete => 'Delete';
  @override String get close => 'Close';
  @override String get retry => 'Retry';

  @override String get loginNameLabel => 'Name';
  @override String get loginNameRequired => 'Name required';
  @override String get loginEmailLabel => 'Email';
  @override String get loginEmailInvalid => 'Valid email required';
  @override String get loginPasswordLabel => 'Password';
  @override String get loginPasswordTooShort => 'Min. 8 characters';
  @override String get loginSignIn => 'Sign in';
  @override String get loginRegister => 'Register';
  @override String get loginSwitchToLogin => 'Already have an account? Sign in';
  @override String get loginSwitchToRegister => 'No account yet? Register';
  @override String get dashboardOverviewTooltip => 'Overview';
  @override String get dashboardMessagesTooltip => 'Messages';
  @override String get dashboardNewProject => 'New project';
  @override String get dashboardInviteMemberTooltip => 'Invite member';
  @override String get dashboardEmptyProjects =>
      'No projects yet — create your first one!';

  @override String get overviewTitle => 'Overview';
  @override String get overviewSectionTasks => 'Tasks';
  @override String get overviewSectionDeadlines => 'Deadlines — next 14 days';
  @override String get overviewColumnEmpty => 'None';
  @override String get overviewDeadlineOverdue => 'Overdue';
  @override String get overviewDeadlineToday => 'Today';
  @override String get overviewListViewTooltip => 'List view';
  @override String get overviewKanbanViewTooltip => 'Kanban view';
  @override String get overviewFilterAll => 'All';
  @override String get overviewSortDeadline => 'Deadline';
  @override String get overviewSortNewest => 'Newest';
  @override String get overviewSortTitle => 'Title';

  @override String get projectListTitle => 'Projects';
  @override String get projectListNewProject => 'New project';
  @override String get projectListEmptyTitle => 'No projects yet';
  @override String get projectListEmptySubtitle =>
      'Create your first project via the button below.';

  @override String get projectDetailInviteTooltip => 'Invite member';
  @override String get projectDetailTabTasks => 'Tasks';
  @override String get projectDetailTabNotes => 'Notes';
  @override String get projectDetailTabMembers => 'Members';
  @override String get projectDetailNewTask => 'New task';
  @override String get projectDetailTasksEmptyTitle => 'No tasks yet';
  @override String get projectDetailTasksEmptySubtitle =>
      'Add the first task via the button below.';
  @override String get projectDetailNotesHint => 'Project notes…';
  @override String get projectDetailMembersEmptyTitle => 'No members yet';
  @override String get projectDetailMembersEmptySubtitle =>
      'Invite team members via the icon in the top right.';

  @override String get createProjectTitle => 'New project';
  @override String get createProjectNameLabel => 'Project name';
  @override String get createProjectNameHint => 'e.g. Marketing Q3';
  @override String get createProjectNameRequired => 'Name required';
  @override String get createProjectSubmit => 'Create';

  @override String get createTaskTitle => 'New task';
  @override String get createTaskTitleLabel => 'Title';
  @override String get createTaskTitleEmpty => 'Title cannot be empty';
  @override String get createTaskPickDeadline => 'Pick deadline (optional)';
  @override String get createTaskRemoveDeadline => 'Remove deadline';
  @override String get createTaskAssigneeLabel => 'Assign (optional)';
  @override String get createTaskAssigneeUnassigned => 'Leave open';
  @override String get createTaskSubmit => 'Create';
  @override String get createTaskProjectLabel => 'Project';
  @override String get createTaskProjectRequired => 'Please select a project';

  @override String get inviteMemberTitle => 'Invite member';
  @override String get inviteMemberLabel => 'Email or username';
  @override String get inviteMemberHint => 'e.g. max@example.com';
  @override String get inviteMemberRequired => 'Input required';
  @override String get inviteMemberRoleLabel => 'Role';
  @override String get inviteMemberSubmit => 'Invite';

  @override String get taskOverdue => 'Overdue';
  @override String get taskToday => 'Today';
  @override String get taskTake => 'Take';
  @override String get taskComplete => 'Complete';

  @override String get dmTitle => 'Messages';
  @override String get dmNew => 'New message';
  @override String get dmEmptyTitle => 'No messages yet';
  @override String get dmEmptySubtitle =>
      'Start a conversation via the button below.';
  @override String get dmYouPrefix => 'You: ';
  @override String get dmNewTitle => 'Send message to…';
  @override String get dmNoTeamMembers =>
      'No team members found. Join a project first.';
  @override String get dmChatEmptyTitle => 'No messages yet';
  @override String get dmChatEmptySubtitle => 'Send the first message.';
  @override String get dmInputHint => 'Message…';

  @override String get quickSearchHint => 'Search…';
  @override String get quickSearchSectionProjects => 'Projects';
  @override String get quickSearchSectionTasks => 'Tasks';
  @override String get quickSearchNoResults => 'No results';
  @override String get quickSearchPlaceholder => 'Type to search…';

  @override String get notificationTaskAssignedTitle => 'Task assigned';
  @override String get notificationTaskAssignedFallback => 'New task';
  @override String get notificationDeadlineTodayTitle => 'Deadline today';
  @override String get notificationDeadlineTodayBodyTemplate =>
      '"{title}" is due in less than 24 hours';

  @override String get taskStatusOpen => 'Open';
  @override String get taskStatusTaken => 'Taken';
  @override String get taskStatusDone => 'Done';
}

final appStringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeProvider);
  return locale.languageCode == 'en'
      ? const _AppStringsEn()
      : const _AppStringsDe();
});

extension AppStringsX on WidgetRef {
  AppStrings get strings => read(appStringsProvider);
}

extension AppStringsContextX on BuildContext {
  /// Pulls strings via a ProviderScope.containerOf lookup so non-Consumer
  /// widgets can format short messages. Prefer ref.watch(appStringsProvider)
  /// in widgets that should rebuild on locale changes.
  AppStrings get strings =>
      ProviderScope.containerOf(this, listen: false).read(appStringsProvider);
}
