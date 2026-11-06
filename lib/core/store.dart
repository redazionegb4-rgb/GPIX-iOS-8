import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as im;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'data.dart';
import 'profile_links.dart';

class GpixStore extends ChangeNotifier with WidgetsBindingObserver {
  bool foreground = true, presenceBusy = false;
  bool get activityVisible => preferences['activityStatus'] != false;
  bool online(String id) =>
      activityVisible &&
      user(id).flag('online') &&
      user(id).number('onlineUntil', now + 1) > now;
  List<J> typingPeers(String tid) => activityVisible
      ? thread(tid)
            .rows('typing')
            .where((x) => x.str('user') != myId && x.number('until') > now)
            .toList()
      : [];
  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    foreground = value == AppLifecycleState.resumed;
    if (signedIn && !demo) {
      unawaited(
        api('/presence', payload: {'active': foreground})
            .then((_) async {
              if (foreground) await sync(silent: true);
            })
            .catchError((_) {}),
      );
    }
  }

  Future<void> typingSignal(
    String tid,
    bool active, {
    String kind = 'typing',
  }) async {
    if (demo || (!activityVisible && active) || token.isEmpty) return;
    await api(
      '/threads/$tid/typing',
      payload: {'active': active, 'kind': kind},
    );
  }

  Future<void> threadPresence(String tid) async {
    if (demo || !foreground || token.isEmpty || presenceBusy) return;
    presenceBusy = true;
    try {
      final result = await api('/threads/$tid/presence');
      final people = users;
      for (final fresh in result.rows('users')) {
        final id = fresh.str('id'),
            index = people.indexWhere((x) => x.str('id') == id);
        final next = <String, dynamic>{...user(id)}
          ..remove('online')
          ..remove('lastActive')
          ..remove('onlineUntil')
          ..addAll(fresh);
        if (index >= 0) {
          people[index] = next;
        } else {
          people.add(next);
        }
      }
      state['users'] = people;
      thread(tid)['typing'] = result.rows('typing');
      notifyListeners();
    } finally {
      presenceBusy = false;
    }
  }

  static const productionServer = 'https://gpix.cc';
  final ValueNotifier<double> uploadProgress = ValueNotifier<double>(0);
  final http.Client client;
  final FlutterSecureStorage vault;
  GpixStore({http.Client? client, FlutterSecureStorage? vault})
    : client = client ?? http.Client(),
      vault = vault ?? const FlutterSecureStorage();
  J state = {};
  String server = productionServer, token = '';
  String appearance = 'light';
  Future<void> setAppearance(String value) async {
    if (!['system', 'light', 'dark'].contains(value)) return;
    appearance = value;
    await prefs?.setString('gpix.appearance', value);
    notifyListeners();
  }

  bool demo = false, ready = false;
  Timer? _poll;
  SharedPreferences? prefs;
  final Map<String, Future<void>> _pending = {};
  bool get signedIn => state.containsKey('me') && (demo || token.isNotEmpty);
  J get me => state.obj('me');
  List<J> get socialNotifications => state
      .rows('notifications')
      .where(
        (n) => ![
          'message',
          'call',
          'instant',
          'messageReaction',
        ].contains(n.str('type')),
      )
      .toList();
  final Map<String, List<String>> _searchHistory = {};
  String get _searchKey => 'gpix.search.${demo ? "demo" : server}.$myId';
  List<String> get searchHistory => List.unmodifiable(
    _searchHistory.putIfAbsent(
      _searchKey,
      () => prefs?.getStringList(_searchKey) ?? [],
    ),
  );
  Future<void> rememberSearch(String value) async {
    final term = value.trim();
    if (term.isEmpty) return;
    final rows = searchHistory
        .where((v) => v.toLowerCase() != term.toLowerCase())
        .toList();
    rows.insert(0, term.length > 120 ? term.substring(0, 120) : term);
    _searchHistory[_searchKey] = rows.take(20).toList();
    notifyListeners();
    await prefs?.setStringList(_searchKey, _searchHistory[_searchKey]!);
  }

  Future<void> clearSearchHistory() async {
    _searchHistory[_searchKey] = [];
    notifyListeners();
    await prefs?.remove(_searchKey);
  }

  Future<void> removeSearch(String term) async {
    _searchHistory[_searchKey] = searchHistory.where((v) => v != term).toList();
    notifyListeners();
    await prefs?.setStringList(_searchKey, _searchHistory[_searchKey]!);
  }

  List<J> chatReactions(J t) {
    final ids = t.rows('messages').map((m) => m.str('id')).toSet();
    return state
        .rows('notifications')
        .where(
          (n) =>
              n.str('type') == 'messageReaction' &&
              !n.flag('seen') &&
              ids.contains(n.str('ref')),
        )
        .toList()
      ..sort((a, b) => b.number('created').compareTo(a.number('created')));
  }

  bool chatHasUnread(J t) => unread(t) > 0 || chatReactions(t).isNotEmpty;
  final _readingThreads = <String>{};
  bool get hasActivity => socialNotifications.any((n) => !n.flag('seen'));
  List<String> viewers(J p) =>
      p.ids('viewers').where((id) => id != p.str('author')).toList();
  List<J> get notes => state
      .rows('notes')
      .where((n) => n.number('expires') > now && !blocked(n.str('owner')))
      .toList();
  bool get readReceipts =>
      me['readReceipts'] != false && me['readReceipts'] != 0;
  String get myId => me.str('id');
  List<J> get storyUsers {
    final list = users
        .where(
          (u) =>
              u.str('id') != myId &&
              !blocked(u.str('id')) &&
              stories(u.str('id')).isNotEmpty,
        )
        .toList();
    final order = {for (var i = 0; i < list.length; i++) list[i].str('id'): i};
    bool seen(J u) => stories(
      u.str('id'),
    ).every((p) => p.flag('seenByMe') || p.ids('viewers').contains(myId));
    list.sort((a, b) {
      final av = seen(a), bv = seen(b);
      return av == bv
          ? order[a.str('id')]!.compareTo(order[b.str('id')]!)
          : av
          ? 1
          : -1;
    });
    return list;
  }

  List<J> get users => state.rows('users');
  List<J> get allPosts => state.rows('posts');
  List<J> get posts => allPosts
      .where(
        (p) =>
            !p.flag('archived') &&
            p.str('kind') == 'post' &&
            !blocked(p.str('author')),
      )
      .toList();
  List<J> get reels => allPosts
      .where(
        (p) =>
            !p.flag('archived') &&
            p.str('kind') == 'reel' &&
            !blocked(p.str('author')),
      )
      .toList();
  List<J> get threads =>
      state
          .rows('threads')
          .where((t) => !t.ids('members').any(blocked))
          .toList()
        ..sort((a, b) => _last(b).compareTo(_last(a)));
  bool messageRequest(J t) {
    if (t.str('requestDecision') == 'restricted' ||
        preferences.ids('restricted').contains(other(t)))
      return true;
    if (t.str('owner').isNotEmpty || t.str('requestDecision') == 'accepted')
      return false;
    final messages = t.rows('messages');
    return messages.isNotEmpty &&
        messages.first.str('author') != myId &&
        !messages.any((m) => m.str('author') == myId) &&
        !follows(other(t));
  }

  List<J> get inboxThreads => threads
      .where((t) => t.str('requestDecision') != 'hidden' && !messageRequest(t))
      .toList();
  List<J> get requestedThreads => threads
      .where((t) => t.str('requestDecision') != 'hidden' && messageRequest(t))
      .toList();
  List<J> get hiddenRequests =>
      threads.where((t) => t.str('requestDecision') == 'hidden').toList();
  double _last(J t) {
    final message = t.rows('messages').lastOrNull?.number('created') ?? 0;
    final reaction = chatReactions(t).firstOrNull?.number('created') ?? 0;
    return reaction > message ? reaction : message;
  }

  J user(String id) => id == myId
      ? me
      : users.firstWhere(
          (u) => u.str('id') == id,
          orElse: () => {
            'id': id,
            'name': 'Account non disponibile',
            'username': 'utente',
          },
        );
  J post(String id) =>
      allPosts.firstWhere((p) => p.str('id') == id, orElse: () => {});
  J thread(String id) =>
      threads.firstWhere((t) => t.str('id') == id, orElse: () => {});
  String other(J t) =>
      t.ids('members').firstWhere((e) => e != myId, orElse: () => myId);
  String threadName(J t) =>
      t.str('title').isNotEmpty ? t.str('title') : user(other(t)).str('name');
  bool blocked(String id) => state.ids('blocks').contains(id);
  bool closeStory(String id) {
    final list = stories(id);
    if (list.isEmpty) return false;
    final latest = list.reduce(
      (a, b) => a.number('created') >= b.number('created') ? a : b,
    );
    return latest.str('audience') == 'close';
  }

  bool hasUnseenStories(String id) => stories(id).any(
    (story) => !story.flag('seenByMe') && !story.ids('viewers').contains(myId),
  );

  bool follows(String id) => state.ids('following').contains(id);
  List<J> stories(String userId, {bool archive = false}) => allPosts
      .where(
        (p) =>
            p.str('kind') == 'story' &&
            p.str('author') == userId &&
            !p.flag('archived') &&
            (archive || p.number('expires') > now),
      )
      .toList();
  List<J> highlights(String userId) =>
      state.rows('highlights').where((h) => h.str('owner') == userId).toList();
  List<String> media(J p) {
    final list = p['mediaItems'];
    if (list is List && list.isNotEmpty)
      return list
          .map((e) => e is Map ? object(e).str('url') : '$e')
          .where((e) => e.isNotEmpty)
          .toList();
    return p.str('media').isEmpty ? [] : [p.str('media')];
  }

  final Map<String, String> uploadedUrls = {};
  String url(String reference) {
    final ref = uploadedUrls[reference] ?? reference;
    return ref.startsWith('/media/') || ref.startsWith('/music/audio/')
        ? '$server$ref'
        : ref;
  }

  int unread(J t) => t
      .rows('messages')
      .where((m) => m.str('author') != myId && !m.ids('readBy').contains(myId))
      .length;
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    prefs = await SharedPreferences.getInstance();
    appearance = prefs!.getString('gpix.appearance') ?? 'light';
    server = productionServer;
    token = await vault.read(key: 'gpix.token') ?? '';
    final previousServer = prefs!
        .getString('gpix.server')
        ?.replaceAll(RegExp(r'/+$'), '');
    if (token.isNotEmpty &&
        previousServer != null &&
        previousServer.isNotEmpty &&
        previousServer != productionServer) {
      token = '';
      await vault.delete(key: 'gpix.token');
    }
    demo = false;
    await prefs!.remove('gpix.demo');
    ready = true;
    notifyListeners();
    if (!demo && token.isNotEmpty) {
      try {
        await sync();
      } catch (_) {
        token = '';
        await vault.delete(key: 'gpix.token');
      }
    }
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (signedIn && !demo && foreground) {
        sync(silent: true);
      }
    });
  }

  Future<void> startDemo({bool reset = false}) async {
    if (reset) await _clearDemoFiles();
    demo = true;
    token = '';
    await vault.delete(key: 'gpix.token');
    if (reset || !state.containsKey('me')) {
      try {
        state = object(jsonDecode(prefs?.getString('gpix.demoData') ?? '{}'));
      } catch (_) {
        state = {};
      }
      if (reset || !state.containsKey('me')) state = _seed();
    }
    normalizeDemoConnections();
    await _persist();
    notifyListeners();
  }

  void startTestDemo() {
    demo = true;
    ready = true;
    state = _seed();
    normalizeDemoPresence();
    notifyListeners();
  }

  void normalizeDemoPresence() {
    if (!demo) return;
    for (final u in users.where((x) => x.str('id') != myId)) {
      u.putIfAbsent('online', () => ['u0', 'u2'].contains(u.str('id')));
      u.putIfAbsent('lastActive', () => now - (u.flag('online') ? 0 : 1800));
      if (u.flag('online')) u['onlineUntil'] = now + 86400;
    }
  }

  void normalizeDemoConnections() {
    if (!demo || me.isEmpty) return;
    normalizeDemoPresence();
    final graph = <String, List<String>>{
      for (final u in users) u.str('id'): u.ids('followingList'),
    };
    graph[myId] = state.ids('following');
    for (final id in state.ids('blocks')) {
      graph[myId]?.remove(id);
      graph[id]?.remove(myId);
    }
    for (final u in [me, ...users]) {
      final id = u.str('id');
      u['followingList'] = graph[id] ?? <String>[];
      u['following'] = (graph[id] ?? []).length;
      final followers = graph.entries
          .where((e) => e.value.contains(id))
          .map((e) => e.key)
          .toList();
      u['followersList'] = followers;
      u['followers'] = followers.length;
    }
    state['following'] = graph[myId] ?? <String>[];
  }

  Future<void> _persist() async {
    await prefs?.setString('gpix.server', server);
    await prefs?.setBool('gpix.demo', demo);
    if (demo) await prefs?.setString('gpix.demoData', jsonEncode(state));
  }

  Future<J> _request(String route, {J? body}) async {
    final uri = Uri.parse('$server$route');
    if (uri.scheme != 'https')
      throw Exception(
        'Inserisci un indirizzo HTTPS valido per il server GPIX.',
      );
    http.Response r;
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'X-GPIX-Active': foreground ? '1' : '0',
    };
    if (body == null) {
      r = await client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 35));
    } else {
      r = await client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
    }
    J data;
    try {
      data = object(jsonDecode(r.body));
    } catch (_) {
      throw Exception('Il server non ha restituito una risposta valida.');
    }
    if (r.statusCode >= 400)
      throw Exception(
        data.str('detail', 'Operazione non riuscita (${r.statusCode}).'),
      );
    return data;
  }

  Future<void> authenticate({
    String endpoint = productionServer,
    required String login,
    required String password,
    String? email,
    String? name,
  }) async {
    server = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    final register = email != null;
    final r = await _request(
      '/auth/${register ? 'register' : 'login'}',
      body: register
          ? {
              'username': login.trim().toLowerCase(),
              'password': password,
              'email': email.trim().toLowerCase(),
              'name': name?.trim(),
              'device': Platform.isIOS
                  ? 'iPhone / iPad'
                  : Platform.isAndroid
                  ? 'Android'
                  : Platform.operatingSystem,
            }
          : {'login': login.trim(), 'password': password},
    );
    final nextToken = r.str('token'), nextState = r.obj('state');
    if (nextToken.isEmpty || nextState.obj('me').str('id').isEmpty)
      throw Exception('Accesso non completato. Riprova.');
    await vault.write(key: 'gpix.token', value: nextToken);
    token = nextToken;
    demo = false;
    state = nextState;
    await _persist();
    notifyListeners();
  }

  J get preferences => state.obj('preferences');
  Future<void> setPreference(String key, dynamic value) =>
      act('preferences', {'key': key, 'value': value});
  Future<J> accountRequest(String action, J payload) =>
      _request('/auth/$action', body: payload);
  Future<J> api(String route, {J? payload}) => _request(route, body: payload);
  Future<void> verifyEmail(String code) async {
    await accountRequest('verification-confirm', {'code': code});
    await sync(silent: false);
  }

  Future<void> rtcSignal(String id, String kind, J data) async {
    await _request(
      '/actions',
      body: {
        'action': 'callSignal',
        'payload': {'id': id, 'kind': kind, 'data': data},
      },
    );
  }

  Future<J> liveGet(String id, int after) =>
      _request('/live/room/$id?after=$after');
  Future<void> liveSignal(String id, String viewer, String kind, J data) async {
    await _request(
      '/actions',
      body: {
        'action': 'liveSignal',
        'payload': {'id': id, 'viewer': viewer, 'kind': kind, 'data': data},
      },
    );
  }

  Future<String> startLive(String title) async {
    await act('liveStart', {'title': title});
    return state
        .rows('lives')
        .firstWhere((r) => r.str('host') == myId)
        .str('id');
  }

  Future<List<J>> musicTracks() async {
    if (demo)
      throw Exception(
        'La musica online è disponibile accedendo al server GPIX.',
      );
    return (await _request('/music')).rows('tracks');
  }

  Future<J> rtcGet(String route) => _request('/rtc/$route');
  Future<String> startCall(String tid, bool video) async {
    await act('callStart', {'id': tid, 'video': video});
    return state
        .rows('calls')
        .firstWhere(
          (c) =>
              c.str('caller') == myId &&
              c.str('thread') == tid &&
              c.str('status') == 'ringing',
        )
        .str('id');
  }

  int homeRefreshRevision = 0;
  Future<void> refreshHome() async {
    if (demo) {
      // Re-read persisted demo data and rebuild the feed, while preserving local edits.
      await _persist();
      final saved = prefs?.getString('gpix.demoData');
      if (saved != null) state = object(jsonDecode(saved));
      normalizeDemoConnections();
    } else {
      await sync();
    }
    homeRefreshRevision++;
    notifyListeners();
  }

  Future<void> sync({bool silent = false}) async {
    if (demo || token.isEmpty) return;
    try {
      final r = await _request('/state');
      final next = r.obj('state');
      if (jsonEncode(next) != jsonEncode(state)) {
        state = next;
        notifyListeners();
      }
    } catch (e) {
      if (!silent) rethrow;
    }
  }

  Future<void> act(String action, [J payload = const {}]) async {
    if (action == 'note' && !payload.flag('delete')) {
      final value = payload.str('text').trim();
      if (value.isEmpty ||
          value.characters.length > 60 ||
          !['mutual', 'close'].contains(payload.str('audience', 'mutual'))) {
        throw Exception('Scrivi una nota entro 60 caratteri.');
      }
    }
    final key = '$action:${payload['id'] ?? payload['user'] ?? ''}';
    if (_pending.containsKey(key)) return _pending[key]!;
    final future = _perform(action, payload);
    _pending[key] = future;
    try {
      await future;
    } finally {
      _pending.remove(key);
    }
  }

  Future<void> _perform(String action, J p) async {
    if (demo) {
      _local(action, p);
      normalizeDemoConnections();
      if (action == 'deleteAccount') {
        await prefs?.remove('gpix.demoData');
        await _clearDemoFiles();
      }
      await _persist();
      notifyListeners();
      return;
    }
    final r = await _request(
      '/actions',
      body: {'action': action, 'payload': p},
    );
    if (r.flag('deleted')) {
      await logout(remote: false);
      return;
    }
    state = r.obj('state');
    notifyListeners();
  }

  Future<void> _clearDemoFiles() async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/gpix-media');
    if (await folder.exists()) await folder.delete(recursive: true);
    uploadedUrls.clear();
  }

  Future<String> upload(String path, String mime) async {
    if (demo) {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory('${root.path}/gpix-media');
      await dir.create(recursive: true);
      final ext = mime == 'image/gif'
          ? '.gif'
          : mime == 'audio/mpeg'
          ? '.mp3'
          : mime == 'audio/wav'
          ? '.wav'
          : mime == 'video/quicktime'
          ? '.mov'
          : mime == 'image/png'
          ? '.png'
          : mime.contains('video')
          ? '.mp4'
          : mime.contains('audio')
          ? '.m4a'
          : '.jpg';
      return (await File(path).copy('${dir.path}/${newId()}$ext')).path;
    }
    final file = File(path);
    if (await file.length() > 25 * 1024 * 1024)
      throw Exception('Il file supera 25 MB.');
    uploadProgress.value = 0;
    final bytes = utf8.encode(
      jsonEncode({
        'mime': mime,
        'data': base64Encode(await file.readAsBytes()),
      }),
    );
    final request = _UploadRequest(
      Uri.parse('$server/media'),
      bytes,
      (v) => uploadProgress.value = v,
    );
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(minutes: 3)),
    );
    final r = object(jsonDecode(response.body));
    if (response.statusCode >= 400)
      throw Exception(
        r.str('detail', 'Caricamento non riuscito. Puoi riprovare.'),
      );
    uploadProgress.value = 1;
    uploadedUrls[r.str('id')] = r.str('url');
    return r.str('id');
  }

  Future<String> openThread(String user) async {
    await act('thread', {'user': user});
    return threads
        .firstWhere(
          (t) => t.str('owner').isEmpty && t.ids('members').contains(user),
        )
        .str('id');
  }

  Future<void> markRead(String tid) async {
    if (!_readingThreads.add(tid)) return;
    try {
      final reactions = chatReactions(thread(tid));
      for (final n in reactions) {
        await act('notificationsRead', {'id': n.str('id')});
      }
      final unread = thread(tid)
          .rows('messages')
          .where(
            (m) => m.str('author') != myId && !m.ids('readBy').contains(myId),
          )
          .map((m) => m.str('id'))
          .toList();
      for (final id in unread) {
        await act('read', {'id': id});
      }
    } finally {
      _readingThreads.remove(tid);
    }
  }

  Future<void> send(
    String tid,
    String text, {
    String kind = 'text',
    String media = '',
    String reply = '',
    String story = '',
    bool viewOnce = false,
    int maxOpens = 1,
    int? expiresIn,
  }) => act('message', {
    'id': tid,
    'text': text,
    'kind': kind,
    'media': media,
    'reply': reply,
    'story': story,
    'viewOnce': viewOnce,
    'maxOpens': maxOpens,
    'expiresIn': expiresIn ?? thread(tid).number('messageTTL').toInt(),
  });
  Future<String> uploadAsset(String reference, String mime) async {
    if (reference.startsWith('https://')) return reference;
    if (demo) return reference;
    final data = await rootBundle.load('assets/media/$reference');
    final r = await _request(
      '/media',
      body: {'mime': mime, 'data': base64Encode(data.buffer.asUint8List())},
    );
    return r.str('id');
  }

  J message(String id) {
    for (final t in threads) {
      for (final m in t.rows('messages')) {
        if (m.str('id') == id) return m;
      }
    }
    return {};
  }

  bool expired(J m) =>
      m.flag('expired') ||
      (m.number('expires') > 0 && m.number('expires') <= now) ||
      (m.number('readExpiresAt') > 0 && m.number('readExpiresAt') <= now);
  void seedInstants() {
    if (state['demoInstants'] != null) return;
    final friend = users.firstWhere(
      (u) => u.str('id') != myId,
      orElse: () => {},
    );
    state['demoInstants'] = [
      if (friend.isNotEmpty)
        {
          'id': 'instant-demo',
          'owner': friend['id'],
          'username': friend['username'],
          'caption': 'Una foto al volo',
          'created': now,
          'expires': now + 86400,
          'retainUntil': now + 365 * 86400,
          'media': friend.str('avatar'),
          'opened': false,
        },
    ];
  }

  bool get instantsPaused => preferences.number('instantsSnoozedUntil') > now;
  List<J> get instantPile {
    if (!demo) return state.rows('instantPile');
    seedInstants();
    return instantsPaused
        ? []
        : state
              .rows('demoInstants')
              .where(
                (x) =>
                    x.str('owner') != myId &&
                    !x.flag('opened') &&
                    x.number('expires') > now &&
                    !blocked(x.str('owner')) &&
                    !preferences.ids('muted').contains(x.str('owner')) &&
                    !preferences.ids('restricted').contains(x.str('owner')),
              )
              .toList();
  }

  List<String> instantAudience(String audience) => users
      .where(
        (u) =>
            u.str('id') != myId &&
            !blocked(u.str('id')) &&
            (audience == 'close'
                ? state.ids('closeFriends').contains(u.str('id'))
                : follows(u.str('id')) &&
                      me.ids('followersList').contains(u.str('id'))),
      )
      .map((u) => u.str('id'))
      .toList();
  Future<Uint8List> instantPreview(String id) async {
    if (demo) {
      final row = state
          .rows('demoInstants')
          .firstWhere((x) => x.str('id') == id);
      final ref = row.str('media');
      final source = ref.startsWith('/')
          ? await File(ref).readAsBytes()
          : (await rootBundle.load('assets/media/$ref')).buffer.asUint8List();
      final image = im.decodeImage(source);
      if (image == null) throw Exception('Foto non disponibile');
      return Uint8List.fromList(
        im.encodeJpg(
          im.gaussianBlur(
            im.copyResize(image, width: 12, height: 12),
            radius: 3,
          ),
        ),
      );
    }
    final r = await client
        .get(
          Uri.parse('$server/instants/$id/preview'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('Anteprima non disponibile');
    return Uint8List.fromList(r.bodyBytes);
  }

  bool canReplyStory(J story) =>
      story.str('author') == myId ||
      user(story.str('author'))['storyRepliesAllowed'] != false;
  Future<J> instantList() async {
    if (!demo) return api('/instants');
    seedInstants();
    return {
      'received': instantPile,
      'active': state
          .rows('demoInstants')
          .where((x) => x.str('owner') == myId && x.number('expires') > now)
          .toList(),
      'sent': state
          .rows('demoInstants')
          .where((x) => x.str('owner') == myId)
          .toList(),
      'friendsCount': instantAudience('friends').length,
      'closeCount': instantAudience('close').length,
      'paused': instantsPaused,
      'eligible': {
        ...instantAudience('friends'),
        ...instantAudience('close'),
      }.toList(),
    };
  }

  Future<String> sendInstant(
    String media,
    List<String> recipients,
    String caption, {
    String requestKey = '',
    String audience = '',
    String replyTo = '',
  }) async {
    if (!demo) {
      final r = await api(
        '/instants/send',
        payload: {
          'media': media,
          'recipients': recipients,
          'caption': caption,
          'requestKey': requestKey,
          if (audience.isNotEmpty) 'audience': audience,
          if (replyTo.isNotEmpty) 'replyTo': replyTo,
        },
      );
      return r.str('id');
    }
    seedInstants();
    final prior = state
        .rows('demoInstants')
        .where(
          (x) => requestKey.isNotEmpty && x.str('requestKey') == requestKey,
        );
    if (prior.isNotEmpty) return prior.first.str('id');
    final ids = replyTo.isNotEmpty
        ? state
              .rows('demoInstants')
              .where((x) => x.str('id') == replyTo)
              .map((x) => x.str('owner'))
              .toList()
        : audience.isNotEmpty
        ? instantAudience(audience)
        : recipients;

    final id = newId();
    state['demoInstants'] = [
      ...state.rows('demoInstants'),
      {
        'id': id,
        'owner': myId,
        'username': me.str('username'),
        'media': media,
        'caption': caption,
        'created': now,
        'expires': now + 86400,
        'retainUntil': now + 365 * 86400,
        'recipients': ids.length,
        'requestKey': requestKey,
      },
    ];
    await _persist();
    notifyListeners();
    return id;
  }

  Future<void> snoozeInstants(bool paused) async {
    if (!demo) {
      await api('/instants/preferences', payload: {'paused': paused});
      await sync();
      return;
    }
    state['preferences'] = {
      ...preferences,
      'instantsSnoozedUntil': paused ? now + 86400 : 0,
    };
    await _persist();
    notifyListeners();
  }

  Future<void> deleteInstant(String id) async {
    if (!demo) {
      await api('/instants/$id/delete', payload: {});
      return;
    }
    state['demoInstants'] = state
        .rows('demoInstants')
        .where((x) => x.str('id') != id)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<J> instantArchivePage({String cursor = ''}) async {
    if (!demo)
      return api(
        '/instants/archive${cursor.isEmpty ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
      );
    seedInstants();
    final all =
        state
            .rows('demoInstants')
            .where(
              (x) =>
                  x.str('owner') == myId &&
                  x.number('retainUntil', x.number('created') + 365 * 86400) >
                      now,
            )
            .toList()
          ..sort((a, b) => b.number('created').compareTo(a.number('created')));
    final offset = int.tryParse(cursor) ?? 0;
    return {
      'items': all
          .skip(offset)
          .take(100)
          .map((x) => {...x, 'viewsCount': x.rows('openedBy').length})
          .toList(),
      'nextCursor': all.length > offset + 100 ? '${offset + 100}' : '',
    };
  }

  Future<J> instantViewers(String id, {int offset = 0}) async {
    if (!demo) return api('/instants/$id/viewers?offset=$offset');
    final row = state
        .rows('demoInstants')
        .where((x) => x.str('id') == id && x.str('owner') == myId)
        .firstOrNull;
    if (row == null) throw Exception('Istantanea non disponibile');
    final views = row.rows('openedBy');
    return {
      'items': views
          .skip(offset)
          .take(50)
          .map(
            (v) => {
              ...v,
              'name': user(v.str('user')).str('name'),
              'username': user(v.str('user')).str('username'),
              'avatar': user(v.str('user')).str('avatar'),
            },
          )
          .toList(),
      'total': views.length,
      'nextOffset': offset + 50 < views.length ? offset + 50 : null,
    };
  }

  Future<List<J>> instantArchive() async =>
      (await instantArchivePage()).rows('items');
  Future<Uint8List> instantBytes(String id, {bool archive = false}) async {
    if (demo) {
      seedInstants();
      final list = archive
          ? state
                .rows('demoInstants')
                .where(
                  (x) =>
                      x.str('owner') == myId &&
                      x.number(
                            'retainUntil',
                            x.number('created') + 365 * 86400,
                          ) >
                          now,
                )
                .toList()
          : instantPile;
      final row = list.firstWhere((x) => x.str('id') == id, orElse: () => {});
      if (row.isEmpty) throw Exception('Istantanea non disponibile');
      if (!archive) {
        row['opened'] = true;
        row['openedBy'] = [
          ...row.rows('openedBy').where((v) => v.str('user') != myId),
          {'user': myId, 'opened': now},
        ];
        await _persist();
        notifyListeners();
      }
      final ref = row.str('media');
      return ref.startsWith('/')
          ? await File(ref).readAsBytes()
          : Uint8List.fromList(
              (await rootBundle.load('assets/media/$ref')).buffer.asUint8List(),
            );
    }
    final uri = Uri.parse(
      '$server/instants/$id/${archive ? 'archive-photo' : 'open'}',
    );
    final headers = {'Authorization': 'Bearer $token'};
    final r =
        await (archive
                ? client.get(uri, headers: headers)
                : client.post(uri, headers: headers))
            .timeout(const Duration(seconds: 35));
    if (r.statusCode >= 400) throw Exception('Istantanea non disponibile');
    return Uint8List.fromList(r.bodyBytes);
  }

  Future<Uint8List> openInstant(String id) => instantBytes(id);
  Future<void> instantFeedback(
    String id,
    String kind,
    String text,
    String key,
  ) async {
    if (!demo) {
      await api(
        '/instants/$id/feedback',
        payload: {'kind': kind, 'text': text, 'requestKey': key},
      );
      await sync();
      return;
    }
    seedInstants();
    final row = state
        .rows('demoInstants')
        .firstWhere(
          (x) => x.str('id') == id && x.flag('opened'),
          orElse: () => {},
        );
    if (row.isEmpty) throw Exception('Apri prima l’istantanea.');
    final done = state.ids('demoInstantFeedback');
    if (done.contains(key)) return;
    await act('thread', {'user': row.str('owner')});
    final t = threads.firstWhere(
      (x) => x.ids('members').contains(row.str('owner')),
    );
    await act('message', {
      'id': t.str('id'),
      'kind': 'text',
      'text': kind == 'reaction'
          ? 'Ha reagito $text alla tua istantanea'
          : 'Risposta alla tua istantanea: $text',
    });
    state['demoInstantFeedback'] = [...done, key];
    await _persist();
  }

  Future<String> instantRecap(List<String> ids, String key) async {
    if (!demo)
      return (await api(
        '/instants/recap',
        payload: {'ids': ids, 'requestKey': key},
      )).str('media');
    if (ids.isEmpty || ids.length > 9)
      throw Exception('Seleziona da 1 a 9 foto.');
    final cols = ids.length == 1
            ? 1
            : ids.length <= 4
            ? 2
            : 3,
        rows =
            (ids.length /
                    (ids.length == 1
                        ? 1
                        : ids.length <= 4
                        ? 2
                        : 3))
                .ceil();
    final canvas = im.Image(width: 1080, height: 1920);
    im.fill(canvas, color: im.ColorRgb8(15, 15, 18));
    final w = 1080 ~/ cols, h = 1920 ~/ rows;
    for (var i = 0; i < ids.length; i++) {
      final bytes = await instantBytes(ids[i], archive: true);
      final image = im.decodeImage(bytes);
      if (image == null) throw Exception('Foto non valida');
      final tile = im.copyResizeCropSquare(image, size: w - 12);
      final fit = im.copyResize(tile, width: w - 12, height: h - 12);
      im.compositeImage(
        canvas,
        fit,
        dstX: i % cols * w + 6,
        dstY: i ~/ cols * h + 6,
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/recap-${newId()}.jpg');
    try {
      await file.writeAsBytes(im.encodeJpg(canvas, quality: 90));
      return await upload(file.path, 'image/jpeg');
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  Future<Uint8List> openOnce(String id) async {
    final m = message(id);
    if (demo) {
      if (m.isEmpty ||
          m.str('author') == myId ||
          expired(m) ||
          m.ids('openedBy').contains(myId))
        throw Exception('Questa foto non è più disponibile.');
      final ref = m.str('media');
      await act('openOnce', {'id': id});
      return ref.startsWith('/')
          ? await File(ref).readAsBytes()
          : Uint8List.fromList(
              (await rootBundle.load('assets/media/$ref')).buffer.asUint8List(),
            );
    }
    final r = await client
        .post(
          Uri.parse('$server/messages/$id/open'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 35));
    if (r.statusCode >= 400)
      throw Exception('Questa foto non è più disponibile.');
    await sync(silent: true);
    return Uint8List.fromList(r.bodyBytes);
  }

  Future<void> storyReply(J story, String text) async {
    if (!canReplyStory(story))
      throw Exception('Le risposte a questa storia sono disattivate.');
    final tid = await openThread(story.str('author'));
    await send(tid, text, kind: 'story', story: story.str('id'));
  }

  Future<void> logout({bool remote = true}) async {
    if (!demo && token.isNotEmpty) {
      try {
        await api('/presence', payload: {'active': false});
      } catch (_) {}
    }
    if (remote && !demo && token.isNotEmpty) {
      try {
        await _request('/auth/logout', body: {});
      } catch (_) {}
    }
    token = '';
    demo = false;
    state = {};
    await vault.delete(key: 'gpix.token');
    await _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    client.close();
    super.dispose();
  }

  void _local(String action, J p) {
    final id = p.str('id'), uid = p.str('user');
    final item = post(id);
    final t = thread(id);
    final items = allPosts;
    final groups = state.rows('threads');
    switch (action) {
      case 'preferences':
        state['preferences'] = {
          ...state.obj('preferences'),
          p.str('key'): p['value'],
        };
        break;
      case 'profileLinks':
        if (p.rows('links').length > 5) throw Exception('Massimo 5 link');
        me['links'] = [
          for (final link in p.rows('links'))
            link.str('type').isNotEmpty
                ? socialLink(
                    link.str('type'),
                    link.str('value'),
                    link.str('title'),
                  )
                : link,
        ];
        break;
      case 'pinPost':
        final ids = me.ids('pinnedPosts')..remove(p.str('id'));
        if (p['enabled'] != false) {
          if (ids.length >= 3) throw Exception('Massimo 3 post fissati');
          ids.insert(0, p.str('id'));
        }
        me['pinnedPosts'] = ids;
        break;
      case 'gridOrder':
        me['gridOrder'] = p.ids('ids');
        break;
      case 'messageRequest':
        t['requestDecision'] = p.str('decision') == 'accepted'
            ? 'accepted'
            : 'hidden';
        break;
      case 'messageExpiry':
        t['messageTTL'] = p.number('seconds');
        break;
      case 'noteReact':
        final note = state
            .rows('notes')
            .where(
              (x) =>
                  x.str('owner') == uid &&
                  x.number('created') == p.number('created'),
            )
            .firstOrNull;
        if (note == null) throw Exception('Nota non disponibile');
        if (!note.flag('likedByMe')) {
          note['likedByMe'] = true;
          note['likesCount'] = note.number('likesCount') + 1;
        }
        break;
      case 'note':
        state['notes'] = state
            .rows('notes')
            .where((n) => n.str('owner') != myId)
            .toList();
        if (!p.flag('delete'))
          state['notes'] = [
            {
              'owner': myId,
              'text': p.str('text').trim(),
              'audience': p.str('audience', 'mutual'),
              'created': now,
              'expires': now + 86400,
            },
            ...state.rows('notes'),
          ];
        break;
      case 'repost':
        final list = item.ids('reposts')..remove(myId);
        if (p['enabled'] != false) list.add(myId);
        item['reposts'] = list;
        break;
      case 'closeFriend':
        final ids = state.ids('closeFriends')..remove(uid);
        if (p['enabled'] != false) ids.add(uid);
        state['closeFriends'] = ids;
        break;
      case 'profile':
        me.addAll(p);
        break;
      case 'pollVote':
        final poll = item.obj('style').obj('poll');
        final counts =
            (poll['counts'] as List?)
                ?.map((v) => (v as num).toInt())
                .toList() ??
            List<int>.filled(poll.ids('options').length, 0);
        final old = poll.number('myVote', -1).toInt(),
            choice = p.number('choice').toInt();
        if (choice < 0 || choice >= counts.length)
          throw Exception('Risposta non valida');
        if (old >= 0 && old < counts.length) counts[old]--;
        counts[choice]++;
        poll['counts'] = counts;
        poll['myVote'] = choice;
        break;
      case 'post':
        state['posts'] = [
          {
            'id': newId(),
            'author': myId,
            'kind': p.str('kind'),
            'text': p.str('text'),
            'media': p.str('media'),
            'mediaItems': p['mediaItems'] ?? [],
            'location': p.str('location'),
            'style': p['style'] ?? {},
            'audience': p.str('audience', 'all'),
            'created': now,
            'expires': p.str('kind') == 'story' ? now + 86400 : 0,
            'likes': <String>[],
            'comments': <J>[],
            'saved': false,
            'viewers': <String>[],
          },
          ...items,
        ];
        break;
      case 'deletePost':
        state['posts'] = items.where((e) => e.str('id') != id).toList();
        break;
      case 'editPost':
        item['text'] = p.str('text');
        item['location'] = p.str('location');
        break;
      case 'archivePost':
        item['archived'] = p['enabled'] ?? true;
        break;
      case 'postOptions':
        item['commentsOff'] = p['commentsOff'] ?? false;
        item['hideLikes'] = p['hideLikes'] ?? false;
        break;
      case 'like':
        final likes = item.ids('likes')..remove(myId);
        if (p['enabled'] != false) likes.add(myId);
        item['likes'] = likes;
        break;
      case 'save':
        item['saved'] = p['enabled'] ?? true;
        break;
      case 'comment':
        item['comments'] = [
          ...item.rows('comments'),
          {
            'id': newId(),
            'author': myId,
            'text': p.str('text'),
            'parent': p.str('parent'),
            'media': p.str('media'),
            'likes': <String>[],
            'created': now,
          },
        ];
        break;
      case 'likeComment':
      case 'hideComment':
      case 'deleteComment':
        for (final post in items) {
          final comments = post.rows('comments');
          final c = comments.firstWhere(
            (e) => e.str('id') == id,
            orElse: () => {},
          );
          if (c.isNotEmpty) {
            if (action == 'hideComment') {
              if (post.str('author') != myId)
                throw Exception('Operazione non consentita');
              c['hidden'] = p['enabled'] != false;
            } else if (action == 'deleteComment') {
              if (c.str('author') != myId && post.str('author') != myId)
                throw Exception('Operazione non consentita');
              post['comments'] = comments
                  .where((e) => e.str('id') != id && e.str('parent') != id)
                  .toList();
            } else {
              final likes = c.ids('likes')..remove(myId);
              if (p['enabled'] != false) likes.add(myId);
              c['likes'] = likes;
              post['comments'] = comments;
            }
          }
        }
        break;
      case 'removeFollower':
        final followers = me.ids('followersList')..remove(uid);
        me['followersList'] = followers;
        me['followers'] = followers.length;
        final following = user(uid).ids('followingList')..remove(myId);
        user(uid)['followingList'] = following;
        user(uid)['following'] = following.length;
        break;
      case 'follow':
        final following = state.ids('following')..remove(uid);
        final pending = state.ids('pending')..remove(uid);
        if (p['enabled'] != false) {
          if (user(uid).flag('private')) {
            pending.add(uid);
          } else {
            following.add(uid);
          }
        }
        state['following'] = following;
        state['pending'] = pending;
        me['following'] = following.length;
        me['followingList'] = following;
        final people = user(uid).ids('followersList')..remove(myId);
        if (following.contains(uid)) people.add(myId);
        user(uid)['followersList'] = people;
        user(uid)['followers'] = people.length;
        break;
      case 'accept':
        state['requests'] = state.ids('requests')..remove(uid);
        if (p['enabled'] != false) {
          final list = me.ids('followersList');
          if (!list.contains(uid)) list.add(uid);
          me['followersList'] = list;
          me['followers'] = list.length;
          final following = user(uid).ids('followingList');
          if (!following.contains(myId)) following.add(myId);
          user(uid)['followingList'] = following;
        }
        break;
      case 'block':
        final blocks = state.ids('blocks')..remove(uid);
        if (p['enabled'] != false) blocks.add(uid);
        state['blocks'] = blocks;
        if (p['enabled'] != false) {
          state['following'] = state.ids('following')..remove(uid);
          state['pending'] = state.ids('pending')..remove(uid);
          me['following'] = state.ids('following').length;
        }
        break;
      case 'highlight':
        state['highlights'] = [
          ...state.rows('highlights'),
          {
            'id': newId(),
            'owner': myId,
            'title': p.str('title'),
            'posts': p['posts'] ?? [],
          },
        ];
        break;
      case 'addHighlight':
        final h = state.rows('highlights').firstWhere((h) => h.str('id') == id);
        h['posts'] = {...h.ids('posts'), p.str('post')}.toList();
        break;
      case 'deleteHighlight':
        state['highlights'] = state
            .rows('highlights')
            .where((e) => e.str('id') != id)
            .toList();
        break;
      case 'thread':
        if (!groups.any(
          (t) => t.str('owner').isEmpty && t.ids('members').contains(uid),
        ))
          groups.add({
            'id': newId(),
            'members': [myId, uid],
            'messages': <J>[],
            'title': '',
            'owner': '',
          });
        state['threads'] = groups;
        break;
      case 'group':
        groups.add({
          'id': newId(),
          'title': p.str('title'),
          'owner': myId,
          'members': [myId, ...p.ids('users')],
          'messages': <J>[],
        });
        state['threads'] = groups;
        break;
      case 'renameGroup':
        t['title'] = p.str('title');
        break;
      case 'addMember':
        t['members'] = {...t.ids('members'), uid}.toList();
        break;
      case 'removeMember':
        t['members'] = t.ids('members')..remove(uid);
        break;
      case 'leaveGroup':
        state['threads'] = groups.where((e) => e.str('id') != id).toList();
        break;
      case 'message':
        t['requestDecision'] = 'accepted';
        final source = post(p.str('story'));
        t['messages'] = [
          ...t.rows('messages'),
          {
            'id': newId(),
            'author': myId,
            'kind': p.str('kind', 'text'),
            'text': p.str('text'),
            'media': p.str('media'),
            'reply': p.str('reply'),
            'story': source.isEmpty
                ? {}
                : {
                    'id': source['id'],
                    'media': source['media'],
                    'text': source['text'],
                    'style': source['style'],
                  },
            'created': now,
            'edited': false,
            'readBy': <String>[],
            'readAt': <String, dynamic>{},
            'afterRead': p.number('expiresIn') == -1 && !p.flag('viewOnce'),
            'viewOnce': p.flag('viewOnce'),
            'maxOpens': p.number('maxOpens', 1),
            'openCounts': <String, dynamic>{},
            'expires': p.number('expiresIn') > 0
                ? now + p.number('expiresIn')
                : (p.flag('viewOnce') ? now + 86400 : 0),
            'openedBy': <String>[],
            'reactions': <String, dynamic>{},
          },
        ];
        break;
      case 'openOnce':
        final m = message(id);
        if (m.isEmpty ||
            expired(m) ||
            m.ids('openedBy').contains(myId) ||
            m.str('author') == myId)
          throw Exception('Foto non disponibile.');
        final counts = m.obj('openCounts');
        counts[myId] = counts.number(myId) + 1;
        m['openCounts'] = counts;
        if (counts.number(myId) >= m.number('maxOpens', 1))
          m['openedBy'] = [...m.ids('openedBy'), myId];
        break;
      case 'sharePost':
        final source = post(p.str('post'));
        _local('message', {
          'id': id,
          'kind': 'post',
          'text': source.str('text'),
        });
        thread(id).rows('messages').last['post'] = source.str('id');
        break;
      case 'read':
      case 'react':
      case 'editMessage':
      case 'deleteMessage':
      case 'forward':
        for (final conversation in groups) {
          final messages = conversation.rows('messages');
          final m = messages.firstWhere(
            (e) => e.str('id') == id,
            orElse: () => {},
          );
          if (m.isEmpty) continue;
          if (action == 'forward' &&
              (m.flag('viewOnce') ||
                  m.number('expires') > 0 ||
                  m.flag('afterRead')))
            throw Exception('Questo contenuto non può essere inoltrato.');
          if (action != 'read' && action != 'deleteMessage' && expired(m))
            throw Exception('Messaggio scaduto.');
          if (action == 'read') {
            m['readBy'] = {...m.ids('readBy'), myId}.toList();
            m['readAt'] = {...m.obj('readAt'), myId: now};
            if (m.flag('afterRead')) m['readExpiresAt'] = now + 5;
          }
          if (action == 'react') {
            final reactions = m.obj('reactions');
            if (p.str('emoji').isEmpty) {
              reactions.remove(myId);
            } else {
              reactions[myId] = p.str('emoji');
            }
            m['reactions'] = reactions;
          }
          if (action == 'editMessage') {
            m['text'] = p.str('text');
            m['edited'] = true;
          }
          if (action == 'deleteMessage')
            messages.removeWhere((e) => e.str('id') == id);
          conversation['messages'] = messages;
          if (action == 'forward') {
            _local('thread', {'user': uid});
            final target = state
                .rows('threads')
                .firstWhere(
                  (t) =>
                      t.ids('members').contains(uid) && t.str('owner').isEmpty,
                );
            target['messages'] = [
              ...target.rows('messages'),
              {
                ...m,
                'id': newId(),
                'author': myId,
                'created': now,
                'reply': '',
                'readBy': <String>[],
                'reactions': <String, dynamic>{},
              },
            ];
          }
          break;
        }
        break;
      case 'see':
        final viewers = item.ids('viewers');
        if (item.str('author') != myId && !viewers.contains(myId))
          viewers.add(myId);
        item['viewers'] = viewers;
        item['seenByMe'] = true;
        break;
      case 'notificationsRead':
        for (final n in state.rows('notifications')) {
          if ((id.isEmpty && n.str('type') != 'messageReaction') ||
              n.str('id') == id)
            n['seen'] = true;
        }
        break;
      case 'report':
        state['reports'] = [
          ...state.rows('reports'),
          {...p, 'created': now},
        ];
        break;
      case 'deleteAccount':
        state = {};
        demo = false;
        break;
      default:
        throw Exception('Azione non supportata: $action');
    }
  }

  J _seed() {
    final users = <J>[
      {
        'id': 'me',
        'name': 'Dmb',
        'username': 'dmb',
        'bio': 'Ogni sfumatura, una storia. 🏳️‍🌈',
        'avatar': 'avatar4.jpg',
        'private': false,
        'followers': 2,
        'following': 2,
        'followersList': ['u0', 'u2'],
        'followingList': ['u0', 'u1'],
        'website': '',
        'pronouns': 'lui / he',
      },
    ];
    final names = [
      'Andrea Rossi',
      'Giulia Bianchi',
      'Alex Rivera',
      'Matteo Costa',
    ];
    final handles = ['andrea.rossi', 'giulia.b', 'alex.rivera', 'matteo.costa'];
    for (var i = 0; i < 4; i++) {
      users.add({
        'id': 'u$i',
        'name': names[i],
        'username': handles[i],
        'bio': i == 2
            ? 'Design, musica e libertà.\nThey / them 🏳️‍🌈'
            : 'Piccoli momenti, persone vere.\nItalia · ${i == 1 ? 'lei / she' : 'lui / he'}',
        'avatar': 'avatar$i.jpg',
        'private': false,
        'followers': 148 + i * 23,
        'following': 87 + i,
        'followersList': ['me'],
        'followingList': ['me'],
      });
    }
    final graph = <String, List<String>>{
      'me': ['u0', 'u1'],
      'u0': ['me', 'u1'],
      'u1': ['u2'],
      'u2': ['me', 'u0'],
      'u3': ['u1', 'u2'],
    };
    for (final u in users) {
      final id = u.str('id');
      final followers = graph.entries
          .where((e) => e.value.contains(id))
          .map((e) => e.key)
          .toList();
      u['followingList'] = graph[id] ?? <String>[];
      u['following'] = (graph[id] ?? []).length;
      u['followersList'] = followers;
      u['followers'] = followers.length;
    }
    final captions = [
      'Un posto nel mondo. Le persone giuste. 🌈',
      'Ci sono momenti che vorresti tenere per sempre.',
      'Il mare, un respiro e niente da dimostrare.',
      'Fuori dagli schemi. Dentro la vita.',
    ];
    final posts = <J>[];
    for (var i = 0; i < 4; i++) {
      posts.add({
        'id': 'p$i',
        'author': 'u$i',
        'kind': 'post',
        'text': captions[i],
        'media': 'post${i == 0 ? 5 : i}.jpg',
        'mediaItems': i == 1 ? ['post1.jpg', 'post3.jpg'] : [],
        'location': [
          'Roma, Italia',
          'Dolomiti',
          'Un posto felice',
          'Firenze',
        ][i],
        'created': now - 1800 - i * 720,
        'expires': 0,
        'archived': false,
        'saved': false,
        'likes': ['u${(i + 1) % 4}', 'u${(i + 2) % 4}'],
        'comments': i == 0
            ? [
                {
                  'id': 'c0',
                  'author': 'u1',
                  'text': 'Questo è il mood giusto ✨',
                  'parent': '',
                  'created': now - 700,
                  'likes': ['u2'],
                },
              ]
            : <J>[],
        'style': {'aspect': 1.0},
      });
      posts.add({
        'id': 's$i',
        'author': 'u$i',
        'kind': 'story',
        'text': [
          'Un po’ più liberi.\nUn po’ più noi.',
          'Il mio posto felice.',
          'Tutte le nostre sfumature.',
          'Una pausa dal rumore.',
        ][i],
        'media': 'post${i + 1}.jpg',
        'created': now - 600,
        'expires': now + 85000,
        'style': {
          'background': i,
          'x': 0.5,
          'y': 0.7,
          'size': 30,
          'font': 0,
          'color': 0,
          'zoom': 1.0,
          'sticker': i == 0 ? '🌈' : '',
        },
        'likes': <String>[],
        'comments': <J>[],
        'viewers': <String>[],
      });
    }
    posts.add({
      'id': 'r0',
      'author': 'u2',
      'kind': 'reel',
      'text': 'Un piccolo momento, tutto per te. ✨',
      'media': 'reel.mp4',
      'likes': ['u0', 'u1'],
      'comments': <J>[],
      'created': now - 300,
      'saved': false,
    });
    posts.add({
      'id': 'my-p0',
      'author': 'me',
      'kind': 'post',
      'text': 'Essere se stessi è un buon punto di partenza. 🌈',
      'media': 'post0.jpg',
      'created': now - 9000,
      'likes': ['u0', 'u2'],
      'comments': <J>[],
      'saved': false,
      'location': 'Un nuovo inizio',
    });
    posts.add({
      'id': 'my-s0',
      'author': 'me',
      'kind': 'story',
      'text': 'Ogni sfumatura conta.',
      'media': 'post3.jpg',
      'created': now - 900,
      'expires': now + 85000,
      'likes': ['u0'],
      'comments': <J>[],
      'viewers': ['u0', 'u2'],
      'style': {'x': .5, 'y': .7, 'size': 29, 'color': 0, 'sticker': '🌈'},
    });
    return {
      'me': users.first,
      'users': users,
      'posts': posts,
      'following': ['u0', 'u1'],
      'pending': <String>[],
      'requests': <String>[],
      'blocks': <String>[],
      'highlights': <J>[
        {
          'id': 'h0',
          'owner': 'me',
          'title': 'Momenti',
          'posts': ['my-s0'],
        },
      ],
      'threads': [
        {
          'id': 't0',
          'members': ['me', 'u0'],
          'title': '',
          'owner': '',
          'messages': [
            {
              'id': 'm0',
              'author': 'u0',
              'kind': 'text',
              'text': 'Ehi! Come è andata la giornata? 😊',
              'created': now - 1800,
              'reactions': <String, dynamic>{},
              'readBy': ['me'],
            },
            {
              'id': 'm1',
              'author': 'me',
              'kind': 'text',
              'text': 'Bene! Mi serviva proprio un po’ di aria nuova.',
              'created': now - 1700,
              'reactions': {'u0': '❤️'},
              'readBy': ['u0'],
            },
            {
              'id': 'once-demo',
              'author': 'u0',
              'kind': 'image',
              'text': '',
              'media': 'post0.jpg',
              'viewOnce': true,
              'expires': now + 86400,
              'openedBy': <String>[],
              'created': now - 1600,
              'readBy': ['me'],
              'reactions': <String, dynamic>{},
            },
            {
              'id': 'm2',
              'author': 'u0',
              'kind': 'text',
              'text': 'Allora un caffè nel weekend? ☕',
              'created': now - 1500,
              'reactions': <String, dynamic>{},
              'readBy': <String>[],
            },
          ],
        },
        {
          'id': 't1',
          'members': ['me', 'u2'],
          'title': '',
          'owner': '',
          'messages': [
            {
              'id': 'm3',
              'author': 'u2',
              'kind': 'text',
              'text': 'Ti ho mandato una cosa che ti piacerà 🌈',
              'created': now - 6000,
              'reactions': <String, dynamic>{},
              'readBy': ['me'],
            },
          ],
        },
      ],
      'notifications': [
        {
          'id': 'n0',
          'actor': 'u1',
          'type': 'comment',
          'ref': 'p0',
          'created': now - 600,
          'seen': false,
        },
        {
          'id': 'n1',
          'actor': 'u0',
          'type': 'message',
          'ref': 't0',
          'created': now - 1800,
          'seen': false,
        },
      ],
    };
  }
}

class GpixScope extends InheritedNotifier<GpixStore> {
  const GpixScope({super.key, required GpixStore store, required super.child})
    : super(notifier: store);
  static GpixStore of(BuildContext c, {bool listen = true}) => listen
      ? c.dependOnInheritedWidgetOfExactType<GpixScope>()!.notifier!
      : c.getInheritedWidgetOfExactType<GpixScope>()!.notifier!;
}

class _UploadRequest extends http.BaseRequest {
  final List<int> bytes;
  final void Function(double) progress;
  _UploadRequest(Uri uri, this.bytes, this.progress) : super('POST', uri) {
    contentLength = bytes.length;
  }
  @override
  http.ByteStream finalize() {
    super.finalize();
    Stream<List<int>> chunks() async* {
      for (var offset = 0; offset < bytes.length; offset += 65536) {
        final end = (offset + 65536).clamp(0, bytes.length);
        yield bytes.sublist(offset, end);
        progress(end / bytes.length);
      }
    }

    return http.ByteStream(chunks());
  }
}
