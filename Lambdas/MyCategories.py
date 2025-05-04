import pymysql
import json
import os

def lambda_handler(event, context):
    # Parse the user_id from the event
    user_id = event['queryStringParameters']['user_id']

    # Environment variables
    db_host = os.environ['DB_HOST']
    db_name = os.environ['DB_NAME']
    db_user = os.environ['DB_USER']
    db_pass = os.environ['DB_PASS']

    # Query logic wrapped inside a 'with' statement
    try:
        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                # Select user categories based on user_id
                cur.execute("SELECT user_categories FROM Users WHERE id = %s", user_id)
                user_categories_result = cur.fetchone()
                if user_categories_result:
                    category_ids = user_categories_result[0].split(',')
                    
                    # Query Categories table to get category names
                    categories = []
                    for category_id in category_ids:
                        cur.execute("SELECT id, category_name FROM Categories WHERE id = %s", category_id)
                        category_result = cur.fetchone()
                        if category_result:
                            categories.append({"id": str(category_result[0]), "name": category_result[1]})
                    conn.commit()
                else:
                    return {
                        "statusCode": 404,
                        "body": json.dumps(f"User with ID {user_id} not found")
                    }

    except pymysql.MySQLError as e:
        print("ERROR: Unexpected error: Could not connect to MySQL instance.")
        print(e)
        return {
            "statusCode": 500,
            "body": json.dumps("Server error")
        }
    
    # Return the result
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(categories)
    }
