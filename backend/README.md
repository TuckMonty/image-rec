# Backend for Image Recognition POC

- All backend code is now in `backend/src/`
- Data is stored in `backend/data/`
- To run: `uvicorn src.app:app --reload`

---

## Local Development (without Docker)

1. **Install Python 3.9+ and create a virtual environment:**
   ```sh
   python -m venv .venv
   .venv\Scripts\activate  # On Windows
   # or
   source .venv/bin/activate  # On Mac/Linux
   ```
2. **Install dependencies:**
   ```sh
   pip install -r requirements.txt
   ```
3. **Run the FastAPI app:**
   ```sh
   uvicorn src.app:app --reload
   ```
   The API will be available at http://127.0.0.1:8000

## Local Development with Docker

1. **Build the Docker image:**
   ```sh
   docker build -t image-rec-backend .
   ```
   
   **Or, start and run the docker image with docker compose**

   ```sh
   docker-compose up -d --build
   ```
   **then stop the container**
   ```sh
   docker-compose down
   ```

2. **Run the container:**
   ```sh
   docker run -p 8000:8000 image-rec-backend
   ```
   or
   ```sh
   docker run --env-file .env -p 8000:8000 image-rec-backend
   ```
   The API will be available at http://127.0.0.1:8000

## Notes
- By default, images and features are stored in the `data/` directory. This is not persisted in Docker unless you mount a volume.
- For development, you can mount your local `data/` folder into the container:
  ```sh
  docker run -p 8000:8000 -v %cd%/data:/app/data image-rec-backend  # Windows
  # or
  docker run -p 8000:8000 -v $(pwd)/data:/app/data image-rec-backend  # Mac/Linux
  ```
- To install new dependencies, add them to `requirements.txt` and rebuild the image.

---
For more details, see the main project README.


## Production Deployment

**IMPORTANT**: Never commit credentials to git. Use environment variables or secrets management.

### Manual Deployment (Legacy - to be replaced by CI/CD)

When connected to EC2:
1. Pull latest code: `git pull`
2. Build image: `docker build -t image-rec-backend .`
3. Run container with environment variables from AWS Secrets Manager or .env file:
   ```sh
   docker run -d --name image-rec-backend -p 8000:8000 \
     -e DATABASE_URL=${DATABASE_URL} \
     -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
     -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
     -e AWS_REGION=${AWS_REGION} \
     -e S3_BUCKET=${S3_BUCKET} \
     image-rec-backend
   ```

See `docs/DEPLOYMENT.md` for automated CI/CD deployment instructions.