import 'package:flutter/material.dart';
import 'src/link_handler.dart';
import 'pnta_flutter_platform_interface.dart';

class _PntaFlutterConfig {
  final String projectId;
  final bool autoHandleLinks;
  final bool showSystemUI;
  final bool registerDevice;
  Map<String, dynamic>? metadata;

  _PntaFlutterConfig({
    required this.projectId,
    required this.autoHandleLinks,
    required this.showSystemUI,
    required this.registerDevice,
    this.metadata,
  });
}

class PntaFlutter {
  static _PntaFlutterConfig? _config;
  static String? _deviceToken;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Setup
  /// Main initialization - handles everything for most apps
  static Future<void> initialize(
    String projectId, {
    Map<String, dynamic>? metadata,
    bool registerDevice = true,
    bool autoHandleLinks = false,
    bool showSystemUI = false,
  }) async {
    if (_config != null) {
      debugPrint('PNTA: Already initialized.');
      return;
    }
    try {
      // Validate project ID
      if (!projectId.startsWith('prj_')) {
        debugPrint('PNTA: Invalid project ID. Must start with "prj_".');
        return;
      }
      _config = _PntaFlutterConfig(
        projectId: projectId,
        autoHandleLinks: autoHandleLinks,
        showSystemUI: showSystemUI,
        registerDevice: registerDevice,
        metadata: metadata,
      );
      LinkHandler.initialize(autoHandleLinks: autoHandleLinks);
      await PntaFlutterPlatform.instance
          .setForegroundPresentationOptions(showSystemUI: showSystemUI);

      // Always check if permissions are already granted
      final permissionsGranted =
          await PntaFlutterPlatform.instance.checkNotificationPermission();

      if (permissionsGranted) {
        // Always register if permissions available, regardless of registerDevice flag
        await _performRegistration(metadata: metadata, skipPrompt: true);
      } else if (registerDevice) {
        // Only prompt for permissions if registerDevice: true
        await _performRegistration(metadata: metadata);
      }
    } catch (e, st) {
      debugPrint('PNTA: Initialization error: $e\n$st');
    }
  }

  // Registration
  /// For delayed registration scenarios - prompts for permissions and registers if granted
  static Future<void> registerDevice() async {
    if (_config == null) {
      debugPrint('PNTA: Must call initialize() before registering device.');
      return;
    }
    await _performRegistration(metadata: _config!.metadata);
  }

  /// Update device metadata
  static Future<void> updateMetadata(Map<String, dynamic> metadata) async {
    if (_config == null) {
      debugPrint('PNTA: Must call initialize() before updating metadata.');
      return;
    }
    try {
      await PntaFlutterPlatform.instance
          .updateMetadata(_config!.projectId, metadata);
      _config!.metadata = metadata;
    } catch (e, st) {
      debugPrint('PNTA: updateMetadata error: $e\n$st');
    }
  }

  // Notifications
  /// Stream of notifications received while app is in foreground
  static Stream<Map<String, dynamic>> get foregroundNotifications =>
      PntaFlutterPlatform.instance.foregroundNotifications;

  /// Stream of notification taps
  static Stream<Map<String, dynamic>> get onNotificationTap =>
      PntaFlutterPlatform.instance.onNotificationTap.asyncMap((payload) async {
        if (_config?.autoHandleLinks == true) {
          await handleLink(payload['link_to'] as String?);
        }
        return payload;
      });

  // Utilities
  /// Manually handle a deep link
  static Future<bool> handleLink(String? link) async {
    return await LinkHandler.handleLink(link);
  }

  // Getters
  static String? get projectId => _config?.projectId;
  static bool get autoHandleLinks => _config?.autoHandleLinks ?? false;
  static bool get showSystemUI => _config?.showSystemUI ?? false;
  static Map<String, dynamic>? get currentMetadata => _config?.metadata;
  static String? get deviceToken => _deviceToken;

  // Private
  static Future<void> _performRegistration({
    Map<String, dynamic>? metadata,
    bool skipPrompt = false,
  }) async {
    try {
      final granted = skipPrompt
          ? await PntaFlutterPlatform.instance.checkNotificationPermission()
          : await PntaFlutterPlatform.instance.requestNotificationPermission();

      if (!granted) {
        debugPrint('PNTA: Notification permission denied.');
        return;
      }

      // Pure device registration with SDK version
      _deviceToken =
          await PntaFlutterPlatform.instance.identify(_config!.projectId);

      // Update metadata if provided
      if (metadata != null && metadata.isNotEmpty) {
        await PntaFlutterPlatform.instance
            .updateMetadata(_config!.projectId, metadata);
        _config!.metadata = metadata;
      }
    } catch (e, st) {
      debugPrint('PNTA: Registration error: $e\n$st');
    }
  }
}
