# Trainingo Backend 설정 가이드

이 문서는 **백엔드 서버 설정과 실행 방법만** 정리합니다.

Flutter 앱 실행 방법, Android Studio 실행 방법, 화면 테스트 방법은 루트 `README.md`를 참고하세요.

## 1. 백엔드 구조

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

프로젝트 루트에서 `.env.example`을 복사해서 `.env` 파일을 만듭니다.

```powershell
copy backend\.env.example backend\.env
```

`backend/.env` 파일을 열고 값을 입력합니다.

```env
GROQ_API_KEY=your_groq_api_key_here
DATABASE_URL=sqlite:///./backend/trainingo.db
# DB_PATH=./backend/trainingo.db
```

| 변수명 | 설명 |
| --- | --- |
| `GROQ_API_KEY` | Groq API 키입니다. AI 커리큘럼 생성과 문제 생성에 필요합니다. |
| `DATABASE_URL` | SQLite DB 위치입니다. 기본값은 `backend/trainingo.db`입니다. |
| `DB_PATH` | DB 파일 경로를 직접 지정할 때 사용하는 선택 설정입니다. 보통은 주석 상태로 둡니다. |

`.env` 파일에는 개인 API 키가 들어가므로 GitHub에 올리면 안 됩니다.

## 3. Python 가상환경 생성 및 패키지 설치

프로젝트 루트에서 실행합니다.

```powershell
python -m venv backend\.venv
backend\.venv\Scripts\activate
pip install -r backend\requirements.txt
```

이미 가상환경이 있다면 아래만 실행합니다.

```powershell
backend\.venv\Scripts\activate
pip install -r backend\requirements.txt
```

## 4. SQLite DB 초기화

프로젝트 루트에서 실행합니다.

```powershell
python backend\init_db.py
```

정상 실행 후 아래 파일이 생성되면 됩니다.

```text
backend/trainingo.db
```

## 5. 백엔드 서버 실행 방법

백엔드 서버는 실행 환경에 따라 `--host` 값을 다르게 사용할 수 있습니다.

### 5-1. 기본 로컬 실행

Flutter Web, Windows Desktop, 또는 USB 연결 + `adb reverse` 방식으로 실행할 때 사용합니다.

```powershell
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

정상 실행 확인:

```text
http://127.0.0.1:8000
http://127.0.0.1:8000/docs
```

### 5-2. 실제 피지컬 디바이스에서 PC IP로 접근할 때

실제 휴대폰에서 PC의 IP 주소로 직접 백엔드에 접근하려면 `0.0.0.0`으로 실행합니다.

```powershell
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

이 경우 같은 Wi-Fi에 연결된 휴대폰에서 아래 형태로 접근할 수 있습니다.

```text
http://PC의_IP주소:8000
```

예시:

```text
http://192.168.0.15:8000
```

### 5-3. Android Emulator에서 사용할 때

Android Emulator는 PC의 localhost를 `10.0.2.2`로 접근합니다.

백엔드는 아래처럼 실행하면 됩니다.

```powershell
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Flutter 앱 쪽 백엔드 주소는 아래 값을 사용합니다.

```text
http://10.0.2.2:8000
```

## 6. PyCharm 실행 설정

PyCharm에서 `Run > Edit Configurations...`로 이동합니다.

설정 예시:

```text
Module name: uvicorn
Parameters: backend.main:app --reload --host 127.0.0.1 --port 8000
Working directory: 프로젝트 루트 경로
```

피지컬 디바이스에서 PC IP로 직접 접근해야 한다면 Parameters를 아래처럼 바꿉니다.

```text
backend.main:app --reload --host 0.0.0.0 --port 8000
```

## 7. 백엔드 실행 요약

처음 한 번만:

```powershell
copy backend\.env.example backend\.env
python -m venv backend\.venv
backend\.venv\Scripts\activate
pip install -r backend\requirements.txt
python backend\init_db.py
```

이후 실행할 때:

```powershell
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

피지컬 디바이스에서 PC IP로 직접 접근할 때:

```powershell
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```
