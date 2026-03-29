CREATE TABLE IF NOT EXISTS evaluations (
  evaluation_id INT AUTO_INCREMENT PRIMARY KEY,
  scholar_id INT NOT NULL,
  program_type ENUM('student_assistant', 'varsity') NOT NULL,
  course_year VARCHAR(120) DEFAULT '',
  assigned_area VARCHAR(120) DEFAULT '',
  supervisor_name VARCHAR(120) DEFAULT '',
  month_label VARCHAR(60) DEFAULT '',
  ratings_json TEXT NOT NULL,
  total_score INT DEFAULT 0,
  average_score DECIMAL(5,2) DEFAULT 0,
  recommendation TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_evaluations_scholar (scholar_id),
  INDEX idx_evaluations_program (program_type)
);
