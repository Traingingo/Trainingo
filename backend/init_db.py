from . import database


def main():
    database.init_db()
    print(f"DB file: {database.get_db_path()}")


if __name__ == "__main__":
    main()
