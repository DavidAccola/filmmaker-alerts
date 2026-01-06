import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DebugLogger {
  static DebugLogger? _instance;
  static DebugLogger get instance => _instance ??= DebugLogger._();
  
  DebugLogger._();
  
  File? _logFile;
  static const int maxLogLines = 200; // Keep logs manageable for context
  static const String logFileName = 'tv_notification_debug.log';
  
  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$logFileName');
      
      // Clear old logs on init to start fresh
      if (await _logFile!.exists()) {
        await _logFile!.delete();
      }
      
      await _logFile!.create();
      await _writeToFile('=== TV Notification Debug Session Started ===');
      await _writeToFile('Timestamp: ${DateTime.now().toIso8601String()}');
      await _writeToFile('');
    } catch (e) {
      debugPrint('[DebugLogger] Failed to initialize: $e');
    }
  }
  
  Future<void> log(String component, String message) async {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19); // HH:MM:SS
    final logLine = '[$timestamp][$component] $message';
    
    // Always print to debug console
    debugPrint(logLine);
    
    // Also write to file
    await _writeToFile(logLine);
  }
  
  Future<void> _writeToFile(String line) async {
    if (_logFile == null) return;
    
    try {
      await _logFile!.writeAsString('$line\n', mode: FileMode.append);
      
      // Keep file size manageable by truncating if too long
      await _truncateIfNeeded();
    } catch (e) {
      debugPrint('[DebugLogger] Failed to write to file: $e');
    }
  }
  
  Future<void> _truncateIfNeeded() async {
    if (_logFile == null) return;
    
    try {
      final lines = await _logFile!.readAsLines();
      if (lines.length > maxLogLines) {
        // Keep the header and last maxLogLines-10 lines
        final header = lines.take(3).toList(); // Session start info
        final recentLines = lines.skip(lines.length - (maxLogLines - 10)).toList();
        
        final truncatedContent = [
          ...header,
          '... [truncated ${lines.length - maxLogLines} older lines] ...',
          '',
          ...recentLines,
        ].join('\n');
        
        await _logFile!.writeAsString(truncatedContent);
      }
    } catch (e) {
      debugPrint('[DebugLogger] Failed to truncate file: $e');
    }
  }
  
  Future<String> getLogPath() async {
    if (_logFile == null) {
      await init();
    }
    return _logFile?.path ?? 'Log file not available';
  }
  
  Future<String> getLogContent() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return 'No log file available';
    }
    
    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }
  
  // Convenience methods for different components
  Future<void> logHistory(String message) => log('HistoryScreen', message);
  Future<void> logNotification(String message) => log('NotificationService', message);
  Future<void> logBackground(String message) => log('BackgroundService', message);
  Future<void> logGeneral(String message) => log('General', message);
}