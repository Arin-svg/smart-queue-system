# Smart Queue System

Flutter MVC foundation for UMPSA PKU Pekan, based on the supplied diagram.

- `lib/config/`: app, authentication routes and API configuration.
- `lib/model/`: data entities and status enums.
- `lib/pages/`: views; all 17 screens from the diagram are present.
- `lib/controller/`: presentation state and feature controller foundations.
- `lib/services/`: API, authentication and notification boundaries.
- `lib/main.dart`: app setup, dependency creation and routes.

Views delegate actions to controllers. Controllers use services and expose models
to views. Services will encapsulate Laravel communication.

## Current scope

The app opens a basic login view with input validation and a password recovery
route. Other pages are named placeholders. Authentication is unconfigured;
no credentials are accepted and no backend requests are made.
API and notification services and both AI controllers are contracts only.
Feature controllers and models are starting structures, not completed workflows.

Next work includes Laravel integration, JSON mapping, session storage, role-based
route protection, feature screens, QR scanning and notifications.
AI priority and waiting-time features require an agreed implementation and validation.

## Verification

Run `flutter analyze` and `flutter test`.

