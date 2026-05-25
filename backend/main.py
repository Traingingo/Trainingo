import os
import json
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from groq import AsyncGroq
from pypdf import PdfReader
from pptx import Presentation
import io

import database

load_dotenv(dotenv_path="/Users/gimgeonhui/developer/3_projects/Trainingo/backend/.env")
app = FastAPI()

# 데이터베이스 초기화
database.init_db()

# 크롬(Flutter Web) 통신을 위한 CORS 설정 완벽 유지
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Groq 비동기 클라이언트 초기화
client = AsyncGroq(api_key=os.getenv("GROQ_API_KEY"))

class QuestionRequest(BaseModel):
    subject: str
    difficulty: str
    level_title: str = ""
    level_description: str = ""
    count: int = 3
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

# --- 1. 사용자 인증 (Auth) API ---
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

# --- 2. 학습 로드맵 및 세션 API ---
@app.get("/api/sessions")
async def get_sessions(user_id: int):
    sessions = database.get_study_sessions(user_id)
    return {"sessions": sessions}

@app.post("/api/complete-lesson")
async def complete_lesson(request: CompleteLessonRequest):
    success = database.update_lesson_completion(request.session_id, request.lesson_id)
    if not success:
        raise HTTPException(status_code=400, detail="레벨 완료 처리에 실패했습니다.")
    return {"message": "레벨 완료 처리 및 다음 레벨 잠금 해제 성공"}

@app.post("/api/generate-curriculum")
async def generate_curriculum(request: CurriculumRequest):
    try:
        # 이미 이 주제로 진행 중인 세션이 있다면 로드
        existing_session = database.get_session_by_subject(request.user_id, request.subject)
        if existing_session:
            print(f"♻️ 기존 '{request.subject}' 학습 세션을 재사용합니다.")
            return {
                "session_id": existing_session["id"],
                "subject": existing_session["subject"],
                "progress": existing_session["progress"],
                "curriculum": existing_session["curriculum"]
            }

        # 1. 입력 유효성 검증 프롬프트 (스팸/Gibberish 차단)
        # LLM에게 주제 검증과 커리큘럼 생성을 한번에 요청하여 속도 향상
        prompt = f"""
        당신은 유능한 교육 전문가입니다. 사용자가 학습하고자 하는 주제: '{request.subject}' 에 대한 적절성 검사 및 듀오링고 스타일의 점진적인 4단계 커리큘럼을 생성해 주세요.
        
        먼저 입력값 '{request.subject}'이 실제 교육적 가치나 학습할 내용이 있는 올바른 단어나 문법, 개념(예: 파이썬, 영어 회화, 조선 역사 등)인지 판별하세요. 
        만약 'dsadadsa', '12312312'와 같은 무의미한 자판 배열, 스팸, 심한 비속어, 아무런 뜻이 없는 입력값이라면 "valid" 값을 false로 설정하고, 사용자에게 한국어로 안내할 친절한 오류 메시지를 "error_message"에 작성하세요.
        
        반드시 아래의 JSON object 형식으로만 응답해야 하며, 다른 설명이나 텍스트는 포함하지 마십시오.
        각 레벨 객체 내부의 키값(id, level, title, description)은 규격에 맞춰야 합니다.
        
        {{
          "valid": true,
          "error_message": "",
          "curriculum": [
            {{
              "id": 1,
              "level": 1,
              "title": "기초 다지기",
              "description": "이 주제에 대한 기본 용어와 개념을 이해합니다."
            }}
          ]
        }}
        
        학습자가 기초부터 응용까지 차근차근 올라갈 수 있도록 4단계(Level 1 ~ 4)로 구성해 주세요.
        title은 각 레벨의 핵심 내용을 담은 명확한 제목으로 작성하고, description은 해당 단원에서 배우는 것을 한국어로 친절하게 한 문장으로 설명해 주세요.
        """

        response = await client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            response_format={"type": "json_object"}
        )

        raw_content = response.choices[0].message.content.strip()
        data_object = json.loads(raw_content)

        if not data_object.get("valid", True):
            error_msg = data_object.get("error_message", "올바른 학습 주제가 아닙니다. 배우고 싶은 과목이나 주제를 명확하게 적어주세요!")
            print(f"⚠️ 학습 주제 무효 처리: '{request.subject}' -> {error_msg}")
            raise HTTPException(status_code=400, detail=error_msg)

        parsed_curriculum = data_object.get("curriculum", [])
        final_curriculum = []
        for i, item in enumerate(parsed_curriculum):
            final_curriculum.append({
                "id": i + 1, # 임시 레벨 인덱스
                "level": int(item.get("level", i + 1)),
                "title": f"Level {i + 1}. {item.get('title', '학습 단원')}",
                "description": item.get("description", "이 단원의 핵심 개념을 학습합니다."),
                "isLocked": i > 0,
                "isCompleted": False
            })

        # 생성된 세션 및 레벨 목록을 DB에 저장
        session_id = database.create_study_session(
            user_id=request.user_id,
            subject=request.subject,
            curriculum=final_curriculum
        )

        # 저장된 세션 상세 정보 다시 가져오기
        saved_session = database.get_session_by_subject(request.user_id, request.subject)
        
        print(f"✅ 성공적으로 '{request.subject}'에 대한 커리큘럼 세션(ID: {session_id})을 생성 및 저장했습니다.")
        return {
            "session_id": saved_session["id"],
            "subject": saved_session["subject"],
            "progress": saved_session["progress"],
            "curriculum": saved_session["curriculum"]
        }

    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"❌ 커리큘럼 생성 중 에러 발생: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- 3. 문제 생성 API (RAG 지원) ---
@app.post("/api/generate-questions")
async def generate_questions(request: QuestionRequest):
    try:
        # 단원명과 설명이 주어졌다면 프롬프트에 추가 반영
        context_str = f" 학습 단원은 '{request.level_title}' ({request.level_description}) 입니다." if request.level_title else ""
        
        # 만약 세션 ID가 있고, 해당 세션에 문서 추출 텍스트(source_text)가 있는 경우 RAG로 문제 생성
        source_text = None
        if request.session_id > 0:
            source_text = database.get_session_source_text(request.session_id)
            
        if source_text:
            print(f"📖 세션 ID {request.session_id}의 문서 데이터를 활용하여 문제를 생성합니다. (RAG 적용)")
            prompt = f"""
            당신은 유능한 교육 전문가입니다. 제공된 아래의 [참고자료] 내용을 토대로 {request.subject} 과목{context_str}에 대한 퀴즈 문제를 생성해 주세요.
            반드시 제공된 [참고자료]의 사실과 정보에만 기반하여 문제를 출제해야 합니다. 외부의 일반적인 정보로 문제를 지어내지 마세요.
            난이도는 '{request.difficulty}'이며, 총 {request.count}문제를 만들어야 합니다.
            
            [참고자료]
            {source_text[:15000]}  # 컨텍스트 길이 안전을 위해 최대 1.5만자 슬라이싱
            
            반드시 아래의 JSON object 형식으로만 응답해야 하며, 다른 설명이나 텍스트는 포함하지 마십시오.
            각 문제 객체 내부의 키값(question, options, answer, explanation)은 반드시 문자열(String) 또는 리스트(List) 형태여야 합니다.
            
            {{
              "questions": [
                {{
                  "question": "참고자료에서 출제한 문제 내용",
                  "options": ["1번 보기", "2번 보기", "3번 보기", "4번 보기"],
                  "answer": "정답 내용 (options 중 하나와 정확히 일치해야 함)",
                  "explanation": "참고자료에 근거한 해설 내용"
                }}
              ]
            }}
            """
        else:
            print(f"🤖 일반 지식 기반 문제를 생성합니다: '{request.subject}'")
            prompt = f"""
            당신은 유능한 교육 전문가입니다. {request.subject} 과목{context_str}에 대한 퀴즈 문제를 생성해 주세요.
            난이도는 '{request.difficulty}'이며, 총 {request.count}문제를 만들어야 합니다.
            
            반드시 아래의 JSON object 형식으로만 응답해야 하며, 다른 설명이나 텍스트는 포함하지 마십시오.
            각 문제 객체 내부의 키값(question, options, answer, explanation)은 반드시 문자열(String) 또는 리스트(List) 형태여야 합니다.
            
            {{
              "questions": [
                {{
                  "question": "문제 내용",
                  "options": ["1번 보기", "2번 보기", "3번 보기", "4번 보기"],
                  "answer": "정답 내용 (options 중 하나와 정확히 일치해야 함)",
                  "explanation": "해설 내용"
                }}
              ]
            }}
            """

        response = await client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,  # 규격 일탈 원천 차단
            response_format={"type": "json_object"}
        )

        raw_content = response.choices[0].message.content.strip()
        data_object = json.loads(raw_content)
        parsed_questions = data_object.get("questions", [])

        final_questions = []
        for i, q in enumerate(parsed_questions):
            if isinstance(q, str):
                try:
                    q = json.loads(q)
                except:
                    continue

            final_questions.append({
                "id": int(i + 1),
                "question": q.get("question", "문제를 생성하지 못했습니다."),
                "options": q.get("options", ["-", "-", "-", "-"]),
                "answer": q.get("answer", ""),
                "explanation": q.get("explanation", "해설이 제공되지 않았습니다."),
                "source_type": "Document" if source_text else "AI",
                "difficulty": request.difficulty
            })

        print(f"✅ 성공적으로 {len(final_questions)}문제를 생성하여 반환합니다.")
        return {"questions": final_questions}

    except Exception as e:
        print(f"❌ API 요청 처리 중 내부 에러 발생: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- 4. 오답 노트 (Review) API ---
@app.get("/api/incorrect-answers")
async def get_incorrect_answers(user_id: int):
    answers = database.get_incorrect_answers(user_id)
    return {"answers": answers}

@app.post("/api/incorrect-answers")
async def add_incorrect_answer(request: IncorrectAnswerRequest):
    row_id = database.add_incorrect_answer(
        request.user_id,
        request.subject,
        request.question,
        request.options,
        request.answer,
        request.explanation,
        request.user_answer
    )
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

# --- 5. 자료 업로드 및 RAG 기반 학습 생성 API ---
@app.post("/api/upload-material")
async def upload_material(
    file: UploadFile = File(...),
    user_id: int = Form(...)
):
    try:
        content = await file.read()
        filename = file.filename
        file_ext = os.path.splitext(filename)[1].lower()
        
        extracted_text = ""
        
        if file_ext == ".txt":
            extracted_text = content.decode("utf-8", errors="ignore")
        elif file_ext == ".pdf":
            # PDF Reader로 텍스트 추출
            pdf_file = io.BytesIO(content)
            reader = PdfReader(pdf_file)
            text_list = []
            for page in reader.pages:
                text = page.extract_text()
                if text:
                    text_list.append(text)
            extracted_text = "\n".join(text_list)
        elif file_ext in [".pptx", ".ppt"]:
            # python-pptx로 텍스트 추출
            pptx_file = io.BytesIO(content)
            prs = Presentation(pptx_file)
            text_list = []
            for slide in prs.slides:
                for shape in slide.shapes:
                    if hasattr(shape, "text") and shape.text.strip():
                        text_list.append(shape.text.strip())
            extracted_text = "\n".join(text_list)
        else:
            raise HTTPException(status_code=400, detail="지원되지 않는 파일 확장자입니다. (.txt, .pdf, .pptx)만 지원합니다.")
        
        if not extracted_text.strip():
            raise HTTPException(status_code=400, detail="문서 내에서 추출할 수 있는 텍스트가 없습니다.")
            
        print(f"📂 파일 업로드 성공: {filename} (크기: {len(content)} bytes, 추출 텍스트: {len(extracted_text)} 자)")

        # 추출된 텍스트를 토대로 커리큘럼 생성 요청
        subject_name = f"[자료] {filename}"
        
        # 이미 해당 이름의 세션이 있으면 중복 방지를 위해 삭제 후 재생성 또는 로드
        existing_session = database.get_session_by_subject(user_id, subject_name)
        if existing_session:
            # 기존 세션에 source_text만 업데이트하거나 그냥 리턴
            print(f"♻️ 기존 업로드 세션 '{subject_name}'을 반환합니다.")
            return {
                "session_id": existing_session["id"],
                "subject": existing_session["subject"],
                "progress": existing_session["progress"],
                "curriculum": existing_session["curriculum"]
            }

        # LLM을 호출하여 업로드된 텍스트 기반의 커리큘럼 설계
        prompt = f"""
        당신은 유능한 교육 전문가입니다. 업로드된 참고 자료의 내용을 학습하기 위해 듀오링고 스타일의 점진적인 4단계 커리큘럼을 생성해 주세요.
        
        [참고자료 요약 또는 일부 내용]
        {extracted_text[:6000]}  # 텍스트 요약을 위해 앞 6000자 사용
        
        반드시 아래의 JSON object 형식으로만 응답해야 하며, 다른 설명이나 텍스트는 포함하지 마십시오.
        각 레벨 객체 내부의 키값(id, level, title, description)은 규격에 맞춰야 합니다.
        
        {{
          "curriculum": [
            {{
              "id": 1,
              "level": 1,
              "title": "기초 단어 및 개요",
              "description": "문서에 소개된 기초적인 주요 용어를 공부합니다."
            }}
          ]
        }}
        
        학습자가 본 문서의 개념을 기초부터 단계별로 학습할 수 있도록 4단계(Level 1 ~ 4) 코스로 작성해 주세요.
        """

        response = await client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            response_format={"type": "json_object"}
        )

        raw_content = response.choices[0].message.content.strip()
        data_object = json.loads(raw_content)
        parsed_curriculum = data_object.get("curriculum", [])

        final_curriculum = []
        for i, item in enumerate(parsed_curriculum):
            final_curriculum.append({
                "id": i + 1,
                "level": int(item.get("level", i + 1)),
                "title": f"Level {i + 1}. {item.get('title', '학습 단원')}",
                "description": item.get("description", "이 단원의 핵심 개념을 학습합니다."),
                "isLocked": i > 0,
                "isCompleted": False
            })

        # DB 세션 생성 (추출된 전체 텍스트 저장)
        session_id = database.create_study_session(
            user_id=user_id,
            subject=subject_name,
            curriculum=final_curriculum,
            source_text=extracted_text
        )

        saved_session = database.get_session_by_subject(user_id, subject_name)
        print(f"✅ 업로드 파일 기반 커리큘럼(ID: {session_id}) 생성 성공!")

        return {
            "session_id": saved_session["id"],
            "subject": saved_session["subject"],
            "progress": saved_session["progress"],
            "curriculum": saved_session["curriculum"]
        }

    except Exception as e:
        print(f"❌ 자료 업로드/분석 실패: {e}")
        raise HTTPException(status_code=500, detail=str(e))