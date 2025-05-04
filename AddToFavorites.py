import json
import os
import pymysql
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

rds_host = os.environ['DB_HOST']
name = os.environ['DB_USER']
password = os.environ['DB_PASS']
db_name = os.environ['DB_NAME']

def lambda_handler(event, context):
    body = json.loads(event['body'])
    item_id = body['itemId']  # changed from postId to item_id to be generic
    user_id = body['user_id']
    item_type = body.get('itemType', 'post')  # default to 'post' if itemType not provided

    try:
        # Connect to the database using a with statement to ensure it's always closed
        with pymysql.connect(host=rds_host, user=name, passwd=password, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                # Determine the column to update based on item type
                column_name = 'favorite_clothing' if item_type == 'clothing' else 'favorite_posts'
                
                # Fetch the current favorite items from the user
                cur.execute(f"SELECT {column_name} FROM Users WHERE id = %s", (user_id,))
                result = cur.fetchone()
                if result:
                    favorite_items = result[0] if result[0] else ""
                    favorite_items_list = favorite_items.split(',') if favorite_items else []
                    
                    # Check if the item is already in the list and add/remove it
                    if str(item_id) in favorite_items_list:
                        favorite_items_list.remove(str(item_id))
                        action_message = f'Successfully removed from {item_type} favorites'
                        logger.info(f"Item ID {item_id} removed from user {user_id}'s {item_type} favorites.")
                    else:
                        favorite_items_list.append(str(item_id))
                        action_message = f'Successfully added to {item_type} favorites'
                        logger.info(f"Item ID {item_id} added to user {user_id}'s {item_type} favorites.")
                    
                    # Update the new list of favorite items in the database
                    favorite_items = ','.join(favorite_items_list)
                    cur.execute(f"UPDATE Users SET {column_name} = %s WHERE id = %s", (favorite_items, user_id))
                    conn.commit()
                    
                    return {
                        'statusCode': 200,
                        'body': json.dumps(action_message)
                    }
                else:
                    logger.warning(f"User with ID {user_id} not found.")
                    return {
                        'statusCode': 404,
                        'body': json.dumps('User not found')
                    }
    except pymysql.MySQLError as e:
        logger.error(f"Database error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('Database connection failed')
        }
