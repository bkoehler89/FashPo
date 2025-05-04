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

# Retrieve database and AWS credentials from environment variables
db_host = os.environ['DB_HOST']
db_name = os.environ['DB_NAME']
db_user = os.environ['DB_USER']
db_pass = os.environ['DB_PASS']
bucket_name = os.environ['BUCKET_NAME']

def get_s3_image(image_key):
    s3 = boto3.client('s3')
    try:
        response = s3.get_object(Bucket=bucket_name, Key=image_key)
        return base64.b64encode(response['Body'].read()).decode('utf-8')
    except ClientError as e:
        logger.error(f"Error fetching image from S3: {e}")
        return None
        
def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        category_id = body['categoryId']
        user_id = body['userId']
        gender = body['gender']
        last_post_id = body['lastPostId']
        page_size = int(body['pageSize'])

        is_subscribed = False
        images_data = []

        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
            logger.info("Successfully connected to the database")

            with conn.cursor() as cur:
                cur.execute("SELECT user_categories FROM Users WHERE id = %s", (user_id,))
                user_categories_result = cur.fetchone()
                if user_categories_result and category_id in user_categories_result[0].split(','):
                    is_subscribed = True

                cur.execute("SELECT post_ids FROM Categories WHERE id = %s", (category_id,))
                category_result = cur.fetchone()
                if category_result:
                    post_ids = category_result[0].split(',')
                    last_post_index = post_ids.index(last_post_id) + 1 if last_post_id else 0

                    valid_post_count = 0
                    for post_id in post_ids[last_post_index:]:
                        if valid_post_count == page_size:
                            break
                        cur.execute("""
                            SELECT id, image_url, gender_restriction, owner_id, description, category 
                            FROM Posts 
                            WHERE id = %s""", (post_id,))
                        post_result = cur.fetchone()
                        if post_result and (post_result[2] == gender or post_result[2] == 'All'):
                            image_url = post_result[1]
                            image_key = '/'.join(image_url.split('/')[3:])
                            image_base64 = get_s3_image(image_key)
                            if image_base64:
                                images_data.append({
                                    'post_id': str(post_result[0]),
                                    'image_base64': image_base64,
                                    'owner_id': post_result[3],
                                    'description': post_result[4],
                                    'category': post_result[5]
                                })
                                valid_post_count += 1

        response = {
            'statusCode': 200,
            'body': json.dumps({
                'images_data': images_data,
                'is_subscribed': is_subscribed
            })
        }
        return response

    except pymysql.MySQLError as e:
        logger.error("ERROR: Unexpected error: Could not connect to MySQL instance.")
        logger.exception(e)
        return {
            'statusCode': 500,
            'body': json.dumps({"error": str(e)})
        }
