import json
import pymysql
import os
import sys
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DB_HOST = os.environ['DB_HOST']
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASS = os.environ['DB_PASS']

def lambda_handler(event, context):

    try:
        # Establish a connection to the database using 'with' statement
        with pymysql.connect(host=DB_HOST, user=DB_USER, passwd=DB_PASS, db=DB_NAME, connect_timeout=5) as conn:
            logger.info("SUCCESS: Connection to RDS MySQL instance succeeded")

            body = json.loads(event['body'])
            # Parse the incoming JSON event to get postId and commentId
            postId = body['postId']
            commentId = str(body['commentId'])

            with conn.cursor() as cursor:
                # Get the current comments list for the post
                cursor.execute("SELECT comments FROM Posts WHERE id = %s", (postId,))
                result = cursor.fetchone()
                if result and result[0]:
                    current_comments = result[0].split(',')
                    if commentId in current_comments:
                        # Remove the commentId from the list
                        current_comments.remove(commentId)
                        new_comments = ','.join(current_comments)

                        # Update the comments column
                        cursor.execute("UPDATE Posts SET comments = %s WHERE id = %s", (new_comments, postId))
                        conn.commit()
                        return {
                            'statusCode': 200,
                            'body': json.dumps('Comment successfully deleted.')
                        }
                return {
                    'statusCode': 404,
                    'body': json.dumps('Comment or Post not found.')
                }
    except pymysql.MySQLError as e:
        logger.error("ERROR: Unexpected error: Could not connect to MySQL instance.")
        logger.error(e)
        return {
            'statusCode': 500,
            'body': json.dumps('Error in database connection.')
        }
    except Exception as e:
        logger.error(e)
        return {
            'statusCode': 500,
            'body': json.dumps('Error deleting comment.')
        }
