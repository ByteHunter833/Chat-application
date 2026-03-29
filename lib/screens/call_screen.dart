import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import '../providers/app_providers.dart';

class CallPage extends ConsumerWidget {
  const CallPage({super.key, required this.callID});

  final String callID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ZegoUIKitPrebuiltCall(
      appID: 1138717761,
      appSign:
          '4364cdd8f3ffdccdc1e7877a83d9fe4700e3e4e63784b9a9a6b9e5f6cc136ddb',
      userID: currentUser.id,
      userName: currentUser.username,
      callID: callID,
      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
    );
  }
}
