import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../models/models.dart';
import 'app_navigator.dart';
import 'push_notification_service.dart';

const int zegoAppId = 1138717761;
const String zegoAppSign =
    '4364cdd8f3ffdccdc1e7877a83d9fe4700e3e4e63784b9a9a6b9e5f6cc136ddb';

class CallInvitationService {
  CallInvitationService._();

  static String? _initializedForUserId;
  static final Map<String, _TrackedCall> _trackedCalls =
      <String, _TrackedCall>{};
  static CallStatusReporter? _onCallStatusChanged;
  static String? _lastOutgoingCallId;

  static void registerNavigator() {
    ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(appNavigatorKey);
  }

  static Future<void> ensureInitialized(
    User user, {
    CallStatusReporter? onCallStatusChanged,
  }) async {
    final service = ZegoUIKitPrebuiltCallInvitationService();
    _onCallStatusChanged = onCallStatusChanged;
    if (_initializedForUserId == user.id && service.isInit) {
      return;
    }

    if (service.isInit) {
      await service.uninit();
    }

    await service.init(
      appID: zegoAppId,
      appSign: zegoAppSign,
      userID: user.id,
      userName: user.name,
      plugins: [ZegoUIKitSignalingPlugin()],
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (event, defaultAction) {
          _trackedCalls.remove(event.callID);
          if (_lastOutgoingCallId == event.callID) {
            _lastOutgoingCallId = null;
          }
          defaultAction.call();
        },
      ),
      invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
        onOutgoingCallSent: (callID, caller, callType, callees, customData) {
          _lastOutgoingCallId = callID;
          _trackCall(
            callID: callID,
            isVideoCall: callType == ZegoCallInvitationType.videoCall,
            customData: customData,
          );
          unawaited(
            _reportCallStatus(callID: callID, status: _CallStatus.outgoing),
          );
        },
        onOutgoingCallAccepted: (callID, callee) {
          unawaited(
            _reportCallStatus(callID: callID, status: _CallStatus.ongoing),
          );
        },
        onOutgoingCallDeclined: (callID, callee, customData) {
          unawaited(
            _reportCallStatus(callID: callID, status: _CallStatus.cancelled),
          );
        },
        onOutgoingCallRejectedCauseBusy: (callID, callee, customData) {
          unawaited(
            _reportCallStatus(callID: callID, status: _CallStatus.cancelled),
          );
        },
        onOutgoingCallTimeout: (callID, callees, isVideoCall) {
          unawaited(
            _reportCallStatus(callID: callID, status: _CallStatus.cancelled),
          );
        },
        onOutgoingCallCancelButtonPressed: () {
          final callID = _lastOutgoingCallId;
          if (callID == null) {
            return;
          }

          unawaited(
            _reportCallStatus(callID: callID, status: _CallStatus.cancelled),
          );
        },
      ),
      requireConfig: (invitationData) {
        final isVideoCall =
            invitationData.type == ZegoCallInvitationType.videoCall;
        final config = invitationData.type == ZegoCallInvitationType.videoCall
            ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

        config.turnOnCameraWhenJoining = isVideoCall;
        config.turnOnMicrophoneWhenJoining = true;
        config.useSpeakerWhenJoining = true;
        config.audioVideoView.showCameraStateOnView = true;
        config.audioVideoView.showUserNameOnView = true;
        config.audioVideoView.useVideoViewAspectFill = true;

        config.avatarBuilder = (context, size, user, extraInfo) {
          return Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x332563EB),
            ),
            alignment: Alignment.center,
            child: Text(
              _buildInitials(user?.name ?? 'U'),
              style: TextStyle(
                color: Colors.white,
                fontSize: size.width * 0.26,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        };

        return config;
      },
    );

    _initializedForUserId = user.id;
  }

  static Future<void> uninitialize() async {
    _initializedForUserId = null;
    _trackedCalls.clear();
    _lastOutgoingCallId = null;
    _onCallStatusChanged = null;
    await ZegoUIKitPrebuiltCallInvitationService().uninit();
  }

  static Future<bool> startCall({
    required User currentUser,
    required User targetUser,
    required String chatId,
    required bool isVideoCall,
    String? callID,
  }) async {
    final resolvedCallID =
        callID ?? '${chatId}_${DateTime.now().millisecondsSinceEpoch}';
    final customData = jsonEncode({
      'chatId': chatId,
      'isVideoCall': isVideoCall,
    });

    _trackedCalls[resolvedCallID] = _TrackedCall(
      chatId: chatId,
      isVideoCall: isVideoCall,
    );
    _lastOutgoingCallId = resolvedCallID;

    final didSend = await ZegoUIKitPrebuiltCallInvitationService().send(
      invitees: [ZegoCallUser(targetUser.id, targetUser.name)],
      isVideoCall: isVideoCall,
      customData: customData,
      callID: resolvedCallID,
      notificationTitle: isVideoCall ? 'Incoming video call' : 'Incoming call',
      notificationMessage: isVideoCall
          ? 'Tap to join the video call'
          : 'Tap to join the voice call',
    );

    if (!didSend) {
      _trackedCalls.remove(resolvedCallID);
      if (_lastOutgoingCallId == resolvedCallID) {
        _lastOutgoingCallId = null;
      }
    } else {
      unawaited(
        PushNotificationService.createCallInvitation(
          callerId: currentUser.id,
          callerName: currentUser.name,
          calleeId: targetUser.id,
          chatId: chatId,
          callId: resolvedCallID,
          isVideoCall: isVideoCall,
        ),
      );
    }

    return didSend;
  }

  static void disposeLater() {
    unawaited(uninitialize());
  }

  static String _buildInitials(String name) {
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty);
    if (parts.length >= 2) {
      final list = parts.toList();
      return '${list.first[0]}${list[1][0]}'.toUpperCase();
    }

    if (parts.isEmpty) {
      return 'U';
    }

    return parts.first.substring(0, 1).toUpperCase();
  }

  static void _trackCall({
    required String callID,
    required bool isVideoCall,
    String? customData,
  }) {
    if (_trackedCalls.containsKey(callID)) {
      return;
    }

    final parsedData = _parseCustomData(customData);
    final chatId = parsedData['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) {
      return;
    }

    _trackedCalls[callID] = _TrackedCall(
      chatId: chatId,
      isVideoCall: parsedData['isVideoCall'] as bool? ?? isVideoCall,
    );
  }

  static Future<void> _reportCallStatus({
    required String callID,
    required _CallStatus status,
  }) async {
    final trackedCall = _trackedCalls[callID];
    final callback = _onCallStatusChanged;
    if (trackedCall == null || callback == null) {
      return;
    }

    await callback(
      CallStatusMessage(
        chatId: trackedCall.chatId,
        messageId: 'call_${callID}_${status.name}',
        text: _buildStatusText(
          status: status,
          isVideoCall: trackedCall.isVideoCall,
        ),
      ),
    );

    if (status != _CallStatus.outgoing) {
      _trackedCalls.remove(callID);
      if (_lastOutgoingCallId == callID) {
        _lastOutgoingCallId = null;
      }
    }
  }

  static Map<String, dynamic> _parseCustomData(String? customData) {
    if (customData == null || customData.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      return Map<String, dynamic>.from(
        jsonDecode(customData) as Map<String, dynamic>,
      );
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  static String _buildStatusText({
    required _CallStatus status,
    required bool isVideoCall,
  }) {
    final callLabel = isVideoCall ? 'video call' : 'call';
    switch (status) {
      case _CallStatus.outgoing:
        return 'Outgoing $callLabel';
      case _CallStatus.ongoing:
        return 'Ongoing $callLabel';
      case _CallStatus.cancelled:
        return 'Cancelled $callLabel';
    }
  }
}

typedef CallStatusReporter = Future<void> Function(CallStatusMessage message);

class CallStatusMessage {
  const CallStatusMessage({
    required this.chatId,
    required this.messageId,
    required this.text,
  });

  final String chatId;
  final String messageId;
  final String text;
}

class _TrackedCall {
  const _TrackedCall({required this.chatId, required this.isVideoCall});

  final String chatId;
  final bool isVideoCall;
}

enum _CallStatus { outgoing, ongoing, cancelled }
