"""Main application for AI Service using Groq."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from prometheus_fastapi_instrumentator import Instrumentator

from config import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO if not settings.debug else logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)

# Groq client (initialized on startup)
groq_client = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan events."""
    global groq_client
    
    logger.info("Starting AI Service...")
    
    # Initialize Groq
    if settings.groq_api_key:
        try:
            from groq import Groq
            groq_client = Groq(api_key=settings.groq_api_key)
            logger.info(f"Groq API initialized with model: {settings.groq_model}")
        except Exception as e:
            logger.error(f"Failed to initialize Groq: {e}")
    else:
        logger.warning("GROQ_API_KEY not set - AI features will be disabled")
    
    yield
    
    logger.info("Shutting down AI Service...")


# Create FastAPI application
app = FastAPI(
    title="Colink AI Service",
    description="AI-powered features for Colink Slack Clone",
    version=settings.service_version,
    lifespan=lifespan,
)

# Expose Prometheus metrics
Instrumentator().instrument(app).expose(app)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_origins(),
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request/Response models
class RephraseRequest(BaseModel):
    """Request model for rephrase endpoint."""
    text: str


class RephraseResponse(BaseModel):
    """Response model for rephrase endpoint."""
    original: str
    rephrased: str
    was_changed: bool


class SuggestRepliesRequest(BaseModel):
    """Request model for suggest-replies endpoint."""
    message: str


class SuggestRepliesResponse(BaseModel):
    """Response model for suggest-replies endpoint."""
    original_message: str
    suggestions: list[str]


class SummarizeRequest(BaseModel):
    """Request model for summarize endpoint."""
    messages: list[str]


class SummarizeResponse(BaseModel):
    """Response model for summarize endpoint."""
    summary: str
    message_count: int


class AskRequest(BaseModel):
    """Request model for ask endpoint."""
    question: str
    context: str | None = None


class AskResponse(BaseModel):
    """Response model for ask endpoint."""
    question: str
    answer: str


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "ai-service",
        "version": settings.service_version,
        "status": "running",
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": settings.service_name,
        "version": settings.service_version,
        "groq_configured": bool(settings.groq_api_key),
    }


@app.post("/rephrase", response_model=RephraseResponse)
async def rephrase_message(request: RephraseRequest):
    """
    Rephrase a message to fix grammar and improve clarity.
    
    Takes a potentially jumbled or grammatically incorrect message
    and returns a properly structured version.
    """
    global groq_client
    
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Text is required")
    
    original_text = request.text.strip()
    
    # If Groq is not configured, return original text
    if not groq_client:
        logger.warning("Groq not configured, returning original text")
        return RephraseResponse(
            original=original_text,
            rephrased=original_text,
            was_changed=False,
        )
    
    try:
        # Create prompt for rephrasing
        prompt = f"""You are a helpful writing assistant. Rephrase the following message to fix any grammatical errors, improve clarity, and make it sound natural. Keep the tone casual and friendly (suitable for a chat message). If the message is already correct, return it as-is.

IMPORTANT: Only return the rephrased message, nothing else. No explanations, no quotes, no prefixes.

Message to rephrase: {original_text}"""

        # Call Groq API
        chat_completion = groq_client.chat.completions.create(
            messages=[
                {"role": "user", "content": prompt}
            ],
            model=settings.groq_model,
            temperature=0.7,
            max_tokens=256,
        )
        
        rephrased_text = chat_completion.choices[0].message.content.strip()
        
        # Remove any quotes that might wrap the response
        if rephrased_text.startswith('"') and rephrased_text.endswith('"'):
            rephrased_text = rephrased_text[1:-1]
        if rephrased_text.startswith("'") and rephrased_text.endswith("'"):
            rephrased_text = rephrased_text[1:-1]
        
        was_changed = rephrased_text.lower() != original_text.lower()
        
        logger.info(f"Rephrased: '{original_text}' -> '{rephrased_text}'")
        
        return RephraseResponse(
            original=original_text,
            rephrased=rephrased_text,
            was_changed=was_changed,
        )
        
    except Exception as e:
        error_str = str(e).lower()
        logger.error(f"Error calling Groq API: {e}")
        if 'rate' in error_str or 'limit' in error_str or '429' in error_str:
            raise HTTPException(status_code=429, detail="Rate limit reached. Please try again in a moment.")
        raise HTTPException(status_code=500, detail=f"Failed to rephrase message: {str(e)}")


@app.post("/suggest-replies", response_model=SuggestRepliesResponse)
async def suggest_replies(request: SuggestRepliesRequest):
    """
    Generate smart reply suggestions for a message.
    
    Takes a message and returns 3 natural reply options.
    """
    global groq_client
    
    if not request.message or not request.message.strip():
        raise HTTPException(status_code=400, detail="Message is required")
    
    original_message = request.message.strip()
    
    # If Groq is not configured, return default suggestions
    if not groq_client:
        logger.warning("Groq not configured, returning default suggestions")
        return SuggestRepliesResponse(
            original_message=original_message,
            suggestions=["Got it!", "Thanks for sharing!", "I'll look into it."],
        )
    
    try:
        # Create prompt for generating reply suggestions
        prompt = f"""You are helping generate quick reply suggestions for a chat message. Generate exactly 3 short, natural reply options for the following message. Each reply should be brief (1-15 words), casual, and appropriate for workplace chat.

IMPORTANT: Return ONLY 3 replies, one per line. No numbering, no quotes, no explanations.

Message to reply to: "{original_message}"

Generate 3 reply options:"""

        # Call Groq API
        chat_completion = groq_client.chat.completions.create(
            messages=[
                {"role": "user", "content": prompt}
            ],
            model=settings.groq_model,
            temperature=0.8,
            max_tokens=128,
        )
        
        response_text = chat_completion.choices[0].message.content.strip()
        
        # Parse the response - split by newlines and clean up
        suggestions = []
        for line in response_text.split('\n'):
            line = line.strip()
            # Remove numbering like "1.", "1)", "-", "*"
            if line and len(line) > 0:
                # Remove common prefixes
                for prefix in ['1.', '2.', '3.', '1)', '2)', '3)', '-', '*', '•']:
                    if line.startswith(prefix):
                        line = line[len(prefix):].strip()
                        break
                # Remove quotes
                if line.startswith('"') and line.endswith('"'):
                    line = line[1:-1]
                if line.startswith("'") and line.endswith("'"):
                    line = line[1:-1]
                if line:
                    suggestions.append(line)
        
        # Ensure we have exactly 3 suggestions
        if len(suggestions) < 3:
            defaults = ["Got it!", "Thanks!", "I'll check it out."]
            suggestions.extend(defaults[len(suggestions):3])
        suggestions = suggestions[:3]
        
        logger.info(f"Generated suggestions for: '{original_message}' -> {suggestions}")
        
        return SuggestRepliesResponse(
            original_message=original_message,
            suggestions=suggestions,
        )
        
    except Exception as e:
        error_str = str(e).lower()
        logger.error(f"Error calling Groq API: {e}")
        if 'rate' in error_str or 'limit' in error_str or '429' in error_str:
            raise HTTPException(status_code=429, detail="Rate limit reached. Please try again in a moment.")
        raise HTTPException(status_code=500, detail=f"Failed to generate suggestions: {str(e)}")


@app.post("/summarize", response_model=SummarizeResponse)
async def summarize_messages(request: SummarizeRequest):
    """
    Summarize a list of chat messages.
    
    Takes an array of messages and returns a bullet-point summary.
    """
    global groq_client
    
    if not request.messages or len(request.messages) == 0:
        raise HTTPException(status_code=400, detail="Messages are required")
    
    message_count = len(request.messages)
    
    # If Groq is not configured, return a placeholder summary
    if not groq_client:
        logger.warning("Groq not configured, returning placeholder summary")
        return SummarizeResponse(
            summary="• This is a placeholder summary (AI service not configured)\n• " + str(message_count) + " messages were discussed",
            message_count=message_count,
        )
    
    try:
        # Join messages with newlines for context
        messages_text = "\n".join([f"- {msg}" for msg in request.messages[:50]])  # Limit to 50 messages
        
        prompt = f"""You are summarizing a chat conversation. Create a concise bullet-point summary of the key points discussed in these messages. Use 3-5 bullet points maximum.

IMPORTANT: 
- Return ONLY bullet points, each starting with "•"
- Be concise (1 line per bullet)
- Focus on the main topics and decisions

Messages to summarize:
{messages_text}

Summary:"""

        chat_completion = groq_client.chat.completions.create(
            messages=[
                {"role": "user", "content": prompt}
            ],
            model=settings.groq_model,
            temperature=0.5,
            max_tokens=512,
        )
        
        summary = chat_completion.choices[0].message.content.strip()
        
        logger.info(f"Generated summary for {message_count} messages")
        
        return SummarizeResponse(
            summary=summary,
            message_count=message_count,
        )
        
    except Exception as e:
        error_str = str(e).lower()
        logger.error(f"Error calling Groq API: {e}")
        if 'rate' in error_str or 'limit' in error_str or '429' in error_str:
            raise HTTPException(status_code=429, detail="Rate limit reached. Please try again in a moment.")
        raise HTTPException(status_code=500, detail=f"Failed to summarize: {str(e)}")


@app.post("/ask", response_model=AskResponse)
async def ask_ai(request: AskRequest):
    """
    Answer a question using AI.
    
    Takes a question and optional context, returns an AI-generated answer.
    """
    global groq_client
    
    if not request.question or not request.question.strip():
        raise HTTPException(status_code=400, detail="Question is required")
    
    question = request.question.strip()
    
    # If Groq is not configured, return a placeholder
    if not groq_client:
        logger.warning("Groq not configured, returning placeholder answer")
        return AskResponse(
            question=question,
            answer="I'm sorry, the AI service is not configured. Please set up the GROQ_API_KEY.",
        )
    
    try:
        context_text = ""
        if request.context:
            context_text = f"\nContext from the conversation:\n{request.context}\n"
        
        prompt = f"""You are a helpful AI assistant in a team chat application. Answer the following question helpfully and concisely. Keep your response brief (2-3 sentences max) and friendly.
{context_text}
Question: {question}

Answer:"""

        chat_completion = groq_client.chat.completions.create(
            messages=[
                {"role": "user", "content": prompt}
            ],
            model=settings.groq_model,
            temperature=0.7,
            max_tokens=256,
        )
        
        answer = chat_completion.choices[0].message.content.strip()
        
        logger.info(f"Generated answer for question: '{question[:50]}...'")
        
        return AskResponse(
            question=question,
            answer=answer,
        )
        
    except Exception as e:
        logger.error(f"Error calling Groq API: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to answer: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=settings.host, port=settings.port)
