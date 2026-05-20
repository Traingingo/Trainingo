# trainingo

A new Flutter project.

## 폴더 구조
```bash
lib/
 ┣ main.dart
 ┣ core/
 ┃ ┣ constants/
 ┃ ┣ theme/
 ┃ ┣ utils/
 ┣ models/
 ┃ ┣ user_model.dart
 ┃ ┣ question_model.dart
 ┃ ┣ lesson_model.dart
 ┃ ┣ study_material_model.dart
 ┣ services/
 ┃ ┣ api_service.dart
 ┃ ┣ auth_service.dart
 ┃ ┣ question_service.dart
 ┃ ┣ material_service.dart
 ┣ providers/ 또는 bloc/
 ┃ ┣ auth_provider.dart
 ┃ ┣ learning_provider.dart
 ┃ ┣ question_provider.dart
 ┣ screens/
 ┃ ┣ auth/
 ┃ ┣ home/
 ┃ ┣ learning/
 ┃ ┣ materials/
 ┃ ┣ review/
 ┣ widgets/
 ┃ ┣ common/
 ┃ ┣ question/
 ┃ ┣ progress/
 ┗ routes/
   ┗ app_routes.dart
```

---
## requirements.txt

로컬 터미널에서 아래 코드 실행
```bash
flutter pub get
```

---