# Image Recognition App

A full-stack image recognition application that allows users to upload items with images and search for similar items using computer vision.

## Architecture

- **Backend**: FastAPI (Python) with PostgreSQL database
- **Frontend**: React with Chakra UI
- **Image Storage**: AWS S3
- **Deployment**: Single AWS EC2 instance with automated CI/CD via GitHub Actions

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

### Deployment to AWS

This project uses Infrastructure as Code (Terraform) and automated CI/CD (GitHub Actions).

**Initial Setup (One-Time):**
1. Deploy infrastructure with Terraform
2. Deploy initial Docker image to EC2 using deployment script
3. Configure GitHub Secrets
4. Push to `main` branch → Automated deployments from then on

For detailed instructions, see:
- **Quick Setup**: [`docs/QUICK_START.md`](docs/QUICK_START.md)
- **Full Guide**: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)

**Important:** After running `terraform apply`, you must run the initial deployment script (`deploy-ec2.ps1` on Windows or `deploy-ec2.sh` on Linux/Mac) to build and deploy the first Docker image to your EC2 instance.

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
- AWS EC2 (single instance)
- AWS RDS PostgreSQL
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

## Deployment Workflow

### Initial Setup
1. **Deploy Infrastructure**: Run `terraform apply` to create AWS resources (VPC, EC2, RDS, S3, etc.)
2. **Deploy Initial Image**: Run `deploy-ec2.ps1` (Windows) or `deploy-ec2.sh` (Linux/Mac) to build and deploy the Docker image to EC2
3. **Configure CI/CD**: Set up GitHub Secrets for automated deployments

### Automated Deployments
After initial setup, deployments are fully automated:

1. Push code to `main` branch
2. GitHub Actions automatically builds Docker image
3. Image is transferred to EC2 via AWS Systems Manager
4. Service is restarted with new image
5. Application is available at `http://<EC2_IP>:8000`

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
