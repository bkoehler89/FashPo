import pymysql
import json
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_categories_dict(user_categories, cursor):
    categories_dict = {}
    if user_categories:
        # Fetch category names for the corresponding IDs
        categories_ids = user_categories.split(',')
        sql_categories = "SELECT id, category_name FROM Categories WHERE id IN (%s)"
        formatted_ids = ','.join(['%s'] * len(categories_ids))
        cursor.execute(sql_categories % formatted_ids, tuple(categories_ids))
        categories = cursor.fetchall()
        # Construct the categories dictionary
        categories_dict = {str(category['id']): category['category_name'] for category in categories}
    return categories_dict

def get_favorite_posts_dict(favorite_posts):
    # Split the favorite posts by comma and create a dictionary with the word 'Post'
    return {int(post_id): 'Post' for post_id in favorite_posts.split(',') if post_id} if favorite_posts else {}

def get_clothing_articles_dict(favorite_clothing, cursor):
    clothing_articles_dict = {}
    if favorite_clothing:
        clothing_ids = favorite_clothing.split(',')
        # Ensure the IDs are unique to avoid redundant queries
        unique_clothing_ids = list(set(clothing_ids))
        sql_clothing = "SELECT post_id, type FROM ClothingArticles WHERE id IN (%s)"
        formatted_ids = ','.join(['%s'] * len(unique_clothing_ids))
        cursor.execute(sql_clothing % formatted_ids, tuple(unique_clothing_ids))
        clothing_articles = cursor.fetchall()
        for article in clothing_articles:
            post_id = article['post_id']
            article_type = article['type']
            # Append the type to the existing entry, separating with a comma if necessary
            if post_id in clothing_articles_dict:
                clothing_articles_dict[post_id] += ',' + article_type
            else:
                clothing_articles_dict[post_id] = article_type
    return clothing_articles_dict

def update_favorite_posts_with_clothing(favorite_posts_dict, clothing_articles_dict):
    for post_id, types in clothing_articles_dict.items():
        # If the post_id is already a key in the favorite_posts_dict, append the types
        if post_id in favorite_posts_dict:
            # Check if the type is already in the string to avoid duplicates
            existing_types = favorite_posts_dict[post_id].split(',')
            new_types = [t for t in types.split(',') if t not in existing_types]
            favorite_posts_dict[post_id] = ','.join(existing_types + new_types)
        else:
            favorite_posts_dict[post_id] = types
    return favorite_posts_dict

def lambda_handler(event, context):
    # Log the received event
    logger.info("Received event: %s", event)
    
    # Parse the incoming JSON payload
    body = json.loads(event['body'])
    username = body['username']

    # Log the parsed username
    logger.info("Username received: %s", username)

    try:
        # Using 'with' statement for proper connection management
        with pymysql.connect(
            host=os.environ['DB_HOST'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASS'],
            db=os.environ['DB_NAME'],
            connect_timeout=5,
            cursorclass=pymysql.cursors.DictCursor
        ) as connection:
            with connection.cursor() as cursor:
                # Check if the username exists and fetch details
                sql_user = "SELECT id, gender, age, height, user_categories, favorite_posts, favorite_clothing FROM Users WHERE username = %s"
                cursor.execute(sql_user, (username,))
                user = cursor.fetchone()

                if user:
                    # User exists, process favorite posts and clothing
                    categories_dict = get_categories_dict(user['user_categories'], cursor)
                    favorite_posts_dict = get_favorite_posts_dict(user['favorite_posts'])
                    clothing_articles_dict = get_clothing_articles_dict(user['favorite_clothing'], cursor)
                    updated_favorites = update_favorite_posts_with_clothing(favorite_posts_dict, clothing_articles_dict)

                    response_body = {
                        'id': user['id'],
                        'gender': user['gender'],
                        'age': user['age'],
                        'height': user['height'],
                        'categories': categories_dict,
                        'favorites': updated_favorites  # Return the updated favorites dictionary
                    }
                else:
                    # User does not exist, return the message
                    response_body = {'message': "Username doesn't exist"}

        # Prepare the response
        response = {
            'statusCode': 200,
            'body': json.dumps(response_body),
            'headers': {
                'Content-Type': 'application/json'
            },
        }

        # Log the response
        logger.info("Response: %s", response)

        return response
    except pymysql.MySQLError as e:
        # Log the error
        logger.error("Could not connect to MySQL: %s", e)
        return {
            'statusCode': 500,
            'body': json.dumps({'message': "Error connecting to the database"}),
            'headers': {
                'Content-Type': 'application/json'
            },
        }
