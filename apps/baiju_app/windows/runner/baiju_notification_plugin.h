#ifndef RUNNER_BAIJU_NOTIFICATION_PLUGIN_H_
#define RUNNER_BAIJU_NOTIFICATION_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <string>

// Native Windows notification plugin using Shell_NotifyIcon (system tray balloon).
// No third-party libraries required.
class BaijuNotificationPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit BaijuNotificationPlugin(flutter::PluginRegistrarWindows* registrar);
  ~BaijuNotificationPlugin() override;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void ShowBalloonNotification(const std::wstring& title,
                               const std::wstring& body);

  flutter::PluginRegistrarWindows* registrar_;
  NOTIFYICONDATAW nid_;
  bool icon_added_ = false;

  void EnsureIconAdded();
  void RemoveIcon();
};

#endif  // RUNNER_BAIJU_NOTIFICATION_PLUGIN_H_
