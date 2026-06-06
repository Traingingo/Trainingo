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

## 백엔드 실행 방법

## Flutter 실행 방법

Flutter 앱은 Android Studio에서 실행합니다.

실행 방식은 다음 두 가지로 나뉩니다.

1. 실제 핸드폰을 USB로 연결해서 실행
2. Android Emulator, 즉 가상 디바이스로 실행

실행 전에 PyCharm에서 FastAPI 백엔드 서버가 먼저 실행되어 있어야 합니다.

---

### 1. 백엔드 서버 실행 확인

프로젝트 루트에서 백엔드 서버를 실행합니다.

```bash
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

서버가 정상 실행되면 다음 주소에서 확인할 수 있습니다.

```text
http://127.0.0.1:8000
http://127.0.0.1:8000/docs
```

> 기존처럼 Flutter Web 또는 Windows 데스크톱에서만 테스트할 경우에는 `--host 127.0.0.1`로 실행해도 됩니다.
> 하지만 실제 핸드폰 USB 실행이나 Emulator 실행까지 고려하면 `--host 0.0.0.0`으로 실행하는 것을 권장합니다.

---

# 실제 핸드폰 USB 연결 실행

실제 핸드폰을 USB로 연결해서 실행할 때는 `adb reverse`를 사용합니다.

이 방식을 사용하면 공유기 IP가 바뀌어도 Flutter 코드의 백엔드 주소를 매번 수정하지 않아도 됩니다.

---

## 1. Flutter 백엔드 주소 설정

실제 핸드폰 USB 연결 기준으로 Flutter 코드의 백엔드 주소는 다음과 같이 설정합니다.

```dart
const String baseUrl = "http://127.0.0.1:8000";
```

예시:

```dart
class ApiConfig {
  static const String baseUrl = "http://127.0.0.1:8000";
}
```

`adb reverse`를 설정하면 핸드폰 앱에서 `127.0.0.1:8000`으로 요청했을 때 PC의 백엔드 서버로 연결됩니다.

```text
핸드폰 Flutter 앱
        ↓
http://127.0.0.1:8000
        ↓
USB 연결 + adb reverse
        ↓
PC FastAPI 백엔드 서버
```

---

## 2. 핸드폰 USB 디버깅 설정

핸드폰에서 다음 설정을 켭니다.

```text
개발자 옵션 > USB 디버깅 ON
```

USB 연결 후 핸드폰 화면에 `USB 디버깅을 허용하시겠습니까?` 창이 뜨면 허용합니다.

---

## 3. Android Studio Terminal에서 실행

Android Studio 하단의 Terminal을 열고, Flutter 프로젝트 루트 폴더로 이동합니다.

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
```

연결된 디바이스를 확인합니다.

```powershell
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
```

정상적으로 연결되면 다음과 비슷하게 출력됩니다.

```text
List of devices attached
기기번호    device
```

만약 `unauthorized`라고 뜨면 핸드폰 화면에서 USB 디버깅 허용을 눌러야 합니다.

그다음 포트 연결을 설정합니다.

```powershell
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
```

마지막으로 Flutter 앱을 실행합니다.

```powershell
flutter run
```

또는 Android Studio의 실행 버튼을 눌러 실행할 수 있습니다.

---

## 4. 실제 핸드폰 USB 실행 요약

PyCharm에서 백엔드 실행:

```bash
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

Android Studio Terminal:

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo

& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices

& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000

flutter run
```

Flutter 백엔드 주소:

```dart
const String baseUrl = "http://127.0.0.1:8000";
```

---

# Android Emulator 가상 디바이스 실행

Android Emulator에서 실행하는 경우에는 `adb reverse`를 사용할 필요가 없습니다.

Android Emulator에서 PC의 localhost에 접근할 때는 `10.0.2.2` 주소를 사용합니다.

---

## 1. Flutter 백엔드 주소 설정

Android Emulator 기준 백엔드 주소는 다음과 같이 설정합니다.

```dart
const String baseUrl = "http://10.0.2.2:8000";
```

예시:

```dart
class ApiConfig {
  static const String baseUrl = "http://10.0.2.2:8000";
}
```

연결 구조는 다음과 같습니다.

```text
Android Emulator Flutter 앱
        ↓
http://10.0.2.2:8000
        ↓
PC FastAPI 백엔드 서버
```

---

## 2. Emulator 실행 순서

먼저 PyCharm에서 백엔드 서버를 실행합니다.

```bash
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

그다음 Android Studio에서 Android Emulator를 실행합니다.

Flutter 프로젝트 루트 폴더에서 앱을 실행합니다.

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
flutter run
```

또는 Android Studio의 실행 버튼을 눌러 실행할 수 있습니다.

---

# Flutter Web / Windows 실행

Flutter Web에서 실행하려면 다음 명령어를 사용합니다.

```bash
flutter pub get
flutter run -d chrome
```

Windows 데스크톱에서 확인하려면 다음처럼 실행할 수 있습니다.

```bash
flutter run -d windows
```

Flutter Web 또는 Windows 실행 시에는 백엔드 주소를 다음처럼 사용할 수 있습니다.

```dart
const String baseUrl = "http://127.0.0.1:8000";
```

---

# HTTP 통신 허용 설정

백엔드 서버 주소가 `https://`가 아니라 `http://`라면 Android에서 요청이 막힐 수 있습니다.

이 경우 다음 파일을 수정합니다.

```text
android/app/src/main/AndroidManifest.xml
```

`<application>` 태그 안에 다음 옵션을 추가합니다.

```bash
android:usesCleartextTraffic="true"
```

예시:

```bash
<application
    android:label="trainingo"
    android:name="${applicationName}"
    android:usesCleartextTraffic="true"
    android:icon="@mipmap/ic_launcher">
```

---

# 실행 환경별 백엔드 주소 정리

| 실행 환경            | Flutter 백엔드 주소          | 추가 설정                              |
| ---------------- | ----------------------- | ---------------------------------- |
| 실제 핸드폰 USB 연결    | `http://127.0.0.1:8000` | `adb reverse tcp:8000 tcp:8000` 필요 |
| Android Emulator | `http://10.0.2.2:8000`  | 별도 `adb reverse` 불필요               |
| Flutter Web      | `http://127.0.0.1:8000` | 백엔드 서버만 실행                         |
| Windows Desktop  | `http://127.0.0.1:8000` | 백엔드 서버만 실행                         |

---

# 자주 발생하는 오류

## adb 명령어가 인식되지 않는 경우

오류 예시:

```text
adb : 'adb' 용어가 cmdlet, 함수, 스크립트 파일 또는 실행할 수 있는 프로그램 이름으로 인식되지 않습니다.
```

이 경우 `adb`가 환경변수 PATH에 등록되어 있지 않은 것입니다.

아래처럼 전체 경로로 실행합니다.

```powershell
& "C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
```

또는 platform-tools 폴더로 이동해서 실행합니다.

```powershell
cd C:\Users\User\AppData\Local\Android\Sdk\platform-tools
.\adb devices
.\adb reverse tcp:8000 tcp:8000
```

단, 이 위치에서 `flutter run`을 실행하면 안 됩니다.

`flutter run`은 반드시 `pubspec.yaml` 파일이 있는 Flutter 프로젝트 루트 폴더에서 실행해야 합니다.

---

## No pubspec.yaml file found 오류

오류 예시:

```text
Error: No pubspec.yaml file found.
This command should be run from the root of your Flutter project.
```

이 오류는 Flutter 프로젝트 폴더가 아닌 곳에서 `flutter run`을 실행했을 때 발생합니다.

해결 방법:

```powershell
cd C:\Users\User\KGH_Projects\AndroidStudioProjects\Trainingo
flutter run
```

---

## 핸드폰이 unauthorized로 뜨는 경우

`adb devices` 실행 결과가 다음과 같이 나올 수 있습니다.

```text
List of devices attached
기기번호    unauthorized
```

이 경우 핸드폰 화면에 뜬 USB 디버깅 허용 창에서 허용을 눌러야 합니다.

핸드폰에서 다음 설정도 확인합니다.

```text
개발자 옵션 > USB 디버깅 ON
```

---

## 백엔드 연결이 안 되는 경우

다음 항목을 확인합니다.

1. PyCharm에서 백엔드 서버가 실행 중인지 확인
2. 백엔드가 `0.0.0.0:8000`으로 실행 중인지 확인
3. 실제 핸드폰 USB 실행이면 `adb reverse tcp:8000 tcp:8000`을 실행했는지 확인
4. Flutter 코드의 `baseUrl`이 실행 환경에 맞는지 확인
5. `AndroidManifest.xml`에 `android:usesCleartextTraffic="true"`가 들어갔는지 확인
