import pymysql
import json
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

def lambda_handler(event, context):
    # Environment variables
    db_host = os.environ['DB_HOST']
    db_name = os.environ['DB_NAME']
    db_user = os.environ['DB_USER']
    db_pass = os.environ['DB_PASS']

    # Initialize categories list
    categories = []

    # Connect to the database using 'with' statement for better resource management
    try:
        with pymysql.connect(host=db_host, user=db_user, passwd=db_pass, db=db_name, connect_timeout=5) as conn:
            with conn.cursor() as cur:
                # Select all categories where 'public' column is 1
                cur.execute("SELECT id, category_name FROM Categories WHERE public = 1")
                results = cur.fetchall()
                for result in results:
                    # Append a dictionary for each category
                    categories.append({"id": str(result[0]), "name": result[1]})
                conn.commit()
    except pymysql.MySQLError as e:
        logger.error("ERROR: Unexpected error: Could not connect to MySQL instance.")
        logger.error(e)
        return {
            "statusCode": 500,
            "body": json.dumps("Server error")
        }

    # Log the successful operation
    logger.info("Successfully fetched categories")

    # Return the result
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"  # Ensure to set the appropriate CORS headers
        },
        "body": json.dumps(categories)
    }
