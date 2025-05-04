import pymysql
import json
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

db_host = os.environ['DB_HOST']
db_name = os.environ['DB_NAME']
db_user = os.environ['DB_USER']
db_pass = os.environ['DB_PASS']

def calculate_percentage(up_votes, down_votes):
    num_up_votes = len(up_votes) if up_votes else 0
    num_down_votes = len(down_votes) if down_votes else 0
    total_votes = num_up_votes + num_down_votes
    percentage_up_votes = (num_up_votes / total_votes * 100) if total_votes > 0 else 0
    return round(percentage_up_votes), total_votes

def lambda_handler(event, context):
    body = json.loads(event['body'])
    clothing_id = body['clothing_id']
    user_action = body['user_action']  # 'like', 'dislike', or 'favorite'
    action_type = body['action_type']  # 'add' or 'remove'
    user_id = str(body['user_id'])

    column_to_update = {
        'like': 'up_votes',
        'dislike': 'down_votes',
        'favorite': 'favorites'
    }.get(user_action, None)

    if column_to_update is None:
        logger.error(f"Invalid user action: {user_action}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid user action'})
        }

    try:
        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                # Retrieve the current lists from the database
                cur.execute(f"SELECT up_votes, down_votes FROM ClothingArticles WHERE id = %s", (clothing_id,))
                result = cur.fetchone()
                
                if result:
                    up_votes = result[0].split(',') if result[0] else []
                    down_votes = result[1].split(',') if result[1] else []

                    # Update the lists based on action
                    if column_to_update == 'up_votes':
                        if action_type == 'add' and user_id not in up_votes:
                            up_votes.append(user_id)
                        elif action_type == 'remove' and user_id in up_votes:
                            up_votes.remove(user_id)
                    elif column_to_update == 'down_votes':
                        if action_type == 'add' and user_id not in down_votes:
                            down_votes.append(user_id)
                        elif action_type == 'remove' and user_id in down_votes:
                            down_votes.remove(user_id)
                    
                    # Calculate new vote percentage and total votes
                    updated_percentage, total_votes = calculate_percentage(up_votes, down_votes)

                    # Update the database
                    updated_list = ','.join(up_votes if column_to_update == 'up_votes' else down_votes)
                    cur.execute(f"UPDATE ClothingArticles SET {column_to_update} = %s WHERE id = %s", (updated_list, clothing_id))
                    conn.commit()
                else:
                    logger.info(f"Clothing article with id {clothing_id} not found.")
                    return {
                        'statusCode': 404,
                        'body': json.dumps({'error': "Clothing article not found"})
                    }

    except pymysql.MySQLError as e:
        logger.error("Failed to update the database.")
        logger.error(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Database update failed'})
        }

    logger.info(f"Successfully updated {column_to_update} for clothing id {clothing_id}.")
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f"Successfully updated {column_to_update}",
            'upvote_percentage': updated_percentage,
            'total_votes': total_votes
        })
    }
