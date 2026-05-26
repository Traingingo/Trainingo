import io
import json
import os
from pathlib import Path
from typing import List, Optional, Tuple

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from groq import AsyncGroq
from pydantic import BaseModel
from pptx import Presentation
from pypdf import PdfReader

import database

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(dotenv_path=BASE_DIR / ".env")

app = FastAPI()

# Flutter Web 개발용 CORS입니다. 운영 환경에서는 allow_origins를 실제 도메인으로 제한해야 합니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = AsyncGroq(api_key=os.getenv("GROQ_API_KEY"))


class QuestionRequest(BaseModel):
    subject: str
    difficulty: str
    level_title: str = ""
    level_description: str = ""
    count: int = 10
    session_id: int = 0


class CurriculumRequest(BaseModel):
    subject: str
    user_id: int = 1


class RegisterRequest(BaseModel):
    email: str
    password: str
    nickname: str


class LoginRequest(BaseModel):
    email: str
    password: str


class CompleteLessonRequest(BaseModel):
    session_id: int
    lesson_id: int


class IncorrectAnswerRequest(BaseModel):
    user_id: int
    subject: str
    question: str
    options: list
    answer: str
    explanation: str
    user_answer: str


@app.get("/")
def read_root():
    return {"message": "백엔드 서버 정상 작동 중!"}


def normalize_curriculum(parsed_curriculum: List[dict]) -> List[dict]:
    if not parsed_curriculum:
        parsed_curriculum = [
            {"level": 1, "title": "자료 핵심 개요", "description": "업로드한 자료의 전체 구조와 핵심 키워드를 파악합니다."},
            {"level": 2, "title": "주요 개념 이해", "description": "자료에 등장하는 주요 개념과 정의를 학습합니다."},
            {"level": 3, "title": "내용 연결과 적용", "description": "개념 간 관계를 정리하고 실제 상황에 적용해 봅니다."},
            {"level": 4, "title": "종합 복습", "description": "자료 전체 내용을 문제 풀이로 종합 복습합니다."},
        ]

    final_curriculum = []
    for i, item in enumerate(parsed_curriculum):
        if not isinstance(item, dict):
            continue
        try:
            level = int(item.get("level", i + 1))
        except (TypeError, ValueError):
            level = i + 1
        final_curriculum.append(
            {
                "id": i + 1,
                "level": level,
                "title": f"Level {i + 1}. {item.get('title', '학습 단원')}",
                "description": item.get("description", "이 단원의 핵심 개념을 학습합니다."),
                "isLocked": i > 0,
                "isCompleted": False,
            }
        )
    return final_curriculum or normalize_curriculum([])


async def generate_curriculum_from_source_text(source_text: str) -> List[dict]:
    prompt = f"""
    당신은 유능한 교육 전문가입니다. 업로드된 참고 자료의 내용을 학습하기 위해 듀오링고 스타일의 점진적인 4단계 커리큘럼을 생성해 주세요.

    [참고자료 요약 또는 일부 내용]
    {source_text[:6000]}

    반드시 아래 JSON object 형식으로만 응답하세요.
    {{"curriculum": [{{"id": 1, "level": 1, "title": "기초 단어 및 개요", "description": "문서에 소개된 기초적인 주요 용어를 공부합니다."}}]}}

    학습자가 본 문서의 개념을 기초부터 단계별로 학습할 수 있도록 4단계(Level 1 ~ 4) 코스로 작성해 주세요.
    """
    response = await client.chat.completions.create(
        model="openai/gpt-oss-120b",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3,
        response_format={"type": "json_object"},
    )
    data_object = json.loads(response.choices[0].message.content.strip())
    return normalize_curriculum(data_object.get("curriculum", []))


def decode_text_file(content: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "cp949", "euc-kr"):
        try:
            return content.decode(encoding)
        except UnicodeDecodeError:
            continue
    return content.decode("utf-8", errors="ignore")


async def extract_text_from_upload_file(file: UploadFile) -> Tuple[str, str]:
    filename = file.filename or "unknown"
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail=f"{filename}: 비어 있는 파일입니다.")

    file_ext = os.path.splitext(filename)[1].lower()
    try:
        if file_ext == ".txt":
            extracted_text = decode_text_file(content)
        elif file_ext == ".pdf":
            reader = PdfReader(io.BytesIO(content))
            extracted_text = "\n".join(filter(None, (page.extract_text() for page in reader.pages)))
        elif file_ext == ".pptx":
            prs = Presentation(io.BytesIO(content))
            text_list = []
            for slide in prs.slides:
                for shape in slide.shapes:
                    if hasattr(shape, "text") and shape.text.strip():
                        text_list.append(shape.text.strip())
            extracted_text = "\n".join(text_list)
        elif file_ext == ".ppt":
            raise HTTPException(
                status_code=400,
                detail=f"{filename}: .ppt는 레거시 PowerPoint 형식이라 서버에서 안정적으로 읽을 수 없습니다. .pptx로 변환한 뒤 다시 업로드해 주세요.",
            )
        else:
            raise HTTPException(status_code=400, detail="지원되지 않는 파일 확장자입니다. (.txt, .pdf, .ppt, .pptx)만 선택할 수 있습니다.")
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"{filename}: 텍스트 추출 중 오류가 발생했습니다. {exc}")

    if not extracted_text.strip():
        raise HTTPException(status_code=400, detail=f"{filename}: 문서 내에서 추출할 수 있는 텍스트가 없습니다.")

    print(f"📂 파일 텍스트 추출 성공: {filename} (원본: {len(content)} bytes, 추출: {len(extracted_text)} 자)")
    return filename, extracted_text.strip()


async def build_combined_source_text(files: List[UploadFile]) -> Tuple[str, List[str], int]:
    if not files:
        raise HTTPException(status_code=400, detail="업로드할 파일을 1개 이상 선택해 주세요.")

    uploaded_files: List[str] = []
    source_parts: List[str] = []
    for file in files:
        filename, extracted_text = await extract_text_from_upload_file(file)
        uploaded_files.append(filename)
        source_parts.append(f"[파일명: {filename}]\n{extracted_text}")

    combined_source_text = "\n\n".join(source_parts).strip()
    if not combined_source_text:
        raise HTTPException(status_code=400, detail="업로드한 자료에서 추출된 텍스트가 없습니다.")
    return combined_source_text, uploaded_files, len(combined_source_text)


def build_material_subject(uploaded_files: List[str]) -> str:
    return f"[자료] {uploaded_files[0]}" if len(uploaded_files) == 1 else f"[자료] {uploaded_files[0]} 외 {len(uploaded_files) - 1}개"


@app.post("/api/auth/register")
async def register(request: RegisterRequest):
    user = database.register_user(request.email, request.password, request.nickname)
    if not user:
        raise HTTPException(status_code=400, detail="이미 가입된 이메일이거나 회원가입에 실패했습니다.")
    print(f"👤 회원가입 성공: {user['email']} ({user['nickname']})")
    return {"user": user}


@app.post("/api/auth/login")
async def login(request: LoginRequest):
    user = database.login_user(request.email, request.password)
    if not user:
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 일치하지 않습니다.")
    print(f"🔓 로그인 성공: {user['email']} ({user['nickname']})")
    return {"user": user}


@app.get("/api/sessions")
async def get_sessions(user_id: int):
    return {"sessions": database.get_study_sessions(user_id)}


@app.post("/api/complete-lesson")
async def complete_lesson(request: CompleteLessonRequest):
    success = database.update_lesson_completion(request.session_id, request.lesson_id)
    if not success:
        raise HTTPException(status_code=400, detail="레벨 완료 처리에 실패했습니다.")
    return {"message": "레벨 완료 처리 및 다음 레벨 잠금 해제 성공"}


@app.post("/api/generate-curriculum")
async def generate_curriculum(request: CurriculumRequest):
    try:
        existing_session = database.get_session_by_subject(request.user_id, request.subject)
        if existing_session:
            print(f"♻️ 기존 '{request.subject}' 학습 세션을 재사용합니다.")
            return {"session_id": existing_session["id"], "subject": existing_session["subject"], "progress": existing_session["progress"], "curriculum": existing_session["curriculum"]}

        prompt = f"""
        당신은 유능한 교육 전문가입니다. 사용자가 학습하고자 하는 주제: '{request.subject}' 에 대한 적절성 검사 및 듀오링고 스타일의 점진적인 4단계 커리큘럼을 생성해 주세요.
        입력값이 무의미한 자판 배열, 스팸, 심한 비속어라면 valid=false와 친절한 error_message를 반환하세요.
        반드시 JSON object 형식으로만 응답하세요.
        {{"valid": true, "error_message": "", "curriculum": [{{"id": 1, "level": 1, "title": "기초 다지기", "description": "이 주제에 대한 기본 용어와 개념을 이해합니다."}}]}}
        학습자가 기초부터 응용까지 올라갈 수 있도록 4단계(Level 1 ~ 4)로 구성해 주세요.
        """
        response = await client.chat.completions.create(
            model="openai/gpt-oss-120b",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            response_format={"type": "json_object"},
        )
        data_object = json.loads(response.choices[0].message.content.strip())
        if not data_object.get("valid", True):
            error_msg = data_object.get("error_message", "올바른 학습 주제가 아닙니다. 배우고 싶은 과목이나 주제를 명확하게 적어주세요!")
            print(f"⚠️ 학습 주제 무효 처리: '{request.subject}' -> {error_msg}")
            raise HTTPException(status_code=400, detail=error_msg)

        session_id = database.create_study_session(request.user_id, request.subject, normalize_curriculum(data_object.get("curriculum", [])))
        saved_session = database.get_session_by_id(session_id)
        print(f"✅ 성공적으로 '{request.subject}'에 대한 커리큘럼 세션(ID: {session_id})을 생성 및 저장했습니다.")
        return {"session_id": saved_session["id"], "subject": saved_session["subject"], "progress": saved_session["progress"], "curriculum": saved_session["curriculum"]}
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ 커리큘럼 생성 중 에러 발생: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/generate-questions")
async def generate_questions(request: QuestionRequest):
    try:
        context_str = f" 학습 단원은 '{request.level_title}' ({request.level_description}) 입니다." if request.level_title else ""
        source_text = database.get_session_source_text(request.session_id) if request.session_id > 0 else None
        if source_text:
            print(f"📖 세션 ID {request.session_id}의 문서 데이터를 활용하여 문제를 생성합니다. (RAG 적용)")
            basis = f"""
            제공된 아래의 [참고자료] 내용에만 기반해 {request.subject} 과목{context_str}에 대한 객관식 퀴즈를 생성해 주세요.
            [참고자료]
            {source_text[:15000]}
            """
        else:
            print(f"🤖 일반 지식 기반 문제를 생성합니다: '{request.subject}'")
            basis = f"{request.subject} 과목{context_str}에 대한 객관식 퀴즈를 생성해 주세요."

        prompt = f"""
        당신은 유능한 교육 전문가입니다. {basis}
        난이도는 '{request.difficulty}'이며, 총 {request.count}문제를 만들어야 합니다.
        반드시 questions 배열에 총 {request.count}개의 문제를 넣어 주세요.
        반드시 아래 JSON object 형식으로만 응답하세요.
        {{"questions": [{{"question": "문제 내용", "options": ["1번 보기", "2번 보기", "3번 보기", "4번 보기"], "answer": "정답 내용", "explanation": "해설 내용"}}]}}
        """
        response = await client.chat.completions.create(
            model="openai/gpt-oss-120b",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            response_format={"type": "json_object"},
        )
        parsed_questions = json.loads(response.choices[0].message.content.strip()).get("questions", [])
        final_questions = []
        for q in parsed_questions:
            if len(final_questions) >= request.count:
                break
            if isinstance(q, str):
                try:
                    q = json.loads(q)
                except json.JSONDecodeError:
                    continue
            if not isinstance(q, dict):
                continue
            options = q.get("options", ["-", "-", "-", "-"])
            if not isinstance(options, list):
                options = ["-", "-", "-", "-"]
            final_questions.append(
                {
                    "id": len(final_questions) + 1,
                    "question": q.get("question", "문제를 생성하지 못했습니다."),
                    "options": options,
                    "answer": q.get("answer", ""),
                    "explanation": q.get("explanation", "해설이 제공되지 않았습니다."),
                    "source_type": "Document" if source_text else "AI",
                    "difficulty": request.difficulty,
                }
            )
        actual_count = len(final_questions)
        if actual_count < request.count:
            print(f"⚠️ 요청한 {request.count}문제보다 적은 {actual_count}문제만 생성되었습니다.")
        else:
            print(f"✅ 성공적으로 {actual_count}문제를 생성하여 반환합니다.")
        return {"questions": final_questions}
    except Exception as e:
        print(f"❌ API 요청 처리 중 내부 에러 발생: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/incorrect-answers")
async def get_incorrect_answers(user_id: int):
    return {"answers": database.get_incorrect_answers(user_id)}


@app.post("/api/incorrect-answers")
async def add_incorrect_answer(request: IncorrectAnswerRequest):
    row_id = database.add_incorrect_answer(request.user_id, request.subject, request.question, request.options, request.answer, request.explanation, request.user_answer)
    if not row_id:
        raise HTTPException(status_code=500, detail="오답을 DB에 등록하지 못했습니다.")
    print(f"📝 오답 추가 완료: (User ID: {request.user_id}, 과목: {request.subject})")
    return {"id": row_id, "message": "오답 노트 등록 완료"}


@app.delete("/api/incorrect-answers/{answer_id}")
async def delete_incorrect_answer(answer_id: int):
    success = database.delete_incorrect_answer(answer_id)
    if not success:
        raise HTTPException(status_code=404, detail="해당 오답 항목을 찾을 수 없습니다.")
    print(f"🗑️ 오답 삭제 완료 (ID: {answer_id})")
    return {"message": "오답 노트에서 삭제되었습니다."}


@app.post("/api/upload-material")
async def upload_material(
    user_id: int = Form(...),
    files: Optional[List[UploadFile]] = File(None),
    file: Optional[UploadFile] = File(None),
    session_id: Optional[int] = Form(None),
    regenerate_curriculum: bool = Form(False),
):
    try:
        upload_files: List[UploadFile] = []
        if files:
            upload_files.extend(files)
        if file:
            upload_files.append(file)

        combined_source_text, uploaded_files, total_extracted_length = await build_combined_source_text(upload_files)

        if session_id:
            existing_session = database.get_session_by_id(session_id)
            if not existing_session:
                raise HTTPException(status_code=404, detail="자료를 추가할 기존 로드맵을 찾을 수 없습니다.")
            if existing_session["user_id"] != user_id:
                raise HTTPException(status_code=403, detail="다른 사용자의 로드맵에는 자료를 추가할 수 없습니다.")

            appended = database.append_session_source_text(session_id, combined_source_text)
            if not appended:
                raise HTTPException(status_code=500, detail="기존 로드맵에 자료를 추가하지 못했습니다.")
            if regenerate_curriculum:
                updated_source_text = database.get_session_source_text(session_id) or combined_source_text
                regenerated_curriculum = await generate_curriculum_from_source_text(updated_source_text)
                database.replace_session_curriculum(session_id, regenerated_curriculum)

            saved_session = database.get_session_by_id(session_id)
            print(f"✅ 기존 로드맵(ID: {session_id})에 자료 {len(uploaded_files)}개 추가 완료 (커리큘럼 재생성: {regenerate_curriculum})")
            return {
                "session_id": saved_session["id"],
                "subject": saved_session["subject"],
                "progress": saved_session["progress"],
                "curriculum": saved_session["curriculum"],
                "uploaded_files": uploaded_files,
                "total_extracted_length": total_extracted_length,
                "appended_to_session": True,
                "regenerated_curriculum": regenerate_curriculum,
            }

        subject_name = build_material_subject(uploaded_files)
        existing_session = database.get_session_by_subject(user_id, subject_name)
        if existing_session:
            print(f"♻️ 기존 업로드 세션 '{subject_name}'을 반환합니다.")
            return {
                "session_id": existing_session["id"],
                "subject": existing_session["subject"],
                "progress": existing_session["progress"],
                "curriculum": existing_session["curriculum"],
                "uploaded_files": uploaded_files,
                "total_extracted_length": total_extracted_length,
                "appended_to_session": False,
                "regenerated_curriculum": False,
            }

        new_session_id = database.create_study_session(user_id, subject_name, await generate_curriculum_from_source_text(combined_source_text), combined_source_text)
        saved_session = database.get_session_by_id(new_session_id)
        print(f"✅ 업로드 자료 기반 커리큘럼(ID: {new_session_id}) 생성 성공!")
        return {
            "session_id": saved_session["id"],
            "subject": saved_session["subject"],
            "progress": saved_session["progress"],
            "curriculum": saved_session["curriculum"],
            "uploaded_files": uploaded_files,
            "total_extracted_length": total_extracted_length,
            "appended_to_session": False,
            "regenerated_curriculum": False,
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ 자료 업로드/분석 실패: {e}")
        raise HTTPException(status_code=500, detail=str(e))
