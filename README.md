# ADÜPass 🔓

ADÜPass is a next-generation, mobile-first, and multi-factor campus access control system tailored for modern universities. Designed with a clean corporate aesthetic, the system eliminates the need for physical plastic IDs by introducing an interconnected ecosystem comprising a **Flutter Mobile App**, a **Split-Screen Desktop Turnstile Simulator**, and an **AI-Powered Real-Time Face Recognition Engine**.

The entire infrastructure runs on a reactive, event-driven architecture orchestrated by **Firebase Firestore**, delivering microsecond-level synchronization between user devices and physical gate terminals.

---

## 🌟 Core Features

### 1. Mobile Client (Student & Personnel App)
* **Corporate Identity:** Completely themed with a clean light layout utilizing the university's corporate identity palette (Navy, Royal Blue, and Accent Cyan).
* **Dynamic QR Pass:** Generates and scans time-hashed, secure QR tokens that rotate every 3 seconds to prevent fraudulent reuse or screenshot sharing.
* **Conceptual NFC "Tap-and-Go":** Features an elegant, high-fidelity UI entry point for NFC validation that triggers an immersive native BottomSheet, showcasing the system's scalability for hardware deployment.
* **Crash-Proof Architecture:** Wrapped in absolute `try-catch` execution shields to guarantee standalone operations even when disconnected from development environments.

### 2. Turnstile Simulator (Split-Screen Desktop GUI)
* **Dual-Verification Panel:** A responsive macOS/Windows layout split horizontally:
    * *Left Column:* Displays the active, rotating cryptographic QR token with automated countdown feeds.
    * *Right Column:* Displays an AI Smart Frame placeholder representing the active computer vision terminal waiting for physical face metrics.
* **Unified Access Callbacks:** Triggers a synchronized, full-screen green access overlay across both the mobile and desktop views instantaneously upon verification.

### 3. AI Face Recognition Gate
* **Edge-Based Inference:** A lightweight Python microservice utilizing `OpenCV` and `face_recognition` (dlib) running locally via a secure virtual environment.
* **Tokenized Dispatch:** Automatically converts facial frames into 128-dimensional biometric embeddings, verifies identities against safe local vector indices, and updates the shared Firestore bridge document instantly.
* **Privacy by Design:** Fully GDPR and KVKK compliant; raw images are processed on local volatile memory nodes and never transmitted or logged into the cloud.

---

## 🎨 Design & Palette System

The user interface strictly adheres to the following modern UI token variables:

| Token Name | Hex Value | Application Context |
| :--- | :--- | :--- |
| `primaryColor` | `#0D2B5C` | Corporate Navy for AppBars, Primary Actions & Branding |
| `secondaryBlue`| `#1F5FBF` | Royal Blue accentuation for buttons, gradients and focus borders |
| `accentCyan`   | `#2EC4B6` | Vivid Turkuaz for NFC elements, success statuses & secondary cues |
| `background`   | `#FFFFFF` | Sterile white canvas background ensuring maximum contrast |
| `textDark`     | `#0B1F3A` | High-readability deep dark navy for professional typography |

---

## Demo Video
https://github.com/user-attachments/assets/87e04517-bd2f-4f4c-8017-ffe7aaeb06d6
---
Thanks ! 
