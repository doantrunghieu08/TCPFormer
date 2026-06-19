FROM python:3.10-slim as builder

WORKDIR /app/data

RUN pip install --no-cache-dir gdown

RUN gdown 124t_JEyiavo_qYcFj6iSKVudMm268brG -O TCPFormer_ap3d_81.pth.tr
RUN gdown 1_EjMWL9Rd9hPXaSahzShxm1-Ud2f4o5r -O train.pkl
# RUN gdown 1LuhnQabwXBOzAeRkODJYxr9drf85MJSp -O yolov8n.pt

FROM runpod/pytorch:1.0.3-cu1281-torch280-ubuntu2404

WORKDIR /app

# Environment
ENV PYTHONUNBUFFERED=1
ENV VLM_API_URL="http://localhost:8000"

# Install runtime system dependencies (kept together for single layer)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglx-mesa0 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    zstd \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy only requirements first to leverage Docker cache for deps
COPY requirements.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy small application files (keep large model weights last to avoid cache invalidation)
COPY start.sh local_pose_3d_server.py tcpformer_model.py ./

# Prepare runtime directories and permissions
RUN mkdir -p /app/videos && chmod +x /app/start.sh

# Copy large model weight last (minimize rebuilds of earlier layers)
COPY --from=builder /app/data/* ./

# Expose ports (optional, services communicate via localhost inside container)
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/', timeout=5)"

# Start script
CMD ["/bin/bash", "./start.sh"]
