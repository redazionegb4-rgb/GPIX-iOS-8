import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'social.dart';
import 'calls.dart';

Future<void> createLive(BuildContext c, {String? initialTitle}) async {
  final title =
      initialTitle ??
      await textDialog(
        c,
        'Titolo della diretta',
        '',
        hint: 'Di cosa parliamo?',
      );
  if (title == null || !c.mounted) return;
  final s = GpixScope.of(c, listen: false);
  await perform(c, () async {
    final id = s.demo ? 'demo' : await s.startLive(title);
    if (c.mounted)
      await open(c, LiveRoom(id: id, host: s.myId, title: title, demo: s.demo));
  });
}

class LiveRoom extends StatefulWidget {
  final String id, host, title;
  final bool demo;
  const LiveRoom({
    super.key,
    required this.id,
    required this.host,
    this.title = '',
    this.demo = false,
  });
  @override
  State<LiveRoom> createState() => _LiveRoomState();
}

class _LiveRoomState extends State<LiveRoom> with WidgetsBindingObserver {
  final video = RTCVideoRenderer();
  final input = TextEditingController();
  final Map<String, RTCPeerConnection> peers = {};
  final Map<String, List<RTCIceCandidate>> buffered = {};
  final Map<String, Future<void>> queues = {};
  final Set<String> remoteSet = {};
  GpixStore? s;
  MediaStream? stream;
  J config = {};
  List<String> viewers = [];
  List<J> comments = [];
  int cursor = 0, ticks = 0, likes = 0;
  Timer? timer;
  bool initialized = false,
      polling = false,
      ended = false,
      mic = true,
      camera = true;
  String error = '';
  bool get hosting => widget.host == s?.myId;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      s = GpixScope.of(context, listen: false);
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) => init());
    }
  }

  Future<void> init() async {
    try {
      activeCall.value = 'live:${widget.id}';
      await video.initialize();
      if (!mounted || ended) return;
      if (hosting) {
        stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {'facingMode': 'user', 'width': 640, 'height': 960},
        });
        if (!mounted || ended) {
          for (final t in stream!.getTracks()) {
            await t.stop();
          }
          await stream?.dispose();
          return;
        }
        video.srcObject = stream;
      }
      if (widget.demo) {
        setState(() {});
        return;
      }
      config = await s!.rtcGet('config');
      if (!hosting) await s!.act('liveJoin', {'id': widget.id});
      await poll();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        ticks++;
        if (ticks % 8 == 0)
          s!.act('liveHeartbeat', {'id': widget.id}).catchError((e) => fail(e));
        poll();
      });
    } catch (e) {
      fail(e);
    }
  }

  Future<void> signal(String peer, String kind, J data) {
    final q = (queues[peer] ?? Future.value())
        .catchError((_) {})
        .then((_) => s!.liveSignal(widget.id, peer, kind, data));
    queues[peer] = q;
    return q;
  }

  Future<RTCPeerConnection> ensure(String id) async {
    if (peers.containsKey(id)) return peers[id]!;
    final pc = await createPeerConnection({
      'iceServers': config['iceServers'],
      'sdpSemantics': 'unified-plan',
    });
    peers[id] = pc;
    buffered[id] = [];
    if (hosting) {
      for (final t in stream!.getTracks()) {
        await pc.addTrack(t, stream!);
      }
    } else {
      pc.onTrack = (e) {
        if (e.streams.isNotEmpty && mounted && !ended) {
          video.srcObject = e.streams.first;
          setState(() {});
        }
      };
    }
    pc.onIceCandidate = (ice) {
      if (ice.candidate?.isNotEmpty == true)
        signal(id, 'ice', ice.toMap()).catchError((_) {});
    };
    return pc;
  }

  Future<void> poll() async {
    if (polling || ended || !mounted) return;
    polling = true;
    try {
      final r = await s!.liveGet(widget.id, cursor);
      if (!mounted || ended) return;
      if (r.obj('room').str('status') != 'live') {
        await finish(remote: true);
        return;
      }
      viewers = r.ids('viewers');
      comments = r.rows('comments');
      likes = r.number('likes').toInt();
      if (hosting) {
        for (final id in peers.keys.toList().where(
          (id) => !viewers.contains(id),
        )) {
          await peers.remove(id)?.close();
          remoteSet.remove(id);
          buffered.remove(id);
        }
        for (final id in viewers) {
          if (!peers.containsKey(id)) {
            try {
              final pc = await ensure(id);
              final offer = await pc.createOffer();
              await pc.setLocalDescription(offer);
              await signal(id, 'offer', offer.toMap());
            } catch (_) {
              await peers.remove(id)?.close();
              remoteSet.remove(id);
            }
          }
        }
      }
      for (final item in r.rows('signals')) {
        final id = item.str('viewer'), data = item.obj('data');
        if (!hosting || viewers.contains(id)) {
          final pc = await ensure(id);
          if (item.str('kind') == 'offer' &&
              !hosting &&
              !remoteSet.contains(id)) {
            await pc.setRemoteDescription(
              RTCSessionDescription(data.str('sdp'), data.str('type')),
            );
            remoteSet.add(id);
            for (final ice in buffered[id] ?? []) {
              await pc.addCandidate(ice);
            }
            buffered[id]?.clear();
            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            await signal(id, 'answer', answer.toMap());
          } else if (item.str('kind') == 'answer' &&
              hosting &&
              !remoteSet.contains(id)) {
            await pc.setRemoteDescription(
              RTCSessionDescription(data.str('sdp'), data.str('type')),
            );
            remoteSet.add(id);
            for (final ice in buffered[id] ?? []) {
              await pc.addCandidate(ice);
            }
            buffered[id]?.clear();
          } else if (item.str('kind') == 'ice') {
            final ice = RTCIceCandidate(
              data.str('candidate'),
              data['sdpMid'],
              (data['sdpMLineIndex'] as num?)?.toInt(),
            );
            if (remoteSet.contains(id)) {
              await pc.addCandidate(ice);
            } else {
              buffered[id]?.add(ice);
            }
          }
        }
        cursor = item.number('seq').toInt();
      }
      if (mounted) setState(() {});
    } catch (e) {
      await fail(e);
    } finally {
      polling = false;
    }
  }

  Future<void> cleanup() async {
    timer?.cancel();
    for (final t in stream?.getTracks() ?? []) {
      try {
        await t.stop();
      } catch (_) {}
    }
    for (final p in peers.values.toList()) {
      try {
        await p.close();
      } catch (_) {}
    }
    peers.clear();
    if (video.textureId != null) video.srcObject = null;
  }

  Future<void> fail(Object e) async {
    if (ended || !mounted) return;
    setState(() {
      error = e.toString().replaceFirst('Exception: ', '');
      ended = true;
    });
    await cleanup();
    if (!widget.demo)
      unawaited(
        s!
            .act(hosting ? 'liveEnd' : 'liveLeave', {'id': widget.id})
            .catchError((_) {}),
      );
  }

  Future<void> finish({bool remote = false}) async {
    if (!ended) {
      setState(() => ended = true);
      await cleanup();
      if (!widget.demo && !remote)
        unawaited(
          s!
              .act(hosting ? 'liveEnd' : 'liveLeave', {'id': widget.id})
              .catchError((_) {}),
        );
    }
    if (!remote && mounted) Navigator.pop(context);
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    await perform(context, () async {
      if (widget.demo) {
        setState(() => comments.insert(0, {'author': s!.myId, 'text': text}));
      } else {
        await s!.act('liveComment', {'id': widget.id, 'text': text});
        await poll();
      }
      input.clear();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) finish();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    unawaited(
      cleanup()
          .whenComplete(() async {
            await stream?.dispose();
            await video.dispose();
          })
          .catchError((_) {}),
    );
    input.dispose();
    Future.microtask(() {
      if (activeCall.value == 'live:${widget.id}') activeCall.value = '';
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final store = GpixScope.of(c);
    return PopScope(
      canPop: ended,
      onPopInvokedWithResult: (didPop, r) {
        if (!didPop) finish();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              if (video.srcObject != null)
                Positioned.fill(
                  child: RTCVideoView(
                    video,
                    mirror: hosting,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 13, 8, 0),
                    child: Row(
                      children: [
                        Avatar(widget.host, size: 35),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            store.user(widget.host).str('username'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: danger,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            widget.demo ? 'DEMO' : 'LIVE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GIcon(
                          CupertinoIcons.eye,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${viewers.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          tooltip: 'Chiudi diretta',
                          onPressed: () async {
                            if (hosting &&
                                !ended &&
                                !await gpixAlert(
                                  c,
                                  'Terminare la diretta?',
                                  'Gli spettatori verranno disconnessi.',
                                  confirm: 'Termina',
                                  cancel: true,
                                ))
                              return;
                            finish();
                          },
                          icon: const GIcon(
                            CupertinoIcons.xmark,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  if (widget.demo)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Anteprima locale · nessuno spettatore reale',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  if (ended)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(
                            error.isEmpty ? 'La diretta è terminata' : error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (!ended)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 17),
                        itemCount: comments.length,
                        itemBuilder: (c, i) {
                          final m = comments[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${store.user(m.str('author')).str('username')} ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: m.str('text')),
                                ],
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (!ended)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 9, 13, 17),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: input,
                              onSubmitted: (_) => send(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Commenta…',
                                hintStyle: const TextStyle(
                                  color: Colors.white60,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 10,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Invia commento',
                            onPressed: send,
                            icon: const GIcon(
                              CupertinoIcons.paperplane,
                              color: Colors.white,
                            ),
                          ),
                          if (hosting) ...[
                            IconButton(
                              tooltip: 'Microfono diretta',
                              onPressed: () {
                                setState(() => mic = !mic);
                                for (final t
                                    in stream?.getAudioTracks() ?? []) {
                                  t.enabled = mic;
                                }
                              },
                              icon: GIcon(
                                mic
                                    ? CupertinoIcons.mic
                                    : CupertinoIcons.mic_slash,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cambia camera diretta',
                              onPressed: () {
                                final tracks = stream?.getVideoTracks() ?? [];
                                if (tracks.isNotEmpty)
                                  Helper.switchCamera(tracks.first);
                              },
                              icon: const GIcon(
                                CupertinoIcons.camera_rotate,
                                color: Colors.white,
                              ),
                            ),
                          ] else
                            IconButton(
                              tooltip: 'Mi piace alla diretta',
                              onPressed: () => perform(c, () async {
                                if (widget.demo) {
                                  setState(() => likes = 1);
                                } else {
                                  await store.act('liveLike', {
                                    'id': widget.id,
                                  });
                                  await poll();
                                }
                              }),
                              icon: const GIcon(
                                CupertinoIcons.heart,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (!ended && likes > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '$likes Mi piace',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
