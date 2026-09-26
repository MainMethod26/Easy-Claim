# EasyClaim Frontend

This is the Flutter application for the EasyClaim platform. It contains two separate entry points tailored for different users:

- **Customer App** (`lib/main.dart`): The main application for customers to view covers, start claims, and track their progress.
- **Admin/Insurer App** (`lib/main_admin.dart`): The portal for insurer staff (Admins, Managers, Assessors) to manage and review claims.

## Directory Structure

The `lib/` directory is organized as follows:

- **`models/`**: Data models and classes that represent business objects (e.g., Claims, Covers, Profiles).
- **`providers/`**: State management classes. The app uses the `provider` package to manage app state, handle logic, and provide data to the UI.
- **`screens/`**: Full-page UI views. Each screen corresponds to a specific route or page in the application (e.g., home screens, claim forms).
  - **`admin/`**: Screens specific to the Insurer/Admin portal (e.g., dashboard, admin authentication).
- **`services/`**: API integration and external service logic. This is where network requests to the backend (`backend/`) are handled.
- **`widgets/`**: Reusable UI components. Small, isolated UI pieces like buttons, cards, and forms that are shared across different screens.
- **`main.dart`**: The entry point for the Customer-facing application.
- **`main_admin.dart`**: The entry point for the Insurer/Admin-facing application.

## Testing

Tests are located in the `test/` directory. You can run the flutter test suite using:

```bash
flutter test
```

## Node Proxy (Development)

There is a small Node.js proxy server (`server.js`) configured via `package.json` that is used for local development routing.
