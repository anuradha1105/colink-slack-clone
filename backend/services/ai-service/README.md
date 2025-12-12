# Colink AI Service

AI-powered features for Colink Slack Clone using **Google Gemini 2.0 Flash**.

## Features

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/rephrase` | POST | Fix grammar & improve message clarity |
| `/suggest-replies` | POST | Generate 3 smart reply suggestions |
| `/summarize` | POST | Summarize conversations (up to 50 messages) |
| `/ask` | POST | AI assistant for questions |
| `/health` | GET | Health check |
| `/metrics` | GET | Prometheus metrics |

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Set API key
export GEMINI_API_KEY=your_key_here

# Run
python main.py
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `GEMINI_API_KEY` | - | Google Gemini API key (required) |
| `PORT` | `8011` | Server port |
| `DEBUG` | `false` | Enable debug logging |

## API Examples

**Rephrase:**
```json
POST /rephrase
{ "text": "i m goin tmrw" }
→ { "rephrased": "I'm going tomorrow.", "was_changed": true }
```

**Smart Replies:**
```json
POST /suggest-replies
{ "message": "Can you review my PR?" }
→ { "suggestions": ["Sure!", "On it!", "I'll check it out."] }
```

**Summarize:**
```json
POST /summarize
{ "messages": ["msg1", "msg2", "msg3"] }
→ { "summary": "• Key point 1\n• Key point 2", "message_count": 3 }
```

## Tech Stack

FastAPI • Pydantic v2 • Google Gemini • Prometheus • Uvicorn

---

