FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY services/websocket/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy service code
COPY services/websocket/ /app/

# Expose WebSocket port
EXPOSE 8009

# Run the application
CMD ["python", "-m", "uvicorn", "main:socket_app", "--host", "0.0.0.0", "--port", "8009", "--reload"]
