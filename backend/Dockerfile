# Use official Python image
FROM python:3.9-slim

# Set work directory
WORKDIR /app

# Install system dependencies (if needed)
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY src ./src

# Expose FastAPI port
EXPOSE 8000

# Start FastAPI app with Uvicorn (production, no --reload)
CMD ["uvicorn", "src.app:app", "--host", "0.0.0.0", "--port", "8000"]
