# Smart Queue System

Flutter MVC app for UMPSA PKU Pekan with a Laravel API in `backend/`.

- `lib/config/`: app, authentication routes and API configuration.
- `lib/model/`: data entities and status enums.
- `lib/pages/`: login, password recovery, signed-in landing page and feature placeholders.
- `lib/controller/`: presentation state and feature controller foundations.
- `lib/services/`: HTTP API and authentication.
- `database/smart_queue_system.sql`: initial eight-table MySQL schema.
- `backend/`: Laravel API using the imported database.

See [backend setup](backend/README.md) to start the API and create your first account.

Login uses User ID and password, supports all four roles and has token-based logout.
Tokens are in memory for now; app restart requires a new login.
Password reset email, business workflows and AI features are not implemented.

Run `flutter analyze` and `flutter test` from this folder.
Run `php artisan test` from `backend/` for isolated API tests.
