import os
import boto3
import logging
from PIL import Image
import io

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        source_bucket = os.environ['SOURCE_BUCKET']
        dest_bucket = os.environ['DEST_BUCKET']

        # Get file information
        file_key = event['Records'][0]['s3']['object']['key']

        # Download the image
        file_obj = s3.get_object(Bucket=source_bucket, Key=file_key)
        file_content = file_obj["Body"].read()

        # Open the image with PIL
        image = Image.open(io.BytesIO(file_content))

        # Create a thumbnail
        thumbnail_size = (128, 128)
        image.thumbnail(thumbnail_size)

        # Save the image to an in-memory file
        buffer = io.BytesIO()
        image.save(buffer, 'JPEG')
        buffer.seek(0)

        # Create a new key for the thumbnail image
        filename, file_extension = os.path.splitext(file_key)
        thumbnail_key = f"{filename}_thumbnail{file_extension}"

        # Upload the thumbnail to the destination bucket
        s3.put_object(Body=buffer, ContentType='image/jpeg', Bucket=dest_bucket, Key=thumbnail_key)

        logger.info(f'Thumbnail created for {file_key} and saved as {thumbnail_key}')

        return {
            'statusCode': 200,
            'body': f'Thumbnail created for {file_key} and saved as {thumbnail_key}'
        }

    except Exception as e:
        logger.error("Error occurred: " + str(e))
        return {
            'statusCode': 500,
            'body': 'An error occurred: ' + str(e)
        }