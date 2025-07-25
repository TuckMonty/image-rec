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


## Local Development with Docker Compose

1. **Build and start the backend service:**
   ```sh
   docker-compose up -d --build
   ```
   This will build the image (if needed) and start the backend container in the background.

2. **Stop the backend service:**
   ```sh
   docker-compose down
   ```
   The API will be available at http://127.0.0.1:8000


## Notes
- By default, images and features are stored in the `data/` directory. This is not persisted in Docker unless you mount a volume.
- The provided `docker-compose.yml` mounts the backend code and data directories for development, so changes to your code and data are reflected in the container.
- To install new dependencies, add them to `requirements.txt` and re-run:
  ```sh
  docker-compose up -d --build
  ```

---
For more details, see the main project README.
