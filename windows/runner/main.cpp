#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "utils.h"

// AppUserModelID must match the applicationId used in windows_notification.
// Required for toast notifications to work on non-packaged (non-MSIX) apps.
constexpr const wchar_t kAppUserModelId[] = L"FilmmakerAlerts.App";

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Register AppUserModelID so Windows toast notifications work for
  // non-packaged apps. This must be called before any window is created.
  //
  // TODO(installer): When adding an installer (MSIX, Inno Setup, etc.),
  // create a Start Menu shortcut that includes this same AppUserModelID
  // ("FilmmakerAlerts.App"). Windows requires a matching shortcut for
  // toast notifications to fully work on non-packaged apps. Without it,
  // toasts may silently fail on some Windows configurations.
  // See: https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/send-local-toast-other-apps
  ::SetCurrentProcessExplicitAppUserModelID(kAppUserModelId);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"filmmaker_alerts_flutter", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
