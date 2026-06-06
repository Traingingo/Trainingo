import json
import os
import sqlite3
from datetime import date, timedelta
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


def _table_columns(cursor, table_name: str) -> set[str]:
    cursor.execute(f"PRAGMA table_info({table_name})")
    return {row["name"] for row in cursor.fetchall()}


def _ensure_column(cursor, table_name: str, column_name: str, column_sql: str):
    if column_name not in _table_columns(cursor, table_name):
        cursor.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_sql}")


def _run_migrations(conn):
    cursor = conn.cursor()
    _ensure_column(cursor, "study_sessions", "generation_mode", "generation_mode TEXT NOT NULL DEFAULT 'ai_only'")
    _ensure_column(cursor, "study_sessions", "difficulty", "difficulty TEXT NOT NULL DEFAULT '초급'")
    _ensure_column(cursor, "study_sessions", "last_studied_at", "last_studied_at TIMESTAMP")
    _ensure_column(cursor, "incorrect_answers", "session_id", "session_id INTEGER DEFAULT 0")
    _ensure_column(cursor, "incorrect_answers", "question_id", "question_id INTEGER DEFAULT 0")
    _ensure_column(cursor, "incorrect_answers", "question_type", "question_type TEXT NOT NULL DEFAULT 'multiple_choice'")
    _ensure_column(cursor, "incorrect_answers", "difficulty", "difficulty TEXT NOT NULL DEFAULT '초급'")
    _ensure_column(cursor, "incorrect_answers", "is_reviewed", "is_reviewed INTEGER DEFAULT 0")
    conn.commit()


def init_db():
    if not SCHEMA_PATH.exists():
        raise FileNotFoundError(f"DB schema file not found: {SCHEMA_PATH}")
    conn = get_db_connection()
    try:
        with SCHEMA_PATH.open("r", encoding="utf-8") as schema_file:
            conn.executescript(schema_file.read())
        _run_migrations(conn)
        conn.commit()
        print(f"SQLite Database initialized successfully: {DB_PATH}")
    finally:
        conn.close()


def _difficulty_to_learning_level(difficulty: str) -> str:
    if difficulty == "중급":
        return "intermediate"
    if difficulty == "고급":
        return "advanced"
    return "beginner"


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
    source_text = session.pop("source_text", None)
    session["topic"] = session.get("subject", "")
    session["learning_level"] = _difficulty_to_learning_level(session.get("difficulty", "초급"))
    session["has_material"] = bool(source_text and str(source_text).strip())
    session["curriculum"] = _fetch_curriculum(cursor, session["id"])
    return session


def _json_loads(value, fallback):
    try:
        if value is None:
            return fallback
        return json.loads(value)
    except Exception:
        return fallback


# User Authentication Helpers
def register_user(email, password, nickname):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO users (email, password, nickname) VALUES (?, ?, ?)", (email, password, nickname))
        conn.commit()
        return {"id": cursor.lastrowid, "email": email, "nickname": nickname}
    except sqlite3.IntegrityError:
        return None
    finally:
        conn.close()


def login_user(email, password):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT id, email, nickname FROM users WHERE email = ? AND password = ?", (email, password))
        row = cursor.fetchone()
        if row:
            return {"id": row["id"], "email": row["email"], "nickname": row["nickname"]}
        return None
    finally:
        conn.close()


# Study Session Helpers
def get_session_by_subject(user_id, subject, generation_mode=None, difficulty=None):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT id, user_id, subject, generation_mode, difficulty, progress, source_text, created_at, updated_at, last_studied_at
            FROM study_sessions
            WHERE user_id = ? AND subject = ?
        """
        params = [user_id, subject]
        if generation_mode:
            query += " AND generation_mode = ?"
            params.append(generation_mode)
        if difficulty:
            query += " AND difficulty = ?"
            params.append(difficulty)
        query += " ORDER BY id DESC LIMIT 1"
        cursor.execute(query, params)
        return _session_row_to_dict(cursor, cursor.fetchone())
    finally:
        conn.close()


def get_session_by_id(session_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, subject, generation_mode, difficulty, progress, source_text, created_at, updated_at, last_studied_at
            FROM study_sessions
            WHERE id = ?
            """,
            (session_id,),
        )
        return _session_row_to_dict(cursor, cursor.fetchone())
    finally:
        conn.close()


def create_study_session(user_id, subject, curriculum, source_text=None, generation_mode="ai_only", difficulty="초급"):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            INSERT INTO study_sessions (user_id, subject, generation_mode, difficulty, source_text)
            VALUES (?, ?, ?, ?, ?)
            """,
            (user_id, subject, generation_mode, difficulty, source_text),
        )
        session_id = cursor.lastrowid
        _insert_curriculum(cursor, session_id, curriculum)
        conn.commit()
        return session_id
    finally:
        conn.close()


def _insert_curriculum(cursor, session_id, curriculum):
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


def get_study_sessions(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, subject, generation_mode, difficulty, progress, source_text, created_at, updated_at, last_studied_at
            FROM study_sessions
            WHERE user_id = ?
            ORDER BY COALESCE(last_studied_at, updated_at, created_at) DESC, id DESC
            """,
            (user_id,),
        )
        return [_session_row_to_dict(cursor, row) for row in cursor.fetchall()]
    finally:
        conn.close()


def update_session_generation_settings(session_id: int, generation_mode: str, difficulty: str) -> bool:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE study_sessions SET generation_mode = ?, difficulty = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (generation_mode, difficulty, session_id),
        )
        conn.commit()
        return cursor.rowcount > 0
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
                    WHEN source_text IS NULL OR TRIM(source_text) = '' THEN ?
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
        _insert_curriculum(cursor, session_id, curriculum)
        cursor.execute("UPDATE study_sessions SET progress = 0.0, updated_at = CURRENT_TIMESTAMP WHERE id = ?", (session_id,))
        conn.commit()
        return True
    finally:
        conn.close()


def update_lesson_completion(session_id, lesson_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT level FROM lessons WHERE session_id = ? AND id = ?", (session_id, lesson_id))
        current_lesson = cursor.fetchone()
        if not current_lesson:
            return False
        current_level = current_lesson["level"]
        cursor.execute("UPDATE lessons SET is_completed = 1, is_locked = 0 WHERE id = ?", (lesson_id,))
        cursor.execute("UPDATE lessons SET is_locked = 0 WHERE session_id = ? AND level = ?", (session_id, current_level + 1))
        cursor.execute("SELECT COUNT(*) as total, SUM(is_completed) as completed FROM lessons WHERE session_id = ?", (session_id,))
        progress_row = cursor.fetchone()
        total = progress_row["total"]
        completed = progress_row["completed"] or 0
        progress = float(completed) / float(total) if total > 0 else 0.0
        cursor.execute("UPDATE study_sessions SET progress = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", (progress, session_id))
        conn.commit()
        return True
    finally:
        conn.close()


def get_session_source_text(session_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT source_text FROM study_sessions WHERE id = ?", (session_id,))
        row = cursor.fetchone()
        return row["source_text"] if row else None
    finally:
        conn.close()


# Question / Answer Helpers
def _question_answer(question: dict) -> str:
    return first_non_empty(
        question.get("answer"),
        question.get("correct_answer"),
        question.get("model_answer"),
        question.get("sample_answer"),
        question.get("expected_answer"),
    )


def first_non_empty(*values) -> str:
    for value in values:
        text = str(value).strip() if value is not None else ""
        if text:
            return text
    return ""


def _insert_question(cursor, session_id: int, question: dict) -> int:
    q_type = question.get("type") or question.get("question_type") or "multiple_choice"
    options = question.get("options") if isinstance(question.get("options"), list) else []
    model_answer = first_non_empty(question.get("model_answer"), question.get("modelAnswer"), question.get("sample_answer"), question.get("sampleAnswer"), question.get("expected_answer"), question.get("expectedAnswer"))
    cursor.execute(
        """
        INSERT INTO questions (session_id, question_type, difficulty, question_text, options_json, correct_answer, model_answer, explanation, raw_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            session_id,
            q_type,
            question.get("difficulty", "초급"),
            question.get("question") or question.get("question_text") or "",
            json.dumps(options, ensure_ascii=False),
            _question_answer(question),
            model_answer,
            question.get("explanation", ""),
            json.dumps(question, ensure_ascii=False),
        ),
    )
    return cursor.lastrowid


def save_generated_questions(session_id: int, questions: list[dict]) -> list[dict]:
    if session_id <= 0:
        return questions
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        saved = []
        for question in questions:
            question_id = _insert_question(cursor, session_id, question)
            saved_question = dict(question)
            saved_question["id"] = question_id
            saved.append(saved_question)
        cursor.execute("UPDATE study_sessions SET updated_at = CURRENT_TIMESTAMP WHERE id = ?", (session_id,))
        conn.commit()
        return saved
    finally:
        conn.close()


def _ensure_question_for_answer(cursor, session_id: int, question_id: int, payload: dict) -> int:
    if question_id > 0:
        cursor.execute("SELECT id FROM questions WHERE id = ?", (question_id,))
        if cursor.fetchone():
            return question_id
    question = {
        "type": payload.get("question_type", "multiple_choice"),
        "difficulty": payload.get("difficulty", "초급"),
        "question": payload.get("question_text", ""),
        "options": payload.get("options", []),
        "answer": payload.get("correct_answer", ""),
        "model_answer": payload.get("model_answer", ""),
        "explanation": payload.get("explanation", ""),
    }
    return _insert_question(cursor, session_id, question)


def _record_daily(cursor, user_id: int, subject: str, is_correct: bool):
    study_date = date.today().isoformat()
    cursor.execute("SELECT * FROM study_daily_records WHERE user_id = ? AND study_date = ?", (user_id, study_date))
    row = cursor.fetchone()
    if row:
        topics = [item.strip() for item in (row["studied_topics"] or "").split(",") if item.strip()]
        if subject and subject not in topics:
            topics.append(subject)
        cursor.execute(
            """
            UPDATE study_daily_records
            SET solved_count = solved_count + 1,
                correct_count = correct_count + ?,
                wrong_count = wrong_count + ?,
                studied_topics = ?
            WHERE id = ?
            """,
            (1 if is_correct else 0, 0 if is_correct else 1, ", ".join(topics), row["id"]),
        )
    else:
        cursor.execute(
            """
            INSERT INTO study_daily_records (user_id, study_date, solved_count, correct_count, wrong_count, studied_topics)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (user_id, study_date, 1, 1 if is_correct else 0, 0 if is_correct else 1, subject or ""),
        )


def record_answer(
    user_id: int,
    session_id: int,
    question_id: int,
    subject: str,
    question_type: str,
    difficulty: str,
    question_text: str,
    options: list,
    correct_answer: str,
    model_answer: str,
    explanation: str,
    user_answer: str,
    is_correct: bool,
) -> int:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        payload = {
            "question_type": question_type,
            "difficulty": difficulty,
            "question_text": question_text,
            "options": options,
            "correct_answer": correct_answer,
            "model_answer": model_answer,
            "explanation": explanation,
        }
        real_question_id = _ensure_question_for_answer(cursor, session_id, question_id, payload)
        cursor.execute(
            """
            INSERT INTO answer_records (user_id, session_id, question_id, user_answer, is_correct)
            VALUES (?, ?, ?, ?, ?)
            """,
            (user_id, session_id, real_question_id, user_answer, 1 if is_correct else 0),
        )
        record_id = cursor.lastrowid
        cursor.execute(
            "UPDATE study_sessions SET last_studied_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (session_id,),
        )
        _record_daily(cursor, user_id, subject, is_correct)
        if not is_correct:
            _insert_incorrect_answer(
                cursor,
                user_id=user_id,
                session_id=session_id,
                question_id=real_question_id,
                subject=subject,
                question_type=question_type,
                difficulty=difficulty,
                question=question_text,
                options=options,
                answer=first_non_empty(model_answer, correct_answer),
                explanation=explanation,
                user_answer=user_answer,
            )
        conn.commit()
        return record_id
    finally:
        conn.close()


# Incorrect Answers Helpers
def _insert_incorrect_answer(cursor, user_id, session_id, question_id, subject, question_type, difficulty, question, options, answer, explanation, user_answer):
    cursor.execute(
        """
        INSERT INTO incorrect_answers (user_id, session_id, question_id, subject, question_type, difficulty, question, options_json, answer, explanation, user_answer)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (user_id, session_id, question_id, subject, question_type, difficulty, question, json.dumps(options, ensure_ascii=False), answer, explanation, user_answer),
    )
    return cursor.lastrowid


def add_incorrect_answer(user_id, subject, question, options, answer, explanation, user_answer, session_id=0, question_id=0, question_type="multiple_choice", difficulty="초급"):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        row_id = _insert_incorrect_answer(cursor, user_id, session_id, question_id, subject, question_type, difficulty, question, options, answer, explanation, user_answer)
        conn.commit()
        return row_id
    finally:
        conn.close()


def get_incorrect_answers(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT
                ia.id,
                ia.user_id,
                ia.session_id,
                ia.question_id,
                COALESCE(s.subject, ia.subject) AS subject,
                COALESCE(q.question_type, ia.question_type) AS question_type,
                COALESCE(q.difficulty, ia.difficulty) AS difficulty,
                COALESCE(q.question_text, ia.question) AS question,
                COALESCE(q.options_json, ia.options_json) AS options_json,
                COALESCE(q.correct_answer, ia.answer) AS answer,
                q.model_answer AS model_answer,
                q.raw_json AS raw_json,
                COALESCE(q.explanation, ia.explanation) AS explanation,
                ia.user_answer,
                ia.created_at,
                ia.is_reviewed
            FROM incorrect_answers ia
            LEFT JOIN questions q ON q.id = ia.question_id
            LEFT JOIN study_sessions s ON s.id = ia.session_id
            WHERE ia.user_id = ? AND COALESCE(ia.is_reviewed, 0) = 0
            ORDER BY ia.created_at DESC
            """,
            (user_id,),
        )
        answers = []
        for row in cursor.fetchall():
            answer = dict(row)
            raw_json = _json_loads(answer.pop("raw_json", None), {})
            answer["options"] = _json_loads(answer.pop("options_json", "[]"), [])
            answer["correct_answer"] = answer.get("answer", "")
            answer["sample_answer"] = raw_json.get("sample_answer") or raw_json.get("sampleAnswer") or ""
            answer["expected_answer"] = raw_json.get("expected_answer") or raw_json.get("expectedAnswer") or ""
            answers.append(answer)
        return answers
    finally:
        conn.close()


def delete_incorrect_answer(answer_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE incorrect_answers SET is_reviewed = 1 WHERE id = ?", (answer_id,))
        conn.commit()
        return cursor.rowcount > 0
    finally:
        conn.close()


# Calendar Helpers
def _calculate_streak(records: list[dict]) -> int:
    record_dates = {record["study_date"] for record in records if record.get("solved_count", 0) > 0}
    cursor_day = date.today()
    streak = 0
    while cursor_day.isoformat() in record_dates:
        streak += 1
        cursor_day -= timedelta(days=1)
    return streak


def get_study_calendar(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, study_date, solved_count, correct_count, wrong_count, studied_topics
            FROM study_daily_records
            WHERE user_id = ?
            ORDER BY study_date DESC
            """,
            (user_id,),
        )
        records = []
        for row in cursor.fetchall():
            record = dict(row)
            record["studied_topics"] = [item.strip() for item in (record.get("studied_topics") or "").split(",") if item.strip()]
            records.append(record)
        return {"records": records, "streak_days": _calculate_streak(records)}
    finally:
        conn.close()
