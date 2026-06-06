# Trainingo

Flutter + FastAPI + SQLite 기반 AI 학습 로드맵/퀴즈 생성 프로젝트입니다.

## 주요 구조

```bash
lib/
 ┣ main.dart
 ┣ core/
 ┣ models/
 ┣ providers/
 ┣ routes/
 ┣ screens/
 ┣ services/
 ┗ widgets/

backend/
 ┣ main.py          # FastAPI API 서버
 ┣ database.py      # DB 연결 및 CRUD 함수
 ┣ init_db.py       # DB 초기화 전용 실행 파일
 ┣ schema.sql       # SQLite 스키마
 ┣ .env.example     # 백엔드 환경 변수 예시
 ┣ README.md        # 백엔드 실행 가이드
 ┗ requirements.txt
```

## 로컬 실행 전 준비

### 1. 백엔드 환경 변수 설정

`backend/.env.example` 파일을 복사해서 `backend/.env` 파일을 만듭니다.

```powershell
copy backend\.env.example backend\.env
```

`backend/.env` 파일에 Groq API 키를 입력합니다.

```env
GROQ_API_KEY=your_groq_api_key_here
DATABASE_URL=sqlite:///./backend/trainingo.db
# DB_PATH=./backend/trainingo.db
```

`GROQ_API_KEY`는 AI 커리큘럼/문제 생성을 위해 필요합니다.

`DATABASE_URL`은 SQLite DB 파일 위치입니다. 기본값 그대로 사용하면 프로젝트 루트 기준 `backend/trainingo.db` 파일을 사용합니다.

> `.env` 파일은 개인 API 키가 들어가므로 GitHub에 올리면 안 됩니다.

---

### 2. 백엔드 패키지 설치

프로젝트 루트에서 실행합니다.

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
python -m venv backend\.venv
backend\.venv\Scripts\activate
pip install -r backend\requirements.txt
```

이미 가상환경을 만들었다면 아래만 실행하면 됩니다.

```powershell
backend\.venv\Scripts\activate
pip install -r backend\requirements.txt
```

---

### 3. SQLite DB 초기화

프로젝트 루트에서 실행합니다.

```powershell
python backend\init_db.py
```

실행 후 `backend/trainingo.db` 파일이 생성되면 정상입니다.

---

## 로컬 터미널 실행 방법

Trainingo는 백엔드 서버와 Flutter 앱을 **서로 다른 터미널**에서 실행합니다.

### 터미널 1: FastAPI 백엔드 실행

프로젝트 루트에서 실행합니다.

```powershell
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

정상 실행 확인:

```text
http://127.0.0.1:8000
http://127.0.0.1:8000/docs
```

실제 휴대폰이나 외부 기기에서 PC IP로 접근해야 한다면 아래처럼 실행할 수 있습니다.

```powershell
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

---

### 터미널 2: Flutter 앱 실행

프로젝트 루트에서 실행합니다.

```powershell
flutter pub get
flutter run
```

Chrome으로 실행할 경우:

```powershell
flutter run -d chrome
```

Windows 데스크톱으로 실행할 경우:

```powershell
flutter run -d windows
```

---

## 실제 핸드폰 USB 연결 실행

Flutter 앱의 백엔드 주소가 `http://127.0.0.1:8000`으로 되어 있다면, 실제 핸드폰에서는 `adb reverse`를 설정해야 합니다.

### 1. 백엔드 실행

```powershell
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

### 2. 다른 터미널에서 ADB 연결

`adb`가 PATH에 등록되어 있으면:

```powershell
adb devices
adb reverse tcp:8000 tcp:8000
adb reverse --list
```

`adb`가 인식되지 않으면 전체 경로로 실행합니다.

```powershell
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse --list
```

그 다음 Flutter 앱을 실행합니다.

```powershell
flutter run
```

`adb reverse`를 사용하면 실제 핸드폰 앱에서 `http://127.0.0.1:8000`으로 요청해도 PC에서 실행 중인 FastAPI 서버로 연결됩니다.

---

## Android Emulator 실행

Android Emulator에서 실행할 때는 보통 Flutter의 백엔드 주소를 아래처럼 사용합니다.

```dart
http://10.0.2.2:8000
```

`10.0.2.2`는 Android Emulator에서 PC의 localhost를 가리키는 주소입니다.

---

## 실행 환경별 백엔드 주소

| 실행 환경 | Flutter 백엔드 주소 | 추가 설정 |
| --- | --- | --- |
| 실제 핸드폰 USB | `http://127.0.0.1:8000` | `adb reverse tcp:8000 tcp:8000` 필요 |
| Android Emulator | `http://10.0.2.2:8000` | 보통 별도 reverse 불필요 |
| Flutter Web | `http://127.0.0.1:8000` | 백엔드 서버만 실행 |
| Windows Desktop | `http://127.0.0.1:8000` | 백엔드 서버만 실행 |

---

## 자주 발생하는 오류

### `Connection refused`

백엔드 서버가 꺼져 있거나, 앱이 잘못된 주소로 요청하고 있는 경우입니다.

확인할 것:

1. 백엔드 서버가 실행 중인지 확인
2. 실제 핸드폰이면 `adb reverse tcp:8000 tcp:8000` 실행 여부 확인
3. Android Emulator면 `10.0.2.2:8000` 사용 여부 확인
4. 브라우저에서 `http://127.0.0.1:8000/docs` 접속 확인

### `adb` 명령어가 인식되지 않는 경우

Android SDK Platform-Tools 경로를 직접 사용합니다.

```powershell
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
```

또는 환경 변수 `Path`에 아래 경로를 추가합니다.

```text
C:\Users\User\AppData\Local\Android\Sdk\platform-tools
```

### `No pubspec.yaml file found`

Flutter 프로젝트 루트가 아닌 곳에서 실행한 경우입니다.

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
flutter run
```

---

## 참고

백엔드 실행에 대한 자세한 내용은 `backend/README.md`를 참고하세요.
