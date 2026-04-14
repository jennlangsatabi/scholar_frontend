# Scholarship Backend Integration

## System Architecture

- `Flutter UI`
  - Entry and routing: `main.dart`, `role_selection.dart`, `admin_main.dart`, `scholar_main.dart`
  - Admin modules: dashboard, scholar management, verification, monitoring, reports, announcements, admin notifications
  - Scholar modules: login, dashboard by scholar type, profile, uploads, notifications
- `HTTP/JSON API`
  - Shared client config: [lib/services/api_config.dart](/c:/Projects/scholar_flutter/lib/services/api_config.dart)
  - Shared request helpers: [lib/services/backend_api.dart](/c:/Projects/scholar_flutter/lib/services/backend_api.dart)
- `PHP Backend`
  - Path: `C:\xampp\htdocs\scholar_php`
  - Shared bootstrap: `backend_common.php`, `connection.php`
  - Feature endpoints: auth, scholars, submissions, notifications, monitoring, reports
- `MySQL`
  - Database: `scholarship`
  - Main tables used: `users`, `scholars`, `applications`, `submissions`, `notifications`, `replies`, `requirements`
  - Optional tables used if present: `announcements`, `duty_logs`

## Deployment Scope

The active codebase is wired to a custom PHP/MySQL backend.

## Dart File Responsibilities

- `main.dart`: app root, role/login flow, switches to admin or scholar shell.
- `role_selection.dart`: selects Admin vs Scholars portal.
- `admin_login.dart`: admin authentication against `auth_login.php`.
- `scholar_login.dart`: scholar authentication against `auth_login.php`; now consumes backend scholarship category.
- `admin_dashboard.dart`: admin overview stats and recent submissions.
- `admin_main.dart`: admin sidebar shell and module navigation.
- `admin_managescholar.dart`: CRUD for scholar records.
- `admin_notification.dart`: admin notification/reply inbox.
- `academic_dashboard.dart`: academic scholar dashboard fed by `get_scholar_dashboard.php`.
- `academic_profile.dart`: academic scholar profile fed by `get_scholar_profile.php`.
- `varsity_dashboard.dart`: varsity dashboard fed by `get_scholar_dashboard.php`.
- `varsity_profile.dart`: varsity profile fed by `get_scholar_profile.php`.
- `student_assistant_dashboard.dart`: student assistant stats/submissions from `get_sa_stats.php`.
- `gift_of_education_dashboard.dart`: gift-of-education dashboard fed by `get_scholar_dashboard.php`.
- `profile.dart`: student assistant profile fed by `get_scholar_profile.php`.
- `profile_components.dart`: reusable profile layout/table/dropdown widgets.
- `notification.dart`: scholar notification inbox, read/unread, delete, reply.
- `announcement.dart`: creates announcements that fan out into notifications.
- `monitoring.dart`: admin monitoring summary from `get_monitoring_summary.php`.
- `reports.dart`: admin report summary from `get_reports_summary.php`.
- `student_upload_screen.dart`: legacy image upload screen, now points to shared backend URL.
- `upload_files.dart`: main multi-file upload/analyze/submit screen.
- `document_model.dart`: submission/document JSON model.
- `verification.dart`: admin review queue and approve/reject actions.
- `dashboard_components.dart`: reusable dashboard UI helpers.
- `dashboard_style.dart`: shared dashboard colors and box decoration.

## Screens Already Calling Backend APIs

- `admin_login.dart`
- `scholar_login.dart`
- `admin_dashboard.dart`
- `admin_managescholar.dart`
- `admin_notification.dart`
- `academic_dashboard.dart`
- `student_assistant_dashboard.dart`
- `gift_of_education_dashboard.dart`
- `varsity_dashboard.dart`
- `profile.dart`
- `academic_profile.dart`
- `varsity_profile.dart`
- `notification.dart`
- `announcement.dart`
- `monitoring.dart`
- `reports.dart`
- `upload_files.dart`
- `student_upload_screen.dart`
- `verification.dart`

## API Endpoint List

### Existing / reused

- Local XAMPP path: `POST /scholar_php/auth_login.php`
- Local XAMPP path: `GET /scholar_php/google_oauth_start.php` or equivalent OAuth start endpoint configured through `GOOGLE_OAUTH_URL`
- Render backend service root path: `POST /auth_login.php`
- Render backend service root path: `GET /google_oauth_start.php`
- `GET /scholar_php/get_admin_stats.php`
- `GET /scholar_php/get_scholars.php`
- `POST /scholar_php/add_scholar.php`
- `POST /scholar_php/edit_scholar.php`
- `POST /scholar_php/delete_scholar.php`
- `GET /scholar_php/get_verifications.php`
- `POST /scholar_php/update_status.php`
- `POST /scholar_php/upload_document.php`
- `GET /scholar_php/get_notifications.php`
- `GET /scholar_php/get_admin_notifications.php`
- `POST /scholar_php/save_announcement.php`
- `POST /scholar_php/save_reply.php`
- `POST /scholar_php/delete_notification.php`
- `POST /scholar_php/delete_reply.php`
- `GET /scholar_php/get_sa_stats.php`

### Added for this integration

- `GET /scholar_php/get_scholar_dashboard.php`
- `GET /scholar_php/get_scholar_profile.php`
- `GET /scholar_php/get_monitoring_summary.php`
- `GET /scholar_php/get_reports_summary.php`
- `POST /scholar_php/mark_notification_read.php`
- `POST /scholar_php/mark_all_notifications_read.php`

## Screen to Table Mapping

- Login screens
  - Tables: `users`, `scholars`
- Admin dashboard
  - Tables: `scholars`, `applications`, `submissions`, `requirements`
- Manage scholar
  - Tables: `users`, `scholars`
- Verification
  - Tables: `submissions`, `applications`, `scholars`, `requirements`
- Upload files / student upload
  - Tables: `applications`, `submissions`, `requirements`
- Scholar dashboards
  - Tables: `scholars`, `applications`, `submissions`, optional `duty_logs`
- Scholar profiles
  - Tables: `users`, `scholars`
- Notifications / admin notifications
  - Tables: `notifications`, `replies`, `users`
- Announcements
  - Tables: `announcements` if present, always `notifications`, `users`
- Monitoring
  - Tables: `scholars`, `users`, `applications`, `submissions`
- Reports
  - Tables: `scholars`, `submissions`

## Database Relations

The project currently depends on these table relationships:

- `users.id -> scholars.user_id`
- `users.id -> notifications.user_id`
- `users.id -> replies.user_id`
- `scholars.scholar_id -> applications.scholar_id`
- `applications.application_id -> submissions.application_id`
- `requirements.requirement_id -> submissions.requirement_id`
- `notifications.notification_id -> replies.notification_id`
- `scholars.scholar_id -> evaluations.scholar_id`

Conceptual graph:

```text
users
  |- scholars
  |    |- applications
  |         |- submissions
  |              |- requirements
  |    |- evaluations
  |
  |- notifications
  |    |- replies
  |
  |- announcements
```

## Required Database Connections

- Scholar profiles -> `scholars`
  - `user_id`, `first_name`, `middle_name`, `last_name`, `course`, `year_level`, `scholarship_category`, `assigned_area`, `academic_type`, `sport_type`, `gift_type`, `scholarship_status`, `gpa`
- Notifications -> `notifications`
  - `notification_id`, `user_id`, `message`, `is_read`, `created_at`
- File uploads -> `submissions`
  - `submission_id`, `application_id`, `requirement_id`, `file_path`, `status`, `remarks`, `upload_date`, `reviewer_comment`

## JSON Response Shape

```json
{
  "status": "success",
  "data": []
}
```

or feature-specific objects:

```json
{
  "status": "success",
  "stats": {
    "display_name": "Juan Dela Cruz",
    "category": "Academic Scholar",
    "status": "Active"
  },
  "submissions": [
    {
      "submission_id": 12,
      "name": "grades_sem1.pdf",
      "type": "Report of Grades",
      "status": "Approved"
    }
  ]
}
```

## Flutter HTTP Examples

```dart
final login = await BackendApi.postForm(
  'auth_login.php',
  body: {
    'email': email,
    'password': password,
  },
);
```

```dart
final profile = await BackendApi.getJson(
  'get_scholar_profile.php',
  query: {'user_id': userId},
);
```

```dart
final request = http.MultipartRequest(
  'POST',
  ApiConfig.uri('upload_document.php'),
)
  ..fields['user_id'] = userId
  ..fields['document_type'] = 'Report of Grades';
```

## Authentication Flow

1. Flutter posts credentials to `auth_login.php`.
2. PHP validates `users.email` + password hash/plain fallback.
3. For scholars, PHP also loads `scholars.scholarship_category`.
4. Flutter routes:
   - `role == admin` -> admin shell
   - `role == scholar` -> scholar shell using backend scholar type
5. Google OAuth button:
   - Flutter opens the URL from `GOOGLE_OAUTH_URL`.
   - Append `role=admin` or `role=scholar` so the backend can branch the OAuth callback if needed.
   - The current app launches the auth URL externally; the backend still needs to complete the OAuth callback/session exchange.

## Files Changed

- Flutter:
  - `lib/services/api_config.dart`
  - `lib/services/backend_api.dart`
  - `lib/admin_login.dart`
  - `lib/scholar_login.dart`
  - `lib/admin_managescholar.dart`
  - `lib/scholar_main.dart`
  - `lib/notification.dart`
  - `lib/admin_notification.dart`
  - `lib/announcement.dart`
  - `lib/upload_files.dart`
  - `lib/student_upload_screen.dart`
  - `lib/profile.dart`
  - `lib/academic_profile.dart`
  - `lib/varsity_profile.dart`
  - `lib/academic_dashboard.dart`
  - `lib/varsity_dashboard.dart`
  - `lib/gift_of_education_dashboard.dart`
  - `lib/monitoring.dart`
  - `lib/reports.dart`
  - `lib/verification.dart`
- PHP:
  - `C:\xampp\htdocs\scholar_php\auth_login.php`
  - `C:\xampp\htdocs\scholar_php\get_sa_stats.php`
  - `C:\xampp\htdocs\scholar_php\get_scholar_dashboard.php`
  - `C:\xampp\htdocs\scholar_php\get_scholar_profile.php`
  - `C:\xampp\htdocs\scholar_php\get_monitoring_summary.php`
  - `C:\xampp\htdocs\scholar_php\get_reports_summary.php`
  - `C:\xampp\htdocs\scholar_php\mark_notification_read.php`
  - `C:\xampp\htdocs\scholar_php\mark_all_notifications_read.php`
