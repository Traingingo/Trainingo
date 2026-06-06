# Trainingo Backend 실행 가이드

이 문서는 Trainingo 프로젝트의 Backend 서버 실행 방법을 정리한 문서이다.

Backend는 **PyCharm**에서 실행하며, Flutter 앱과 연동하기 위해 FastAPI + Uvicorn 기준으로 실행한다.

---

## 1. 실행 환경

* IDE: PyCharm
* Backend Framework: FastAPI
* Server: Uvicorn
* 기본 포트: `8000`

---

## 2. PyCharm Configuration 설정

PyCharm 상단 메뉴에서 다음 경로로 이동한다.

```text
Run > Edit Configurations...
```

Backend 실행 Configuration을 선택한 뒤, 실행 옵션을 아래와 같이 설정한다.

---

## 3. 기본 실행 명령어

Backend 파일명이 `main.py`이고, 내부에 `app = FastAPI()`가 있는 경우 다음 명령어를 사용한다.

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

만약 Backend 파일명이 `app.py`라면 다음처럼 실행한다.

```bash
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

---

## 4. PyCharm 설정 예시

PyCharm Configuration에서 `Script` 또는 `Module name`에 `uvicorn`을 설정하고, `Parameters`에는 아래 내용을 입력한다.

```bash
main:app --host 0.0.0.0 --port 8000 --reload
```

또는 PyCharm에 Host, Port 입력 칸이 따로 있는 경우 다음과 같이 설정한다.

```text
Host: 0.0.0.0
Port: 8000
Additional options: --reload
```

---

## 5. 중요한 설정

Backend를 Flutter 앱과 연결하려면 반드시 다음 옵션을 사용해야 한다.

```bash
--host 0.0.0.0
```

`127.0.0.1` 또는 `localhost`로만 서버를 실행하면 외부 디바이스에서 접근이 안 될 수 있다.

따라서 개발 중에는 다음과 같은 형태로 실행한다.

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 6. 정상 실행 확인

Backend가 정상적으로 실행되면 PyCharm 콘솔에 다음과 비슷한 문구가 출력된다.

```text
Uvicorn running on http://0.0.0.0:8000
```

또는 브라우저에서 아래 주소로 접속해 확인할 수 있다.

```text
http://127.0.0.1:8000
```

FastAPI 문서 페이지는 다음 주소에서 확인할 수 있다.

```text
http://127.0.0.1:8000/docs
```

---

## 7. 실행 요약

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Backend 서버는 Flutter 앱을 실행하기 전에 먼저 실행되어 있어야 한다.
