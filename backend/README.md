# Trainingo Backend 실행 가이드

Trainingo 백엔드는 FastAPI + Uvicorn + SQLite 기반 API 서버입니다.

Flutter 앱을 실행하기 전에 백엔드 서버가 먼저 켜져 있어야 합니다.

## 1. 백엔드 폴더 구조

```bash
backend/
 ┣ main.py          # FastAPI API 서버
 ┣ database.py      # SQLite 연결 및 CRUD 함수
 ┣ init_db.py       # DB 초기화 스크립트
 ┣ schema.sql       # DB 테이블 스키마
 ┣ .env.example     # 환경 변수 예시
 ┣ requirements.txt # Python 패키지 목록
 ┗ README.md
```

## 2. 환경 변수 설정

프로젝트 루트에서 `.env.example`을 복사해 `.env` 파일을 만듭니다.

```powershell
copy backend\.env.example backend\.env
```

`backend/.env` 파일을 열고 값을 입력합니다.

```env
GROQ_API_KEY=your_groq_api_key_here
DATABASE_URL=sqlite:///./backend/trainingo.db
# DB_PATH=./backend/trainingo.db
```

### 환경 변수 설명

| 변수명 | 설명 |
| --- | --- |
| `GROQ_API_KEY` | Groq API 키. AI 커리큘럼/문제 생성에 필요 |
| `DATABASE_URL` | SQLite DB 위치. 기본값은 `backend/trainingo.db` |
| `DB_PATH` | DB 파일 경로를 직접 지정할 때 사용. 보통은 주석 상태로 둬도 됨 |

`.env` 파일에는 개인 API 키가 들어가므로 GitHub에 올리면 안 됩니다.

## 3. Python 가상환경 생성 및 패키지 설치

프로젝트 루트에서 실행합니다.

```powershell
python -m venv backend\.venv
backend\.venv\Scripts\activate
pip install -r backend\requirements.txt
```

이미 가상환경이 있다면 다음만 실행합니다.

```powershell
backend\.venv\Scripts\activate
pip install -r backend\requirements.txt
```

## 4. DB 초기화

프로젝트 루트에서 실행합니다.

```powershell
python backend\init_db.py
```

정상 실행 후 `backend/trainingo.db` 파일이 생성됩니다.

## 5. 로컬 터미널에서 백엔드 실행

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

## 6. PyCharm에서 실행하는 경우

PyCharm에서 `Run > Edit Configurations...`로 이동합니다.

설정 예시:

```text
Module name: uvicorn
Parameters: backend.main:app --reload --host 127.0.0.1 --port 8000
Working directory: 프로젝트 루트 경로
```

실제 핸드폰에서 PC IP로 접근해야 하는 경우에는 host를 `0.0.0.0`으로 바꿀 수 있습니다.

```powershell
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

## 7. Flutter 앱과 연결

### Flutter Web / Windows Desktop

백엔드 주소:

```text
http://127.0.0.1:8000
```

### 실제 핸드폰 USB 연결

Flutter 앱의 백엔드 주소를 `http://127.0.0.1:8000`으로 유지하려면 ADB reverse를 사용합니다.

```powershell
adb reverse tcp:8000 tcp:8000
```

`adb`가 인식되지 않으면 전체 경로로 실행합니다.

```powershell
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
```

### Android Emulator

Android Emulator에서는 PC의 localhost를 아래 주소로 접근합니다.

```text
http://10.0.2.2:8000
```

## 8. 실행 요약

터미널 1에서 백엔드 실행:

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

터미널 2에서 실제 핸드폰 USB 연결 시:

```powershell
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
```

그 다음 Flutter 앱을 실행합니다.
