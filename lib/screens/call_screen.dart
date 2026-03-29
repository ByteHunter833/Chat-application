import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CallScreen extends StatefulWidget {
  final String userName;
  final String userAvatar;

  const CallScreen({
    super.key,
    required this.userName,
    required this.userAvatar,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isVideoOn = true;
  bool _isSpeakerOn = false;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    _startCallTimer();
  }

  void _startCallTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _callDuration++);
        _startCallTimer();
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.darkSurface, AppTheme.darkBg],
              ),
            ),
          ),
          // User Info
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Avatar
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(widget.userAvatar),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(color: AppTheme.primary, width: 3),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXl),
                // Name
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Duration
                Text(
                  _formatDuration(_callDuration),
                  style: const TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCallButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        active: !_isMuted,
                        onPressed: () {
                          setState(() => _isMuted = !_isMuted);
                        },
                      ),
                      const SizedBox(width: AppTheme.spacingXl),
                      _buildCallButton(
                        icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                        active: _isVideoOn,
                        onPressed: () {
                          setState(() => _isVideoOn = !_isVideoOn);
                        },
                      ),
                      const SizedBox(width: AppTheme.spacingXl),
                      _buildCallButton(
                        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        active: _isSpeakerOn,
                        onPressed: () {
                          setState(() => _isSpeakerOn = !_isSpeakerOn);
                        },
                      ),
                    ],
                  ),
                ),
                // End Call Button
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.error,
                  ),
                  child: Material(
                    shape: const CircleBorder(),
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppTheme.darkTertiary : AppTheme.darkSurface,
        border: Border.all(
          color: active ? AppTheme.primary : AppTheme.darkBorder,
          width: 2,
        ),
      ),
      child: Material(
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(
            icon,
            color: active ? AppTheme.primary : AppTheme.darkTextSecondary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
