import os
import easyocr
import logging
from django.conf import settings
from django.core.files.storage import default_storage
from rest_framework.decorators import api_view
from rest_framework.response import Response
from PIL import Image
import pytesseract
import torch
import tensorflow as tf
import openai
import pandas as pd
from django.core.exceptions import ImproperlyConfigured
import base64
import requests
from tensorflow.keras.preprocessing import image
from tensorflow.keras.models import load_model
import numpy as np
import cv2
from io import BytesIO
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import face_recognition
from .facerec import SimpleFacerec 


# Logging setup
logger = logging.getLogger(__name__)

# Initialize face recognition system
face_rec = SimpleFacerec()
face_rec.load_encoding_images(os.path.join(settings.MEDIA_ROOT, 'faces'))

# Ensure your API key is correctly loaded from the environment
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')

# Load YOLO model
yolo_model = torch.hub.load('ultralytics/yolov5', 'yolov5l', pretrained=True)

# Load MoViNet-A2 Model for Activity Recognition
activity_model_path = os.path.join(settings.MEDIA_ROOT, 'models', 'movinet_a2_kinetics_600')
activity_model = tf.saved_model.load(activity_model_path)

# Load activity labels
activity_labels_path = os.path.join(settings.MEDIA_ROOT, 'static_data', 'kinetics_600_labels.csv')
activity_labels_df = pd.read_csv(activity_labels_path)
activity_names = activity_labels_df['name'].tolist()


# Load the trained currency detection model
currency_model_path = os.path.join(settings.MEDIA_ROOT, 'models', 'final_mobilenetv2_model.keras')
if not os.path.exists(currency_model_path):
    raise ImproperlyConfigured(f"Currency model not found at {currency_model_path}")
    
currency_model = load_model(currency_model_path)

# Corrected Index to Class Mapping
index_to_class = {0: '10', 1: '100', 2: '20', 3: '200', 4: '2000', 5: '50', 6: '500'}


@api_view(['POST'])
def detect_currency(request):
    if 'file' in request.FILES:
        image_file = request.FILES['file']
        
        # Save the image to the uploads directory
        file_path = default_storage.save(os.path.join('uploads', image_file.name), image_file)
        full_file_path = os.path.join(settings.MEDIA_ROOT, file_path)
        
        try:
            # Load and preprocess the image for MobileNetV2
            img = image.load_img(full_file_path, target_size=(224, 224))
            img_array = image.img_to_array(img)
            img_array = np.expand_dims(img_array, axis=0)  # Add batch dimension
            img_array = tf.keras.applications.mobilenet_v2.preprocess_input(img_array)  # Preprocess

            # Perform prediction using the loaded model
            predictions = currency_model.predict(img_array)

            # Debugging: Print the raw prediction outputs
            print(f"Raw predictions: {predictions}")

            predicted_class_index = np.argmax(predictions, axis=1)[0]
            predicted_class_label = index_to_class.get(predicted_class_index, "Unknown currency")

            # Debugging: Print the predicted index and corresponding class label
            print(f"Predicted class index: {predicted_class_index}")
            print(f"Predicted class label: {predicted_class_label}")

            return Response({"predicted_currency": predicted_class_label})
        except Exception as e:
            logger.error(f"Error processing file: {str(e)}")
            return Response({"error": "File processing error"}, status=500)
    else:
        return Response({"error": "No file provided"}, status=400)
    
# Object Detection
@api_view(['POST'])
def object_detection(request):
    logger.info("Received request for object detection")  # Logging the incoming request
    if 'file' in request.FILES:
        image = request.FILES['file']

        try:
            # Save file
            file_path = default_storage.save(os.path.join('uploads', image.name), image)
            full_file_path = os.path.join(settings.MEDIA_ROOT, file_path)
            logger.info(f"Image saved at {full_file_path}")

            # Check if file is saved
            if not os.path.exists(full_file_path):
                logger.error(f"File does not exist at {full_file_path}")
                return Response({"error": "File does not exist"}, status=500)

            # Perform object detection using YOLO
            logger.info(f"Performing object detection on {full_file_path}")
            img = Image.open(full_file_path)
            results = yolo_model(img)
            logger.info(f"YOLO model results: {results}")  # Logging YOLO results
            
            objects_detected = results.pandas().xyxy[0].to_dict(orient="records")

            # Set a confidence threshold (for example, 0.5 or 50%)
            confidence_threshold = 0.6  # Adjust this value to improve accuracy (0.5 = 50%)
            filtered_objects = [
                obj for obj in objects_detected if obj['confidence'] >= confidence_threshold
            ]

            # Log filtered objects
            logger.info(f"Filtered objects with confidence >= {confidence_threshold}: {filtered_objects}")

            return Response({"detected_objects": filtered_objects})

        except Exception as e:
            logger.error(f"Error processing object detection: {str(e)}")
            return Response({"error": f"Object detection error: {str(e)}"}, status=500)
    else:
        logger.warning("No file uploaded in the request")
        return Response({"error": "No file uploaded"}, status=400)
    
    
@api_view(['POST'])
def add_face(request):
    """
    Endpoint to add a face. It receives images and a name, saving them for face recognition.
    """
    # Check if 'files' and 'name' are in the request
    if 'files' not in request.FILES or 'name' not in request.data:
        logger.error("No files uploaded or name missing")
        return Response({"error": "No files uploaded or name missing"}, status=400)
    
    images = request.FILES.getlist('files')
    name = request.data['name'].strip()  # Strip any extra spaces from the name
    
    # Check if at least one image is provided
    if len(images) == 0:
        logger.error("No images provided")
        return Response({"error": "No images provided"}, status=400)

    try:
        # Save each image for the person
        for image in images:
            # Validate image type (optional but recommended)
            if image.content_type not in ['image/jpeg', 'image/png']:
                logger.error(f"Invalid file type {image.content_type} for image {image.name}")
                return Response({"error": f"Invalid file type {image.content_type}"}, status=400)

            # Save the image
            file_path = default_storage.save(os.path.join('faces', f"{name}_{image.name}"), image)
            full_file_path = os.path.join(settings.MEDIA_ROOT, file_path)

            # Check if the file was successfully saved
            if not os.path.exists(full_file_path):
                logger.error(f"Face file does not exist at {full_file_path}")
                return Response({"error": f"Face file does not exist at {full_file_path}"}, status=500)

            logger.info(f"Face added for {name}, image saved at {full_file_path}")

        # Reload face encodings (assuming face_rec is a valid instance)
        face_rec.load_encoding_images(os.path.join(settings.MEDIA_ROOT, 'faces'))
        logger.info(f"Face added successfully for {name}")
        return Response({"message": f"Face added successfully for {name}"})

    except Exception as e:
        logger.error(f"Error adding face: {str(e)}")
        return Response({"error": "Add face error", "details": str(e)}, status=500)



# Recognize Face from the video stream
@api_view(['POST'])
def recognize_face(request):
    """
    Endpoint to recognize faces from an uploaded image.
    It returns the recognized person's name.
    """
    if 'file' in request.FILES:
        image = request.FILES['file']

        try:
            # Save the uploaded image temporarily
            file_path = default_storage.save(os.path.join('uploads', image.name), image)
            full_file_path = os.path.join(settings.MEDIA_ROOT, file_path)

            # Check if file is saved
            if not os.path.exists(full_file_path):
                logger.error(f"Face file does not exist at {full_file_path}")
                return Response({"error": "Face file does not exist"}, status=500)

            # Load the image for face recognition
            img = cv2.imread(full_file_path)

            # Detect and recognize faces in the image
            face_locations, face_names = face_rec.detect_known_faces(img)

            if face_names:
                recognized_faces = [{"name": name} for name in face_names]
                logger.info(f"Recognized faces: {recognized_faces}")
                return Response({"recognized_faces": recognized_faces})
            else:
                logger.info("No faces recognized.")
                return Response({"recognized_faces": []})

        except Exception as e:
            logger.error(f"Error recognizing face: {str(e)}")
            return Response({"error": "Face recognition error"}, status=500)
    else:
        return Response({"error": "No file uploaded"}, status=400)
# Function to encode the image in base64 format
def encode_image(image_path):
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

@csrf_exempt
def read_text(request):
    try:
        # Check if the file is included in the request
        image_file = request.FILES.get('file')
        if not image_file:
            return JsonResponse({"error": "No file uploaded"}, status=400)

        # Convert the image to a base64 string
        image = Image.open(image_file)
        buffered = BytesIO()
        image.save(buffered, format="JPEG")
        base64_image = base64.b64encode(buffered.getvalue()).decode('utf-8')

        # Create the headers for the request to OpenAI
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {OPENAI_API_KEY}"
        }

        # Prepare the payload for GPT-4 mini, requesting pure text extraction
        payload = {
            "model": "gpt-4o",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "Extract only the text from the following image without adding any extra words or explanation:"
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            "max_tokens": 300
        }

        # Make the request to OpenAI API
        response = requests.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload)

        # Parse the response from OpenAI
        result = response.json()
        if response.status_code == 200:
            # Extract the text content directly
            extracted_text = result['choices'][0]['message']['content'].strip()

            # Print the extracted pure text in the terminal
            print(extracted_text)

            # Return the pure extracted text as a JSON response
            return JsonResponse({"extracted_text": extracted_text}, status=200)
        else:
            return JsonResponse({"error": f"OpenAI Error: {result['error']['message']}"}, status=response.status_code)

    except Exception as e:
        # Print the error in the terminal
        print(f"Internal Server Error: {str(e)}")
        return JsonResponse({"error": f"Internal Server Error: {str(e)}"}, status=500)
    
    
# Preprocess video for MoViNet model
def preprocess_video(video_path, frame_size=(224, 224), num_frames=100):
    frames = []
    cap = cv2.VideoCapture(video_path)
    frame_count = 0

    while cap.isOpened() and frame_count < num_frames:
        ret, frame = cap.read()
        if not ret:
            break
        resized_frame = cv2.resize(frame, frame_size)
        rgb_frame = cv2.cvtColor(resized_frame, cv2.COLOR_BGR2RGB)
        normalized_frame = rgb_frame / 255.0
        frames.append(normalized_frame)
        frame_count += 1

    cap.release()

    # Convert list of frames to a NumPy array
    video_tensor = np.stack(frames, axis=0)
    video_tensor = np.expand_dims(video_tensor, axis=0)  # Add batch dimension
    return tf.convert_to_tensor(video_tensor, dtype=tf.float32)

# Activity recognition endpoint
@api_view(['POST'])
def activity_recognition(request):
    if 'file' in request.FILES:
        video = request.FILES['file']
        try:
            # Save video temporarily
            file_path = default_storage.save(os.path.join('uploads', video.name), video)
            full_file_path = os.path.join(settings.MEDIA_ROOT, file_path)

            # Preprocess video for model input
            video_tensor = preprocess_video(full_file_path)

            # Run the video through the model
            logits = activity_model.signatures["serving_default"](video_tensor)
            predictions = tf.nn.softmax(logits['classifier_head'], axis=-1).numpy()[0]

            # Get the top prediction
            top_prediction_idx = np.argmax(predictions)
            confidence = predictions[top_prediction_idx]
            predicted_activity = activity_names[top_prediction_idx]

            # Log prediction for debugging
            logger.info(f"Predicted Activity: {predicted_activity}, Confidence: {confidence:.2f}")
            print(f"Predicted Activity: {predicted_activity}, Confidence: {confidence:.2f}")

            # Return prediction result
            return Response({
                "predicted_activity": predicted_activity,
                "confidence": float(confidence)
            })

        except Exception as e:
            logger.error(f"Error processing activity recognition: {str(e)}")
            return Response({"error": "Activity recognition error"}, status=500)
    else:
        return Response({"error": "No video uploaded"}, status=400)

    
    
# Function to describe the image using OpenAI API
def generate_image_description(image_path):
    try:
        # Encode the image as base64
        base64_image = encode_image(image_path)

        # Set up the headers and payload for the API request
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {OPENAI_API_KEY}"
        }

        payload = {
            "model": "gpt-4o-mini",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "What’s in this image?"
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            "max_tokens": 300
        }

        # Send the request to the OpenAI API
        response = requests.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload)
        response.raise_for_status()  # Raise an error for bad responses (status code 4xx or 5xx)

        # Get the description from the API response
        return response.json()['choices'][0]['message']['content'].strip()

    except Exception as e:
        logger.error(f"Error processing image description: {str(e)}")
        return None

# Django view to handle image upload and description generation
@api_view(['POST'])
def describe_image(request):
    try:
        # Check if the file is present in the request
        if 'file' in request.FILES:
            image = request.FILES['file']
            file_path = default_storage.save(os.path.join('uploads', image.name), image)
            full_file_path = os.path.join(settings.MEDIA_ROOT, file_path)

            # Generate the description for the uploaded image
            description = generate_image_description(full_file_path)

            if description:
                return Response({"description": description})
            else:
                return Response({"error": "Could not generate description"}, status=500)
        else:
            return Response({"error": "No file provided"}, status=400)
    except Exception as e:
        logger.error(f"Error in describe_image: {str(e)}")
        return Response({"error": "Error processing image"}, status=500)