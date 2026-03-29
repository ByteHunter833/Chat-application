import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MessageInputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;

  final bool isLoading;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,

    this.isLoading = false,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  bool _hasText = false;
  late final FocusNode _focusNode;
  bool _isEmojiPickerVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    widget.controller.addListener(_updateHasText);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateHasText);
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessageInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateHasText);
      widget.controller.addListener(_updateHasText);
      _hasText = widget.controller.text.isNotEmpty;
    }
  }

  void _updateHasText() {
    final hasText = widget.controller.text.isNotEmpty;
    if (_hasText == hasText) {
      return;
    }

    setState(() {
      _hasText = hasText;
    });
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus && _isEmojiPickerVisible) {
      setState(() {
        _isEmojiPickerVisible = false;
      });
    }
  }

  void _toggleEmojiPicker() {
    if (widget.isLoading) {
      return;
    }

    if (_isEmojiPickerVisible) {
      setState(() {
        _isEmojiPickerVisible = false;
      });
      _focusNode.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isEmojiPickerVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: widget.isLoading ? null : widget.onAttach,
                color: AppTheme.primary,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkTertiary
                        : AppTheme.lightTertiary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          minLines: 1,
                          enabled: !widget.isLoading,
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            hintStyle: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isEmojiPickerVisible
                              ? Icons.keyboard_outlined
                              : Icons.emoji_emotions_outlined,
                        ),
                        onPressed: _toggleEmojiPicker,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              GestureDetector(
                onTap: widget.isLoading || !_hasText ? null : widget.onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasText && !widget.isLoading
                        ? AppTheme.primary
                        : (isDark
                              ? AppTheme.darkTertiary
                              : AppTheme.lightTertiary),
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: _hasText
                                ? Colors.white
                                : (isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary),
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _isEmojiPickerVisible
                ? Padding(
                    key: const ValueKey('emoji-picker'),
                    padding: const EdgeInsets.only(top: AppTheme.spacingMd),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: EmojiPick(
                        textEditingController: widget.controller,
                        isDark: isDark,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('emoji-picker-hidden')),
          ),
        ],
      ),
    );
  }
}

class EmojiPick extends StatefulWidget {
  final TextEditingController? textEditingController;
  final bool isDark;

  const EmojiPick({
    super.key,
    this.textEditingController,
    required this.isDark,
  });

  @override
  State<EmojiPick> createState() => _EmojiPickState();
}

class _EmojiPickState extends State<EmojiPick> {
  @override
  Widget build(BuildContext context) {
    return EmojiPicker(
      textEditingController: widget.textEditingController,
      config: Config(
        height: 320,
        checkPlatformCompatibility: true,
        emojiViewConfig: EmojiViewConfig(
          emojiSizeMax:
              28 *
              (foundation.defaultTargetPlatform == TargetPlatform.iOS
                  ? 1.20
                  : 1.0),
          backgroundColor: widget.isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
        ),
        viewOrderConfig: const ViewOrderConfig(
          top: EmojiPickerItem.categoryBar,
          middle: EmojiPickerItem.emojiView,
          bottom: EmojiPickerItem.searchBar,
        ),
        skinToneConfig: const SkinToneConfig(),
        categoryViewConfig: CategoryViewConfig(
          backgroundColor: widget.isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          indicatorColor: AppTheme.primary,
          iconColorSelected: AppTheme.primary,
          iconColor: widget.isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
        bottomActionBarConfig: BottomActionBarConfig(
          backgroundColor: widget.isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          buttonColor: AppTheme.primary,
          buttonIconColor: Colors.white,
        ),
        searchViewConfig: SearchViewConfig(
          backgroundColor: widget.isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          buttonIconColor: widget.isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
          hintText: 'Search emoji',
          hintTextStyle: TextStyle(
            color: widget.isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
          inputTextStyle: TextStyle(
            color: widget.isDark
                ? AppTheme.darkTextPrimary
                : AppTheme.lightTextPrimary,
          ),
        ),
      ),
    );
  }
}
