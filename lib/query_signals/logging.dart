import 'dart:io';

import 'package:logger/logger.dart';

/// Logging levels for query_signals package
enum QuerySignalsLogLevel {
  /// No logging at all
  none,

  /// Only errors and warnings
  error,

  /// Errors, warnings, and important info messages
  warn,

  /// All info messages (default)
  info,

  /// Debug messages for development
  debug,

  /// Verbose logging including internal state changes
  verbose,
}

class QuerySignalsLogger {
  static final QuerySignalsLogger _instance = QuerySignalsLogger._internal();
  static QuerySignalsLogger get instance => _instance;

  late final Logger _logger;
  QuerySignalsLogLevel _globalLogLevel = QuerySignalsLogLevel.info;

  QuerySignalsLogger._internal() {
    _logger = Logger(
      printer: _QuerySignalsPrinter(),
      filter: _QuerySignalsFilter(),
      output: _AnsiAwareOutput(),
    );
  }

  void setGlobalLogLevel(QuerySignalsLogLevel level) {
    _globalLogLevel = level;
  }

  QuerySignalsLogLevel get globalLogLevel => _globalLogLevel;

  /// Check if a specific log level is enabled globally
  bool isLogLevelEnabled(QuerySignalsLogLevel level) {
    return level.index <= _globalLogLevel.index;
  }

  /// Debug level logging
  void debug(
    String message, {
    dynamic key,
    QuerySignalsLogLevel? level,
    Map<String, dynamic>? metadata,
  }) {
    _logMessage(
      message,
      QuerySignalsLogLevel.debug,
      key: key,
      queryLogLevel: level,
      metadata: metadata,
    );
  }

  /// Info level logging
  void info(
    String message, {
    dynamic key,
    QuerySignalsLogLevel? level,
    Map<String, dynamic>? metadata,
  }) {
    _logMessage(
      message,
      QuerySignalsLogLevel.info,
      key: key,
      queryLogLevel: level,
      metadata: metadata,
    );
  }

  /// Warning level logging
  void warn(
    String message, {
    dynamic key,
    QuerySignalsLogLevel? level,
    Map<String, dynamic>? metadata,
  }) {
    _logMessage(
      message,
      QuerySignalsLogLevel.warn,
      key: key,
      queryLogLevel: level,
      metadata: metadata,
    );
  }

  /// Error level logging
  void error(
    String message, {
    dynamic key,
    QuerySignalsLogLevel? level,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _logMessage(
      message,
      QuerySignalsLogLevel.error,
      key: key,
      queryLogLevel: level,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Verbose level logging
  void verbose(
    String message, {
    dynamic key,
    QuerySignalsLogLevel? level,
    Map<String, dynamic>? metadata,
  }) {
    _logMessage(
      message,
      QuerySignalsLogLevel.verbose,
      key: key,
      queryLogLevel: level,
      metadata: metadata,
    );
  }

  /// Internal method to handle all logging logic
  void _logMessage(
    String message,
    QuerySignalsLogLevel level, {
    dynamic key,
    QuerySignalsLogLevel? queryLogLevel,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final effectiveLevel = queryLogLevel ?? _globalLogLevel;

    // Skip logging if globally disabled or level is below threshold
    if (effectiveLevel == QuerySignalsLogLevel.none ||
        level.index > effectiveLevel.index) {
      return;
    }

    final emoji = _getEmojiForLevel(level);
    final keyStr = key != null ? '${_formatKey(key)} ... ' : '';
    final metadataStr = metadata != null && metadata.isNotEmpty
        ? ' - ${metadata.entries.map((e) => '${e.key}: ${e.value}').join(', ')}'
        : '';
    final fullMessage = '$emoji $keyStr$message$metadataStr';

    switch (level) {
      case QuerySignalsLogLevel.error:
        if (error != null) {
          _logger.e(fullMessage, error: error, stackTrace: stackTrace);
        } else {
          _logger.e(fullMessage);
        }
        break;
      case QuerySignalsLogLevel.warn:
        _logger.w(fullMessage);
        break;
      case QuerySignalsLogLevel.info:
        _logger.i(fullMessage);
        break;
      case QuerySignalsLogLevel.debug:
        _logger.d(fullMessage);
        break;
      case QuerySignalsLogLevel.verbose:
        _logger.t(fullMessage); // 'trace' level for verbose
        break;
      case QuerySignalsLogLevel.none:
        // Do nothing
        break;
    }
  }

  /// Format key to string - handles QueryKey objects and strings
  String _formatKey(dynamic key) {
    if (key is String) return key;
    return key.toString();
  }

  String _getEmojiForLevel(QuerySignalsLogLevel level) {
    switch (level) {
      case QuerySignalsLogLevel.error:
        return '🔴';
      case QuerySignalsLogLevel.warn:
        return '🟡';
      case QuerySignalsLogLevel.info:
        return '🔵';
      case QuerySignalsLogLevel.debug:
        return '⚪';
      case QuerySignalsLogLevel.verbose:
        return '⚫';
      case QuerySignalsLogLevel.none:
        return '';
    }
  }
}

/// Custom printer for clean, readable query_signals logs
class _QuerySignalsPrinter extends PrettyPrinter {
  _QuerySignalsPrinter()
      : super(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 120,
          colors: true,
          printEmojis: false, // We add our own emojis
          dateTimeFormat: DateTimeFormat.none,
          noBoxingByDefault: true,
        );
}

/// Filter that respects our log levels
class _QuerySignalsFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Let the QuerySignalsLogger handle filtering
    return true;
  }
}

/// Output that handles ANSI codes properly
class _AnsiAwareOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Check if stdout supports ANSI colors
    final supportsAnsi = stdout.supportsAnsiEscapes;

    for (var line in event.lines) {
      if (supportsAnsi) {
        print(line);
      } else {
        // Strip ANSI codes for terminals that don't support them
        print(_stripAnsiCodes(line));
      }
    }
  }

  String _stripAnsiCodes(String text) {
    // Simple regex to strip ANSI escape sequences
    return text.replaceAll(RegExp(r'\x1B\[[0-9;]*[mG]'), '');
  }
}

/// Global logger instance for easy access
final querySignalsLogger = QuerySignalsLogger.instance;

/// Query-specific logger that automatically applies the query's log level
class QueryLogger {
  final QuerySignalsLogger _baseLogger;
  final QuerySignalsLogLevel? _queryLogLevel;

  QueryLogger(this._baseLogger, this._queryLogLevel);

  void debug(String message, {dynamic key, Map<String, dynamic>? metadata}) {
    _baseLogger._logMessage(
      message,
      QuerySignalsLogLevel.debug,
      key: key,
      queryLogLevel: _queryLogLevel,
      metadata: metadata,
    );
  }

  void info(String message, {dynamic key, Map<String, dynamic>? metadata}) {
    _baseLogger._logMessage(
      message,
      QuerySignalsLogLevel.info,
      key: key,
      queryLogLevel: _queryLogLevel,
      metadata: metadata,
    );
  }

  void warn(String message, {dynamic key, Map<String, dynamic>? metadata}) {
    _baseLogger._logMessage(
      message,
      QuerySignalsLogLevel.warn,
      key: key,
      queryLogLevel: _queryLogLevel,
      metadata: metadata,
    );
  }

  void error(String message,
      {dynamic key,
      Object? error,
      StackTrace? stackTrace,
      Map<String, dynamic>? metadata}) {
    _baseLogger._logMessage(
      message,
      QuerySignalsLogLevel.error,
      key: key,
      queryLogLevel: _queryLogLevel,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  void verbose(String message, {dynamic key, Map<String, dynamic>? metadata}) {
    _baseLogger._logMessage(
      message,
      QuerySignalsLogLevel.verbose,
      key: key,
      queryLogLevel: _queryLogLevel,
      metadata: metadata,
    );
  }
}
