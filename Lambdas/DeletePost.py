import pymysql
import json
import os
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Helper function to remove the ID from a comma-separated list
def remove_id_from_list(id_list, id_to_remove):
    id_list = id_list.split(',') if id_list else []
    id_list = [id for id in id_list if id.strip() and id.strip() != str(id_to_remove)]
    return ','.join(id_list)

# Helper function to get the current time in EST
def get_current_time_est():
    # UTC time + timedelta to account for EST timezone (-5 hours)
    utc_time = datetime.utcnow()
    est_time = utc_time - timedelta(hours=5)
    return est_time

# Lambda handler function
def lambda_handler(event, context):
    # Parse the incoming ID from the event
    body = json.loads(event['body'])
    post_id = body['id']
    if not post_id:
        return {'statusCode': 400, 'body': json.dumps('No ID provided.')}

    # Get database credentials from environment variables
    db_host = os.environ['DB_HOST']
    db_name = os.environ['DB_NAME']
    db_user = os.environ['DB_USER']
    db_pass = os.environ['DB_PASS']

    try:
        # Connect to the database
        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                # Check and remove the ID from the Users table
                cur.execute("SELECT id, user_posts, favorite_posts FROM Users")
                users = cur.fetchall()
                for user_id, user_posts, favorite_posts in users:
                    new_user_posts = remove_id_from_list(user_posts, post_id)
                    new_favorite_posts = remove_id_from_list(favorite_posts, post_id)
                    if user_posts != new_user_posts or favorite_posts != new_favorite_posts:
                        cur.execute("UPDATE Users SET user_posts = %s, favorite_posts = %s WHERE id = %s",
                                    (new_user_posts, new_favorite_posts, user_id))

                # Check and remove the ID from the Categories table
                cur.execute("SELECT id, post_ids FROM Categories")
                categories = cur.fetchall()
                for category_id, post_ids in categories:
                    new_post_ids = remove_id_from_list(post_ids, post_id)
                    if post_ids != new_post_ids:
                        cur.execute("UPDATE Categories SET post_ids = %s WHERE id = %s",
                                    (new_post_ids, category_id))

                # Update the Posts table with the current timestamp in EST
                est_timestamp = get_current_time_est()
                cur.execute("UPDATE Posts SET deleted_at = %s WHERE id = %s", (est_timestamp, post_id))

                # Commit the changes
                conn.commit()

    except pymysql.MySQLError as e:
        logger.error(e)
        return {'statusCode': 500, 'body': json.dumps('Database connection failed.')}

    return {'statusCode': 200, 'body': json.dumps(f'Successfully removed ID {post_id} from Users and Categories, and marked as deleted in Posts.')}

