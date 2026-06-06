-- Trainingo SQLite schema
-- Apply with: python backend/init_db.py

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    nickname TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS study_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    subject TEXT NOT NULL,
    generation_mode TEXT DEFAULT 'ai_only',
    difficulty TEXT DEFAULT 'beginner',
    progress REAL DEFAULT 0.0,
    source_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_studied_at TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS lessons (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    level INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    is_locked INTEGER DEFAULT 1,
    is_completed INTEGER DEFAULT 0,
    FOREIGN KEY(session_id) REFERENCES study_sessions(id)
);

CREATE TABLE IF NOT EXISTS questions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER,
    question_type TEXT NOT NULL,
    difficulty TEXT NOT NULL,
    question_text TEXT NOT NULL,
    options_json TEXT DEFAULT '[]',
    correct_answer TEXT DEFAULT '',
    model_answer TEXT DEFAULT '',
    sample_answer TEXT DEFAULT '',
    expected_answer TEXT DEFAULT '',
    explanation TEXT DEFAULT '',
    source_type TEXT DEFAULT 'AI',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(session_id) REFERENCES study_sessions(id)
);

CREATE TABLE IF NOT EXISTS answer_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    session_id INTEGER NOT NULL,
    question_id INTEGER NOT NULL,
    user_answer TEXT NOT NULL,
    is_correct INTEGER NOT NULL DEFAULT 0,
    answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(session_id) REFERENCES study_sessions(id),
    FOREIGN KEY(question_id) REFERENCES questions(id)
);

CREATE TABLE IF NOT EXISTS incorrect_answer_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    session_id INTEGER,
    question_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_reviewed INTEGER DEFAULT 0,
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(session_id) REFERENCES study_sessions(id),
    FOREIGN KEY(question_id) REFERENCES questions(id)
);

CREATE TABLE IF NOT EXISTS study_calendar (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    study_date TEXT NOT NULL,
    solved_count INTEGER DEFAULT 0,
    correct_count INTEGER DEFAULT 0,
    wrong_count INTEGER DEFAULT 0,
    studied_topics_json TEXT DEFAULT '[]',
    UNIQUE(user_id, study_date),
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_study_sessions_user_recent
ON study_sessions(user_id, last_studied_at DESC, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_lessons_session_level
ON lessons(session_id, level);

CREATE INDEX IF NOT EXISTS idx_questions_session_type
ON questions(session_id, question_type, difficulty);

CREATE INDEX IF NOT EXISTS idx_answer_records_user_answered
ON answer_records(user_id, answered_at DESC);

CREATE INDEX IF NOT EXISTS idx_answer_records_session_question
ON answer_records(session_id, question_id);

CREATE INDEX IF NOT EXISTS idx_incorrect_notes_user_created
ON incorrect_answer_notes(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_incorrect_notes_session_question
ON incorrect_answer_notes(session_id, question_id);

CREATE INDEX IF NOT EXISTS idx_study_calendar_user_date
ON study_calendar(user_id, study_date DESC);
