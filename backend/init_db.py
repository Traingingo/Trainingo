import argparse
from pathlib import Path

try:
    from . import database
except ImportError:
    import database


def reset_db_file() -> None:
    db_path = Path(database.get_db_path())
    if db_path.exists():
        db_path.unlink()
        print(f"기존 DB 파일 삭제 완료: {db_path}")
    else:
        print(f"삭제할 기존 DB 파일이 없습니다: {db_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Trainingo SQLite DB 초기화/마이그레이션 도구"
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="기존 trainingo.db 파일을 삭제한 뒤 완전히 새 DB로 다시 생성합니다. 기존 학습/오답 데이터가 모두 삭제됩니다.",
    )
    args = parser.parse_args()

    if args.reset:
        reset_db_file()

    database.init_db()
    print(f"DB file: {database.get_db_path()}")

    if not args.reset:
        print("기존 데이터는 유지하고, 없는 테이블/컬럼만 추가했습니다.")
        print("DB를 완전히 비우려면: python init_db.py --reset")


if __name__ == "__main__":
    main()
