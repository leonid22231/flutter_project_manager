#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

void ActivateExistingProjectManagerWindow() {
  HWND hwnd = ::FindWindowW(nullptr, L"Project Manager");
  if (hwnd == nullptr) {
    return;
  }

  const DWORD target_thread = ::GetWindowThreadProcessId(hwnd, nullptr);
  const DWORD current_thread = ::GetCurrentThreadId();
  bool attached = false;
  if (target_thread != 0 && target_thread != current_thread) {
    attached =
        ::AttachThreadInput(current_thread, target_thread, TRUE) != FALSE;
  }

  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  } else {
    ::ShowWindow(hwnd, SW_SHOW);
  }
  ::BringWindowToTop(hwnd);
  ::SetForegroundWindow(hwnd);

  if (attached) {
    ::AttachThreadInput(current_thread, target_thread, FALSE);
  }
}

bool HasMinimizedArgument(const std::vector<std::string>& args) {
  for (const auto& arg : args) {
    if (arg == "--minimized") {
      return true;
    }
  }
  return false;
}

}  // namespace

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

  // One instance. A second launch shows the window that is already running.
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"Local\\ProjectManager");
  if (instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateExistingProjectManagerWindow();
    ::CloseHandle(instance_mutex);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool start_minimized = HasMinimizedArgument(command_line_arguments);

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  window.SetStartMinimized(start_minimized);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Project Manager", origin, size)) {
    if (instance_mutex != nullptr) {
      ::CloseHandle(instance_mutex);
    }
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (instance_mutex != nullptr) {
    ::CloseHandle(instance_mutex);
  }
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
