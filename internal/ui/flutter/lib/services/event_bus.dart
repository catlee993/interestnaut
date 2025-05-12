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
  static bool _isConnecting = false;
  
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
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  bool _shutdown = false;

  /// Initialize the event bus with the Go backend
  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isConnecting) return;

    _isConnecting = true;
    
    try {
      // Check if FFI is initialized
      if (!FFIInitializer.isInitialized) {
        _isConnecting = false;
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
      
      // Initialize the event bus
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
        _isConnecting = false;
        throw Exception('Failed to initialize event bus, port: $port');
      }
      
      debugPrint('Event bus initialized on port $port');
      await _instance._connect(port);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize event bus: $e');
      // Schedule a retry
      _instance._scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }
  
  /// Connect to the event bus server
  Future<void> _connect(int port) async {
    // Cancel any pending reconnections
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
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
          if (!_shutdown) {
            _scheduleReconnect();
          }
        },
        onDone: () {
          debugPrint('Event stream closed');
          if (!_shutdown) {
            _scheduleReconnect();
          }
        }
      );
      
      // Reset reconnect attempts on successful connection
      _reconnectAttempts = 0;
      
      debugPrint('Connected to event bus on port $port');
    } catch (e) {
      debugPrint('Error connecting to event bus: $e');
      if (!_shutdown) {
        _scheduleReconnect();
      }
    }
  }
  
  /// Schedule a reconnection attempt with exponential backoff
  void _scheduleReconnect() {
    if (_shutdown || _reconnectTimer != null) return;
    
    _reconnectAttempts++;
    
    // Calculate backoff delay (exponential with jitter)
    final backoffMillis = _initialReconnectDelay.inMilliseconds * 
        (1 << (_reconnectAttempts.clamp(0, 5)));
    final jitter = (backoffMillis * 0.2 * (0.5 - (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0)).toInt();
    final delay = Duration(milliseconds: backoffMillis + jitter);
    
    debugPrint('Scheduling event bus reconnect attempt #$_reconnectAttempts in ${delay.inMilliseconds}ms');
    
    if (_reconnectAttempts <= _maxReconnectAttempts) {
      _reconnectTimer = Timer(delay, () {
        _reconnectTimer = null;
        if (!_shutdown) {
          debugPrint('Attempting to reconnect to event bus...');
          initialize();
        }
      });
    } else {
      debugPrint('Maximum reconnect attempts reached, giving up');
      // After max attempts, wait longer before trying again
      _reconnectTimer = Timer(Duration(seconds: 30), () {
        _reconnectTimer = null;
        _reconnectAttempts = 0; // Reset counter for fresh attempts
        if (!_shutdown) {
          debugPrint('Retrying event bus connection after cooldown');
          initialize();
        }
      });
    }
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
    
    _instance._shutdown = true;
    
    try {
      // Cancel any pending reconnect attempts
      _instance._reconnectTimer?.cancel();
      _instance._reconnectTimer = null;
      
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
    } finally {
      _instance._shutdown = false;
    }
  }
}
