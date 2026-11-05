import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';

final gpixNavigator = GlobalKey<NavigatorState>();
final activeCall = ValueNotifier<String>('');
Future<void> launchCall(BuildContext c, String thread, bool video) async {
  final s = GpixScope.of(c, listen: false);
  if (activeCall.value.isNotEmpty) {
    await gpixAlert(
      c,
      'Chiamata già aperta',
      'Termina la chiamata attuale prima di avviarne un’altra.',
    );
    return;
  }
  if (s.demo) {
    await open(
      c,
      CallScreen(
        id: 'demo',
        peer: s.other(s.thread(thread)),
        video: video,
        demo: true,
      ),
    );
    return;
  }
  await perform(c, () async {
    final id = await s.startCall(thread, video);
    if (c.mounted)
      await open(
        c,
        CallScreen(id: id, peer: s.other(s.thread(thread)), video: video),
      );
  });
}

class IncomingCall extends StatelessWidget {
  const IncomingCall({super.key});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return ValueListenableBuilder<String>(
      valueListenable: activeCall,
      builder: (c, active, _) {
        final calls = s.state
            .rows('calls')
            .where(
              (x) =>
                  x.str('callee') == s.myId &&
                  x.str('status') == 'ringing' &&
                  now - x.number('created') < 60 &&
                  x.str('id') != active &&
                  !s.blocked(x.str('caller')),
            )
            .toList();
        if (calls.isEmpty || active.isNotEmpty) return const SizedBox.shrink();
        final call = calls.first;
        return Positioned(
          top: 0,
          left: 12,
          right: 12,
          child: SafeArea(
            child: Material(
              elevation: 10,
              color: const Color(0xff263b62),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Avatar(call.str('caller'), size: 44),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.user(call.str('caller')).str('name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            call.flag('video')
                                ? 'Videochiamata in arrivo'
                                : 'Chiamata vocale in arrivo',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('reject-call'),
                      onPressed: () {
                        final context =
                            gpixNavigator.currentState?.overlay?.context;
                        if (context != null)
                          perform(
                            context,
                            () => s.act('callEnd', {'id': call['id']}),
                          );
                      },
                      style: IconButton.styleFrom(backgroundColor: danger),
                      icon: const GIcon(
                        CupertinoIcons.phone_down_fill,
                        semanticLabel: 'Rifiuta chiamata',
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey('accept-call'),
                      onPressed: () => gpixNavigator.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => CallScreen(
                            id: call.str('id'),
                            peer: call.str('caller'),
                            video: call.flag('video'),
                            answer: true,
                          ),
                        ),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xff37ac72),
                      ),
                      icon: GIcon(
                        call.flag('video')
                            ? CupertinoIcons.video_camera_solid
                            : CupertinoIcons.phone_fill,
                        semanticLabel: 'Rispondi alla chiamata',
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CallScreen extends StatefulWidget {
  final String id, peer;
  final bool video, answer, demo;
  const CallScreen({
    super.key,
    required this.id,
    required this.peer,
    required this.video,
    this.answer = false,
    this.demo = false,
  });
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final local = RTCVideoRenderer(), remote = RTCVideoRenderer();
  RTCPeerConnection? pc;
  MediaStream? stream;
  GpixStore? store;
  Timer? timer, reconnectTimer;
  Future<void>? mediaCleanup;
  Future<void> sendQueue = Future.value();
  final List<RTCIceCandidate> waitingIce = [];
  bool initialized = false,
      remoteSet = false,
      polling = false,
      mic = true,
      camera = true,
      speaker = false,
      connected = false,
      ending = false;
  int cursor = 0, ticks = 0, elapsed = 0;
  String status = 'Preparazione…', failure = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      camera = widget.video;
      store = GpixScope.of(context, listen: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          activeCall.value = widget.id;
          initialize();
        }
      });
    }
  }

  Future<void> signal(String kind, J data) {
    sendQueue = sendQueue.then((_) => store!.rtcSignal(widget.id, kind, data));
    return sendQueue;
  }

  Future<void> initialize() async {
    try {
      await local.initialize();
      if (!mounted || ending) {
        await local.dispose();
        return;
      }
      await remote.initialize();
      if (!mounted || ending) {
        await local.dispose();
        await remote.dispose();
        return;
      }
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.video
            ? {'facingMode': 'user', 'width': 640, 'height': 960}
            : false,
      });
      if (!mounted || ending) {
        for (final track in stream?.getTracks() ?? []) {
          await track.stop();
        }
        await stream?.dispose();
        return;
      }
      local.srcObject = stream;
      for (final track in stream!.getAudioTracks()) {
        track.enabled = mic;
      }
      for (final track in stream!.getVideoTracks()) {
        track.enabled = camera;
      }
      speaker = widget.video;
      await Helper.setSpeakerphoneOn(speaker);
      if (widget.demo) {
        setState(() => status = 'Demo · anteprima locale');
        return;
      }
      final config = await store!.rtcGet('config');
      pc = await createPeerConnection({
        'iceServers': config['iceServers'],
        'sdpSemantics': 'unified-plan',
      });
      for (final track in stream!.getTracks()) {
        await pc!.addTrack(track, stream!);
      }
      pc!.onIceCandidate = (candidate) {
        if (candidate.candidate?.isNotEmpty == true) {
          signal('ice', candidate.toMap()).catchError((e) {
            fail(e);
          });
        }
      };
      pc!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          remote.srcObject = event.streams.first;
          if (mounted) setState(() {});
        }
      };
      pc!.onConnectionState = (value) {
        if (!mounted || ending) return;
        if (value == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          reconnectTimer?.cancel();
          setState(() {
            connected = true;
            status = 'Connessi';
          });
          store!.act('callConnected', {'id': widget.id}).catchError((e) {
            fail(e);
          });
        } else if (value ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          fail(
            'Connessione non riuscita. Verifica la rete e la configurazione TURN del server.',
          );
        } else if (value ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          setState(() => status = 'Riconnessione…');
          reconnectTimer?.cancel();
          reconnectTimer = Timer(
            const Duration(seconds: 20),
            () =>
                fail('La connessione con l’altra persona è stata interrotta.'),
          );
        }
      };
      if (widget.answer) {
        await store!.act('callAccept', {'id': widget.id});
        setState(() => status = 'Connessione…');
      } else {
        final offer = await pc!.createOffer();
        await pc!.setLocalDescription(offer);
        await signal('offer', offer.toMap());
        setState(() => status = 'Chiamata in corso…');
      }
      await poll();
      if (mounted && !ending)
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          ticks++;
          if (connected) elapsed++;
          if (mounted) setState(() {});
          if (ticks % 10 == 0)
            store!.act('callHeartbeat', {'id': widget.id}).catchError((e) {
              fail(e);
            });
          poll();
        });
    } catch (e) {
      await fail(e);
    }
  }

  Future<void> poll() async {
    if (polling || ending || !mounted) return;
    polling = true;
    try {
      final r = await store!.rtcGet('call/${widget.id}?after=$cursor');
      if (!mounted || ending) return;
      final call = r.obj('call'), state = call.str('status');
      if (['ended', 'declined', 'missed'].contains(state)) {
        setState(() {
          ending = true;
          status = state == 'declined'
              ? 'Chiamata rifiutata'
              : state == 'missed'
              ? 'Nessuna risposta'
              : 'Chiamata terminata';
        });
        timer?.cancel();
        await closeMedia();
        if (mounted) await store!.sync(silent: true);
        return;
      }
      if (state == 'accepted' && !connected)
        setState(() => status = 'Connessione…');
      for (final item in r.rows('signals')) {
        final data = item.obj('data');
        if (item.str('kind') == 'offer' && widget.answer && !remoteSet) {
          await pc!.setRemoteDescription(
            RTCSessionDescription(data.str('sdp'), data.str('type')),
          );
          remoteSet = true;
          for (final ice in waitingIce) {
            await pc!.addCandidate(ice);
          }
          waitingIce.clear();
          final answer = await pc!.createAnswer();
          await pc!.setLocalDescription(answer);
          await signal('answer', answer.toMap());
        } else if (item.str('kind') == 'answer' &&
            !widget.answer &&
            !remoteSet) {
          await pc!.setRemoteDescription(
            RTCSessionDescription(data.str('sdp'), data.str('type')),
          );
          remoteSet = true;
          for (final ice in waitingIce) {
            await pc!.addCandidate(ice);
          }
          waitingIce.clear();
        } else if (item.str('kind') == 'ice') {
          final ice = RTCIceCandidate(
            data.str('candidate'),
            data['sdpMid'],
            (data['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (remoteSet) {
            await pc!.addCandidate(ice);
          } else {
            waitingIce.add(ice);
          }
        }
        cursor = item.number('seq').toInt();
      }
    } catch (e) {
      await fail(e);
    } finally {
      polling = false;
    }
  }

  Future<void> fail(Object e) async {
    if (!mounted || ending) return;
    timer?.cancel();
    setState(() {
      failure = e.toString().replaceFirst('Exception: ', '');
      status = 'Chiamata non disponibile';
      ending = true;
    });
    await closeMedia();
    if (!widget.demo)
      unawaited(store!.act('callEnd', {'id': widget.id}).catchError((_) {}));
  }

  Future<void> closeMedia() => mediaCleanup ??= cleanMedia();
  Future<void> cleanMedia() async {
    reconnectTimer?.cancel();
    for (final track in stream?.getTracks() ?? []) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await pc?.close();
    } catch (_) {}
    pc = null;
    if (local.textureId != null) local.srcObject = null;
    if (remote.textureId != null) remote.srcObject = null;
  }

  Future<void> hangup() async {
    final notify = !ending && !widget.demo;
    ending = true;
    timer?.cancel();
    await closeMedia();
    if (notify)
      unawaited(store!.act('callEnd', {'id': widget.id}).catchError((_) {}));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    timer?.cancel();
    reconnectTimer?.cancel();
    unawaited(
      closeMedia()
          .whenComplete(() async {
            await stream?.dispose();
            await local.dispose();
            await remote.dispose();
            await Helper.setSpeakerphoneOn(false);
          })
          .catchError((_) {}),
    );
    Future.microtask(() {
      if (activeCall.value == widget.id) activeCall.value = '';
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return PopScope(
      canPop: ending,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) hangup();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff243960),
        body: SafeArea(
          child: Stack(
            children: [
              if (widget.video && remote.srcObject != null)
                Positioned.fill(
                  child: RTCVideoView(
                    remote,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              if (widget.video && local.srcObject != null)
                Positioned(
                  top: 20,
                  right: 18,
                  width: 95,
                  height: 145,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: RTCVideoView(
                      local,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              Column(
                children: [
                  const SizedBox(height: 60),
                  if (remote.srcObject == null) ...[
                    Avatar(widget.peer, size: 92),
                    const SizedBox(height: 22),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      s.user(widget.peer).str('name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    connected
                        ? '${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}'
                        : status,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (widget.demo)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(30, 22, 30, 0),
                      child: Text(
                        'Test di camera e microfono sul dispositivo. Nessuna persona reale è collegata nella demo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  if (failure.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        failure,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (!ending)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 17,
                        runSpacing: 18,
                        children: [
                          control(
                            mic
                                ? CupertinoIcons.mic_fill
                                : CupertinoIcons.mic_slash_fill,
                            mic ? 'Microfono' : 'Riattiva',
                            () {
                              setState(() => mic = !mic);
                              for (final t in stream?.getAudioTracks() ?? []) {
                                t.enabled = mic;
                              }
                            },
                          ),
                          control(
                            speaker
                                ? CupertinoIcons.speaker_2_fill
                                : CupertinoIcons.speaker_fill,
                            'Altoparlante',
                            () async {
                              setState(() => speaker = !speaker);
                              await Helper.setSpeakerphoneOn(speaker);
                            },
                          ),
                          if (widget.video) ...[
                            control(
                              camera
                                  ? CupertinoIcons.video_camera_solid
                                  : CupertinoIcons.video_camera,
                              'Camera',
                              () {
                                setState(() => camera = !camera);
                                for (final t
                                    in stream?.getVideoTracks() ?? []) {
                                  t.enabled = camera;
                                }
                              },
                            ),
                            control(
                              CupertinoIcons.camera_rotate,
                              'Ruota',
                              () async {
                                final tracks = stream?.getVideoTracks() ?? [];
                                if (tracks.isNotEmpty)
                                  await Helper.switchCamera(tracks.first);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  control(
                    CupertinoIcons.phone_down_fill,
                    ending ? 'Chiudi' : 'Termina',
                    hangup,
                    red: true,
                  ),
                  const SizedBox(height: 35),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget control(
    IconData icon,
    String label,
    VoidCallback tap, {
    bool red = false,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: label,
        onPressed: tap,
        style: IconButton.styleFrom(
          backgroundColor: red ? danger : Colors.white12,
          padding: const EdgeInsets.all(17),
        ),
        icon: GIcon(icon, color: Colors.white, size: 25),
      ),
      const SizedBox(height: 7),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ],
  );
}
