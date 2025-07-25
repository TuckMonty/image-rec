import boto3
import os
from botocore.exceptions import ClientError
from typing import Optional

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
S3_BUCKET = os.getenv("S3_BUCKET", "your-s3-bucket-name")

s3_client = boto3.client(
    "s3",
    region_name=AWS_REGION,
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
)

def upload_fileobj_to_s3(fileobj, s3_key: str, content_type: Optional[str] = None) -> str:
    """
    Upload a file-like object to S3 and return the S3 key.
    """
    extra_args = {"ContentType": content_type} if content_type else {}
    try:
        s3_client.upload_fileobj(fileobj, S3_BUCKET, s3_key, ExtraArgs=extra_args)
        return s3_key
    except ClientError as e:
        raise RuntimeError(f"Failed to upload to S3: {e}")

def generate_presigned_url(s3_key: str, expires_in: int = 3600) -> str:
    """
    Generate a presigned URL for an S3 object.
    """
    try:
        url = s3_client.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": s3_key},
            ExpiresIn=expires_in,
        )
        return url
    except ClientError as e:
        raise RuntimeError(f"Failed to generate presigned URL for {s3_key}: {e}")

def delete_file_from_s3(s3_key: str):
    """
    Delete a file from S3.
    """
    try:
        s3_client.delete_object(Bucket=S3_BUCKET, Key=s3_key)
    except ClientError as e:
        raise RuntimeError(f"Failed to delete {s3_key} from S3: {e}")
