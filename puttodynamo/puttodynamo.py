import boto3
import os
import json
import logging
from jiwer import wer

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3 = boto3.client('s3')
dynamodb = boto3.client('dynamodb')

# Get environment variable
TABLE = os.environ['DDB_TABLE']


def scoring_function(wer, wpm, word_count):
    """
    Compute a score from 0 to 100 based on WER, WPM, and word count.
    - Lower WER is better.
    - Ideal WPM range is roughly 110–160.
    - Word count bonus if they speak enough.
    """
    # Score out of 40 for WER (lower is better)
    wer_score = max(0, 40 - (wer * 100))

    # Score out of 40 for WPM (ideal between 110–160)
    if 110 <= wpm <= 160:
        wpm_score = 40
    elif wpm < 110:
        wpm_score = max(0, (wpm / 110) * 40)
    else:  # wpm > 160
        wpm_score = max(0, 40 - ((wpm - 160) / 40) * 40)  # penalize for going too fast

    # Score out of 20 for word count (minimum 30 words)
    word_score = min(20, (word_count / 30) * 20)

    total_score = round(wer_score + wpm_score + word_score, 2)
    return total_score


def lambda_handler(event, context):
    logger.info("Lambda triggered. Event: %s", json.dumps(event))

    try:
        # 1. Get bucket and object key from S3 event
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        audio_id = key.replace('.json', '')
        logger.info(f"Bucket: {bucket}, Key: {key}, Audio ID: {audio_id}")

        # 2. Download and read the transcription file
        response = s3.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        transcript_json = json.loads(content)

        # 3. Extract transcript and new metrics
        transcript_text = transcript_json['transcript']
        word_count = transcript_json['word_count']
        duration = transcript_json['duration_seconds']
        wpm = transcript_json['wpm']
        logger.info(f"Transcript: {transcript_text}")
        logger.info(f"word_count: {word_count}, duration: {duration}, wpm: {wpm}")

        # 4. Retrieve original text from DynamoDB
        item = dynamodb.get_item(TableName=TABLE, Key={'id': {'S': audio_id}})
        original_text = item['Item']['original_text']['S']
        logger.info(f"Original text: {original_text}")

        # 5. Compute WER
        wer_score = wer(original_text, transcript_text)
        logger.info(f"WER score: {wer_score}")
        # 5. Compute scoring function
        score = scoring_function(wer_score, wpm, word_count)
        # 6. Update DynamoDB
        response = dynamodb.update_item(
            TableName=TABLE,
            Key={'id': {'S': audio_id}},
            UpdateExpression="SET transcribed_text = :t,total_score = :ts ,wer_score = :w, word_count = :wc, duration_seconds = :d, wpm = :p",
            ExpressionAttributeValues={
                ':t': {'S': transcript_text},
                ':w': {'N': str(round(wer_score, 4))},
                ':wc': {'N': str(word_count)},
                ':d': {'N': str(duration)},
                ':p': {'N': str(round(wpm, 2))},
                ':ts': {'N': str(round(score, 2))}


            }
        )
        logger.info(f"DynamoDB update response: {response}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Transcript and metrics saved to DynamoDB',
                'id': audio_id,
                'wer_score': round(wer_score, 4),
                'wpm': round(wpm, 2),
                'word_count': word_count,
                'duration_seconds': duration,
                'total_score': score
            })
        }

    except Exception as e:
        logger.error("Error occurred: %s", str(e), exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
