import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:otraku/feature/activity/activities_filter_model.dart';
import 'package:otraku/feature/calendar/calendar_models.dart';
import 'package:otraku/feature/collection/collection_filter_model.dart';
import 'package:otraku/feature/discover/discover_filter_model.dart';
import 'package:otraku/feature/viewer/persistence_model.dart';
import 'package:otraku/feature/viewer/repository_model.dart';
import 'package:otraku/util/background_worker.dart';
import 'package:path_provider/path_provider.dart';

final persistenceProvider = NotifierProvider<PersistenceNotifier, Persistence>(
  PersistenceNotifier.new,
);

final viewerIdProvider = persistenceProvider.select((s) => s.accountGroup.account?.id);

class PersistenceNotifier extends Notifier<Persistence> {
  late Box<Map<dynamic, dynamic>> _box;

  @override
  Persistence build() => .empty();

  Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Configure home directory, if not in the browser.
    if (!kIsWeb) Hive.init((await getApplicationDocumentsDirectory()).path);

    _box = await Hive.openBox('persistence');
    final accessTokens = await const FlutterSecureStorage().readAll();

    state = .fromPersistenceMap(_box.toMap(), accessTokens);

    _backfillMissingBanners();
  }

  void cacheSystemPrimaryColors(SystemColors systemColors) {
    state = state.copyWith(systemColors: systemColors);
  }

  void setOptions(Options options) {
    _box.put('options', options.toPersistenceMap());
    state = state.copyWith(options: options);
  }

  void setAppMeta(AppMeta appMeta) {
    _box.put('appMeta', appMeta.toPersistenceMap());
    state = state.copyWith(appMeta: appMeta);
  }

  void setAnimeCollectionMediaFilter(CollectionMediaFilter mediaFilter) {
    _box.put('animeCollectionMediaFilter', mediaFilter.toPersistenceMap());
    state = state.copyWith(animeCollectionMediaFilter: mediaFilter);
  }

  void setMangaCollectionMediaFilter(CollectionMediaFilter mediaFilter) {
    _box.put('mangaCollectionMediaFilter', mediaFilter.toPersistenceMap());
    state = state.copyWith(mangaCollectionMediaFilter: mediaFilter);
  }

  void setDiscoverMediaFilter(DiscoverMediaFilter discoverMediaFilter) {
    _box.put('discoverMediaFilter', discoverMediaFilter.toPersistenceMap());
    state = state.copyWith(discoverMediaFilter: discoverMediaFilter);
  }

  void setHomeActivitiesFilter(HomeActivitiesFilter homeActivitiesFilter) {
    _box.put('homeActivitiesFilter', homeActivitiesFilter.toPersistenceMap());
    state = state.copyWith(homeActivitiesFilter: homeActivitiesFilter);
  }

  void setMediaActivitiesFilter(MediaActivitiesFilter mediaActivitiesFilter) {
    _box.put('mediaActivitiesFilter', mediaActivitiesFilter.toPersistenceMap());
    state = state.copyWith(mediaActivitiesFilter: mediaActivitiesFilter);
  }

  void setCalendarFilter(CalendarFilter calendarFilter) {
    _box.put('calendarFilter', calendarFilter.toPersistenceMap());
    state = state.copyWith(calendarFilter: calendarFilter);
  }

  void setDrafts(Drafts drafts) {
    _box.put('drafts', drafts.toPersistenceMap());
    state = state.copyWith(drafts: drafts);
  }

  void setEffectiveBrightness(bool isDarkActive) {
    if (state.options.isDarkActive == isDarkActive) return;
    state = state.copyWith(options: state.options.copyWith(isDarkActive: isDarkActive));
  }

  void refreshViewerDetails(String newName, String newAvatarUrl) {
    final accounts = state.accountGroup.accounts;
    final accountIndex = state.accountGroup.accountIndex;

    if (accountIndex == null) return;
    final account = accounts[accountIndex];

    if (account.name == newName && account.avatarUrl == newAvatarUrl) return;

    _setAccountGroup(
      AccountGroup(
        accounts: [
          ...accounts.sublist(0, accountIndex),
          Account(
            name: newName,
            avatarUrl: newAvatarUrl,
            bannerUrl: account.bannerUrl,
            id: account.id,
            expiration: account.expiration,
            accessToken: account.accessToken,
          ),
          ...accounts.sublist(accountIndex + 1),
        ],
        accountIndex: accountIndex,
      ),
    );
  }

  void switchToAdjacentAccount(bool next) {
    final accountGroup = state.accountGroup;
    final accounts = accountGroup.accounts;

    if (accounts.length < 2) return;

    var index = accountGroup.accountIndex ?? accounts.length - 1;

    for (var step = 0; step < accounts.length; step++) {
      index = next
          ? (index + 1) % accounts.length
          : (index - 1 + accounts.length) % accounts.length;
      if (DateTime.now().isBefore(accounts[index].expiration)) {
        switchAccount(index);
        return;
      }
    }
  }

  /// Switches active account.
  /// Don't switch to an account whose token has expired.
  void switchAccount(int? index) {
    final accountGroup = state.accountGroup;

    if (index == accountGroup.accountIndex) return;
    if (index != null && (index < 0 || index >= accountGroup.accounts.length)) {
      return;
    }

    if (index == null) BackgroundWorker.clearNotifications();

    _setAccountGroup(AccountGroup(accountIndex: index, accounts: accountGroup.accounts));
  }

  Future<void> addAccount(Account account) async {
    final accounts = state.accountGroup.accounts;
    final accountIndex = state.accountGroup.accountIndex;

    await const FlutterSecureStorage().write(
      key: Account.accessTokenKeyById(account.id),
      value: account.accessToken,
    );

    for (int i = 0; i < accounts.length; i++) {
      if (accounts[i].id == account.id) {
        _setAccountGroup(
          AccountGroup(
            accounts: [...accounts.sublist(0, i), account, ...accounts.sublist(i + 1)],
            accountIndex: accountIndex,
          ),
        );

        switchAccount(i);
        return;
      }
    }

    _setAccountGroup(AccountGroup(accounts: [...accounts, account], accountIndex: accountIndex));

    switchAccount(state.accountGroup.accounts.length - 1);
  }

  Future<void> removeAccount(int index) async {
    final accountGroup = state.accountGroup;

    if (index == accountGroup.accountIndex) return;
    if (index < 0 || index >= accountGroup.accounts.length) return;

    final account = accountGroup.accounts[index];
    await const FlutterSecureStorage().delete(key: Account.accessTokenKeyById(account.id));

    _setAccountGroup(
      AccountGroup(
        accounts: [
          ...accountGroup.accounts.sublist(0, index),
          ...accountGroup.accounts.sublist(index + 1),
        ],
        accountIndex: accountGroup.accountIndex,
      ),
    );
  }

  /// Persists the account changes, but doesn't affect secure storage.
  /// Token changes must be handled separately.
  void _setAccountGroup(AccountGroup accountGroup) {
    _box.put('accountGroup', accountGroup.toPersistenceMap());
    state = state.copyWith(accountGroup: accountGroup);
  }

  Future<void> _backfillMissingBanners() async {
    for (final account in state.accountGroup.accounts) {
      if (account.bannerUrl != null) continue;

      try {
        final data = await Repository(
          null,
        ).request('query(\$id: Int) {User(id: \$id) {bannerImage}}', {'id': account.id});

        final bannerUrl = data['User']?['bannerImage'];
        if (bannerUrl == null) continue;

        final accounts = state.accountGroup.accounts;
        final index = accounts.indexWhere((a) => a.id == account.id);
        if (index == -1) continue;

        _setAccountGroup(
          AccountGroup(
            accounts: [
              ...accounts.sublist(0, index),
              Account(
                id: account.id,
                name: account.name,
                avatarUrl: account.avatarUrl,
                bannerUrl: bannerUrl,
                expiration: account.expiration,
                accessToken: account.accessToken,
              ),
              ...accounts.sublist(index + 1),
            ],
            accountIndex: state.accountGroup.accountIndex,
          ),
        );
      } catch (_) {
        // Ignore - retries on next launch
      }
    }
  }
}
