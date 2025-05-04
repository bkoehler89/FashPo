import json
import pymysql
import os
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
logger.info("Loading environment variables")
db_host = os.environ['DB_HOST']
db_user = os.environ['DB_USER']
db_pass = os.environ['DB_PASS']
db_name = os.environ['DB_NAME']

def calculate_percentage(up_votes, down_votes):
    # Check for None and assign empty string if None
    up_votes = '' if up_votes is None else up_votes
    down_votes = '' if down_votes is None else down_votes

    # Convert the comma-separated string to a list, filtering out any empty strings
    up_votes_list = list(filter(None, up_votes.split(',')))
    down_votes_list = list(filter(None, down_votes.split(',')))

    # Calculate counts
    num_up_votes = len(up_votes_list)
    num_down_votes = len(down_votes_list)
    total_votes = num_up_votes + num_down_votes
    
    # Calculate percentage if there are any votes
    percentage_up_votes = (num_up_votes / total_votes * 100) if total_votes > 0 else 0
    return round(percentage_up_votes)


# Function to get comments for a post
def get_comments_for_post(comments_string, cur):
    comments_data = []
    if comments_string:  # Check if the string is not empty
        try:
            # Split the string by commas to get individual comment IDs
            comment_ids_list = comments_string.split(',')
            
            # Retrieve comment id, text, and owner_id for each comment ID
            for comment_id in comment_ids_list:
                cur.execute("SELECT id, text, owner_id FROM Comments WHERE id = %s", (comment_id,))
                comment = cur.fetchone()
                if comment:
                    comments_data.append({
                        'id': comment[0],
                        'text': comment[1],
                        'owner_id': comment[2]
                    })
            logger.info("Comments data retrieved successfully.")
        except Exception as e:
            logger.error("ERROR: Could not retrieve comments.")
            logger.error(e)
            raise e
    return comments_data

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        post_id = body['post_id']
        user_id = body['user_id']

        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                # Query for user's favorite posts
                cur.execute("SELECT favorite_posts FROM Users WHERE id = %s", (user_id,))
                result = cur.fetchone()
                user_favorited_post = False
                if result and result[0]:
                    # Split favorite_posts by comma to get a list of favorite post IDs
                    favorite_posts = result[0].split(',')
                    user_favorited_post = str(post_id) in favorite_posts
                    logger.info(f"User's favorite post status: {user_favorited_post}")

                # Query for clothing articles
                cur.execute("""
                    SELECT id, type, 
                           FIND_IN_SET(%s, up_votes) > 0 as user_upvoted, 
                           FIND_IN_SET(%s, favorites) > 0 as user_favorited, 
                           FIND_IN_SET(%s, down_votes) > 0 as user_downvoted,
                           up_votes, down_votes
                    FROM ClothingArticles WHERE post_id = %s
                """, (user_id, user_id, user_id, post_id))
                clothing_articles = cur.fetchall()
                logger.info(f"Clothing articles data retrieved successfully.")

                # Query for comments
                cur.execute("SELECT comments FROM Posts WHERE id = %s", (post_id,))
                post_comments = cur.fetchone()
                comments_data = []
                if post_comments and post_comments[0]:
                    comments_string = post_comments[0]
                    comments_data = get_comments_for_post(comments_string, cur)
                    logger.info(f"Comments data: {comments_data}")

        # Process and return the results
        articles_data = [{
            'id': article[0], 
            'type': article[1],
            'user_upvoted': bool(article[2]),
            'user_favorited': bool(article[3]),
            'user_downvoted': bool(article[4]),
            'upvote_percentage': calculate_percentage(article[5], article[6]),
            'total_votes': len(list(filter(None, (article[5] or '').split(',')))) + 
                   len(list(filter(None, (article[6] or '').split(','))))
        } for article in clothing_articles]

        response = {
            'statusCode': 200,
            'headers': { 
                "Content-Type": "application/json"
            },
            'body': json.dumps({
                'articles': articles_data, 
                'post_favorited': user_favorited_post,
                'comments': comments_data
            })
        }
        logger.info("Lambda function executed successfully.")
        return response

    except pymysql.MySQLError as e:
        logger.error("ERROR: Unexpected error: Could not connect to MySQL instance.")
        logger.error(e)
        response = {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
        return response
    finally:
        logger.info("Lambda handler ended")
