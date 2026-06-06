import io
import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from groq import AsyncGroq
from pydantic import BaseModel, Field
from pptx import Presentation
from pypdf import PdfReader

import database

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(dotenv_path=BASE_DIR / ".env")

database.init_db()

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
client = AsyncGroq(api_key=GROQ_API_KEY) if GROQ_API_KEY else None


class QuestionRequest(BaseModel):
    subject: str
    difficulty: str = "초급"
    level_title: str = ""
    level_description: str = ""
    count: int = 10
    session_id: int = 0
    mode: str = "recommended"
    generation_mode: str = "ai_only"
    learning_level: str = "beginner"
    use_uploaded_material: bool = False
    subject_type: str = "conceptual"
    level: int = 1
    allowed_question_types: List[str] = Field(default_factory=list)
    question_type_weights: Dict[str, int] = Field(default_factory=dict)


class CurriculumRequest(BaseModel):
    subject: str
    user_id: int = 1
    generation_mode: str = "ai_only"
    learning_level: str = "beginner"
    difficulty: str = "초급"


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
    options: List[str] = Field(default_factory=list)
    answer: str
    explanation: str
    user_answer: str
    session_id: int = 0
    question_id: int = 0
    question_type: str = "multiple_choice"
    difficulty: str = "초급"


class AnswerRecordRequest(BaseModel):
    user_id: int
    session_id: int = 0
    question_id: int = 0
    subject: str = ""
    question_type: str = "multiple_choice"
    difficulty: str = "초급"
    question_text: str = ""
    options: List[str] = Field(default_factory=list)
    correct_answer: str = ""
    model_answer: str = ""
    explanation: str = ""
    user_answer: str
    is_correct: bool


@app.get("/")
def read_root():
    return {"message": "백엔드 서버 정상 작동 중!"}


def normalize_generation_mode(value: str) -> str:
    normalized = (value or "ai_only").strip().lower()
    if normalized in {"material_only", "materialonly", "document"}:
        return "material_only"
    if normalized in {"mixed", "hybrid", "ai_material"}:
        return "mixed"
    return "ai_only"


def normalize_learning_level(value: str) -> str:
    normalized = (value or "beginner").strip().lower()
    if normalized in {"intermediate", "medium", "중급"}:
        return "intermediate"
    if normalized in {"advanced", "hard", "고급"}:
        return "advanced"
    return "beginner"


def difficulty_from_learning_level(value: str, fallback: str = "초급") -> str:
    level = normalize_learning_level(value)
    if level == "intermediate":
        return "중급"
    if level == "advanced":
        return "고급"
    return fallback if fallback in {"초급", "중급", "고급"} else "초급"


def learning_level_guidance(value: str) -> str:
    level = normalize_learning_level(value)
    if level == "intermediate":
        return """
        중급 난이도 정책:
        - 개념 적용 문제를 포함합니다.
        - 객관식, 단답형, 서술형을 균형 있게 섞습니다.
        - 예시 상황을 보고 개념을 적용하는 문제를 포함합니다.
        """
    if level == "advanced":
        return """
        고급 난이도 정책:
        - 응용, 분석, 서술형 문제 비중을 높입니다.
        - 과목 성격에 맞으면 코딩형, SQL형, 계산형, 코드 해석형 문제를 포함합니다.
        - 단순 암기보다 이해와 적용을 요구하는 문제를 우선합니다.
        """
    return """
    초급 난이도 정책:
    - 핵심 개념 확인 위주로 출제합니다.
    - 객관식과 단답형 비중을 높입니다.
    - 정답이 명확한 쉬운 문제를 우선합니다.
    """


async def call_llm_json(prompt: str, temperature: float = 0.2) -> dict:
    if client is None:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY가 설정되지 않았습니다.")
    response = await client.chat.completions.create(
        model="openai/gpt-oss-120b",
        messages=[{"role": "user", "content": prompt}],
        temperature=temperature,
        response_format={"type": "json_object"},
    )
    return json.loads(response.choices[0].message.content.strip())


def normalize_curriculum(parsed_curriculum: List[dict]) -> List[dict]:
    if not parsed_curriculum:
        parsed_curriculum = [
            {"level": 1, "title": "핵심 개요", "description": "학습 주제의 전체 구조와 핵심 키워드를 파악합니다."},
            {"level": 2, "title": "주요 개념 이해", "description": "주요 개념과 정의를 학습합니다."},
            {"level": 3, "title": "내용 연결과 적용", "description": "개념 간 관계를 정리하고 상황에 적용합니다."},
            {"level": 4, "title": "종합 복습", "description": "문제 풀이로 전체 내용을 종합 복습합니다."},
        ]
    final_curriculum = []
    for index, item in enumerate(parsed_curriculum):
        if not isinstance(item, dict):
            continue
        try:
            level = int(item.get("level", index + 1))
        except (TypeError, ValueError):
            level = index + 1
        final_curriculum.append(
            {
                "id": index + 1,
                "level": level,
                "title": f"Level {index + 1}. {item.get('title', '학습 단원')}",
                "description": item.get("description", "이 단원의 핵심 개념을 학습합니다."),
                "isLocked": index > 0,
                "isCompleted": False,
            }
        )
    return final_curriculum or normalize_curriculum([])


async def generate_curriculum_from_source_text(source_text: str, learning_level: str = "beginner") -> List[dict]:
    prompt = f"""
    당신은 유능한 교육 전문가입니다. 업로드된 참고 자료의 내용을 학습하기 위해 듀오링고 스타일의 점진적인 4단계 커리큘럼을 생성해 주세요.

    [난이도 정책]
    {learning_level_guidance(learning_level)}

    [참고자료 요약 또는 일부 내용]
    {source_text[:6000]}

    반드시 아래 JSON object 형식으로만 응답하세요.
    {{"curriculum": [{{"id": 1, "level": 1, "title": "기초 단어 및 개요", "description": "문서에 소개된 기초적인 주요 용어를 공부합니다."}}]}}
    """
    data_object = await call_llm_json(prompt, temperature=0.3)
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
            raise HTTPException(status_code=400, detail=f"{filename}: .ppt는 안정적으로 읽을 수 없습니다. .pptx로 변환한 뒤 다시 업로드해 주세요.")
        else:
            raise HTTPException(status_code=400, detail="지원되지 않는 파일 확장자입니다. (.txt, .pdf, .ppt, .pptx)만 선택할 수 있습니다.")
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"{filename}: 텍스트 추출 중 오류가 발생했습니다. {exc}")
    if not extracted_text.strip():
        raise HTTPException(status_code=400, detail=f"{filename}: 문서 내에서 추출할 수 있는 텍스트가 없습니다.")
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


def build_material_subject(uploaded_files: List[str], subject: Optional[str] = None) -> str:
    if subject and subject.strip():
        return subject.strip()
    return f"[자료] {uploaded_files[0]}" if len(uploaded_files) == 1 else f"[자료] {uploaded_files[0]} 외 {len(uploaded_files) - 1}개"


def build_type_counts(weights: Dict[str, int], total_count: int) -> Dict[str, int]:
    if not weights:
        return {"multiple_choice": total_count}
    positive = {key: value for key, value in weights.items() if value > 0}
    total_weight = sum(positive.values())
    if total_weight <= 0:
        return {"multiple_choice": total_count}
    raw = []
    for q_type, weight in positive.items():
        exact = total_count * weight / total_weight
        floor_value = int(exact)
        raw.append({"type": q_type, "count": floor_value, "remain": exact - floor_value})
    used = sum(item["count"] for item in raw)
    remain_count = total_count - used
    raw.sort(key=lambda item: item["remain"], reverse=True)
    for index in range(remain_count):
        raw[index % len(raw)]["count"] += 1
    return {item["type"]: item["count"] for item in raw if item["count"] > 0}


def ensure_list(value) -> List[str]:
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if value is None:
        return []
    text = str(value).strip()
    return [text] if text else []


def first_non_empty(*values) -> str:
    for value in values:
        text = str(value).strip() if value is not None else ""
        if text:
            return text
    return ""


def build_fallback_model_answer(question_text: str, answer: str = "") -> str:
    if answer:
        return answer
    return f"이 문제는 '{question_text}'에 대해 핵심 개념과 이유를 간단히 설명하는 답안을 요구합니다."


def normalize_type(value: str) -> str:
    aliases = {
        "multipleChoice": "multiple_choice",
        "shortAnswer": "short_answer",
        "codeReading": "code_reading",
        "sqlWriting": "sql_writing",
        "commandWriting": "command_writing",
    }
    return aliases.get(value, value)


def normalize_short_answer_question(q: dict) -> dict:
    answer = first_non_empty(q.get("answer"), q.get("expected_answer"), q.get("expectedAnswer"), q.get("model_answer"), q.get("modelAnswer")) or "핵심 개념"
    acceptable_answers = ensure_list(q.get("acceptable_answers") or q.get("acceptableAnswers"))
    acceptable_answers = list(dict.fromkeys([answer, *acceptable_answers]))
    q["answer"] = answer
    q["acceptable_answers"] = acceptable_answers
    q["options"] = []
    q["model_answer"] = ""
    q["sample_answer"] = ""
    q["expected_answer"] = answer
    q["keywords"] = ensure_list(q.get("keywords"))
    q["grading_criteria"] = first_non_empty(q.get("grading_criteria"), q.get("gradingCriteria"), "허용 답안과 의미가 같으면 정답으로 인정합니다.")
    return q


def normalize_descriptive_question(q: dict) -> dict:
    answer = first_non_empty(q.get("model_answer"), q.get("modelAnswer"), q.get("sample_answer"), q.get("sampleAnswer"), q.get("expected_answer"), q.get("expectedAnswer"), q.get("answer"))
    answer = build_fallback_model_answer(q.get("question", "서술형 문제"), answer)
    keywords = ensure_list(q.get("keywords")) or ensure_list(q.get("rubric"))[:4]
    q["answer"] = answer
    q["model_answer"] = answer
    q["sample_answer"] = first_non_empty(q.get("sample_answer"), q.get("sampleAnswer"), answer)
    q["expected_answer"] = first_non_empty(q.get("expected_answer"), q.get("expectedAnswer"), answer)
    q["keywords"] = keywords
    q["grading_criteria"] = first_non_empty(q.get("grading_criteria"), q.get("gradingCriteria"), "핵심 키워드와 의미가 포함되어 있으면 부분 정답 이상으로 인정합니다.")
    q["rubric"] = ensure_list(q.get("rubric")) or keywords
    q["options"] = []
    return q


def is_valid_short_answer(q: dict) -> bool:
    answer = first_non_empty(q.get("answer"), q.get("expected_answer"), q.get("expectedAnswer"))
    question_text = str(q.get("question", ""))
    banned_words = ["설명하시오", "서술하시오", "비교하시오", "논하시오"]
    return len(answer) <= 40 and len(answer.split()) <= 6 and not any(word in question_text for word in banned_words)


def normalize_generated_question(q: dict, q_type: str, request: QuestionRequest, source_text: Optional[str]) -> dict:
    if q_type == "short_answer":
        q = normalize_short_answer_question(q)
    elif q_type == "descriptive":
        q = normalize_descriptive_question(q)
    elif q_type != "multiple_choice":
        q["options"] = []
        q["answer"] = first_non_empty(q.get("answer"), q.get("expected_answer"), q.get("expectedAnswer"), q.get("model_answer"), q.get("modelAnswer"))
        q["acceptable_answers"] = ensure_list(q.get("acceptable_answers") or q.get("acceptableAnswers"))
        q["keywords"] = ensure_list(q.get("keywords"))
        q["grading_criteria"] = first_non_empty(q.get("grading_criteria"), q.get("gradingCriteria"))
    return {
        "id": 0,
        "type": q_type,
        "question": q.get("question", "문제를 생성하지 못했습니다."),
        "options": q.get("options", []),
        "answer": q.get("answer", ""),
        "acceptable_answers": ensure_list(q.get("acceptable_answers") or q.get("acceptableAnswers")),
        "explanation": q.get("explanation", "해설이 제공되지 않았습니다."),
        "source_type": "Document" if source_text and request.generation_mode != "ai_only" else "AI",
        "difficulty": request.difficulty,
        "code": q.get("code", ""),
        "language": q.get("language", ""),
        "starter_code": q.get("starter_code", ""),
        "test_cases": q.get("test_cases", []),
        "rubric": ensure_list(q.get("rubric")),
        "expected_format": q.get("expected_format", ""),
        "model_answer": q.get("model_answer", ""),
        "sample_answer": q.get("sample_answer", ""),
        "expected_answer": q.get("expected_answer", ""),
        "keywords": ensure_list(q.get("keywords")),
        "grading_criteria": q.get("grading_criteria", ""),
    }


def build_question_basis(request: QuestionRequest, source_text: Optional[str]) -> str:
    mode = normalize_generation_mode(request.generation_mode)
    if mode == "material_only":
        return f"""
        아래 [참고자료] 내용에만 기반해 문제를 생성하세요. 자료에 없는 사실을 임의로 보강하지 마세요.
        [참고자료]
        {source_text[:15000] if source_text else ''}
        """
    if mode == "mixed":
        return f"""
        아래 [참고자료]를 우선 근거로 사용하고, 부족한 연결 설명은 일반적으로 알려진 {request.subject} 지식으로 보강하세요.
        [참고자료]
        {source_text[:15000] if source_text else ''}
        """
    return f"일반적으로 알려진 {request.subject} 과목 지식을 기반으로 문제를 생성하세요."


def build_question_prompt(request: QuestionRequest, source_text: Optional[str], type_counts: Dict[str, int]) -> str:
    context_str = f"학습 단원은 '{request.level_title}' ({request.level_description}) 입니다." if request.level_title else ""
    return f"""
    당신은 유능한 교육 전문가입니다.

    [과목]
    {request.subject}

    [과목 유형]
    {request.subject_type}

    [학습 모드]
    {request.mode}

    [문제 생성 방식]
    {request.generation_mode}

    [학습 수준]
    {request.learning_level} / {request.difficulty}
    {learning_level_guidance(request.learning_level)}

    [학습 단원]
    {context_str}

    [문제 생성 근거]
    {build_question_basis(request, source_text)}

    [허용된 문제 유형]
    {json.dumps(request.allowed_question_types, ensure_ascii=False)}

    [반드시 지킬 문제 유형별 개수]
    {json.dumps(type_counts, ensure_ascii=False)}

    [중요 규칙]
    1. questions 배열에는 총 {request.count}개의 문제를 넣으세요.
    2. 각 문제의 type은 반드시 허용된 문제 유형 중 하나여야 합니다.
    3. conceptual 과목에는 coding, code_reading, sql_writing, command_writing 문제를 만들지 마세요.
    4. calculation 과목에는 coding 대신 calculation 문제를 사용하세요.
    5. practical 과목 중 데이터베이스/SQL 단원은 sql_writing 문제를 사용할 수 있습니다.
    6. programming 과목은 code_reading 또는 coding 문제를 사용할 수 있습니다.
    7. 객관식 문제만 options를 4개 제공합니다.
    8. 단답형, 서술형, 코딩형, SQL 작성형, 계산형의 options는 빈 배열로 둡니다.
    9. 단답형(short_answer)은 반드시 한 단어 또는 짧은 구문으로 답할 수 있게 만드세요.
       - 빈칸 채우기, 용어 맞히기, 개념명 맞히기, 간단한 결과값 입력, 짧은 정의의 핵심 단어 입력 위주로 만드세요.
       - 긴 설명을 요구하는 문제는 short_answer가 아니라 descriptive로 분류하세요.
       - short_answer에는 answer와 acceptable_answers를 반드시 넣으세요.
    10. 서술형(descriptive)은 model_answer, sample_answer, expected_answer 중 최소 하나를 반드시 채우고 keywords와 grading_criteria를 제공합니다.
    11. 코딩형/SQL 작성형 문제에는 starter_code 또는 test_cases를 가능한 경우 제공합니다.
    12. 반드시 JSON object만 반환하세요. JSON 밖에는 아무 문장도 쓰지 마세요.

    [반환 JSON 형식]
    {{"questions": [{{"id": 1, "type": "short_answer", "question": "빈칸에 들어갈 핵심 용어는?", "options": [], "answer": "캡슐화", "acceptable_answers": ["캡슐화", "encapsulation"], "explanation": "캡슐화는 내부 구현을 숨기는 객체지향 개념입니다.", "model_answer": "", "sample_answer": "", "expected_answer": "캡슐화", "keywords": [], "grading_criteria": "허용 답안과 같으면 정답", "rubric": [], "expected_format": "한 단어 또는 짧은 구문"}}]}}
    """


@app.post("/api/auth/register")
async def register(request: RegisterRequest):
    user = database.register_user(request.email, request.password, request.nickname)
    if not user:
        raise HTTPException(status_code=400, detail="이미 가입된 이메일이거나 회원가입에 실패했습니다.")
    return {"user": user}


@app.post("/api/auth/login")
async def login(request: LoginRequest):
    user = database.login_user(request.email, request.password)
    if not user:
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 일치하지 않습니다.")
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
        request.generation_mode = normalize_generation_mode(request.generation_mode)
        request.learning_level = normalize_learning_level(request.learning_level)
        request.difficulty = difficulty_from_learning_level(request.learning_level, request.difficulty)
        existing_session = database.get_session_by_subject(request.user_id, request.subject, request.generation_mode, request.difficulty)
        if existing_session:
            return {
                "session_id": existing_session["id"],
                "subject": existing_session["subject"],
                "progress": existing_session["progress"],
                "generation_mode": existing_session["generation_mode"],
                "learning_level": existing_session["learning_level"],
                "difficulty": existing_session["difficulty"],
                "curriculum": existing_session["curriculum"],
            }
        prompt = f"""
        당신은 유능한 교육 전문가입니다. 사용자가 학습하고자 하는 주제 '{request.subject}'에 대한 적절성 검사 및 듀오링고 스타일의 4단계 커리큘럼을 생성해 주세요.
        입력값이 무의미한 자판 배열, 스팸, 심한 비속어라면 valid=false와 친절한 error_message를 반환하세요.
        {learning_level_guidance(request.learning_level)}
        반드시 JSON object 형식으로만 응답하세요.
        {{"valid": true, "error_message": "", "curriculum": [{{"id": 1, "level": 1, "title": "기초 다지기", "description": "기본 용어와 개념을 이해합니다."}}]}}
        """
        data_object = await call_llm_json(prompt, temperature=0.3)
        if not data_object.get("valid", True):
            raise HTTPException(status_code=400, detail=data_object.get("error_message", "올바른 학습 주제가 아닙니다."))
        session_id = database.create_study_session(
            request.user_id,
            request.subject,
            normalize_curriculum(data_object.get("curriculum", [])),
            generation_mode=request.generation_mode,
            difficulty=request.difficulty,
        )
        saved_session = database.get_session_by_id(session_id)
        return {
            "session_id": saved_session["id"],
            "subject": saved_session["subject"],
            "progress": saved_session["progress"],
            "generation_mode": saved_session["generation_mode"],
            "learning_level": saved_session["learning_level"],
            "difficulty": saved_session["difficulty"],
            "curriculum": saved_session["curriculum"],
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/api/generate-questions")
async def generate_questions(request: QuestionRequest):
    try:
        request.generation_mode = normalize_generation_mode(request.generation_mode)
        request.learning_level = normalize_learning_level(request.learning_level)
        request.difficulty = difficulty_from_learning_level(request.learning_level, request.difficulty)
        source_text = None
        if request.session_id > 0 and (request.use_uploaded_material or request.generation_mode in {"material_only", "mixed"}):
            source_text = database.get_session_source_text(request.session_id)
        if request.generation_mode == "material_only" and not source_text:
            raise HTTPException(status_code=400, detail="자료 기반 생성에는 먼저 자료 업로드가 필요합니다.")
        if not request.allowed_question_types:
            request.allowed_question_types = ["multiple_choice"]
        request.allowed_question_types = [normalize_type(item) for item in request.allowed_question_types]
        if not request.question_type_weights:
            request.question_type_weights = {"multiple_choice": 100}
        request.question_type_weights = {normalize_type(key): value for key, value in request.question_type_weights.items()}
        allowed_set = set(request.allowed_question_types)
        type_counts = build_type_counts(request.question_type_weights, request.count)
        prompt = build_question_prompt(request, source_text, type_counts)
        data_object = await call_llm_json(prompt, temperature=0.2)
        parsed_questions = data_object.get("questions", [])
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
            q_type = normalize_type(q.get("type", "multiple_choice"))
            if q_type not in allowed_set:
                continue
            if q_type == "short_answer" and not is_valid_short_answer(q):
                continue
            options = q.get("options", [])
            if q_type == "multiple_choice" and (not isinstance(options, list) or len(options) < 2):
                continue
            if q_type != "multiple_choice":
                q["options"] = []
            normalized_question = normalize_generated_question(q, q_type, request, source_text)
            normalized_question["id"] = len(final_questions) + 1
            final_questions.append(normalized_question)
        if request.session_id > 0:
            final_questions = database.save_generated_questions(request.session_id, final_questions)
        return {"questions": final_questions}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/api/answer-records")
async def add_answer_record(request: AnswerRecordRequest):
    row_id = database.record_answer(
        user_id=request.user_id,
        session_id=request.session_id,
        question_id=request.question_id,
        subject=request.subject,
        question_type=normalize_type(request.question_type),
        difficulty=request.difficulty,
        question_text=request.question_text,
        options=request.options,
        correct_answer=request.correct_answer,
        model_answer=request.model_answer,
        explanation=request.explanation,
        user_answer=request.user_answer,
        is_correct=request.is_correct,
    )
    return {"id": row_id, "message": "풀이 기록 저장 완료"}


@app.get("/api/study-calendar")
async def get_study_calendar(user_id: int):
    return database.get_study_calendar(user_id)


@app.get("/api/incorrect-answers")
async def get_incorrect_answers(user_id: int):
    return {"answers": database.get_incorrect_answers(user_id)}


@app.post("/api/incorrect-answers")
async def add_incorrect_answer(request: IncorrectAnswerRequest):
    row_id = database.add_incorrect_answer(
        request.user_id,
        request.subject,
        request.question,
        request.options,
        request.answer,
        request.explanation,
        request.user_answer,
        session_id=request.session_id,
        question_id=request.question_id,
        question_type=normalize_type(request.question_type),
        difficulty=request.difficulty,
    )
    if not row_id:
        raise HTTPException(status_code=500, detail="오답을 DB에 등록하지 못했습니다.")
    return {"id": row_id, "message": "오답 노트 등록 완료"}


@app.delete("/api/incorrect-answers/{answer_id}")
async def delete_incorrect_answer(answer_id: int):
    success = database.delete_incorrect_answer(answer_id)
    if not success:
        raise HTTPException(status_code=404, detail="해당 오답 항목을 찾을 수 없습니다.")
    return {"message": "오답 노트에서 제외되었습니다."}


@app.post("/api/upload-material")
async def upload_material(
    user_id: int = Form(...),
    files: Optional[List[UploadFile]] = File(None),
    file: Optional[UploadFile] = File(None),
    session_id: Optional[int] = Form(None),
    regenerate_curriculum: bool = Form(False),
    subject: Optional[str] = Form(None),
    generation_mode: str = Form("material_only"),
    learning_level: str = Form("beginner"),
    difficulty: str = Form("초급"),
):
    try:
        generation_mode = normalize_generation_mode(generation_mode)
        learning_level = normalize_learning_level(learning_level)
        difficulty = difficulty_from_learning_level(learning_level, difficulty)
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
            database.append_session_source_text(session_id, combined_source_text)
            database.update_session_generation_settings(session_id, generation_mode, difficulty)
            if regenerate_curriculum:
                updated_source_text = database.get_session_source_text(session_id) or combined_source_text
                regenerated_curriculum = await generate_curriculum_from_source_text(updated_source_text, learning_level)
                database.replace_session_curriculum(session_id, regenerated_curriculum)
            saved_session = database.get_session_by_id(session_id)
        else:
            subject_name = build_material_subject(uploaded_files, subject)
            new_session_id = database.create_study_session(
                user_id,
                subject_name,
                await generate_curriculum_from_source_text(combined_source_text, learning_level),
                combined_source_text,
                generation_mode=generation_mode,
                difficulty=difficulty,
            )
            saved_session = database.get_session_by_id(new_session_id)
        return {
            "session_id": saved_session["id"],
            "subject": saved_session["subject"],
            "progress": saved_session["progress"],
            "generation_mode": saved_session["generation_mode"],
            "learning_level": saved_session["learning_level"],
            "difficulty": saved_session["difficulty"],
            "curriculum": saved_session["curriculum"],
            "uploaded_files": uploaded_files,
            "total_extracted_length": total_extracted_length,
            "appended_to_session": bool(session_id),
            "regenerated_curriculum": regenerate_curriculum,
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
