# Image Recognition Frontend

This is a React-based frontend for the image recognition POC.

## Project Structure

- `frontend/` - React app (user interface)
- `backend/` - FastAPI app (existing, in root)

## Getting Started

1. Install dependencies:
   ```sh
   cd frontend
   npm install
   ```
2. Start the development server:
   ```sh
   npm start
   ```

## Features
- Upload images for an item
- Remove images/items
- Query the database with an image
- View top matches

## Deployment
- Designed for easy containerization and AWS deployment.
- Configure API URL via environment variables.
