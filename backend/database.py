import json
import os
import sqlite3
from pathlib import Path
from typing import Optional
from urllib.parse import unquote, urlparse

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent
SCHEMA_PATH = BASE_DIR / "schema.sql"

load_dotenv(dotenv_path=BASE_DIR / ".env")


def _path_from_database_url(database_url: Optional[str]) -> Optional[str]:
    if not database_url:
        return None

    if database_url.startswith("sqlite:///"):
        return database_url.replace("sqlite:///", "", 1)

    parsed = urlparse(database_url)
    if parsed.scheme != "sqlite":
        raise ValueError("현재 프로젝트는 SQLite만 지원합니다. DATABASE_URL은 sqlite:/// 형식이어야 합니다.")

    return unquote(parsed.path)


def _resolve_db_path() -> Path:
    raw_path = os.getenv("DB_PATH") or _path_from_database_url(os.getenv("DATABASE_URL"))
    if not raw_path:
        return BASE_DIR / "trainingo.db"

    db_path = Path(raw_path).expanduser()
    if db_path.is_absolute():
        return db_path

    return (PROJECT_ROOT / db_path).resolve()


DB_PATH = _resolve_db_path()


def get_db_path() -> str:
    return str(DB_PATH)


def get_db_connection():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    if not SCHEMA_PATH.exists():
        raise FileNotFoundError(f"DB schema file not found: {SCHEMA_PATH}")

    conn = get_db_connection()
    try:
        with SCHEMA_PATH.open("r", encoding="utf-8") as schema_file:
            conn.executescript(schema_file.read())
        conn.commit()
        print(f"SQLite Database initialized successfully: {DB_PATH}")
    finally:
        conn.close()


def _lesson_row_to_dict(row):
    lesson = dict(row)
    lesson["isLocked"] = bool(lesson.get("is_locked", 0))
    lesson["isCompleted"] = bool(lesson.get("is_completed", 0))
    return lesson


def _fetch_curriculum(cursor, session_id):
    cursor.execute(
        """
        SELECT id, level, title, description, is_locked, is_completed
        FROM lessons
        WHERE session_id = ?
        ORDER BY level ASC
        """,
        (session_id,),
    )
    return [_lesson_row_to_dict(row) for row in cursor.fetchall()]


def _session_row_to_dict(cursor, row):
    if not row:
        return None

    session = dict(row)
    session["curriculum"] = _fetch_curriculum(cursor, session["id"])
    return session


# User Authentication Helpers
def register_user(email, password, nickname):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO users (email, password, nickname) VALUES (?, ?, ?)",
            (email, password, nickname),
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
    try:
        cursor.execute(
            "SELECT id, email, nickname FROM users WHERE email = ? AND password = ?",
            (email, password),
        )
        row = cursor.fetchone()
        if row:
            return {"id": row["id"], "email": row["email"], "nickname": row["nickname"]}
        return None
    finally:
        conn.close()


# Study Session Helpers
def get_session_by_subject(user_id, subject):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, subject, progress, source_text, created_at, updated_at
            FROM study_sessions
            WHERE user_id = ? AND subject = ?
            """,
            (user_id, subject),
        )
        return _session_row_to_dict(cursor, cursor.fetchone())
    finally:
        conn.close()


def get_session_by_id(session_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, subject, progress, source_text, created_at, updated_at
            FROM study_sessions
            WHERE id = ?
            """,
            (session_id,),
        )
        return _session_row_to_dict(cursor, cursor.fetchone())
    finally:
        conn.close()


def create_study_session(user_id, subject, curriculum, source_text=None):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO study_sessions (user_id, subject, source_text) VALUES (?, ?, ?)",
            (user_id, subject, source_text),
        )
        session_id = cursor.lastrowid

        for index, item in enumerate(curriculum):
            level = int(item.get("level", index + 1))
            title = item.get("title", "학습 단원")
            description = item.get("description", "이 단원의 핵심 개념을 학습합니다.")
            is_locked = 0 if level == 1 else 1
            cursor.execute(
                """
                INSERT INTO lessons (session_id, level, title, description, is_locked, is_completed)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (session_id, level, title, description, is_locked, 0),
            )

        conn.commit()
        return session_id
    finally:
        conn.close()


def get_study_sessions(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, subject, progress, source_text, created_at, updated_at
            FROM study_sessions
            WHERE user_id = ?
            ORDER BY updated_at DESC, id DESC
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
        return [_session_row_to_dict(cursor, row) for row in rows]
    finally:
        conn.close()


def append_session_source_text(session_id: int, additional_text: str) -> bool:
    if not additional_text.strip():
        return False

    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT id FROM study_sessions WHERE id = ?", (session_id,))
        if not cursor.fetchone():
            return False

        cursor.execute(
            """
            UPDATE study_sessions
            SET source_text = CASE
                    WHEN source_text IS NULL OR TRIM(source_text) = ''
                    THEN ?
                    ELSE source_text || CHAR(10) || CHAR(10) || ?
                END,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (additional_text, additional_text, session_id),
        )
        conn.commit()
        return cursor.rowcount > 0
    finally:
        conn.close()


def replace_session_curriculum(session_id: int, curriculum) -> bool:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT id FROM study_sessions WHERE id = ?", (session_id,))
        if not cursor.fetchone():
            return False

        cursor.execute("DELETE FROM lessons WHERE session_id = ?", (session_id,))

        for index, item in enumerate(curriculum):
            level = int(item.get("level", index + 1))
            title = item.get("title", "학습 단원")
            description = item.get("description", "이 단원의 핵심 개념을 학습합니다.")
            is_locked = 0 if level == 1 else 1

            cursor.execute(
                """
                INSERT INTO lessons (session_id, level, title, description, is_locked, is_completed)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (session_id, level, title, description, is_locked, 0),
            )

        cursor.execute(
            """
            UPDATE study_sessions
            SET progress = 0.0,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (session_id,),
        )
        conn.commit()
        return True
    finally:
        conn.close()


def update_lesson_completion(session_id, lesson_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT level FROM lessons WHERE session_id = ? AND id = ?",
            (session_id, lesson_id),
        )
        current_lesson = cursor.fetchone()
        if not current_lesson:
            return False

        current_level = current_lesson["level"]
        cursor.execute("UPDATE lessons SET is_completed = 1, is_locked = 0 WHERE id = ?", (lesson_id,))
        cursor.execute(
            "UPDATE lessons SET is_locked = 0 WHERE session_id = ? AND level = ?",
            (session_id, current_level + 1),
        )

        cursor.execute(
            "SELECT COUNT(*) as total, SUM(is_completed) as completed FROM lessons WHERE session_id = ?",
            (session_id,),
        )
        progress_row = cursor.fetchone()
        total = progress_row["total"]
        completed = progress_row["completed"] or 0
        progress = float(completed) / float(total) if total > 0 else 0.0

        cursor.execute(
            "UPDATE study_sessions SET progress = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (progress, session_id),
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
        options_json = json.dumps(options, ensure_ascii=False)
        cursor.execute(
            """
            INSERT INTO incorrect_answers (user_id, subject, question, options_json, answer, explanation, user_answer)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (user_id, subject, question, options_json, answer, explanation, user_answer),
        )
        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()


def get_incorrect_answers(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, subject, question, options_json, answer, explanation, user_answer, created_at
            FROM incorrect_answers
            WHERE user_id = ?
            ORDER BY created_at DESC
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
        answers = []
        for row in rows:
            answer = dict(row)
            answer["options"] = json.loads(answer["options_json"])
            answers.append(answer)
        return answers
    finally:
        conn.close()


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
    try:
        cursor.execute("SELECT source_text FROM study_sessions WHERE id = ?", (session_id,))
        row = cursor.fetchone()
        if row:
            return row["source_text"]
        return None
    finally:
        conn.close()
