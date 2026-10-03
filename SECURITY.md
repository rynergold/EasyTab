# Security Policy

EasyTab requires macOS Accessibility permissions (`AXUIElement` and `CGEventTap`) to intercept window-switching hotkeys and bring windows into focus. Because of this elevated system privilege, we treat security and privacy with the utmost importance.

## Supported Versions

Only the latest release of EasyTab receives active security updates:

| Version | Supported |
| :--- | :--- |
| `1.2.x` | :white_check_mark: |
| `< 1.2.0` | :x: |

---

## 🔒 Privacy & Local Processing Guarantee

EasyTab operates **100% offline**:
* **Zero Network Traffic**: EasyTab makes zero outbound network requests and has no network entitlements.
* **Zero Telemetry / Analytics**: No user tracking, analytics, or crash data collection.
* **Ephemeral Thumbnails**: Window thumbnails are generated temporarily on-the-fly and cleared from memory as soon as the switcher dismisses.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or privilege issue, please do not open a public issue.

Instead, please report it privately via GitHub:
1. Navigate to the [Security Advisories](https://github.com/rynergold/EasyTab/security/advisories) tab.
2. Click **Report a vulnerability**.

You can expect an initial response within 48 hours. Valid vulnerabilities will be patched promptly and acknowledged in the release notes.
