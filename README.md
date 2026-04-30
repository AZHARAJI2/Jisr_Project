# Jisr (جسر)

Offline-first mesh money transfer prototype built with Flutter and Google Nearby Connections.

## Overview

`Jisr` enables money transfer even when internet is unavailable:

1. Sender creates a transfer on-device.
2. Transfer propagates hop-by-hop across nearby phones over mesh connectivity.
3. When the transfer reaches an online-capable node, settlement can be completed.
4. Sender/receiver see status updates and local notifications on actual delivery.

This repository is a hackathon-grade implementation focused on core flow reliability, security, and user experience.

## Core Features

- Offline transfer propagation over mesh (`P2P_CLUSTER` strategy).
- Multi-device routing with relay support and TTL loop protection.
- Delivery-aware status lifecycle (`pending` -> `completed` only on confirmed delivery trace).
- Transfer path tracing in network view.
- Active transfer node highlighting in **purple** during movement.
- Local notifications for:
  - incoming transfer delivery
  - sender confirmation only after true delivery
- Arabic-first product UX and branding (`جسر`).

## Security Model

The transport and message layer uses strong cryptographic primitives:

- `Ed25519`: digital signatures for message authenticity.
- `X25519`: peer key agreement.
- `HKDF-SHA256`: per-session key derivation.
- `ChaCha20-Poly1305`: authenticated encryption.
- Replay/skew protections for secure frames and trace events.

## Network Visualization Notes

- The detailed network view shows a practical, readable topology for demo usage.
- Purple nodes indicate the node currently carrying the transfer.
- Current UI topology is intentionally simplified (not always full global topology rendering).
- This is a deliberate MVP choice and is directly extensible to full topology visualization.

## Hackathon Scope Assumptions

This project aligns with sandbox-style hackathon assumptions:

- Regulatory/KYC/AML constraints are assumed pre-satisfied by event rules.
- Banking settlement integrations can be simulated via internal flow.
- The implemented in-app receive/settlement behavior is a prototype path to real bank API integration.

## Tech Stack

- Flutter (Dart)
- Google Nearby Connections (native Android plugin bridge)
- Hive (local persistence)
- flutter_local_notifications
- cryptography package

## Project Structure

- `lib/network/mesh_manager.dart`: transfer lifecycle, trace handling, topology merge.
- `lib/network/nearby_mesh_service.dart`: mesh transport, payload handling, telemetry.
- `lib/network/security_service.dart`: key management, signing, encryption/decryption.
- `lib/screens/network_screen.dart`: detailed network map and transfer trace UI.
- `lib/screens/operations_screen.dart`: pending/completed transaction states.
- `lib/network/notification_service.dart`: local notification orchestration.
- `nearby_connections_local/`: Android Nearby plugin customization.

## Run (Debug)

```bash
flutter pub get
flutter run
```

## Build (Release APK)

```bash
flutter build apk --release
```

Output:

- `build/app/outputs/flutter-apk/app-release.apk`

## Current Status

Working well for:

- connection reliability improvements
- offline relay behavior
- delivery-confirmed completion logic
- sender/receiver notification timing fixes
- mesh trace visualization and node quality coloring

Planned production extensions:

- real bank/API settlement integration
- full topology rendering and advanced route analytics
- expanded observability and enterprise controls
