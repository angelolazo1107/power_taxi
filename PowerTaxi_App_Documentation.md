# PowerTaxi Mobile App: Documentation & Feature Summary

---

## 📅 Project Update: March 30, 2026

This document contains the comprehensive technical summary and feature set of the PowerTaxi mobile application, focused on the integration of the Howen AT5 V5 MDT hardware.

---

### 1. System Overview
The PowerTaxi mobile application is built using **Flutter**, leveraging a high-performance reactive framework to provide a premium user experience on specialized Android hardware.

#### 🏛️ Technical Stack:
*   **Frontend**: Flutter / Dart
*   **Backend**: Firebase Firestore (NoSQL)
*   **Hardware Interface**: Howen AT5 V5 SDK (Native Java/Kotlin Bridge)
*   **Authentication**: Multi-tenant RBAC (Role-Based Access Control)

---

### 2. Feature Roadmap & Recent Updates

#### ✅ Native Hardware Pulse Integration
*   Integrated the **Howen OIML Callback** system to capture real-time vehicle pulses.
*   Established a resilient **MethodChannel** for hardware control commands (Start/Stop/Calibration).
*   Configured an **EventChannel** for low-latency hardware status updates to the UI layer.

#### ✅ Advanced Calibration Module
*   **Automated Pulse Stream**: The calibration interface now triggers the hardware sensor immediately upon opening, ensuring accurate readouts for technicians.
*   **Dynamic Distance Mapping**: Support for custom Pulse-to-Kilometer mapping to ensure meter accuracy across different vehicle models.
*   **Resource Safety**: Adaptive logic shuts down hardware sensors when the calibration window is closed, optimizing device longevity.

#### ✅ Secure Multi-Tenant Authentication
*   Implemented **Input Sanitation** (Trim/Lowercase) for Admin and Driver accounts to eliminate credential matching errors.
*   Enabled **Keyboard Submission** on Web portals for faster administrative workflow.
*   Secure **SHA-256 password hashing** is standard across all login protocols.

#### ✅ Data Synchronization & Offline-First
*   **Background Sync**: Trip data is queued locally and synced with the cloud once a stable connection is established.
*   **Recovery Protocol**: Added `RecoveryUtils` to allow for secure account recovery and device resets in field-testing scenarios.

---

### 3. Implementation Checklist for Teams

*   [x] **Build Debug APK**: `flutter build apk --debug`
*   [x] **Confirm Hardware Connection**: Verify `HowenManager` initialization in system logs.
*   [x] **Calibrate Meter**: Perform 1km test drive to verify pulse-to-distance ratio.
*   [x] **Verify Cloud Sync**: Ensure trip records appear in the Admin Dashboard within 5 seconds.

---

### 4. Troubleshooting Guide

| Issue | Potential Cause | Resolution |
| :--- | :--- | :--- |
| **Pulses not updating** | Hardware meter "Started" flag is False | Check `MainActivity.kt` logs for `isMeterRunning`. |
| **Login Access Denied** | Case sensitivity in Firestore | Ensure admin email is saved in lowercase. |
| **Slow UI Response** | EventChannel overload | Throttle UI updates to 10Hz maximum. |

---

### 5. Deployment Instructions

1.  Clone the repository.
2.  Install dependencies: `flutter pub get`.
3.  Ensure the Howen SDK JAR is in the `/android/libs` folder.
4.  Run a debug build for field testing: `flutter build apk --debug`.

---

**End of Documentation**  
*Generated on: 2026-03-30 09:18*
