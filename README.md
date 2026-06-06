# Trainingo

Flutter + FastAPI + SQLite 기반 AI 학습 로드맵/퀴즈 생성 프로젝트입니다.

## 문서 구분

이 문서는 **전체 프로젝트를 로컬에서 실행하는 방법**을 설명합니다.

백엔드 환경 변수, Python 가상환경, DB 초기화처럼 백엔드 자체 설정만 확인하려면 아래 문서를 참고하세요.

```text
backend/README.md
```

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
 ┣ README.md        # 백엔드 전용 설정 가이드
 ┗ requirements.txt
```

## 전체 실행 흐름

Trainingo는 터미널을 최소 2개 사용합니다.

```text
터미널 1: FastAPI 백엔드 서버 실행
터미널 2: Flutter 앱 실행
```

처음 실행하는 팀원은 아래 순서대로 진행하면 됩니다.

1. 백엔드 환경 변수 설정
2. 백엔드 패키지 설치
3. DB 초기화
4. 백엔드 서버 실행
5. Flutter 앱 실행

백엔드 환경 변수와 DB 초기화에 대한 자세한 설명은 `backend/README.md`에 있습니다.

---

## 1. 최초 백엔드 준비

프로젝트 루트에서 실행합니다.

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
copy backend\.env.example backend\.env
python -m venv backend\.venv
backend\.venv\Scripts\activate
pip install -r backend\requirements.txt
python backend\init_db.py
```

그 다음 `backend/.env` 파일을 열고 `GROQ_API_KEY`를 입력합니다.

```env
GROQ_API_KEY=your_groq_api_key_here
DATABASE_URL=sqlite:///./backend/trainingo.db
```

`.env` 파일은 GitHub에 올리면 안 됩니다.

---

## 2. 실행 방법 A: 실제 피지컬 디바이스 USB 연결

실제 휴대폰을 USB로 연결해서 앱을 실행하는 방식입니다.

이 방식은 `adb reverse`를 사용하면 PC IP 주소를 직접 입력하지 않아도 됩니다.

### 터미널 1: 백엔드 실행

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

정상 실행 확인:

```text
http://127.0.0.1:8000
http://127.0.0.1:8000/docs
```

### 터미널 2: ADB reverse 설정 후 Flutter 실행

`adb`가 PATH에 등록되어 있으면:

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
adb devices
adb reverse tcp:8000 tcp:8000
adb reverse --list
flutter pub get
flutter run
```

`adb`가 인식되지 않으면 전체 경로로 실행합니다.

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse --list
flutter pub get
flutter run
```

이 방식에서는 Flutter 앱의 백엔드 주소가 아래처럼 되어 있어도 실제 휴대폰에서 PC 백엔드로 연결됩니다.

```text
http://127.0.0.1:8000
```

연결 구조:

```text
피지컬 디바이스 Flutter 앱
        ↓
http://127.0.0.1:8000
        ↓
USB 연결 + adb reverse
        ↓
PC FastAPI 백엔드 서버
```

> 휴대폰을 뺐다 꽂거나 재부팅하면 `adb reverse`가 풀릴 수 있습니다. 이 경우 다시 `adb reverse tcp:8000 tcp:8000`을 실행하세요.

---

## 3. 실행 방법 B: 실제 피지컬 디바이스에서 PC IP로 직접 접근

USB reverse를 사용하지 않고 같은 Wi-Fi의 PC IP로 직접 접근하는 방식입니다.

### 터미널 1: 백엔드 실행

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

Windows에서 PC IP 확인:

```powershell
ipconfig
```

예를 들어 IPv4 주소가 `192.168.0.15`라면 Flutter 앱의 백엔드 주소는 아래처럼 사용합니다.

```text
http://192.168.0.15:8000
```

### 터미널 2: Flutter 실행

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
flutter pub get
flutter run
```

> 이 방식은 PC와 휴대폰이 같은 Wi-Fi에 연결되어 있어야 합니다.

---

## 4. 실행 방법 C: Android Emulator 가상 디바이스

Android Emulator에서 실행하는 방식입니다.

Emulator에서 PC의 localhost는 `10.0.2.2`로 접근합니다.

### 터미널 1: 백엔드 실행

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Flutter 앱의 백엔드 주소는 아래처럼 사용합니다.

```text
http://10.0.2.2:8000
```

### 터미널 2: Flutter 실행

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
flutter pub get
flutter run
```

또는 Android Studio에서 Emulator를 선택하고 실행 버튼을 누르면 됩니다.

---

## 5. 실행 방법 D: Flutter Web / Windows Desktop

### 백엔드 실행

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
backend\.venv\Scripts\activate
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

### Flutter Web 실행

```powershell
flutter pub get
flutter run -d chrome
```

### Windows Desktop 실행

```powershell
flutter pub get
flutter run -d windows
```

이 경우 Flutter 앱의 백엔드 주소는 아래 값을 사용합니다.

```text
http://127.0.0.1:8000
```

---

## 실행 환경별 백엔드 주소 정리

| 실행 환경 | Flutter 백엔드 주소 | 백엔드 실행 host | 추가 설정 |
| --- | --- | --- | --- |
| 피지컬 디바이스 USB + adb reverse | `http://127.0.0.1:8000` | `127.0.0.1` | `adb reverse tcp:8000 tcp:8000` |
| 피지컬 디바이스 PC IP 직접 접근 | `http://PC_IP:8000` | `0.0.0.0` | 같은 Wi-Fi 필요 |
| Android Emulator | `http://10.0.2.2:8000` | `127.0.0.1` | 별도 reverse 불필요 |
| Flutter Web | `http://127.0.0.1:8000` | `127.0.0.1` | 백엔드만 실행 |
| Windows Desktop | `http://127.0.0.1:8000` | `127.0.0.1` | 백엔드만 실행 |

---

## 자주 발생하는 오류

### `Connection refused`

백엔드 서버가 꺼져 있거나, 앱의 백엔드 주소가 실행 환경과 맞지 않을 때 발생합니다.

확인할 것:

1. 백엔드 서버가 실행 중인지 확인
2. 실제 휴대폰 USB 실행이면 `adb reverse tcp:8000 tcp:8000` 실행 여부 확인
3. Android Emulator면 백엔드 주소가 `10.0.2.2:8000`인지 확인
4. Web/Windows면 백엔드 주소가 `127.0.0.1:8000`인지 확인
5. 브라우저에서 `http://127.0.0.1:8000/docs` 접속 확인

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

백엔드 환경 변수, DB 초기화, 백엔드 단독 실행 설정은 `backend/README.md`를 참고하세요.
