import pymysql
import json
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
db_host = os.environ['DB_HOST']
db_name = os.environ['DB_NAME']
db_user = os.environ['DB_USER']
db_pass = os.environ['DB_PASS']

# Lambda function handler
def lambda_handler(event, context):
    # Parse the categoryId and userId from the event
    body = json.loads(event['body'])
    categoryId = body['categoryId']
    userId = body['userId']

    # Connect to the database using a with statement
    try:
        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
            with conn.cursor(pymysql.cursors.DictCursor) as cursor:
                # Get the current user_categories for the userId
                cursor.execute("SELECT user_categories FROM Users WHERE id = %s", (userId,))
                result = cursor.fetchone()

                if result:
                    # Fetch user_categories and convert to list
                    user_categories = result['user_categories']
                    categories = user_categories.split(',') if user_categories else []

                    # Add or remove categoryId based on current subscription
                    if str(categoryId) in categories:
                        # Remove the categoryId since it's already subscribed
                        categories.remove(str(categoryId))
                    else:
                        # Add the categoryId since it's not currently subscribed
                        categories.append(str(categoryId))

                    # Convert the list back to a comma-separated string
                    new_user_categories = ','.join(categories)

                    # Update the Users table
                    cursor.execute("UPDATE Users SET user_categories = %s WHERE id = %s", (new_user_categories, userId))
                    conn.commit()
                    logger.info(f"Updated user_categories for userId {userId}: {new_user_categories}")

                else:
                    logger.error(f"No user found with userId {userId}")
                    return {
                        'statusCode': 404,
                        'body': json.dumps('User not found')
                    }

    except pymysql.MySQLError as e:
        logger.error(f"SQL Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('Failed to execute query')
        }
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('An unexpected error occurred')
        }

    # Successful execution
    return {
        'statusCode': 200,
        'body': json.dumps('Subscription updated successfully')
    }
