$files = @{}

$files['C:\xampp\htdocs\scholar_php\get_scholar_dashboard.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

$userId = (int) ($_GET['user_id'] ?? request_value('user_id', 0));
if ($userId <= 0) {
    respond_error('Invalid user_id', 422);
}

$sql = "
    SELECT
        s.scholar_id,
        s.first_name,
        s.middle_name,
        s.last_name,
        s.course,
        s.year_level,
        s.gpa,
        s.scholarship_category,
        s.assigned_area,
        s.academic_type,
        s.sport_type,
        s.gift_type,
        s.scholarship_status,
        a.application_id,
        a.status AS application_status,
        a.remarks AS application_remarks
    FROM scholars s
    LEFT JOIN applications a ON a.scholar_id = s.scholar_id
    WHERE s.user_id = ?
    ORDER BY a.application_id DESC
    LIMIT 1
";

$stmt = db_prepare($conn, $sql);
$stmt->bind_param('i', $userId);
$stmt->execute();
$profile = $stmt->get_result()?->fetch_assoc();
$stmt->close();

if (!$profile) {
    respond_error('Scholar profile not found', 404);
}

$applicationId = (int) ($profile['application_id'] ?? 0);
$category = trim((string) ($profile['scholarship_category'] ?? 'Student Assistant'));
$fullName = trim(implode(' ', array_filter([
    trim((string) ($profile['first_name'] ?? '')),
    trim((string) ($profile['middle_name'] ?? '')),
    trim((string) ($profile['last_name'] ?? '')),
])));
$displayName = $fullName !== '' ? $fullName : ('Scholar #' . $userId);
$submissions = [];

if ($applicationId > 0) {
    $subsStmt = db_prepare(
        $conn,
        "
        SELECT
            s.submission_id,
            COALESCE(r.requirement_name, CONCAT('Requirement #', COALESCE(s.requirement_id, 0))) AS type,
            s.status,
            s.upload_date,
            s.file_path,
            s.reviewer_comment
        FROM submissions s
        LEFT JOIN requirements r ON r.requirement_id = s.requirement_id
        WHERE s.application_id = ?
        ORDER BY s.upload_date DESC
        LIMIT 10
        "
    );
    $subsStmt->bind_param('i', $applicationId);
    $subsStmt->execute();
    $submissions = fetch_all_assoc($subsStmt);
    $subsStmt->close();
}

foreach ($submissions as &$submission) {
    $submission['submission_id'] = (int) ($submission['submission_id'] ?? 0);
    $submission['name'] = basename((string) ($submission['file_path'] ?? 'Document'));
    $submission['type'] = (string) ($submission['type'] ?? 'Document');
    $submission['status'] = ucfirst((string) ($submission['status'] ?? 'Pending'));
}
unset($submission);

$renderedHours = 0;
if (db_table_exists($conn, 'duty_logs')) {
    $hoursStmt = db_prepare($conn, 'SELECT COALESCE(SUM(hours), 0) AS rendered_hours FROM duty_logs WHERE user_id = ?');
    $hoursStmt->bind_param('i', $userId);
    $hoursStmt->execute();
    $hoursRow = $hoursStmt->get_result()?->fetch_assoc();
    $hoursStmt->close();
    $renderedHours = (int) ($hoursRow['rendered_hours'] ?? 0);
}

$requiredHours = 100;
$remainingHours = max(0, $requiredHours - $renderedHours);
$gpa = (float) ($profile['gpa'] ?? 0);
$yearLevel = (string) ($profile['year_level'] ?? '0');
$applicationStatus = trim((string) ($profile['application_status'] ?? $profile['scholarship_status'] ?? 'Pending'));
$statusLabel = $applicationStatus !== '' ? ucfirst($applicationStatus) : 'Pending';

$stats = [
    'display_name' => $displayName,
    'category' => $category,
    'course' => (string) ($profile['course'] ?? ''),
    'status' => $statusLabel,
    'type' => $category,
    'gwa' => $gpa > 0 ? number_format($gpa, 2) : '0.00',
    'gpa' => $gpa > 0 ? number_format($gpa, 2) : '0.00',
    'units' => $yearLevel !== '0' ? $yearLevel : '0',
    'rendered_hours' => (string) $renderedHours,
    'remaining_hours' => (string) $remainingHours,
    'assigned_area' => (string) ($profile['assigned_area'] ?? '-'),
    'academic_type' => (string) ($profile['academic_type'] ?? '-'),
    'sport_type' => (string) ($profile['sport_type'] ?? '-'),
    'gift_type' => (string) ($profile['gift_type'] ?? '-'),
    'remarks' => (string) ($profile['application_remarks'] ?? ''),
];

respond_success([
    'stats' => $stats,
    'submissions' => $submissions,
]);
'@

$files['C:\xampp\htdocs\scholar_php\get_scholar_profile.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

$userId = (int) ($_GET['user_id'] ?? request_value('user_id', 0));
if ($userId <= 0) {
    respond_error('Invalid user_id', 422);
}

$stmt = db_prepare(
    $conn,
    "
    SELECT
        s.scholar_id,
        s.first_name,
        s.middle_name,
        s.last_name,
        s.course,
        s.year_level,
        s.scholarship_category,
        s.assigned_area,
        s.academic_type,
        s.sport_type,
        s.gift_type,
        s.scholarship_status,
        s.gpa,
        u.email,
        u.username
    FROM scholars s
    INNER JOIN users u ON u.user_id = s.user_id
    WHERE s.user_id = ?
    LIMIT 1
    "
);
$stmt->bind_param('i', $userId);
$stmt->execute();
$row = $stmt->get_result()?->fetch_assoc();
$stmt->close();

if (!$row) {
    respond_error('Scholar profile not found', 404);
}

$fullName = trim(implode(' ', array_filter([
    trim((string) ($row['first_name'] ?? '')),
    trim((string) ($row['middle_name'] ?? '')),
    trim((string) ($row['last_name'] ?? '')),
])));
$category = trim((string) ($row['scholarship_category'] ?? 'Student Assistant'));
$role = $category !== '' ? $category : 'Scholar';
$semesterOptions = [
    'AY 2025-2026 2nd Semester',
    'AY 2025-2026 1st Semester',
    'Summer 2026',
];

$detailRows = [];
switch (strtolower($category)) {
    case 'academic scholar':
        $detailRows[] = [
            'Scholarship Type' => (string) ($row['academic_type'] ?? 'Academic Scholar'),
            'Benefit' => 'Tuition Assistance',
            'GWA Req.' => ((float) ($row['gpa'] ?? 0)) > 0 ? number_format((float) $row['gpa'], 2) : 'N/A',
            'Monthly Stipend' => 'PHP 3,000.00',
        ];
        break;
    case 'varsity scholar':
        $detailRows[] = [
            'Sport' => (string) ($row['sport_type'] ?? 'Varsity Team'),
            'Head Coach' => 'Athletics Office',
            'Training Schedule' => 'See athletics coordinator',
            'Status' => ucfirst((string) ($row['scholarship_status'] ?? 'active')),
        ];
        break;
    default:
        $detailRows[] = [
            'Assign Area' => (string) ($row['assigned_area'] ?? 'Unassigned'),
            'Duty Hours' => '0',
            'Supervisor' => 'Scholarship Office',
            'Required Hours' => '100',
        ];
        break;
}

respond_success([
    'profile' => [
        'user_id' => $userId,
        'scholar_id' => (int) ($row['scholar_id'] ?? 0),
        'name' => $fullName !== '' ? $fullName : ((string) ($row['username'] ?? ('Scholar #' . $userId))),
        'course' => (string) ($row['course'] ?? ''),
        'email' => (string) ($row['email'] ?? ''),
        'role' => $role,
        'scholarship_category' => $category,
        'assigned_area' => (string) ($row['assigned_area'] ?? ''),
        'academic_type' => (string) ($row['academic_type'] ?? ''),
        'sport_type' => (string) ($row['sport_type'] ?? ''),
        'gift_type' => (string) ($row['gift_type'] ?? ''),
        'status' => (string) ($row['scholarship_status'] ?? ''),
    ],
    'semesters' => $semesterOptions,
    'detail_rows' => $detailRows,
]);
'@

$files['C:\xampp\htdocs\scholar_php\get_monitoring_summary.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

$scholarCounts = [];
$countResult = $conn->query("SELECT scholarship_category, COUNT(*) AS total FROM scholars GROUP BY scholarship_category");
if ($countResult) {
    while ($row = $countResult->fetch_assoc()) {
        $category = trim((string) ($row['scholarship_category'] ?? 'Uncategorized'));
        $scholarCounts[] = [
            'category' => $category !== '' ? $category : 'Uncategorized',
            'total' => (int) ($row['total'] ?? 0),
        ];
    }
}

$submissionRows = [];
$sql = "
    SELECT
        u.user_id,
        CONCAT_WS(' ', s.first_name, s.last_name) AS scholar_name,
        CONCAT_WS(' - ', s.course, s.year_level) AS course_year,
        MAX(sub.upload_date) AS latest_submission,
        SUM(CASE WHEN sub.status = 'approved' THEN 1 ELSE 0 END) AS approved_count,
        SUM(CASE WHEN sub.status = 'pending' THEN 1 ELSE 0 END) AS pending_count,
        s.assigned_area,
        s.scholarship_category
    FROM scholars s
    INNER JOIN users u ON u.user_id = s.user_id
    LEFT JOIN applications a ON a.scholar_id = s.scholar_id
    LEFT JOIN submissions sub ON sub.application_id = a.application_id
    GROUP BY u.user_id, s.first_name, s.last_name, s.course, s.year_level, s.assigned_area, s.scholarship_category
    ORDER BY scholar_name ASC
    LIMIT 50
";
$result = $conn->query($sql);
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $submissionRows[] = [
            'user_id' => (int) ($row['user_id'] ?? 0),
            'name' => trim((string) ($row['scholar_name'] ?? '')),
            'course_year' => trim((string) ($row['course_year'] ?? '')),
            'latest_submission' => (string) ($row['latest_submission'] ?? ''),
            'grade_status' => ((int) ($row['approved_count'] ?? 0)) > 0 ? 'Submitted' : 'Missing',
            'renewal_status' => ((int) ($row['pending_count'] ?? 0)) > 0 ? 'Pending' : 'Submitted',
            'remarks' => ((int) ($row['pending_count'] ?? 0)) > 0 ? 'Notify Scholar' : 'Complete',
            'assigned_area' => (string) ($row['assigned_area'] ?? ''),
            'category' => (string) ($row['scholarship_category'] ?? ''),
        ];
    }
}

respond_success([
    'category_counts' => $scholarCounts,
    'scholars' => $submissionRows,
]);
'@

$files['C:\xampp\htdocs\scholar_php\get_reports_summary.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

$totalScholars = (int) ($conn->query('SELECT COUNT(*) AS total FROM scholars')->fetch_assoc()['total'] ?? 0);
$approved = (int) ($conn->query("SELECT COUNT(*) AS total FROM submissions WHERE status = 'approved'")->fetch_assoc()['total'] ?? 0);
$pending = (int) ($conn->query("SELECT COUNT(*) AS total FROM submissions WHERE status = 'pending'")->fetch_assoc()['total'] ?? 0);
$rejected = (int) ($conn->query("SELECT COUNT(*) AS total FROM submissions WHERE status = 'rejected'")->fetch_assoc()['total'] ?? 0);

$byType = [];
$typeResult = $conn->query("SELECT scholarship_category, COUNT(*) AS total FROM scholars GROUP BY scholarship_category ORDER BY total DESC");
if ($typeResult) {
    while ($row = $typeResult->fetch_assoc()) {
        $byType[] = [
            'label' => (string) ($row['scholarship_category'] ?? 'Uncategorized'),
            'value' => (int) ($row['total'] ?? 0),
        ];
    }
}

respond_success([
    'summary' => [
        'total_scholars' => $totalScholars,
        'approved' => $approved,
        'pending' => $pending,
        'rejected' => $rejected,
    ],
    'by_type' => $byType,
    'status_distribution' => [
        ['label' => 'Approved', 'value' => $approved],
        ['label' => 'Pending', 'value' => $pending],
        ['label' => 'Rejected', 'value' => $rejected],
    ],
]);
'@

$files['C:\xampp\htdocs\scholar_php\mark_notification_read.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

require_method('POST');
$data = require_fields(['notification_id']);

$notificationId = (int) $data['notification_id'];
$isRead = (int) ($data['is_read'] ?? 1);

$stmt = db_prepare($conn, 'UPDATE notifications SET is_read = ? WHERE notification_id = ?');
$stmt->bind_param('ii', $isRead, $notificationId);
if (!$stmt->execute()) {
    $error = $stmt->error;
    $stmt->close();
    respond_error('Failed to update notification: ' . $error, 500);
}
$stmt->close();

respond_success(['message' => 'Notification updated']);
'@

$files['C:\xampp\htdocs\scholar_php\mark_all_notifications_read.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

require_method('POST');
$userId = (int) request_value('user_id', 0);
$isRead = (int) request_value('is_read', 1);

if ($userId <= 0) {
    respond_error('Invalid user_id', 422);
}

$stmt = db_prepare($conn, 'UPDATE notifications SET is_read = ? WHERE user_id = ?');
$stmt->bind_param('ii', $isRead, $userId);
if (!$stmt->execute()) {
    $error = $stmt->error;
    $stmt->close();
    respond_error('Failed to update notifications: ' . $error, 500);
}
$stmt->close();

respond_success(['message' => 'Notifications updated']);
'@

$files['C:\xampp\htdocs\scholar_php\auth_login.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

require_method('POST');
$data = require_fields(['email', 'password']);

$email = trim((string) $data['email']);
$password = (string) $data['password'];

$stmt = db_prepare(
    $conn,
    'SELECT user_id, username, email, password_hash, password, role, is_active FROM users WHERE email = ? LIMIT 1'
);
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()?->fetch_assoc();
$stmt->close();

if (!$user) {
    respond_error('User not found', 404);
}

if (isset($user['is_active']) && (int) $user['is_active'] !== 1) {
    respond_error('User account is inactive', 403);
}

$hashPassword = (string) ($user['password_hash'] ?? '');
$legacyPassword = (string) ($user['password'] ?? '');

$isValid = ($hashPassword !== '' && password_verify($password, $hashPassword))
    || ($legacyPassword !== '' && ($password === $legacyPassword || password_verify($password, $legacyPassword)));

if (!$isValid) {
    respond_error('Invalid password', 401);
}

$extra = [];
if (($user['role'] ?? '') === 'scholar' && db_table_exists($conn, 'scholars')) {
    $profileStmt = db_prepare(
        $conn,
        'SELECT scholar_id, scholarship_category, academic_type, sport_type, gift_type, first_name, last_name FROM scholars WHERE user_id = ? LIMIT 1'
    );
    $profileStmt->bind_param('i', $user['user_id']);
    $profileStmt->execute();
    $profile = $profileStmt->get_result()?->fetch_assoc();
    $profileStmt->close();

    if ($profile) {
        $extra = [
            'scholar_id' => (int) ($profile['scholar_id'] ?? 0),
            'scholarship_category' => $profile['scholarship_category'] ?? '',
            'academic_type' => $profile['academic_type'] ?? '',
            'sport_type' => $profile['sport_type'] ?? '',
            'gift_type' => $profile['gift_type'] ?? '',
            'name' => trim(implode(' ', array_filter([
                trim((string) ($profile['first_name'] ?? '')),
                trim((string) ($profile['last_name'] ?? '')),
            ]))),
        ];
    }
}

respond_success(array_merge([
    'user_id' => (int) $user['user_id'],
    'username' => $user['username'],
    'email' => $user['email'],
    'role' => $user['role'],
], $extra));
'@

$files['C:\xampp\htdocs\scholar_php\get_sa_stats.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

$userId = (int) ($_GET['user_id'] ?? request_value('user_id', 0));
if ($userId <= 0) {
    respond_error('Invalid user_id', 422);
}

$appStmt = db_prepare(
    $conn,
    'SELECT a.application_id, a.status, a.remarks
     FROM applications a
     INNER JOIN scholars s ON s.scholar_id = a.scholar_id
     WHERE s.user_id = ?
     ORDER BY a.application_id DESC
     LIMIT 1'
);
$appStmt->bind_param('i', $userId);
$appStmt->execute();
$application = $appStmt->get_result()?->fetch_assoc();
$appStmt->close();

if (!$application) {
    respond_success([
        'assigned_work' => 0,
        'rendered_hours' => 0,
        'remaining_hours' => 100,
        'duty_status' => 'No Application',
        'submissions_count' => 0,
        'activity_reports' => 0,
        'status' => 'No Application',
        'submissions' => [],
    ]);
}

$applicationId = (int) $application['application_id'];
$subsStmt = db_prepare(
    $conn,
    'SELECT submission_id, requirement_id, file_path, status, upload_date, remarks, reviewer_comment
     FROM submissions
     WHERE application_id = ?
     ORDER BY upload_date DESC'
);
$subsStmt->bind_param('i', $applicationId);
$subsStmt->execute();
$submissions = fetch_all_assoc($subsStmt);
$subsStmt->close();

foreach ($submissions as &$submission) {
    $submission['submission_id'] = (int) $submission['submission_id'];
    $submission['requirement_id'] = isset($submission['requirement_id']) ? (int) $submission['requirement_id'] : null;
    $submission['image_url'] = make_public_file_url((string) $submission['file_path']);
    $submission['doc_name'] = basename((string) ($submission['file_path'] ?? 'Document'));
}
unset($submission);

$renderedHours = 0;
if (db_table_exists($conn, 'duty_logs')) {
    $hoursStmt = db_prepare($conn, 'SELECT COALESCE(SUM(hours), 0) AS total_hours FROM duty_logs WHERE user_id = ?');
    $hoursStmt->bind_param('i', $userId);
    $hoursStmt->execute();
    $hoursRow = $hoursStmt->get_result()?->fetch_assoc();
    $hoursStmt->close();
    $renderedHours = (int) ($hoursRow['total_hours'] ?? 0);
}

respond_success([
    'application_id' => $applicationId,
    'assigned_work' => $renderedHours,
    'rendered_hours' => $renderedHours,
    'remaining_hours' => max(0, 100 - $renderedHours),
    'duty_status' => $application['status'] ?? 'Pending',
    'submissions_count' => count($submissions),
    'activity_reports' => count($submissions),
    'status' => $application['status'],
    'application_remarks' => $application['remarks'],
    'submissions' => $submissions,
]);
'@

$files['C:\xampp\htdocs\scholar_php\save_evaluation.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

require_method('POST');
$data = require_fields(['scholar_id', 'program_type']);

$scholarId = (int) $data['scholar_id'];
$programType = trim((string) $data['program_type']);

if ($scholarId <= 0) {
    respond_error('Invalid scholar_id', 422);
}

$allowedPrograms = ['student_assistant', 'varsity'];
if (!in_array($programType, $allowedPrograms, true)) {
    respond_error('Invalid program_type', 422);
}

$courseYear = trim((string) ($data['course_year'] ?? ''));
$assignedArea = trim((string) ($data['assigned_area'] ?? ''));
$supervisorName = trim((string) ($data['supervisor_name'] ?? ''));
$monthLabel = trim((string) ($data['month_label'] ?? ''));
$ratingsJson = trim((string) ($data['ratings_json'] ?? '{}'));
$recommendation = trim((string) ($data['recommendation'] ?? ''));
$totalScore = (int) ($data['total_score'] ?? 0);
$averageScore = (float) ($data['average_score'] ?? 0);

json_decode($ratingsJson, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    respond_error('ratings_json must be valid JSON', 422);
}

if (!db_table_exists($conn, 'evaluations')) {
    respond_error('Evaluations table not found', 500);
}

$stmt = db_prepare(
    $conn,
    "
    INSERT INTO evaluations
        (scholar_id, program_type, course_year, assigned_area, supervisor_name, month_label,
         ratings_json, total_score, average_score, recommendation)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    "
);
$stmt->bind_param(
    'issssssids',
    $scholarId,
    $programType,
    $courseYear,
    $assignedArea,
    $supervisorName,
    $monthLabel,
    $ratingsJson,
    $totalScore,
    $averageScore,
    $recommendation
);

if (!$stmt->execute()) {
    $error = $stmt->error;
    $stmt->close();
    respond_error('Failed to save evaluation: ' . $error, 500);
}
$evaluationId = $stmt->insert_id;
$stmt->close();

respond_success([
    'evaluation_id' => $evaluationId,
    'message' => 'Evaluation saved.',
]);
'@

$files['C:\xampp\htdocs\scholar_php\get_evaluations.php'] = @'
<?php
declare(strict_types=1);

require_once __DIR__ . '/backend_common.php';

$scholarId = (int) ($_GET['scholar_id'] ?? request_value('scholar_id', 0));
$programType = trim((string) ($_GET['program_type'] ?? request_value('program_type', '')));

if (!db_table_exists($conn, 'evaluations')) {
    respond_success(['data' => []]);
}

$sql = "
    SELECT evaluation_id, scholar_id, program_type, course_year, assigned_area,
           supervisor_name, month_label, ratings_json, total_score, average_score,
           recommendation, created_at
    FROM evaluations
    WHERE 1=1
";
$params = [];
$types = '';

if ($scholarId > 0) {
    $sql .= ' AND scholar_id = ?';
    $params[] = $scholarId;
    $types .= 'i';
}

if ($programType !== '') {
    $sql .= ' AND program_type = ?';
    $params[] = $programType;
    $types .= 's';
}

$sql .= ' ORDER BY created_at DESC LIMIT 50';

$stmt = db_prepare($conn, $sql);
if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}
$stmt->execute();
$rows = fetch_all_assoc($stmt);
$stmt->close();

respond_success(['data' => $rows]);
'@

foreach ($entry in $files.GetEnumerator()) {
  $dir = Split-Path -Path $entry.Key -Parent
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($entry.Key, $entry.Value, $utf8NoBom)
}

Write-Output ("Wrote {0} PHP files" -f $files.Count)
