# SQS Laravel API

Uses the existing MySQL database imported through phpMyAdmin.
Laravel 12 is installed for the local PHP 8.2 runtime.

## Run locally

Start MySQL in XAMPP. From this folder:

```powershell
php artisan serve --host=127.0.0.1 --port=8000
```

The configured database is `smart_queue_system`, with local XAMPP root credentials.
Edit `.env` if your MySQL credentials differ. Never commit that file.

## Create your first account

In another terminal in this folder:

```powershell
php artisan sqs:create-user
```

Enter a User ID, name, email, role and password. Password entry is hidden and
Laravel hashes it before insertion. No shared default accounts are created.

## Database ownership

The eight domain tables are owned by the imported SQL schema. Do not rerun the
initial import over existing data. Laravel migrations only add its API token
table (and migration tracking). The initial token migration has been applied locally.
On another machine, import the SQL, configure .env, then run `php artisan migrate`.
Do not use `migrate:fresh` or `db:wipe` on your imported database.

The user model uses the custom `user_id` key and maps the `roles` relationship.
The generated Laravel user migration and default account seeder were replaced
so they do not conflict with the imported schema.

## API

- POST /api/login: user_identifier, password; returns token and user.
- GET /api/me: authenticated account.
- POST /api/logout: revokes the current token.
- POST /api/forgot-password: validates email, returns 503 until mail is implemented.

Use `Authorization: Bearer <token>`. Tokens expire after 12 hours.
Inactive accounts cannot sign in or use an existing token.
Login has per-account/IP and per-IP rate limits.

Flutter keeps tokens in memory, so restarting the app requires signing in again.
Business feature endpoints and persistent secure session storage are not implemented.
The successful-login screen is a temporary role-labelled landing page.

## Flutter connections

From the Flutter project root:

```powershell
flutter run -d chrome
```

Web and desktop default to http://127.0.0.1:8000/api.
Android emulator defaults to http://10.0.2.2:8000/api.
Local HTTP is enabled only in the Android debug manifest.

For a physical device, run the API on 0.0.0.0 and set the host computer's LAN IP:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:8000/api
```

Use HTTPS for deployment. Local web CORS permits localhost and 127.0.0.1 ports.
Set CORS_ALLOWED_ORIGINS to a comma-separated origin list for a deployed web client.

## Tests

`php artisan test` uses forced SQLite :memory:, never the imported MySQL database.
Auth feature tests cover login, validation, rate limits, inactive users and revocation.
Flutter tests are run from the project root using `flutter test`.

API token implementation: https://laravel.com/docs/12.x/sanctum
