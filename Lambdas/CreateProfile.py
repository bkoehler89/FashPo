import pymysql
import os
import logging
import json
import hashlib
import base64
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def hash_password(password, salt=None):
    if salt is None:
        salt = os.urandom(16)  # 128-bit salt
    assert len(salt) == 16, "Salt must be 128 bits long"
    hashed = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    hashed = base64.b64encode(salt + hashed).decode('ascii')
    return hashed

def lambda_handler(event, context):
    # RDS connection details from environment variables
    rds_host = os.getenv('DB_HOST')
    name = os.getenv('DB_USER')
    password = os.getenv('DB_PASS')
    db_name = os.getenv('DB_NAME')

    # Log environment information
    logger.info("Connecting to database at: {}".format(rds_host))

    # Get the current time in UTC
    utc_now = datetime.utcnow()
    # Assuming EST is 5 hours behind UTC (4 hours during daylight saving time)
    est_offset = timedelta(hours=-5)
    # Apply offset to get EST time
    est_now = utc_now + est_offset
    created_at_str = est_now.strftime('%Y-%m-%d %H:%M:%S')

    # Log the event received
    logger.info(f"Received event: {event}")

    # Parse the incoming JSON data from the 'body' of the event
    try:
        body = json.loads(event['body'])
    except json.JSONDecodeError as e:
        logger.error("Error parsing JSON body from event: {}".format(e))
        return {'statusCode': 400, 'body': json.dumps({'message': 'Invalid JSON format received'})}

    username = body.get('username')
    email = body.get('email')
    gender = body.get('gender')
    age = body.get('age')
    height = body.get('height')
    password_to_hash = body.get('password')

    # Validate received data
    if not all([username, email, gender, age, height, password_to_hash]):
        logger.warning("Missing data from input")
        return {'statusCode': 400, 'body': json.dumps({'message': 'Missing data'})}

    hashed_password = hash_password(password_to_hash)

    try:
        # Use a with statement to ensure the connection is closed properly
        with pymysql.connect(host=rds_host, user=name, passwd=password, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                # SQL INSERT statement
                sql = """
                INSERT INTO Users (username, user_categories, user_posts, favorite_posts, email, gender, age, height, password, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """
                # Executing the SQL statement
                cur.execute(sql, (username, '', '', '', email, gender, age, height, hashed_password, created_at_str))
                conn.commit()  # Commit to save changes
                user_id = cur.lastrowid  # Get the last inserted id
                message = f"User {username} successfully created with ID {user_id}."
                logger.info(message)
    except pymysql.MySQLError as e:
        logger.exception("Database connection or execution failed: {}".format(e))
        return {'statusCode': 500, 'body': json.dumps({'message': 'Database connection or execution failed'})}

    return {'statusCode': 200, 'body': json.dumps({'message': message, 'created_at': created_at_str, 'id': user_id})}
