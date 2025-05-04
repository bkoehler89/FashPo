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
        logger.info(f"Attempting to fetch image from S3 with key: {image_key}")
        response = s3.get_object(Bucket=bucket_name, Key=image_key)
        image_data = base64.b64encode(response['Body'].read()).decode('utf-8')
        logger.info(f"Successfully fetched image from S3 with key: {image_key}")
        return image_data
    except ClientError as e:
        logger.error(f"ClientError fetching image from S3 with key: {image_key}: {e.response['Error']}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error fetching image from S3 with key: {image_key}: {e}")
        return None

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        body = json.loads(event['body'])
        post_ids = body['matchingKeys']
        logger.info(f"Extracted post IDs: {post_ids}, type: {type(post_ids)}, count: {len(post_ids)}")

        # Connect to the database to retrieve image URLs based on post IDs
        images_data = []
        if post_ids:
            try:
                with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
                    logger.info("Successfully connected to the database.")
                    # Inside the for loop that iterates over post_ids
                    for post_id in post_ids:
                        with conn.cursor() as cur:
                            # Updated query to select additional fields
                            query = """
                            SELECT image_url, owner_id, description, category
                            FROM Posts
                            WHERE id = %s
                            """
                            logger.info(f"Executing query: {query} with post ID: {post_id}")
                            cur.execute(query, (post_id,))
                            result = cur.fetchone()
                            if result:
                                image_url, owner_id, description, category = result
                                image_key = '/'.join(image_url.split('/')[3:])
                                image_base64 = get_s3_image(image_key)
                                if image_base64:
                                    images_data.append({
                                        'post_id': str(post_id),  # Convert post_id to string if necessary
                                        'image_base64': image_base64,
                                        'owner_id': owner_id,
                                        'description': description,
                                        'category': category
                                    })
                            else:
                                logger.warning(f"No data found in the database for post ID: {post_id}")

                    
                    
                    return {
                        'statusCode': 200,
                        'headers': {
                            'Content-Type': 'application/json'
                        },
                        'body': json.dumps(images_data)
                    }                    
            except pymysql.MySQLError as e:
                logger.error(f"MySQL error: {e}")
                raise
            except Exception as e:
                logger.error(f"Unexpected error while querying the database: {e}")
                raise
        
                logger.info(f"Returning {len(images_data)} image(s) encoded in Base64.")
        
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(images_data)
                }

    except json.JSONDecodeError as e:
        logger.error(f"JSON decoding error: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({"message": "Bad request. Invalid JSON format."})
        }
    except Exception as e:
        logger.error(f"Unhandled exception occurred during lambda execution: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({"message": "Internal server error"})
        }
