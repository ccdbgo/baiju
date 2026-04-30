#include "baiju_notification_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <string>

// Unique ID for the tray icon
static const UINT kTrayIconId = 1001;
// Custom message for tray icon events (not used for interaction, just needed)
static const UINT WM_TRAYICON = WM_USER + 1;

// Convert UTF-8 std::string to std::wstring
static std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return L"";
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                                static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()),
                      &wide[0], len);
  return wide;
}

// static
void BaijuNotificationPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.baiju.app/notification",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<BaijuNotificationPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_ptr = plugin.get()](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

BaijuNotificationPlugin::BaijuNotificationPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  ZeroMemory(&nid_, sizeof(nid_));
}

BaijuNotificationPlugin::~BaijuNotificationPlugin() {
  RemoveIcon();
}

void BaijuNotificationPlugin::EnsureIconAdded() {
  if (icon_added_) return;

  HWND hwnd = registrar_->GetView()->GetNativeWindow();

  nid_.cbSize = sizeof(NOTIFYICONDATAW);
  nid_.hWnd = hwnd;
  nid_.uID = kTrayIconId;
  nid_.uFlags = NIF_ICON | NIF_TIP | NIF_MESSAGE;
  nid_.uCallbackMessage = WM_TRAYICON;
  // Use the application's own icon
  nid_.hIcon = (HICON)GetClassLongPtrW(hwnd, GCLP_HICON);
  if (!nid_.hIcon) {
    nid_.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
  }
  wcsncpy_s(nid_.szTip, L"白驹", _TRUNCATE);

  Shell_NotifyIconW(NIM_ADD, &nid_);

  // Use version 4 API so notifications go to the Action Center and persist
  // until the user dismisses them.
  nid_.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &nid_);

  icon_added_ = true;
}

void BaijuNotificationPlugin::RemoveIcon() {
  if (!icon_added_) return;
  Shell_NotifyIconW(NIM_DELETE, &nid_);
  icon_added_ = false;
}

void BaijuNotificationPlugin::ShowBalloonNotification(
    const std::wstring& title, const std::wstring& body) {
  EnsureIconAdded();

  // NIF_REALTIME: if the notification cannot be shown immediately, discard it
  // rather than queuing. Combined with NOTIFYICON_VERSION_4 the notification
  // is sent to the Windows Action Center where it persists until the user
  // dismisses it.
  nid_.uFlags = NIF_INFO | NIF_ICON | NIF_TIP | NIF_MESSAGE | NIF_REALTIME;
  nid_.dwInfoFlags = NIIF_INFO | NIIF_NOSOUND | NIIF_RESPECT_QUIET_TIME;

  wcsncpy_s(nid_.szInfoTitle, title.c_str(), _TRUNCATE);
  wcsncpy_s(nid_.szInfo, body.c_str(), _TRUNCATE);

  Shell_NotifyIconW(NIM_MODIFY, &nid_);
}

void BaijuNotificationPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "show") {
    const auto* args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("INVALID_ARGS", "Expected map argument");
      return;
    }

    std::wstring title = L"白驹提醒";
    std::wstring body;

    auto title_it = args->find(flutter::EncodableValue("title"));
    if (title_it != args->end()) {
      const auto* s = std::get_if<std::string>(&title_it->second);
      if (s) title = Utf8ToWide(*s);
    }

    auto body_it = args->find(flutter::EncodableValue("body"));
    if (body_it != args->end()) {
      const auto* s = std::get_if<std::string>(&body_it->second);
      if (s) body = Utf8ToWide(*s);
    }

    ShowBalloonNotification(title, body);
    result->Success();
  } else {
    result->NotImplemented();
  }
}
