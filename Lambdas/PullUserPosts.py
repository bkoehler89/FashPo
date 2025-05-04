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
        logger.info(f"Fetching image from S3 with key: {image_key}")
        response = s3.get_object(Bucket=bucket_name, Key=image_key)
        return base64.b64encode(response['Body'].read()).decode('utf-8')
    except ClientError as e:
        logger.error(f"Failed to fetch image from S3 with key: {image_key}")
        logger.error(e)
        return None

def lambda_handler(event, context):
    logger.info(f"Received event: {event}")

    try:
        body = json.loads(event['body'])
        user_id = body['user_id']
        post_type = body['post_type']
        logger.info(f"User ID: {user_id}, Post Type: {post_type}")

        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                column_name = 'user_posts' if post_type == 'user_posts' else 'favorite_posts'
                cur.execute(f"SELECT {column_name} FROM Users WHERE id = %s", (user_id,))
                posts_result = cur.fetchone()

                if not posts_result or not posts_result[0]:
                    logger.info(f"No posts found for user ID: {user_id}")
                    return {
                        'statusCode': 200,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps([])  # Return an empty list
                    }

                post_ids = posts_result[0].split(',')
                logger.info(f"Post IDs fetched: {post_ids}")

            images_data = []
            for post_id in post_ids:
                with conn.cursor() as cur:
                    # Modified query to also fetch 'owner_id', 'description', and 'category'
                    cur.execute("""
                        SELECT image_url, owner_id, description, category 
                        FROM Posts 
                        WHERE id = %s
                    """, (post_id,))
                    result = cur.fetchone()
                    if result:
                        image_url, owner_id, description, category = result
                        image_key = '/'.join(image_url.split('/')[3:])
                        image_base64 = get_s3_image(image_key)
                        if image_base64:
                            images_data.append({
                                'post_id': post_id,
                                'image_base64': image_base64,
                                'owner_id': owner_id,
                                'description': description,
                                'category': category
                            })

            logger.info(f"Image data fetched: {images_data}")

            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(images_data)
            }

    except Exception as e:
        logger.error("An error occurred during the lambda execution.")
        logger.error(str(e))
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({"message": "Internal server error"})
        }
