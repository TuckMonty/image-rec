# Image Recognition App

A full-stack image recognition application that allows users to upload items with images and search for similar items using computer vision.

## Architecture

- **Backend**: FastAPI (Python) with PostgreSQL database
- **Frontend**: React with Chakra UI
- **Image Storage**: AWS S3
- **Deployment**: AWS ECS Fargate with automated CI/CD via GitHub Actions

## Project Structure

```
image-rec/
├── backend/              # FastAPI backend
│   ├── src/             # Application code
│   ├── Dockerfile       # Backend container
│   └── requirements.txt
├── frontend/            # React frontend
│   ├── src/            # React components
│   └── package.json
├── infrastructure/      # Infrastructure as Code
│   └── terraform/      # Terraform configs for AWS
├── .github/
│   └── workflows/      # CI/CD pipelines
└── docs/               # Documentation
```

## Quick Start

### Local Development

**Backend:**
```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn src.app:app --reload
```

**Frontend:**
```bash
cd frontend
npm install
npm start
```

### Deployment

For automated deployment setup, see:
- **Quick Setup**: [`docs/QUICK_START.md`](docs/QUICK_START.md)
- **Full Guide**: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)

## Features

- Upload items with images to a database
- Search for similar items by uploading an image
- Image similarity matching using computer vision
- RESTful API backend
- Modern, responsive UI

## Technology Stack

**Backend:**
- FastAPI
- PostgreSQL (AWS RDS)
- AWS S3 for image storage
- Docker

**Frontend:**
- React
- Chakra UI
- Axios

**Infrastructure:**
- AWS ECS Fargate
- AWS ECR
- AWS RDS
- AWS S3
- GitHub Actions
- Terraform

## Development

### Prerequisites

- Python 3.9+
- Node.js 18+
- Docker
- AWS CLI (for deployment)
- Terraform (for infrastructure)

### Environment Variables

Create a `.env` file in the backend directory:

```env
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_REGION=us-east-1
S3_BUCKET=your-bucket-name
```

**Never commit `.env` files to git!**

## Deployment

This project uses modern CI/CD practices:

1. Push code to `main` branch
2. GitHub Actions automatically builds Docker images
3. Images are pushed to AWS ECR
4. ECS service is updated with new image
5. Zero-downtime deployment

See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for complete setup instructions.

## Security

- All secrets are stored in AWS Secrets Manager and GitHub Secrets
- No credentials are committed to the repository
- IAM roles follow least privilege principle
- Database is in private subnet
- Images are scanned for vulnerabilities

## Contributing

1. Create a feature branch
2. Make your changes
3. Test locally
4. Create a pull request
5. Automated deployment runs on merge to `main`

## License

MIT
