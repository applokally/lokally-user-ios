import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class LokallyMeetingScreen extends StatefulWidget {
  final String orderId;
  final String meetingId;
  final bool isHost;
  final String title;

  const LokallyMeetingScreen({
    super.key,
    required this.orderId,
    required this.meetingId,
    required this.isHost,
    this.title = 'Lokally Meeting',
  });

  @override
  State<LokallyMeetingScreen> createState() => _LokallyMeetingScreenState();
}

class _LokallyMeetingScreenState extends State<LokallyMeetingScreen> {
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  Timer? signalTimer;

  bool isPreparing = true;
  bool isEnding = false;
  bool isAudioEnabled = true;
  bool isVideoEnabled = true;
  bool isFrontCamera = true;
  bool hasRemoteVideo = false;
  String statusText = 'Preparando Lokally Meeting...';

  String get meetingBaseUri =>
      '/api/customer/store/service-chat/order/${widget.orderId}/meeting/${widget.meetingId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prepareMeeting();
    });
  }

  @override
  void dispose() {
    signalTimer?.cancel();
    closeMeetingResources();
    super.dispose();
  }

  Future<void> prepareMeeting() async {
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      await prepareLocalMedia();
      await preparePeerConnection();

      if (widget.isHost) {
        await startMeetingAsHost();
      } else {
        await joinMeetingAsParticipant();
      }

      startSignalPolling();

      if (mounted) {
        setState(() {
          isPreparing = false;
          statusText = widget.isHost
              ? 'Meeting iniciado. Aguardando o outro participante.'
              : 'Entrando no Lokally Meeting...';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isPreparing = false;
          statusText =
              'Não foi possível iniciar o Lokally Meeting. Verifique câmera, microfone e conexão.';
        });
      }
    }
  }

  Future<void> prepareLocalMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      },
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = localStream;
  }

  Future<void> preparePeerConnection() async {
    peerConnection = await createPeerConnection(rtcConfiguration);

    remoteStream = await createLocalMediaStream('lokally_meeting_remote');
    remoteRenderer.srcObject = remoteStream;

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      sendSignal(
        signalType: 'ice_candidate',
        payload: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      } else if (event.track.kind == 'video' || event.track.kind == 'audio') {
        remoteStream?.addTrack(event.track);
        remoteRenderer.srcObject = remoteStream;
      }

      if (mounted) {
        setState(() {
          hasRemoteVideo = true;
          statusText = 'Conectado ao Lokally Meeting.';
        });
      }
    };

    final List<MediaStreamTrack> tracks = localStream?.getTracks() ?? [];
    for (final MediaStreamTrack track in tracks) {
      await peerConnection?.addTrack(track, localStream!);
    }
  }

  Future<void> startMeetingAsHost() async {
    final Response startResponse = await Get.find<ApiClient>().postData(
      '$meetingBaseUri/start',
      <String, dynamic>{},
    );

    if (!responseIsOk(startResponse)) {
      throw Exception('start_failed');
    }

    final RTCSessionDescription offer = await peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });

    await peerConnection!.setLocalDescription(offer);

    await sendSignal(
      signalType: 'offer',
      receiverType: 'customer',
      payload: {
        'type': offer.type,
        'sdp': offer.sdp,
      },
    );
  }

  Future<void> joinMeetingAsParticipant() async {
    final Response joinResponse = await Get.find<ApiClient>().postData(
      '$meetingBaseUri/join',
      <String, dynamic>{'device_type': 'app'},
    );

    if (!responseIsOk(joinResponse)) {
      throw Exception('join_failed');
    }
  }

  bool responseIsOk(Response response) {
    final dynamic body = response.body;

    return (response.statusCode == 200 || response.statusCode == 201) &&
        body is Map &&
        body['status'] == true;
  }

  void startSignalPolling() {
    signalTimer?.cancel();
    signalTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      readSignals();
    });
    readSignals();
  }

  Future<void> readSignals() async {
    final RTCPeerConnection? connection = peerConnection;
    if (connection == null || isEnding) {
      return;
    }

    try {
      final Response response = await Get.find<ApiClient>().getData(
        '$meetingBaseUri/signals',
      );

      if (!responseIsOk(response)) {
        return;
      }

      final dynamic body = response.body;
      final dynamic dataValue = body['data'];
      final Map<String, dynamic> data = dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : <String, dynamic>{};

      final dynamic signalsValue = data['signals'];
      final List<dynamic> signals =
          signalsValue is List ? signalsValue : <dynamic>[];

      for (final dynamic signalValue in signals) {
        if (signalValue is Map) {
          await handleSignal(Map<String, dynamic>.from(signalValue));
        }
      }
    } catch (_) {
      // Mantém a reunião ativa mesmo se uma leitura pontual falhar.
    }
  }

  Future<void> handleSignal(Map<String, dynamic> signal) async {
    final RTCPeerConnection? connection = peerConnection;
    if (connection == null) {
      return;
    }

    final String signalType = '${signal['signal_type'] ?? ''}';
    final dynamic payloadValue = signal['payload'];
    final Map<String, dynamic> payload = payloadValue is Map
        ? Map<String, dynamic>.from(payloadValue)
        : payloadValue is String
            ? decodePayloadString(payloadValue)
            : <String, dynamic>{};

    if (signalType == 'offer' && !widget.isHost) {
      final String? sdp = payload['sdp']?.toString();
      final String type = payload['type']?.toString() ?? 'offer';

      if (sdp == null || sdp.isEmpty) {
        return;
      }

      await connection.setRemoteDescription(RTCSessionDescription(sdp, type));

      final RTCSessionDescription answer = await connection.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });

      await connection.setLocalDescription(answer);

      await sendSignal(
        signalType: 'answer',
        receiverType: 'seller',
        payload: {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      );

      if (mounted) {
        setState(() {
          statusText = 'Respondendo ao convite de vídeo...';
        });
      }
    } else if (signalType == 'answer' && widget.isHost) {
      final String? sdp = payload['sdp']?.toString();
      final String type = payload['type']?.toString() ?? 'answer';

      if (sdp == null || sdp.isEmpty) {
        return;
      }

      final RTCSessionDescription? currentRemote =
          await connection.getRemoteDescription();

      if (currentRemote == null) {
        await connection.setRemoteDescription(RTCSessionDescription(sdp, type));
      }
    } else if (signalType == 'ice_candidate') {
      final String? candidate = payload['candidate']?.toString();

      if (candidate == null || candidate.isEmpty) {
        return;
      }

      await connection.addCandidate(
        RTCIceCandidate(
          candidate,
          payload['sdpMid']?.toString(),
          int.tryParse('${payload['sdpMLineIndex'] ?? ''}'),
        ),
      );
    }
  }

  Map<String, dynamic> decodePayloadString(String value) {
    try {
      final dynamic decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> sendSignal({
    required String signalType,
    String? receiverType,
    required Map<String, dynamic> payload,
  }) async {
    if (isEnding) {
      return;
    }

    try {
      await Get.find<ApiClient>().postData(
        '$meetingBaseUri/signal',
        <String, dynamic>{
          'signal_type': signalType,
          if (receiverType != null && receiverType.isNotEmpty)
            'receiver_type': receiverType,
          'payload': payload,
        },
      );
    } catch (_) {
      // Não derruba a tela se um ICE candidate falhar.
    }
  }

  Future<void> toggleAudio() async {
    final List<MediaStreamTrack> audioTracks =
        localStream?.getAudioTracks() ?? [];

    for (final MediaStreamTrack track in audioTracks) {
      track.enabled = !isAudioEnabled;
    }

    if (mounted) {
      setState(() {
        isAudioEnabled = !isAudioEnabled;
      });
    }
  }

  Future<void> toggleVideo() async {
    final List<MediaStreamTrack> videoTracks =
        localStream?.getVideoTracks() ?? [];

    for (final MediaStreamTrack track in videoTracks) {
      track.enabled = !isVideoEnabled;
    }

    if (mounted) {
      setState(() {
        isVideoEnabled = !isVideoEnabled;
      });
    }
  }

  Future<void> switchCamera() async {
    final List<MediaStreamTrack> videoTracks =
        localStream?.getVideoTracks() ?? [];

    if (videoTracks.isEmpty) {
      return;
    }

    await Helper.switchCamera(videoTracks.first);

    if (mounted) {
      setState(() {
        isFrontCamera = !isFrontCamera;
      });
    }
  }

  Future<void> endMeeting() async {
    if (isEnding) {
      return;
    }

    setState(() {
      isEnding = true;
      statusText = 'Encerrando Lokally Meeting...';
    });

    signalTimer?.cancel();

    try {
      if (widget.isHost) {
        await Get.find<ApiClient>().postData(
          '$meetingBaseUri/end',
          <String, dynamic>{},
        );
      }
    } catch (_) {
      // Mesmo se o backend falhar, fecha os recursos locais.
    }

    await closeMeetingResources();

    if (mounted) {
      Get.back(result: true);
    }
  }

  Future<void> closeMeetingResources() async {
    signalTimer?.cancel();

    try {
      final List<MediaStreamTrack> tracks = localStream?.getTracks() ?? [];
      for (final MediaStreamTrack track in tracks) {
        await track.stop();
      }

      await localStream?.dispose();
      await remoteStream?.dispose();
      await peerConnection?.close();
      await peerConnection?.dispose();
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    } catch (_) {
      // Evita quebrar ao sair da tela.
    }

    localStream = null;
    remoteStream = null;
    peerConnection = null;
  }

  Future<bool> confirmExit() async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Encerrar Lokally Meeting?',
                  style: textBold.copyWith(color: Colors.black87, fontSize: 17),
                ),
                const SizedBox(height: 9),
                Text(
                  widget.isHost
                      ? 'Ao encerrar, a reunião será finalizada para todos os participantes.'
                      : 'Você sairá da reunião. O prestador poderá continuar com a sala aberta.',
                  textAlign: TextAlign.center,
                  style: textRegular.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        widget.isHost ? 'Encerrar reunião' : 'Sair da reunião',
                        style: textBold.copyWith(
                          color: Colors.white,
                          fontSize: 13.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(false),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      height: 44,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Continuar no Meeting',
                        style: textBold.copyWith(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final bool exit = await confirmExit();
        if (exit) {
          await endMeeting();
        }
      },
      child: SafeArea(
        top: false,
        child: Scaffold(
          backgroundColor: const Color(0xFF101827),
          body: Stack(
            children: [
              Positioned.fill(
                child: hasRemoteVideo
                    ? RTCVideoView(
                        remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : LokallyMeetingWaitingView(
                        title: widget.title,
                        statusText: statusText,
                      ),
              ),
              Positioned(
                right: 18,
                top: MediaQuery.of(context).padding.top + 18,
                child: Container(
                  width: 116,
                  height: 158,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 10),
                        blurRadius: 24,
                        color: Colors.black.withValues(alpha: 0.28),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isVideoEnabled
                      ? RTCVideoView(
                          localRenderer,
                          mirror: isFrontCamera,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Center(
                          child: Icon(
                            Icons.videocam_off_rounded,
                            color: Colors.white.withValues(alpha: 0.78),
                            size: 30,
                          ),
                        ),
                ),
              ),
              Positioned(
                left: 18,
                top: MediaQuery.of(context).padding.top + 18,
                right: 148,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isHost ? 'Prestador' : 'Cliente',
                      style: textMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPreparing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.28),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                        strokeWidth: 2.6,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 18,
                child: LokallyMeetingControls(
                  primaryColor: primaryColor,
                  isAudioEnabled: isAudioEnabled,
                  isVideoEnabled: isVideoEnabled,
                  isEnding: isEnding,
                  onAudioTap: toggleAudio,
                  onVideoTap: toggleVideo,
                  onSwitchCameraTap: switchCamera,
                  onEndTap: () async {
                    final bool exit = await confirmExit();
                    if (exit) {
                      await endMeeting();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LokallyMeetingWaitingView extends StatelessWidget {
  final String title;
  final String statusText;

  const LokallyMeetingWaitingView({
    super.key,
    required this.title,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101827),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textBold.copyWith(color: Colors.white, fontSize: 21),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: textRegular.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13.2,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LokallyMeetingControls extends StatelessWidget {
  final Color primaryColor;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isEnding;
  final VoidCallback onAudioTap;
  final VoidCallback onVideoTap;
  final VoidCallback onSwitchCameraTap;
  final VoidCallback onEndTap;

  const LokallyMeetingControls({
    super.key,
    required this.primaryColor,
    required this.isAudioEnabled,
    required this.isVideoEnabled,
    required this.isEnding,
    required this.onAudioTap,
    required this.onVideoTap,
    required this.onSwitchCameraTap,
    required this.onEndTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LokallyMeetingControlButton(
            icon: isAudioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: isAudioEnabled ? 'Áudio' : 'Mudo',
            onTap: onAudioTap,
          ),
          LokallyMeetingControlButton(
            icon: isVideoEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: isVideoEnabled ? 'Vídeo' : 'Sem vídeo',
            onTap: onVideoTap,
          ),
          LokallyMeetingControlButton(
            icon: Icons.cameraswitch_rounded,
            label: 'Câmera',
            onTap: onSwitchCameraTap,
          ),
          GestureDetector(
            onTap: isEnding ? null : onEndTap,
            child: Container(
              width: 60,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: isEnding
                  ? const Center(
                      child: SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class LokallyMeetingControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const LokallyMeetingControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.17),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 10.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
