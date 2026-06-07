import json
import os
import sqlite3
from datetime import date, timedelta
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional
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


def _table_columns(cursor: sqlite3.Cursor, table_name: str) -> set[str]:
    cursor.execute(f"PRAGMA table_info({table_name})")
    return {row[1] for row in cursor.fetchall()}


def _ensure_column(cursor: sqlite3.Cursor, table_name: str, column_name: str, column_sql: str) -> None:
    if column_name not in _table_columns(cursor, table_name):
        cursor.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_sql}")


def _migrate_schema(conn: sqlite3.Connection) -> None:
    cursor = conn.cursor()

    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='study_sessions'")
    if cursor.fetchone():
        _ensure_column(cursor, "study_sessions", "generation_mode", "generation_mode TEXT DEFAULT 'ai_only'")
        _ensure_column(cursor, "study_sessions", "difficulty", "difficulty TEXT DEFAULT 'beginner'")
        _ensure_column(cursor, "study_sessions", "last_studied_at", "last_studied_at TIMESTAMP")

    conn.commit()


def init_db():
    if not SCHEMA_PATH.exists():
        raise FileNotFoundError(f"DB schema file not found: {SCHEMA_PATH}")

    conn = get_db_connection()
    try:
        with SCHEMA_PATH.open("r", encoding="utf-8") as schema_file:
            conn.executescript(schema_file.read())
        _migrate_schema(conn)
        conn.commit()
        print(f"SQLite Database initialized successfully: {DB_PATH}")
    finally:
        conn.close()


def _safe_json_loads(value: Any, fallback: Any) -> Any:
    if value is None:
        return fallback
    if isinstance(value, (list, dict)):
        return value
    try:
        return json.loads(str(value))
    except (json.JSONDecodeError, TypeError, ValueError):
        return fallback


def _lesson_row_to_dict(row):
    lesson = dict(row)
    lesson["isLocked"] = bool(lesson.get("is_locked", 0))
    lesson["isCompleted"] = bool(lesson.get("is_completed", 0))
    return lesson


def _fetch_curriculum(cursor: sqlite3.Cursor, session_id: int) -> List[Dict[str, Any]]:
    cursor.execute(
        """
        SELECT id, level, title, description, is_locked, is_completed
        FROM lessons
        WHERE session_id = ?
        ORDER BY level ASC, id ASC
        """,
        (session_id,),
    )
    return [_lesson_row_to_dict(row) for row in cursor.fetchall()]


def _session_row_to_dict(cursor: sqlite3.Cursor, row):
    if not row:
        return None

    session = dict(row)
    session["curriculum"] = _fetch_curriculum(cursor, session["id"])
    session["topic"] = session.get("subject", "")
    session["generation_mode"] = session.get("generation_mode") or "ai_only"
    session["difficulty"] = session.get("difficulty") or "beginner"
    return session


# User Authentication Helpers
def register_user(email: str, password: str, nickname: str):
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


def login_user(email: str, password: str):
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
def get_session_by_subject(user_id: int, subject: str):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, subject, generation_mode, difficulty, progress,
                   source_text, created_at, updated_at, last_studied_at
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
            SELECT id, user_id, subject, generation_mode, difficulty, progress,
                   source_text, created_at, updated_at, last_studied_at
            FROM study_sessions
            WHERE id = ?
            """,
            (session_id,),
        )
        return _session_row_to_dict(cursor, cursor.fetchone())
    finally:
        conn.close()


def create_study_session(
    user_id: int,
    subject: str,
    curriculum: Iterable[Dict[str, Any]],
    source_text: Optional[str] = None,
    generation_mode: str = "ai_only",
    difficulty: str = "beginner",
) -> int:
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


def get_study_sessions(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, subject, generation_mode, difficulty, progress,
                   source_text, created_at, updated_at, last_studied_at
            FROM study_sessions
            WHERE user_id = ?
            ORDER BY COALESCE(last_studied_at, updated_at, created_at) DESC, id DESC
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
        return [_session_row_to_dict(cursor, row) for row in rows]
    finally:
        conn.close()


def update_session_setup(session_id: int, generation_mode: str, difficulty: str) -> bool:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE study_sessions
            SET generation_mode = ?, difficulty = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
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


def replace_session_curriculum(session_id: int, curriculum: Iterable[Dict[str, Any]]) -> bool:
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


def update_lesson_completion(session_id: int, lesson_id: int) -> bool:
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
            """
            UPDATE study_sessions
            SET progress = ?, updated_at = CURRENT_TIMESTAMP, last_studied_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (progress, session_id),
        )
        conn.commit()
        return True
    finally:
        conn.close()


def get_session_source_text(session_id: int):
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


# Question and Answer Helpers
def _first_non_empty(*values: Any) -> str:
    for value in values:
        text = str(value).strip() if value is not None else ""
        if text:
            return text
    return ""


def _question_payload_to_columns(question: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "question_type": question.get("type") or question.get("question_type") or "multiple_choice",
        "difficulty": question.get("difficulty") or "beginner",
        "question_text": question.get("question") or question.get("question_text") or "",
        "options_json": json.dumps(question.get("options") or [], ensure_ascii=False),
        "correct_answer": _first_non_empty(question.get("answer"), question.get("correct_answer")),
        "model_answer": _first_non_empty(question.get("model_answer"), question.get("modelAnswer")),
        "sample_answer": _first_non_empty(question.get("sample_answer"), question.get("sampleAnswer")),
        "expected_answer": _first_non_empty(question.get("expected_answer"), question.get("expectedAnswer")),
        "explanation": question.get("explanation") or "",
        "source_type": question.get("source_type") or "AI",
    }


def save_generated_questions(session_id: int, questions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    if session_id <= 0:
        for index, question in enumerate(questions):
            question["id"] = index + 1
        return questions

    conn = get_db_connection()
    cursor = conn.cursor()
    saved_questions: List[Dict[str, Any]] = []
    try:
        for question in questions:
            columns = _question_payload_to_columns(question)
            cursor.execute(
                """
                INSERT INTO questions (
                    session_id, question_type, difficulty, question_text, options_json,
                    correct_answer, model_answer, sample_answer, expected_answer,
                    explanation, source_type
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    session_id,
                    columns["question_type"],
                    columns["difficulty"],
                    columns["question_text"],
                    columns["options_json"],
                    columns["correct_answer"],
                    columns["model_answer"],
                    columns["sample_answer"],
                    columns["expected_answer"],
                    columns["explanation"],
                    columns["source_type"],
                ),
            )
            saved = dict(question)
            saved["id"] = cursor.lastrowid
            saved_questions.append(saved)

        cursor.execute(
            "UPDATE study_sessions SET updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (session_id,),
        )
        conn.commit()
        return saved_questions
    finally:
        conn.close()


def _upsert_calendar(cursor: sqlite3.Cursor, user_id: int, session_id: int, is_correct: bool) -> None:
    study_date = date.today().isoformat()
    cursor.execute("SELECT subject FROM study_sessions WHERE id = ?", (session_id,))
    session_row = cursor.fetchone()
    topic = session_row["subject"] if session_row else "이름 없는 학습"

    cursor.execute(
        "SELECT id, studied_topics_json FROM study_calendar WHERE user_id = ? AND study_date = ?",
        (user_id, study_date),
    )
    row = cursor.fetchone()
    if row:
        topics = _safe_json_loads(row["studied_topics_json"], [])
        if topic and topic not in topics:
            topics.append(topic)
        cursor.execute(
            """
            UPDATE study_calendar
            SET solved_count = solved_count + 1,
                correct_count = correct_count + ?,
                wrong_count = wrong_count + ?,
                studied_topics_json = ?
            WHERE id = ?
            """,
            (1 if is_correct else 0, 0 if is_correct else 1, json.dumps(topics, ensure_ascii=False), row["id"]),
        )
    else:
        cursor.execute(
            """
            INSERT INTO study_calendar (user_id, study_date, solved_count, correct_count, wrong_count, studied_topics_json)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                study_date,
                1,
                1 if is_correct else 0,
                0 if is_correct else 1,
                json.dumps([topic] if topic else [], ensure_ascii=False),
            ),
        )


def add_answer_record(user_id: int, session_id: int, question_id: int, user_answer: str, is_correct: bool) -> Optional[int]:
    if session_id <= 0 or question_id <= 0:
        return None

    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            INSERT INTO answer_records (user_id, session_id, question_id, user_answer, is_correct)
            VALUES (?, ?, ?, ?, ?)
            """,
            (user_id, session_id, question_id, user_answer, 1 if is_correct else 0),
        )
        row_id = cursor.lastrowid
        cursor.execute(
            """
            UPDATE study_sessions
            SET last_studied_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (session_id,),
        )
        _upsert_calendar(cursor, user_id, session_id, is_correct)
        conn.commit()
        return row_id
    finally:
        conn.close()


def _create_question_from_incorrect_payload(
    cursor: sqlite3.Cursor,
    session_id: int,
    subject: str,
    question: str,
    options: Iterable[str],
    answer: str,
    model_answer: str,
    explanation: str,
    question_type: str,
    difficulty: str,
) -> int:
    cursor.execute(
        """
        INSERT INTO questions (
            session_id, question_type, difficulty, question_text, options_json,
            correct_answer, model_answer, sample_answer, expected_answer, explanation, source_type
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            session_id if session_id > 0 else None,
            question_type or "multiple_choice",
            difficulty or "beginner",
            question or f"{subject} 오답 문제",
            json.dumps(list(options), ensure_ascii=False),
            answer,
            model_answer or answer,
            model_answer or answer,
            answer,
            explanation,
            "AI",
        ),
    )
    return cursor.lastrowid


def add_incorrect_answer(
    user_id: int,
    subject: str,
    question: str,
    options: Iterable[str],
    answer: str,
    explanation: str,
    user_answer: str,
    session_id: int = 0,
    question_id: int = 0,
    question_type: str = "",
    difficulty: str = "",
    model_answer: str = "",
):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        if question_id <= 0:
            question_id = _create_question_from_incorrect_payload(
                cursor,
                session_id,
                subject,
                question,
                options,
                answer,
                model_answer,
                explanation,
                question_type,
                difficulty,
            )
        else:
            # 생성된 문제에 모범답안이 빠진 경우 오답노트 표시용으로 보강합니다.
            if answer or model_answer:
                cursor.execute(
                    """
                    UPDATE questions
                    SET correct_answer = COALESCE(NULLIF(correct_answer, ''), ?),
                        model_answer = COALESCE(NULLIF(model_answer, ''), ?),
                        sample_answer = COALESCE(NULLIF(sample_answer, ''), ?),
                        expected_answer = COALESCE(NULLIF(expected_answer, ''), ?)
                    WHERE id = ?
                    """,
                    (answer, model_answer or answer, model_answer or answer, answer, question_id),
                )

        cursor.execute(
            """
            SELECT id FROM incorrect_answer_notes
            WHERE user_id = ? AND question_id = ? AND is_reviewed = 0
            """,
            (user_id, question_id),
        )
        existing = cursor.fetchone()
        if existing:
            conn.commit()
            return existing["id"]

        cursor.execute(
            """
            INSERT INTO incorrect_answer_notes (user_id, session_id, question_id)
            VALUES (?, ?, ?)
            """,
            (user_id, session_id if session_id > 0 else None, question_id),
        )
        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()


def _legacy_incorrect_answers(cursor: sqlite3.Cursor, user_id: int) -> List[Dict[str, Any]]:
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
    except sqlite3.OperationalError:
        return []

    answers = []
    for row in cursor.fetchall():
        answer = dict(row)
        answer["options"] = _safe_json_loads(answer.get("options_json"), [])
        answer["question_text"] = answer.get("question", "")
        answer["correct_answer"] = answer.get("answer", "")
        answer["model_answer"] = answer.get("answer", "")
        answer["question_type"] = "legacy"
        answer["difficulty"] = ""
        answer["is_reviewed"] = 0
        answer["_legacy"] = True
        answers.append(answer)
    return answers


def get_incorrect_answers(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT
                note.id,
                note.user_id,
                note.session_id,
                note.question_id,
                note.created_at,
                note.is_reviewed,
                sessions.subject,
                sessions.generation_mode,
                questions.question_type,
                questions.difficulty,
                questions.question_text,
                questions.options_json,
                questions.correct_answer,
                questions.model_answer,
                questions.sample_answer,
                questions.expected_answer,
                questions.explanation,
                (
                    SELECT ar.user_answer
                    FROM answer_records ar
                    WHERE ar.user_id = note.user_id AND ar.question_id = note.question_id
                    ORDER BY ar.answered_at DESC
                    LIMIT 1
                ) AS user_answer
            FROM incorrect_answer_notes note
            JOIN questions ON questions.id = note.question_id
            LEFT JOIN study_sessions sessions ON sessions.id = note.session_id
            WHERE note.user_id = ? AND note.is_reviewed = 0
            ORDER BY note.created_at DESC, note.id DESC
            """,
            (user_id,),
        )
        answers = []
        for row in cursor.fetchall():
            answer = dict(row)
            display_answer = _first_non_empty(
                answer.get("model_answer"),
                answer.get("sample_answer"),
                answer.get("expected_answer"),
                answer.get("correct_answer"),
            )
            answer["question"] = answer.get("question_text", "")
            answer["options"] = _safe_json_loads(answer.get("options_json"), [])
            answer["answer"] = display_answer
            answer["correct_answer"] = display_answer
            answer["user_answer"] = answer.get("user_answer") or ""
            answers.append(answer)

        answers.extend(_legacy_incorrect_answers(cursor, user_id))
        return answers
    finally:
        conn.close()


def delete_incorrect_answer(answer_id: int) -> bool:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE incorrect_answer_notes SET is_reviewed = 1 WHERE id = ?", (answer_id,))
        if cursor.rowcount == 0:
            try:
                cursor.execute("DELETE FROM incorrect_answers WHERE id = ?", (answer_id,))
            except sqlite3.OperationalError:
                pass
        conn.commit()
        return cursor.rowcount > 0
    finally:
        conn.close()


def _calculate_streak(record_dates: set[str]) -> int:
    streak = 0
    current = date.today()
    while current.isoformat() in record_dates:
        streak += 1
        current -= timedelta(days=1)
    return streak


def get_study_calendar(user_id: int) -> Dict[str, Any]:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT id, user_id, study_date, solved_count, correct_count, wrong_count, studied_topics_json
            FROM study_calendar
            WHERE user_id = ?
            ORDER BY study_date DESC
            """,
            (user_id,),
        )
        records = []
        for row in cursor.fetchall():
            item = dict(row)
            item["studied_topics"] = _safe_json_loads(item.pop("studied_topics_json", "[]"), [])
            solved = item.get("solved_count") or 0
            correct = item.get("correct_count") or 0
            item["accuracy"] = (correct / solved) if solved else 0.0
            records.append(item)

        record_dates = {item["study_date"] for item in records if item.get("solved_count", 0) > 0}
        return {"records": records, "streak_days": _calculate_streak(record_dates)}
    finally:
        conn.close()

def delete_study_session(user_id: int, session_id: int) -> bool:
    """
    진행 중인 학습 목록에서 학습 세션을 삭제합니다.
    세션과 연결된 lessons, questions, answer_records, incorrect_answer_notes도 함께 정리합니다.
    """
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            "SELECT id FROM study_sessions WHERE id = ? AND user_id = ?",
            (session_id, user_id),
        )
        if not cursor.fetchone():
            return False

        cursor.execute(
            "DELETE FROM incorrect_answer_notes WHERE user_id = ? AND session_id = ?",
            (user_id, session_id),
        )

        cursor.execute(
            "DELETE FROM answer_records WHERE user_id = ? AND session_id = ?",
            (user_id, session_id),
        )

        cursor.execute(
            "DELETE FROM questions WHERE session_id = ?",
            (session_id,),
        )

        cursor.execute(
            "DELETE FROM lessons WHERE session_id = ?",
            (session_id,),
        )

        cursor.execute(
            "DELETE FROM study_sessions WHERE id = ? AND user_id = ?",
            (session_id, user_id),
        )

        conn.commit()
        return cursor.rowcount > 0
    finally:
        conn.close()


def clear_incorrect_answers(user_id: int, session_id: Optional[int] = None) -> bool:
    """
    오답노트를 전체 삭제하거나, 특정 학습 세션의 오답만 삭제합니다.
    새 구조에서는 incorrect_answer_notes를 is_reviewed=1로 처리하고,
    예전 legacy incorrect_answers 테이블은 실제 삭제합니다.
    """
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        changed = 0

        if session_id is not None and session_id > 0:
            cursor.execute(
                """
                UPDATE incorrect_answer_notes
                SET is_reviewed = 1
                WHERE user_id = ? AND session_id = ? AND is_reviewed = 0
                """,
                (user_id, session_id),
            )
            changed += cursor.rowcount
        else:
            cursor.execute(
                """
                UPDATE incorrect_answer_notes
                SET is_reviewed = 1
                WHERE user_id = ? AND is_reviewed = 0
                """,
                (user_id,),
            )
            changed += cursor.rowcount

            try:
                cursor.execute(
                    "DELETE FROM incorrect_answers WHERE user_id = ?",
                    (user_id,),
                )
                changed += cursor.rowcount
            except sqlite3.OperationalError:
                pass

        conn.commit()
        return changed >= 0
    finally:
        conn.close()