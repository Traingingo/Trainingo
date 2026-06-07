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