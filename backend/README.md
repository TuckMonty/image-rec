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


scrappy backend deployment, when connected to the ec2:

docker run -d --name image-rec-backend -p 8000:8000 \
  -e DATABASE_URL=... \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_REGION=us-east-1 \
  -e S3_BUCKET=image-rec-backend \
  image-rec-backend