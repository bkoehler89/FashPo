import json
import pymysql
import os
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Retrieve database credentials from environment variables
    db_host = os.environ['DB_HOST']
    db_name = os.environ['DB_NAME']
    db_user = os.environ['DB_USER']
    db_pass = os.environ['DB_PASS']

    try:
        # Parse the input data from the POST request
        data = json.loads(event['body'])
        input_username = data['username']
        
        # Use a with statement to ensure the connection is closed after usage
        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as connection:
            with connection.cursor() as cursor:
                # Query to check if the username exists in the Users table
                cursor.execute("SELECT EXISTS(SELECT 1 FROM Users WHERE username = %s)", (input_username,))
                (exists,) = cursor.fetchone()
                
                # Determine if the username exists
                message = 'Username exists' if exists else 'Username does not exist'

                logger.info("Query executed successfully.")

                # Return the result
                return {
                    'statusCode': 200,
                    'body': json.dumps({'message': message})
                }

    except pymysql.MySQLError as e:
        logger.error("Could not connect to MySQL instance: %s", e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Error connecting to the database.'})
        }
    except KeyError as e:
        logger.error("KeyError: The key %s is missing from the input.", e)
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'The key {e} is missing from the input.'})
        }
    except Exception as e:
        logger.error("Exception: %s", e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'An error occurred processing your request.'})
        }
