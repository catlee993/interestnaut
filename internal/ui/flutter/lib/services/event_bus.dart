import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'ffi_init.dart';

/// EventBus provides a socket-based event system for receiving events from Go
class EventBus {
  static final EventBus _instance = EventBus._internal();
  static bool _isInitialized = false;
  
  // Eagerly initialize function pointers to prevent race conditions
  static int Function()? _initEventBus;
  static void Function()? _shutdownEventBus;
  
  factory EventBus() => _instance;
  
  EventBus._internal();
  
  Socket? _socket;
  final StreamController<Map<String, dynamic>> _controller = 
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>>? _events;
  int? _port;
  
  /// Initialize the event bus with the Go backend
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check if FFI is initialized
      if (!FFIInitializer.isInitialized) {
        throw Exception('FFI library not initialized');
      }
      
      // Get the FFI library directly using the getter
      final dll = FFIInitializer.dylib;
      
      // Look up the functions eagerly to avoid race conditions
      _initEventBus = dll.lookupFunction<Int32 Function(), int Function()>(
        'EventBus_Init'
      );
      
      _shutdownEventBus = dll.lookupFunction<Void Function(), void Function()>(
        'EventBus_Shutdown'
      );
      
      // Initialize the event bus without using compute - it causes problems with FFI
      int port;
      if (_initEventBus == null) {
        debugPrint('ERROR: _initEventBus is null');
        port = -1;
      } else {
        try {
          port = _initEventBus!();
        } catch (e) {
          debugPrint('Error initializing event bus: $e');
          port = -1;
        }
      }
      
      if (port <= 0) {
        throw Exception('Failed to initialize event bus, port: $port');
      }
      
      debugPrint('Event bus initialized on port $port');
      await _instance._connect(port);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize event bus: $e');
      // Don't rethrow - we want the app to continue even if event bus fails
    }
  }
  
  /// Connect to the event bus server
  Future<void> _connect(int port) async {
    if (_socket != null) {
      try {
        _socket!.close();
      } catch (e) {
        // Ignore errors when closing
      }
      _socket = null;
    }
    
    _port = port;
    
    try {
      _socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 5));
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      
      // Get the socket stream and transform it properly
      final socketStream = _socket!;
      
      _events = socketStream
          .cast<List<int>>() // Ensure we have the right type
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) {
            try {
              final decoded = jsonDecode(line) as Map<String, dynamic>;
              debugPrint('Received event: ${decoded['type']}');
              return decoded;
            } catch (e) {
              debugPrint('Error decoding JSON: $e, line: $line');
              return <String, dynamic>{'type': 'error', 'payload': {'error': e.toString()}};
            }
          }).asBroadcastStream();
      
      // Forward events to the controller
      _events!.listen(
        (event) => _controller.add(event),
        onError: (error) {
          debugPrint('Error from event stream: $error');
          _controller.addError(error);
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('Event stream closed');
          _scheduleReconnect();
        }
      );
      
      debugPrint('Connected to event bus on port $port');
    } catch (e) {
      debugPrint('Error connecting to event bus: $e');
      _scheduleReconnect();
    }
  }
  
  /// Schedule a reconnection attempt
  void _scheduleReconnect() {
    if (_port == null) return;
    
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isInitialized) return;
      _connect(_port!);
    });
  }
  
  /// Get all events from the event bus
  Stream<Map<String, dynamic>> get events => _controller.stream;
  
  /// Get only auth status events
  Stream<Map<String, dynamic>> get authEvents => 
      events.where((event) => 
          event['type'] == 'spotify_auth_status_changed')
          .map((event) {
            final payload = event['payload'] as Map<String, dynamic>? ?? {};
            debugPrint('Auth event payload: $payload');
            return payload;
          });
  
  /// Check if the event bus is connected
  bool get isConnected => _socket != null;
  
  /// Shutdown the event bus
  static Future<void> shutdown() async {
    if (!_isInitialized) return;
    
    try {
      if (_instance._socket != null) {
        await _instance._socket!.close();
        _instance._socket = null;
      }
      
      if (_shutdownEventBus != null) {
        _shutdownEventBus!();
      }
      
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error shutting down event bus: $e');
    }
  }
}
