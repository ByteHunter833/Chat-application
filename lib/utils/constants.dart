// Duration constants
import 'package:flutter/material.dart';

const Duration shortDuration = Duration(milliseconds: 150);
const Duration mediumDuration = Duration(milliseconds: 300);
const Duration longDuration = Duration(milliseconds: 500);

// Material design curve (not const, can't use Cubic as const)
final animationCurve = Curves.easeInOutCubic;

// Debounce constants
const int searchDebounceMs = 300;
const int autoSaveDebounceMs = 500;

// Message constants
const int maxMessageLength = 5000;
const int maxImages = 10;

// Pagination
const int pageSize = 20;
const int initialMessages = 50;

// Retry constants
const int maxRetries = 3;
const Duration retryDelay = Duration(seconds: 2);
