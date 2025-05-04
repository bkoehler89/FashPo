import os
import json
import logging
import base64
import pymysql
import boto3
from botocore.exceptions import ClientError
from datetime import datetime, timedelta

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
db_host = os.environ['DB_HOST']
db_name = os.environ['DB_NAME']
db_user = os.environ['DB_USER']
db_pass = os.environ['DB_PASS']
bucket_name = os.environ['BUCKET_NAME']  # Make sure to set this in your Lambda environment variables

# AWS clients
s3_client = boto3.client('s3')
rds_client = pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5)

def upload_image_to_s3(image_data, bucket, folder_name, file_name):
    try:
        s3_client.put_object(Bucket=bucket, Key=f"{folder_name}/{file_name}", Body=image_data)
        return True
    except ClientError as e:
        logger.error("Could not upload to S3: %s", e)
        return False

def lambda_handler(event, context):
    # Parse the JSON body from the event
    try:
        body = json.loads(event.get('body', '{}'))
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps("Error parsing JSON body")
        }

    # Extract owner_id, category, description, and clothing items information
    owner_id = body.get('owner_id')  # We now expect an integer ID for the owner
    category = body.get('category', '')
    description = body.get('description', ' ')
    clothing_items = body.get('clothing_items', [])
    clothing_items_str = ', '.join(clothing_items)
    gender_restriction = body.get('gender_restriction', 'Hello')

    # Get the current time in UTC
    utc_now = datetime.utcnow()
    est_offset = timedelta(hours=-5)  # Assuming EST is 5 hours behind UTC
    est_now = utc_now + est_offset
    created_at_str = est_now.strftime('%Y-%m-%d %H:%M:%S')

    # Insert a new row into the Posts table
    try:
        with rds_client.cursor() as cur:
            cur.execute("""
                INSERT INTO Posts (owner_id, category, description, clothing_items, created_at, gender_restriction) 
                VALUES (%s, %s, %s, %s, %s, %s);
            """, (owner_id, category, description, clothing_items_str, created_at_str, gender_restriction))
            post_id = cur.lastrowid
            rds_client.commit()
    except pymysql.MySQLError as e:
        logger.error(f"Failed to insert new post: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps("Error inserting new post into database")
        }

    # Process the image data and upload to S3
    if 'image' in body:
        image_data = base64.b64decode(body['image'])
        folder_name = f"post_{post_id}"
        file_name = "uploaded_image.jpg"
        if upload_image_to_s3(image_data, bucket_name, folder_name, file_name):
            image_url = f"https://{bucket_name}.s3.amazonaws.com/{folder_name}/{file_name}"
            # Update the Posts table with the image URL
            try:
                with rds_client.cursor() as cur:
                    cur.execute("""
                        UPDATE Posts SET image_url = %s WHERE id = %s;
                    """, (image_url, post_id))
                    rds_client.commit()
            except pymysql.MySQLError as e:
                logger.error(f"Failed to update database with image URL: {e}")
                return {
                    'statusCode': 500,
                    'body': json.dumps("Error updating the database with image URL")
                }
        else:
            return {
                'statusCode': 500,
                'body': json.dumps("Failed to upload image to S3")
            }
    
    # Update the Users table with the new post ID
    try:
        with rds_client.cursor() as cur:
            # First, retrieve the current user_posts for the owner_id
            cur.execute("""
                SELECT user_posts FROM Users WHERE id = %s;
            """, (owner_id,))
            result = cur.fetchone()
            
            # Append the new post ID to the existing list of post IDs
            user_posts = result[0] + ',' + str(post_id) if result and result[0] else str(post_id)
            
            # Update the Users table with the new user_posts
            cur.execute("""
                UPDATE Users SET user_posts = %s WHERE id = %s;
            """, (user_posts, owner_id))
            rds_client.commit()
    except pymysql.MySQLError as e:
        logger.error(f"Failed to update user posts: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps("Error updating user posts in database")
        }
        
    try:
        with rds_client.cursor() as cur:
            # First, retrieve the current post_ids for the category
            cur.execute("""
                SELECT post_ids FROM Categories WHERE category_name = %s;
            """, (category,))
            result = cur.fetchone()
            
            # Append the new post ID to the existing list of post IDs
            if result and result[0]:
                post_ids = result[0] + ',' + str(post_id)
            else:
                post_ids = str(post_id)
            
            # Update the Categories table with the new post_ids
            cur.execute("""
                UPDATE Categories SET post_ids = %s WHERE category_name = %s;
            """, (post_ids, category))
            rds_client.commit()
    except pymysql.MySQLError as e:
        logger.error(f"Failed to update Categories: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps("Error updating Categories in database")
        }

    clothing_article_ids = []  # Initialize a list to store the generated IDs
    try:
        with rds_client.cursor() as cur:
            for item in clothing_items:
                cur.execute("""
                    INSERT INTO ClothingArticles (post_id, type) VALUES (%s, %s);
                """, (post_id, item))
                clothing_article_ids.append(cur.lastrowid)  # Append the last generated ID
            rds_client.commit()
    except pymysql.MySQLError as e:
        logger.error(f"Failed to insert clothing items: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps("Error inserting clothing items into ClothingArticles table")
        }


    # Return a successful response message
    return {
        'statusCode': 200,
        'body': json.dumps({
            "message": "Post created successfully",
            "post_id": post_id,
            "image_url": image_url if 'image' in body else None
        })
    }
