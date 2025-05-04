import os
import json
import logging
import base64
import pymysql
import boto3
from botocore.exceptions import ClientError

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
db_host = os.environ['DB_HOST']
db_name = os.environ['DB_NAME']
db_user = os.environ['DB_USER']
db_pass = os.environ['DB_PASS']
bucket_name = os.environ['BUCKET_NAME']

def get_s3_image(image_key):
    s3 = boto3.client('s3')
    try:
        response = s3.get_object(Bucket=bucket_name, Key=image_key)
        logger.info(f"Successfully retrieved image from S3: {image_key}")
        return base64.b64encode(response['Body'].read()).decode('utf-8')
    except ClientError as e:
        logger.error(f"Failed to get image from S3: {image_key}")
        logger.exception(e)
        return None

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        post_id = body['post_id']
        logger.info(f"Processing post ID: {post_id}")

        # Connect to the database and query the Posts table
        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=10) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT owner_id, category, description, image_url FROM Posts WHERE id = %s", (post_id,))
                result = cur.fetchone()

            if result:
                owner_id, category, description, image_url = result
                logger.info(f"Found post: {post_id}")

                # Split the S3 URL to get only the image key
                image_key = '/'.join(image_url.split('/')[3:])  # Assumes a specific URL structure
                image_base64 = get_s3_image(image_key)
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'owner_id': owner_id, 
                        'category': category, 
                        'description': description,
                        'image_base64': image_base64
                    })
                }
            else:
                logger.warning(f"Post not found: {post_id}")
                return {
                    'statusCode': 404,
                    'body': json.dumps({'message': 'Post not found'})
                }
    except pymysql.MySQLError as e:
        logger.error("ERROR: Unexpected error: Could not connect to MySQL instance.")
        logger.exception(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Internal server error'})
        }
    except Exception as e:
        logger.error("An error occurred during lambda execution.")
        logger.exception(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Internal server error'})
        }
    finally:
        logger.info("Lambda handler finished execution")
