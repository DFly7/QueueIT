# 1. Use the official lightweight Python image
FROM python:3.11-slim

# 2. Set the working directory
WORKDIR /app

# 3. Copy requirements and install them
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copy your backend code
COPY . .

# 5. Ensure Python finds the app package
ENV PYTHONPATH=/app

# 6. Run the FastAPI app using Uvicorn
# Use python -m for reliable module resolution in containers
# 2026 Pro-tip: Use 0.0.0.0 to make it accessible to the cloud network
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]