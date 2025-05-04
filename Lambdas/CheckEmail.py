import json
import pymysql
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Database connection details from environment variables
    db_host = os.environ['DB_HOST']
    db_user = os.environ['DB_USER']
    db_password = os.environ['DB_PASS']
    db_name = os.environ['DB_NAME']

    # Extract the email from the event body
    try:
        body = json.loads(event['body'])
        email_to_check = body['email']
    except (json.JSONDecodeError, KeyError) as e:
        logger.error(f"Error processing the event body: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Bad request, unable to process the data'})
        }

    # Try to establish a connection to the RDS database
    try:
        with pymysql.connect(host=db_host, user=db_user, passwd=db_password, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cursor:
                # Prepare the SQL query to execute
                sql_query = "SELECT email FROM Users WHERE email = %s LIMIT 1;"
                
                # Execute the SQL query
                cursor.execute(sql_query, (email_to_check,))
                result = cursor.fetchone()

                # Check if the result is not None, which means a match was found
                if result:
                    response_message = f"Email {email_to_check} in use"
                else:
                    response_message = "No Match"

    except pymysql.MySQLError as e:
        logger.error(f"Could not connect to MySQL database: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Database connection failed'})
        }

    return {
        'statusCode': 200,
        'body': json.dumps({'message': response_message})
    }
