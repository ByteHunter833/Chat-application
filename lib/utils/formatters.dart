import 'package:intl/intl.dart';

class Formatters {
  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat('EEE').format(dateTime);
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  static String formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM').format(dateTime);
    }
  }

  static String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final presenceDate = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
    final time = DateFormat('HH:mm').format(lastSeen);

    if (presenceDate == today) {
      return 'last seen at $time';
    } else if (presenceDate == yesterday) {
      return 'last seen yesterday at $time';
    } else if (lastSeen.year == now.year) {
      return 'last seen ${DateFormat('d MMM').format(lastSeen)} at $time';
    } else {
      return 'last seen ${DateFormat('dd/MM/yy').format(lastSeen)} at $time';
    }
  }

  static String formatPresenceStatus({
    required bool isOnline,
    DateTime? lastSeen,
  }) {
    if (isOnline) {
      return 'Online';
    }

    return formatLastSeen(lastSeen);
  }

  static String formatMessagePreview(String message, {int maxLength = 50}) {
    if (message.isEmpty) return '...';
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  static String formatAttachmentSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '';
    }

    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final precision = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
  }
}
