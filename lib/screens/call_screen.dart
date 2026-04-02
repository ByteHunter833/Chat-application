import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import '../providers/app_providers.dart';
import '../utils/call_invitation_service.dart';

class CallPage extends ConsumerWidget {
  const CallPage({super.key, required this.callID, this.isVideoCall = true});

  final String callID;
  final bool isVideoCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ZegoUIKitPrebuiltCall(
      appID: zegoAppId,
      appSign: zegoAppSign,
      userID: currentUser.id,
      userName: currentUser.username,
      callID: callID,
      config: (() {
        final config = isVideoCall
            ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
        config.turnOnCameraWhenJoining = isVideoCall;
        config.turnOnMicrophoneWhenJoining = true;
        config.useSpeakerWhenJoining = true;
        config.audioVideoView.showCameraStateOnView = true;
        config.audioVideoView.showUserNameOnView = true;
        config.audioVideoView.useVideoViewAspectFill = true;
        return config;
      })(),
    );
  }
}
