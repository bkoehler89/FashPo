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

def validate_password(stored_password, provided_password):
    # Decode the stored_password which contains the salt and the hashed password
    salt_and_hashed = base64.b64decode(stored_password)
    # The first 16 bytes are the salt, the rest is the hashed password
    salt = salt_and_hashed[:16]
    stored_hashed_password = salt_and_hashed[16:]
    # Hash the provided_password using the same salt
    hashed = hashlib.pbkdf2_hmac('sha256', provided_password.encode('utf-8'), salt, 100000)
    # Compare the stored hashed password with the newly hashed provided password
    return stored_hashed_password == hashed

def lambda_handler(event, context):
    # RDS connection details from environment variables
    rds_host = os.getenv('DB_HOST')
    name = os.getenv('DB_USER')
    password = os.getenv('DB_PASS')
    db_name = os.getenv('DB_NAME')

    # Log the event received
    logger.info(f"Received event for authentication: {event}")

    # Parse the incoming JSON data from the 'body' of the event
    try:
        body = json.loads(event['body'])
    except json.JSONDecodeError as e:
        logger.error("Error parsing JSON body from event: {}".format(e))
        return {'statusCode': 400, 'body': json.dumps({'message': 'Invalid JSON format received'})}

    username = body.get('username')
    provided_password = body.get('password')

    # Validate received data
    if not all([username, provided_password]):
        logger.warning("Missing username or password from input")
        return {'statusCode': 400, 'body': json.dumps({'message': 'Missing username or password'})}

    try:
        # Use a with statement to ensure the connection is closed properly
        with pymysql.connect(host=rds_host, user=name, passwd=password, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                # SQL SELECT statement to retrieve the stored password
                sql = "SELECT password FROM Users WHERE username = %s"
                cur.execute(sql, (username,))
                result = cur.fetchone()
                if result:
                    stored_password = result[0]
                    # Validate the provided password against the stored password
                    if validate_password(stored_password, provided_password):
                        message = "Authentication successful for user {}.".format(username)
                        logger.info(message)
                        return {'statusCode': 200, 'body': json.dumps({'message': message})}
                    else:
                        message = "Authentication failed for user {}.".format(username)
                        logger.warning(message)
                        return {'statusCode': 401, 'body': json.dumps({'message': message})}
                else:
                    message = "Username not found."
                    logger.warning(message)
                    return {'statusCode': 404, 'body': json.dumps({'message': message})}
    except pymysql.MySQLError as e:
        logger.exception("Database connection or execution failed: {}".format(e))
        return {'statusCode': 500, 'body': json.dumps({'message': 'Database connection or execution failed'})}
