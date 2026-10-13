// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncCursorsTable get syncCursors => attachedDatabase.syncCursors;
  $SyncStateTable get syncState => attachedDatabase.syncState;
  $ResyncTokensTable get resyncTokens => attachedDatabase.resyncTokens;
  $BranchesTable get branches => attachedDatabase.branches;
  $TeachingTypesTable get teachingTypes => attachedDatabase.teachingTypes;
  $ContributorsTable get contributors => attachedDatabase.contributors;
  $TeachingsTable get teachings => attachedDatabase.teachings;
  $TeachingGuestsTable get teachingGuests => attachedDatabase.teachingGuests;
  $GatheringTypesTable get gatheringTypes => attachedDatabase.gatheringTypes;
  $GatheringsTable get gatherings => attachedDatabase.gatherings;
  $StatusBackgroundsTable get statusBackgrounds =>
      attachedDatabase.statusBackgrounds;
  $OfficialAccountsTable get officialAccounts =>
      attachedDatabase.officialAccounts;
  $OfficialAccountMembershipsTable get officialAccountMemberships =>
      attachedDatabase.officialAccountMemberships;
  $AnnouncementsTable get announcements => attachedDatabase.announcements;
  $PlaybackProgressTable get playbackProgress =>
      attachedDatabase.playbackProgress;
  $LegalDocumentsTable get legalDocuments => attachedDatabase.legalDocuments;
  $SeasonsTable get seasons => attachedDatabase.seasons;
  $PresentationVocabularyTable get presentationVocabulary =>
      attachedDatabase.presentationVocabulary;
  $MenuEntriesTable get menuEntries => attachedDatabase.menuEntries;
  $MediaPagesTable get mediaPages => attachedDatabase.mediaPages;
  $MediaPageChipsTable get mediaPageChips => attachedDatabase.mediaPageChips;
  $MediaPageSectionsTable get mediaPageSections =>
      attachedDatabase.mediaPageSections;
  $DecorTable get decor => attachedDatabase.decor;
  $AuthChannelsTable get authChannels => attachedDatabase.authChannels;
  $DeviceSettingsTable get deviceSettings => attachedDatabase.deviceSettings;
  $ProfilesTable get profiles => attachedDatabase.profiles;
  $GroupsTable get groups => attachedDatabase.groups;
  $GroupMembersTable get groupMembers => attachedDatabase.groupMembers;
  $GroupJoinRequestsTable get groupJoinRequests =>
      attachedDatabase.groupJoinRequests;
  $GroupMessagesTable get groupMessages => attachedDatabase.groupMessages;
  $GroupReadsTable get groupReads => attachedDatabase.groupReads;
  $MyInteractionsTable get myInteractions => attachedDatabase.myInteractions;
  $SpiritualNotesTable get spiritualNotes => attachedDatabase.spiritualNotes;
  $NoteCategoriesTable get noteCategories => attachedDatabase.noteCategories;
  $GroupArrangementsTable get groupArrangements =>
      attachedDatabase.groupArrangements;
  $MessageReceiptsTable get messageReceipts => attachedDatabase.messageReceipts;
  $GroupMutesTable get groupMutes => attachedDatabase.groupMutes;
  $GroupMessageReactionsTable get groupMessageReactions =>
      attachedDatabase.groupMessageReactions;
  $GroupMessageHidesTable get groupMessageHides =>
      attachedDatabase.groupMessageHides;
  $BibleMarksTable get bibleMarks => attachedDatabase.bibleMarks;
  $BibleReadingStatesTable get bibleReadingStates =>
      attachedDatabase.bibleReadingStates;
  $BiblePlanEnrollmentsTable get biblePlanEnrollments =>
      attachedDatabase.biblePlanEnrollments;
  $BibleQuizResultsTable get bibleQuizResults =>
      attachedDatabase.bibleQuizResults;
  $BibleVerseOfDaysTable get bibleVerseOfDays =>
      attachedDatabase.bibleVerseOfDays;
  $BibleSundayPassagesTable get bibleSundayPassages =>
      attachedDatabase.bibleSundayPassages;
  $BiblePlansTable get biblePlans => attachedDatabase.biblePlans;
  $BibleChallengesTable get bibleChallenges => attachedDatabase.bibleChallenges;
  $BibleQuizzesTable get bibleQuizzes => attachedDatabase.bibleQuizzes;
  $BibleVersionsTable get bibleVersions => attachedDatabase.bibleVersions;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db.attachedDatabase, _db.syncCursors);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db.attachedDatabase, _db.syncState);
  $$ResyncTokensTableTableManager get resyncTokens =>
      $$ResyncTokensTableTableManager(_db.attachedDatabase, _db.resyncTokens);
  $$BranchesTableTableManager get branches =>
      $$BranchesTableTableManager(_db.attachedDatabase, _db.branches);
  $$TeachingTypesTableTableManager get teachingTypes =>
      $$TeachingTypesTableTableManager(_db.attachedDatabase, _db.teachingTypes);
  $$ContributorsTableTableManager get contributors =>
      $$ContributorsTableTableManager(_db.attachedDatabase, _db.contributors);
  $$TeachingsTableTableManager get teachings =>
      $$TeachingsTableTableManager(_db.attachedDatabase, _db.teachings);
  $$TeachingGuestsTableTableManager get teachingGuests =>
      $$TeachingGuestsTableTableManager(
          _db.attachedDatabase, _db.teachingGuests);
  $$GatheringTypesTableTableManager get gatheringTypes =>
      $$GatheringTypesTableTableManager(
          _db.attachedDatabase, _db.gatheringTypes);
  $$GatheringsTableTableManager get gatherings =>
      $$GatheringsTableTableManager(_db.attachedDatabase, _db.gatherings);
  $$StatusBackgroundsTableTableManager get statusBackgrounds =>
      $$StatusBackgroundsTableTableManager(
          _db.attachedDatabase, _db.statusBackgrounds);
  $$OfficialAccountsTableTableManager get officialAccounts =>
      $$OfficialAccountsTableTableManager(
          _db.attachedDatabase, _db.officialAccounts);
  $$OfficialAccountMembershipsTableTableManager
      get officialAccountMemberships =>
          $$OfficialAccountMembershipsTableTableManager(
              _db.attachedDatabase, _db.officialAccountMemberships);
  $$AnnouncementsTableTableManager get announcements =>
      $$AnnouncementsTableTableManager(_db.attachedDatabase, _db.announcements);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(
          _db.attachedDatabase, _db.playbackProgress);
  $$LegalDocumentsTableTableManager get legalDocuments =>
      $$LegalDocumentsTableTableManager(
          _db.attachedDatabase, _db.legalDocuments);
  $$SeasonsTableTableManager get seasons =>
      $$SeasonsTableTableManager(_db.attachedDatabase, _db.seasons);
  $$PresentationVocabularyTableTableManager get presentationVocabulary =>
      $$PresentationVocabularyTableTableManager(
          _db.attachedDatabase, _db.presentationVocabulary);
  $$MenuEntriesTableTableManager get menuEntries =>
      $$MenuEntriesTableTableManager(_db.attachedDatabase, _db.menuEntries);
  $$MediaPagesTableTableManager get mediaPages =>
      $$MediaPagesTableTableManager(_db.attachedDatabase, _db.mediaPages);
  $$MediaPageChipsTableTableManager get mediaPageChips =>
      $$MediaPageChipsTableTableManager(
          _db.attachedDatabase, _db.mediaPageChips);
  $$MediaPageSectionsTableTableManager get mediaPageSections =>
      $$MediaPageSectionsTableTableManager(
          _db.attachedDatabase, _db.mediaPageSections);
  $$DecorTableTableManager get decor =>
      $$DecorTableTableManager(_db.attachedDatabase, _db.decor);
  $$AuthChannelsTableTableManager get authChannels =>
      $$AuthChannelsTableTableManager(_db.attachedDatabase, _db.authChannels);
  $$DeviceSettingsTableTableManager get deviceSettings =>
      $$DeviceSettingsTableTableManager(
          _db.attachedDatabase, _db.deviceSettings);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db.attachedDatabase, _db.groups);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db.attachedDatabase, _db.groupMembers);
  $$GroupJoinRequestsTableTableManager get groupJoinRequests =>
      $$GroupJoinRequestsTableTableManager(
          _db.attachedDatabase, _db.groupJoinRequests);
  $$GroupMessagesTableTableManager get groupMessages =>
      $$GroupMessagesTableTableManager(_db.attachedDatabase, _db.groupMessages);
  $$GroupReadsTableTableManager get groupReads =>
      $$GroupReadsTableTableManager(_db.attachedDatabase, _db.groupReads);
  $$MyInteractionsTableTableManager get myInteractions =>
      $$MyInteractionsTableTableManager(
          _db.attachedDatabase, _db.myInteractions);
  $$SpiritualNotesTableTableManager get spiritualNotes =>
      $$SpiritualNotesTableTableManager(
          _db.attachedDatabase, _db.spiritualNotes);
  $$NoteCategoriesTableTableManager get noteCategories =>
      $$NoteCategoriesTableTableManager(
          _db.attachedDatabase, _db.noteCategories);
  $$GroupArrangementsTableTableManager get groupArrangements =>
      $$GroupArrangementsTableTableManager(
          _db.attachedDatabase, _db.groupArrangements);
  $$MessageReceiptsTableTableManager get messageReceipts =>
      $$MessageReceiptsTableTableManager(
          _db.attachedDatabase, _db.messageReceipts);
  $$GroupMutesTableTableManager get groupMutes =>
      $$GroupMutesTableTableManager(_db.attachedDatabase, _db.groupMutes);
  $$GroupMessageReactionsTableTableManager get groupMessageReactions =>
      $$GroupMessageReactionsTableTableManager(
          _db.attachedDatabase, _db.groupMessageReactions);
  $$GroupMessageHidesTableTableManager get groupMessageHides =>
      $$GroupMessageHidesTableTableManager(
          _db.attachedDatabase, _db.groupMessageHides);
  $$BibleMarksTableTableManager get bibleMarks =>
      $$BibleMarksTableTableManager(_db.attachedDatabase, _db.bibleMarks);
  $$BibleReadingStatesTableTableManager get bibleReadingStates =>
      $$BibleReadingStatesTableTableManager(
          _db.attachedDatabase, _db.bibleReadingStates);
  $$BiblePlanEnrollmentsTableTableManager get biblePlanEnrollments =>
      $$BiblePlanEnrollmentsTableTableManager(
          _db.attachedDatabase, _db.biblePlanEnrollments);
  $$BibleQuizResultsTableTableManager get bibleQuizResults =>
      $$BibleQuizResultsTableTableManager(
          _db.attachedDatabase, _db.bibleQuizResults);
  $$BibleVerseOfDaysTableTableManager get bibleVerseOfDays =>
      $$BibleVerseOfDaysTableTableManager(
          _db.attachedDatabase, _db.bibleVerseOfDays);
  $$BibleSundayPassagesTableTableManager get bibleSundayPassages =>
      $$BibleSundayPassagesTableTableManager(
          _db.attachedDatabase, _db.bibleSundayPassages);
  $$BiblePlansTableTableManager get biblePlans =>
      $$BiblePlansTableTableManager(_db.attachedDatabase, _db.biblePlans);
  $$BibleChallengesTableTableManager get bibleChallenges =>
      $$BibleChallengesTableTableManager(
          _db.attachedDatabase, _db.bibleChallenges);
  $$BibleQuizzesTableTableManager get bibleQuizzes =>
      $$BibleQuizzesTableTableManager(_db.attachedDatabase, _db.bibleQuizzes);
  $$BibleVersionsTableTableManager get bibleVersions =>
      $$BibleVersionsTableTableManager(_db.attachedDatabase, _db.bibleVersions);
}
