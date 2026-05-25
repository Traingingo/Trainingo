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
 ┗ requirements.txt
```

## 이번 변경 사항

- Flutter Web 라우트 가드 추가
  - `/home`, `/lessons`, `/questions`, `/materials`, `/review` 직접 접근 시 로그인하지 않았으면 `/login`으로 이동합니다.
  - 로그인 사용자가 `/login`에 접근하면 `/home`으로 이동합니다.
  - `shared_preferences`로 로그인 사용자를 저장해 Web 새로고침 후에도 최대한 자연스럽게 복원합니다.
- 자료 업로드 개선
  - PDF, PPT, PPTX, TXT 파일을 여러 개 선택할 수 있습니다.
  - Flutter Web/Windows에서 동작하도록 `PlatformFile.bytes` 기반 multipart 업로드를 사용합니다.
  - 서버는 여러 파일의 추출 텍스트를 `[파일명: example.pdf]` 헤더와 함께 하나의 `source_text`로 합칩니다.
  - `.ppt`는 선택은 가능하지만 서버에서 안정적으로 읽을 수 없으므로 `.pptx` 변환 안내를 반환합니다.
- 기존 로드맵 자료 추가
  - `POST /api/upload-material`에 선택적으로 `session_id`, `regenerate_curriculum`을 보낼 수 있습니다.
  - `session_id`가 있으면 기존 `study_sessions.source_text` 뒤에 새 자료 텍스트를 append합니다.
  - `regenerate_curriculum=false`이면 기존 로드맵을 유지합니다.
  - `regenerate_curriculum=true`이면 누적 자료 기준으로 커리큘럼을 다시 생성합니다.
- 문제 수 변경
  - 프론트와 백엔드 기본 문제 수를 10개로 변경했습니다.
  - LLM이 10개보다 적게 반환하면 가능한 문제만 반환하고 서버 로그에 실제 생성 개수를 남깁니다.
- DB 초기화 분리
  - `main.py`에서 서버 시작 시 무조건 `database.init_db()`를 호출하지 않습니다.
  - DB 스키마는 `backend/schema.sql`, 초기화 실행은 `backend/init_db.py`로 분리했습니다.

## 백엔드 실행 방법

### 1. Python 패키지 설치

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 2. 환경 변수 준비

```bash
cp .env.example .env
```

`backend/.env` 예시:

```env
GROQ_API_KEY=your_groq_api_key_here
DATABASE_URL=sqlite:///./backend/trainingo.db
# 또는
# DB_PATH=./backend/trainingo.db
```

상대 경로는 프로젝트 루트를 기준으로 해석됩니다.

### 3. DB 초기화

프로젝트 루트에서 실행합니다.

```bash
python backend/init_db.py
```

정상 실행되면 `backend/trainingo.db`가 생성되고 다음 테이블을 확인할 수 있습니다.

- `users`
- `study_sessions`
- `lessons`
- `incorrect_answers`

### 4. FastAPI 서버 실행

프로젝트 루트에서 실행합니다.

```bash
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

기본 API 주소는 다음과 같습니다.

```text
http://127.0.0.1:8000
```

## Flutter 실행 방법

```bash
flutter pub get
flutter run -d chrome
```

Windows 데스크톱에서 확인하려면 다음처럼 실행할 수 있습니다.

```bash
flutter run -d windows
```

## DataGrip에서 SQLite DB 열기

1. DataGrip 실행
2. `+` 버튼 클릭 후 `Data Source` → `SQLite` 선택
3. `File` 항목에서 `backend/trainingo.db` 선택
4. 연결 테스트 실행
5. `users`, `study_sessions`, `lessons`, `incorrect_answers` 테이블 확인

DB 파일이 없으면 먼저 프로젝트 루트에서 아래 명령을 실행합니다.

```bash
python backend/init_db.py
```

## 주요 API

### 인증

- `POST /api/auth/register`
- `POST /api/auth/login`

### 학습 세션

- `GET /api/sessions?user_id=...`
- `POST /api/generate-curriculum`
- `POST /api/complete-lesson`

### 문제 생성

- `POST /api/generate-questions`
  - 기본 `count`는 10입니다.

### 자료 업로드

- `POST /api/upload-material`

새 로드맵 생성 multipart 필드:

```text
user_id=1
files=<multiple files>
```

기존 로드맵에 자료 추가 multipart 필드:

```text
user_id=1
session_id=3
regenerate_curriculum=false
files=<multiple files>
```

응답에는 최소 다음 값이 포함됩니다.

```json
{
  "session_id": 1,
  "subject": "[자료] example.pdf",
  "progress": 0.0,
  "curriculum": [],
  "uploaded_files": ["example.pdf"],
  "total_extracted_length": 1234
}
```

### 오답 노트

- `GET /api/incorrect-answers?user_id=...`
- `POST /api/incorrect-answers`
- `DELETE /api/incorrect-answers/{answer_id}`

## 테스트 체크리스트

### 라우트 가드

- 로그아웃 상태에서 브라우저 주소창에 `/home` 입력 → `/login` 화면 표시
- 로그아웃 상태에서 `/lessons`, `/questions`, `/materials`, `/review` 직접 접근 → `/login` 화면 표시
- 로그인 후 `/login` 직접 접근 → `/home` 화면 표시
- 로그인 후 새로고침 → 저장된 사용자 정보가 있으면 로그인 상태 복원

### 자료 업로드

- PDF/TXT/PPTX 파일 여러 개 선택 가능
- 여러 파일 업로드 후 새 로드맵 생성 가능
- 응답의 `uploaded_files`, `total_extracted_length` 확인
- `.ppt` 업로드 시 `.pptx` 변환 안내 메시지 확인

### 기존 로드맵 자료 추가

- 자료 업로드 화면에서 `기존 로드맵에 추가하기` 선택 가능
- `GET /api/sessions?user_id=...`로 불러온 로드맵 목록이 드롭다운에 표시
- `regenerate_curriculum=false`일 때 기존 커리큘럼 유지
- `regenerate_curriculum=true`일 때 커리큘럼 재생성

### 문제 생성

- 단원 학습 시작 시 기본 10문제 요청
- 문제 화면 상단에 `현재 문제/전체 문제` 표시
- LLM이 10개 미만 반환해도 화면이 깨지지 않고 가능한 문제만 진행
- 마지막 문제 완료 시 단원 완료 처리 및 다음 단계 잠금 해제

### DB / 백엔드

- `python backend/init_db.py`로 DB 초기화 가능
- `uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000`로 서버 실행 가능
- 서버 실행 시 DB를 매번 강제 초기화하지 않음
- DataGrip에서 `backend/trainingo.db`를 열어 테이블 확인 가능

## 개발 메모

현재 CORS는 Flutter Web 개발 편의를 위해 전체 허용입니다. 운영 배포 시에는 반드시 `allow_origins`를 실제 프론트엔드 도메인으로 제한해야 합니다.
