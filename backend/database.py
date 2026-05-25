import sqlite3
import json
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "trainingo.db")

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 1. Users table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        nickname TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    
    # 2. Study Sessions table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        subject TEXT NOT NULL,
        progress REAL DEFAULT 0.0,
        source_text TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES users(id)
    )
    """)
    
    # 3. Lessons table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS lessons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        level INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        is_locked INTEGER DEFAULT 1,
        is_completed INTEGER DEFAULT 0,
        FOREIGN KEY(session_id) REFERENCES study_sessions(id)
    )
    """)
    
    # 4. Incorrect Answers table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS incorrect_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        subject TEXT NOT NULL,
        question TEXT NOT NULL,
        options_json TEXT NOT NULL,
        answer TEXT NOT NULL,
        explanation TEXT NOT NULL,
        user_answer TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES users(id)
    )
    """)
    
    conn.commit()
    conn.close()
    print("SQLite Database initialized successfully.")

# User Authentication Helpers
def register_user(email, password, nickname):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO users (email, password, nickname) VALUES (?, ?, ?)",
            (email, password, nickname)
        )
        conn.commit()
        user_id = cursor.lastrowid
        return {"id": user_id, "email": email, "nickname": nickname}
    except sqlite3.IntegrityError:
        return None
    finally:
        conn.close()

def login_user(email, password):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, email, nickname FROM users WHERE email = ? AND password = ?",
        (email, password)
    )
    row = cursor.fetchone()
    conn.close()
    if row:
        return {"id": row["id"], "email": row["email"], "nickname": row["nickname"]}
    return None

# Study Session Helpers
def get_session_by_subject(user_id, subject):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, user_id, subject, progress, source_text FROM study_sessions WHERE user_id = ? AND subject = ?",
        (user_id, subject)
    )
    row = cursor.fetchone()
    if not row:
        conn.close()
        return None
    
    session = dict(row)
    cursor.execute(
        "SELECT id, level, title, description, is_locked, is_completed FROM lessons WHERE session_id = ? ORDER BY level ASC",
        (session["id"],)
    )
    lessons = [dict(r) for r in cursor.fetchall()]
    # Convert sqlite 1/0 to bool
    for l in lessons:
        l["isLocked"] = bool(l["is_locked"])
        l["isCompleted"] = bool(l["is_completed"])
    session["curriculum"] = lessons
    conn.close()
    return session

def create_study_session(user_id, subject, curriculum, source_text=None):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Create session
        cursor.execute(
            "INSERT INTO study_sessions (user_id, subject, source_text) VALUES (?, ?, ?)",
            (user_id, subject, source_text)
        )
        session_id = cursor.lastrowid
        
        # Insert lessons
        for item in curriculum:
            # First level is unlocked (is_locked=0), others locked (is_locked=1)
            is_locked = 0 if item["level"] == 1 else 1
            cursor.execute(
                "INSERT INTO lessons (session_id, level, title, description, is_locked, is_completed) VALUES (?, ?, ?, ?, ?, ?)",
                (session_id, item["level"], item["title"], item["description"], is_locked, 0)
            )
        conn.commit()
        return session_id
    finally:
        conn.close()

def get_study_sessions(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, user_id, subject, progress, source_text FROM study_sessions WHERE user_id = ? ORDER BY updated_at DESC",
        (user_id,)
    )
    rows = cursor.fetchall()
    sessions = []
    for row in rows:
        session = dict(row)
        cursor.execute(
            "SELECT id, level, title, description, is_locked, is_completed FROM lessons WHERE session_id = ? ORDER BY level ASC",
            (session["id"],)
        )
        lessons = []
        for r in cursor.fetchall():
            d = dict(r)
            d["isLocked"] = bool(d["is_locked"])
            d["isCompleted"] = bool(d["is_completed"])
            lessons.append(d)
        session["curriculum"] = lessons
        sessions.append(session)
    conn.close()
    return sessions

def update_lesson_completion(session_id, lesson_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Get current completed lesson level
        cursor.execute(
            "SELECT level FROM lessons WHERE session_id = ? AND id = ?",
            (session_id, lesson_id)
        )
        current_lesson = cursor.fetchone()
        if not current_lesson:
            return False
        
        current_level = current_lesson["level"]
        
        # Complete the lesson
        cursor.execute(
            "UPDATE lessons SET is_completed = 1, is_locked = 0 WHERE id = ?",
            (lesson_id,)
        )
        
        # Unlock next level if it exists
        cursor.execute(
            "UPDATE lessons SET is_locked = 0 WHERE session_id = ? AND level = ?",
            (session_id, current_level + 1)
        )
        
        # Calculate new progress
        cursor.execute(
            "SELECT COUNT(*) as total, SUM(is_completed) as completed FROM lessons WHERE session_id = ?",
            (session_id,)
        )
        progress_row = cursor.fetchone()
        total = progress_row["total"]
        completed = progress_row["completed"] or 0
        progress = float(completed) / float(total) if total > 0 else 0.0
        
        # Update session progress
        cursor.execute(
            "UPDATE study_sessions SET progress = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (progress, session_id)
        )
        conn.commit()
        return True
    finally:
        conn.close()

# Incorrect Answers Helpers
def add_incorrect_answer(user_id, subject, question, options, answer, explanation, user_answer):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        options_json = json.dumps(options)
        cursor.execute(
            """
            INSERT INTO incorrect_answers (user_id, subject, question, options_json, answer, explanation, user_answer)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (user_id, subject, question, options_json, answer, explanation, user_answer)
        )
        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()

def get_incorrect_answers(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, user_id, subject, question, options_json, answer, explanation, user_answer, created_at FROM incorrect_answers WHERE user_id = ? ORDER BY created_at DESC",
        (user_id,)
    )
    rows = cursor.fetchall()
    answers = []
    for r in rows:
        d = dict(r)
        d["options"] = json.loads(d["options_json"])
        answers.append(d)
    conn.close()
    return answers

def delete_incorrect_answer(answer_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM incorrect_answers WHERE id = ?", (answer_id,))
        conn.commit()
        return cursor.rowcount > 0
    finally:
        conn.close()

def get_session_source_text(session_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT source_text FROM study_sessions WHERE id = ?", (session_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        return row["source_text"]
    return None
