# Contributing to EasyTab

Thank you for your interest in contributing to **EasyTab**! We welcome bug fixes, performance improvements, and documentation enhancements that align with our mission: keeping EasyTab fast, lightweight, and bloat-free.

---

## 🛠️ Development Setup

EasyTab is built with pure Swift and native AppKit for macOS.

### Prerequisites

* macOS 13.0 (Ventura) or newer
* Xcode Command Line Tools or Xcode 15+ (`xcode-select --install`)
* Git

### Building & Running Locally

1. **Clone the repository:**
   ```bash
   git clone https://github.com/rynergold/EasyTab.git
   cd EasyTab
   ```

2. **Run the test suite:**
   ```bash
   ./scripts/run_tests.sh
   ```

3. **Build the application bundle:**
   ```bash
   ./scripts/build_app.sh
   ```
   The compiled `.app` bundle will be generated in `build/EasyTab.app`.

---

## 🏛️ Architecture Overview

The codebase is organized into modular layers:

* **`Sources/EasyTab/Core`**:
  * `Models/WindowItem.swift`: Lightweight window descriptor model.
  * `StateMachine/SwitcherEngine.swift`: Pure, deterministic state machine handling MRU navigation, forward cycling, and search query filtering.
  * `Protocols/WindowProvider.swift`: Clean interface abstractions.
* **`Sources/EasyTab/Platform`**:
  * `Accessibility/SystemWindowProvider.swift`: Low-overhead window enumeration via `CGWindowListCopyWindowInfo`.
  * `Accessibility/WindowFocusManager.swift`: Direct window raising via `AXUIElement`.
  * `EventTap/EventTapInterceptor.swift`: Passive `CGEventTap` hotkey interceptor for `Command+Tab`, `S`, `Enter`, and `Escape`.
  * `Permissions/PermissionsManager.swift`: macOS Accessibility permission verification.
* **`Sources/EasyTab/UI`**:
  * `Panel/SwitcherHUDPanel.swift`: Floating borderless, non-activating `NSPanel`.
  * `Views/AppKitSwitcherView.swift`: Ultra-responsive hardware-backed AppKit card carousel and search pill.

---

## 📋 Pull Request Guidelines

1. **Keep it lightweight**: EasyTab's core philosophy is extreme performance and zero background bloat. Avoid adding heavy dependencies or slow runtime abstractions.
2. **Pass all unit tests**: Verify `./scripts/run_tests.sh` passes before submitting. Add tests in `Tests/EasyTabTests/` for any new state machine behavior.
3. **Follow Conventional Commits**: Use clear commit messages like `feat(...)`, `fix(...)`, `docs(...)`, or `chore(...)`.
4. **Code of Conduct**: All contributors are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).
