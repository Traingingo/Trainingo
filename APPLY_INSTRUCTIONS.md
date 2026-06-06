# Trainingo quiz setup / dashboard update

이 패키지는 `feature/quiz-setup-dashboard` 브랜치 기준으로 덮어쓸 변경 파일 모음입니다.
GitHub에 직접 push하지 못하는 환경에서는 아래 파일들을 프로젝트 루트에 같은 경로로 복사해서 적용하세요.

## 적용 방법

```bash
# 프로젝트 루트에서 실행
cp -R /path/to/trainingo_changes/lib ./
cp -R /path/to/trainingo_changes/backend ./

python backend/init_db.py
flutter pub get
```

Windows PowerShell에서는 압축을 해제한 뒤 `lib`, `backend` 폴더를 프로젝트 루트에 복사하면 됩니다.

## 새로 추가한 파일

- `lib/models/learning_level.dart`
- `lib/models/question_generation_mode.dart`
- `lib/models/question_setup_config.dart`
- `lib/screens/home/main_tab_screen.dart`
- `lib/screens/learning/question_setup_screen.dart`
- `lib/screens/learning/progressing_learning_screen.dart`
- `lib/screens/progress/study_calendar_screen.dart`

## 수정한 파일

- `lib/models/question_generation_config.dart`
- `lib/providers/learning_provider.dart`
- `lib/providers/question_provider.dart`
- `lib/routes/app_routes.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/learning/lesson_list_screen.dart`
- `lib/screens/learning/question_screen.dart`
- `lib/screens/materials/material_upload_screen.dart`
- `lib/screens/review/review_screen.dart`
- `lib/services/question_service.dart`
- `backend/main.py`
- `backend/database.py`
- `backend/schema.sql`

## 삭제한 파일

없음.

## 로컬 확인

이 패키지 생성 과정에서 확인한 항목:

- `python3 -m py_compile backend/database.py backend/main.py`
- SQLite DB 초기화 및 최소 CRUD smoke test

Flutter SDK/Dart CLI가 없는 실행 환경이어서 `flutter analyze`는 여기서 수행하지 못했습니다. 적용 후 아래 명령으로 확인하세요.

```bash
flutter analyze
flutter test
```
