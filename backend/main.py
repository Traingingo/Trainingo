import os
import json
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from groq import AsyncGroq

load_dotenv()

app = FastAPI()

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

class CurriculumRequest(BaseModel):
    subject: str

@app.get("/")
def read_root():
    return {"message": "백엔드 서버 정상 작동 중!"}

@app.post("/api/generate-curriculum")
async def generate_curriculum(request: CurriculumRequest):
    try:
        prompt = f"""
        당신은 유능한 교육 전문가입니다. 사용자가 학습하고자 하는 주제: '{request.subject}' 에 대해 듀오링고 스타일의 점진적인 4단계 커리큘럼을 생성해 주세요.
        
        반드시 아래의 JSON object 형식으로만 응답해야 하며, 다른 설명이나 텍스트는 포함하지 마십시오.
        각 레벨 객체 내부의 키값(id, level, title, description)은 규격에 맞춰야 합니다.
        
        {{
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
        parsed_curriculum = data_object.get("curriculum", [])

        final_curriculum = []
        for i, item in enumerate(parsed_curriculum):
            final_curriculum.append({
                "id": int(item.get("id", i + 1)),
                "level": int(item.get("level", i + 1)),
                "title": f"Level {i + 1}. {item.get('title', '학습 단원')}",
                "description": item.get("description", "이 단원의 핵심 개념을 학습합니다."),
                "isLocked": i > 0,
                "isCompleted": False
            })

        print(f"✅ 성공적으로 '{request.subject}'에 대한 커리큘럼 {len(final_curriculum)}단계를 생성했습니다.")
        return {"curriculum": final_curriculum}

    except Exception as e:
        print(f"❌ 커리큘럼 생성 중 에러 발생: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/generate-questions")
async def generate_questions(request: QuestionRequest):
    try:
        # 단원명과 설명이 주어졌다면 프롬프트에 추가 반영
        context_str = f" 학습 단원은 '{request.level_title}' ({request.level_description}) 입니다." if request.level_title else ""
        
        prompt = f"""
        당신은 유능한 교육 전문가입니다. {request.subject} 과목{context_str}에 대한 퀴즈 문제를 생성해 주세요.
        난이도는 '{request.difficulty}'이며, 총 {request.count}문제를 만들어야 합니다.
        
        반드시 아래의 JSON object 형식으로만 응답해야 하며, 다른 설명이나 텍스트는 포함하지 마십시오.
        각 문제 객체 내부의 키값(question, options, answer, explanation)은 반드시 문자열(String) 또는 리스트(List) 형태여야 합니다. 전체 구조를 문자열로 직렬화하지 마십시오.
        
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
            temperature=0.1,  # 온도를 최대로 낮춰서 뇌절 및 규격 이탈 원천 차단
            response_format={"type": "json_object"}  # 완벽한 JSON 규격 보장 치트키
        )

        raw_content = response.choices[0].message.content.strip()

        # 1차 파싱
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
                "source_type": "AI",
                "difficulty": request.difficulty
            })

        print(f"✅ 성공적으로 {len(final_questions)}문제를 생성하여 반환합니다.")
        return {"questions": final_questions}

    except Exception as e:
        print(f"❌ API 요청 처리 중 내부 에러 발생: {e}")
        raise HTTPException(status_code=500, detail=str(e))