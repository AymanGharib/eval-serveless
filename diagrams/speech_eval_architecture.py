from diagrams import Diagram
from diagrams.aws.compute import Lambda, ECS
from diagrams.aws.storage import S3
from diagrams.aws.integration import SQS
from diagrams.aws.database import Database

from diagrams.aws.network import APIGateway
from diagrams.onprem.client import Users

with Diagram("Student Speech Evaluation Pipeline", show=False, direction="LR"):
    student = Users("Student")
    api = APIGateway("API Gateway")
    uploader = Lambda("Uploader Lambda")
    audio_bucket = S3("Audio Storage")
    queue = SQS("Transcription Queue")
    whisper = ECS("Whisper on ECS Fargate")
    transcript_bucket = S3("Transcript Storage")
    evaluator = Lambda("Evaluator Lambda")
    results = Database("Evaluation Results")
    
    student >> api >> uploader
    uploader >> audio_bucket
    uploader >> queue
    queue >> whisper
    whisper >> transcript_bucket
    transcript_bucket >> evaluator
    evaluator >> results