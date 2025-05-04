import json
import pymysql
import os
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
db_host = os.environ['DB_HOST']
db_name = os.environ['DB_NAME']
db_user = os.environ['DB_USER']
db_pass = os.environ['DB_PASS']

def lambda_handler(event, context):
    # Log the received event
    logger.info("Received event: " + json.dumps(event))

    body = json.loads(event['body'])
    user_id = body['user_id']
    post_id = body['postId']
    comment_text = body['commentText']

    # Get the current time in UTC and convert to EST
    utc_now = datetime.utcnow()
    est_offset = timedelta(hours=-5)  # Adjust for daylight saving time as necessary
    est_now = utc_now + est_offset
    created_at_str = est_now.strftime('%Y-%m-%d %H:%M:%S')

    # SQL statements
    insert_sql = "INSERT INTO Comments (post_id, text, created_at, owner_id) VALUES (%s, %s, %s, %s)"
    fetch_comments_sql = "SELECT comments FROM Posts WHERE id = %s"
    update_comments_sql = "UPDATE Posts SET comments = %s WHERE id = %s"

    # Establish connection to the RDS instance using a 'with' statement
    try:
        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name) as connection:
            with connection.cursor() as cursor:
                # Execute the SQL statement to insert the new comment
                cursor.execute(insert_sql, (post_id, comment_text, created_at_str, user_id))
                new_comment_id = cursor.lastrowid  # Get the last insert id
                connection.commit()
                logger.info(f"Comment inserted successfully with id {new_comment_id}")

                # Fetch the current comments for the post
                cursor.execute(fetch_comments_sql, (post_id,))
                result = cursor.fetchone()
                current_comments = result[0] if result else None

                # Check if there are any existing comments
                if current_comments:
                    # Append the new comment ID to the existing list
                    updated_comments = f"{current_comments},{new_comment_id}"
                else:
                    # If no existing comments, start a new list
                    updated_comments = str(new_comment_id)

                # Update the Posts table with the new list of comments
                cursor.execute(update_comments_sql, (updated_comments, post_id))
                connection.commit()
                logger.info(f"Updated Posts table with new comments for post id {post_id}")

    except pymysql.MySQLError as e:
        logger.error("ERROR: Unexpected error: Could not connect to MySQL instance.")
        logger.error(e)
        raise

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Comment submitted successfully',
            'comment_id': new_comment_id,
            'created_at': created_at_str
        })
    }
