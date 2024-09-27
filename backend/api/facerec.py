import face_recognition
import cv2
import os
import glob
import numpy as np
import logging

# Initialize logger
logger = logging.getLogger(__name__)

class SimpleFacerec:
    def __init__(self):
        self.known_face_encodings = []
        self.known_face_names = []

        # Resize frame for faster processing
        self.frame_resizing = 0.25

    def load_encoding_images(self, images_path):
        """
        Load encoding images from the specified path.
        :param images_path: Directory where face images are stored.
        """
        # Get list of image files
        images_path_list = glob.glob(os.path.join(images_path, "*.*"))

        print(f"{len(images_path_list)} encoding images found.")

        # Process each image
        for img_path in images_path_list:
            img = cv2.imread(img_path)
            if img is None:
                logger.warning(f"Image {img_path} could not be read. Skipping.")
                continue

            rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

            # Get the filename without extension
            basename = os.path.basename(img_path)
            filename, ext = os.path.splitext(basename)

            # Extract name (assuming format 'name_imagename.ext')
            cleaned_name = filename.split('_')[0]

            # Get face encodings
            encodings = face_recognition.face_encodings(rgb_img)
            if len(encodings) == 0:
                logger.warning(f"No faces found in image {basename}. Image will be kept for future processing.")
                # No face encoding, but we keep the image for future use
                continue  # Skip adding encoding for now

            # Store the first encoding and the associated name
            self.known_face_encodings.append(encodings[0])
            self.known_face_names.append(cleaned_name)

        print("Encoding images loaded")

    def detect_known_faces(self, frame):
        """
        Detect faces in the frame and return their locations and names.
        :param frame: The image frame from which to detect faces.
        :return: Face locations and face names.
        """
        # Resize frame for faster processing
        small_frame = cv2.resize(frame, (0, 0), fx=self.frame_resizing, fy=self.frame_resizing)

        # Convert the image from BGR color to RGB color
        rgb_small_frame = cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB)

        # Detect faces and face encodings in the current frame
        face_locations = face_recognition.face_locations(rgb_small_frame)
        face_encodings = face_recognition.face_encodings(rgb_small_frame, face_locations)

        face_names = []
        for face_encoding in face_encodings:
            # Compare face encoding with known faces
            matches = face_recognition.compare_faces(self.known_face_encodings, face_encoding)
            name = "Unknown"

            # Calculate face distance to find the best match
            face_distances = face_recognition.face_distance(self.known_face_encodings, face_encoding)
            if len(face_distances) > 0:
                best_match_index = np.argmin(face_distances)
                if matches[best_match_index]:
                    name = self.known_face_names[best_match_index]
            face_names.append(name)

        # Adjust face locations according to resizing
        face_locations = np.array(face_locations)
        face_locations = face_locations / self.frame_resizing
        return face_locations.astype(int), face_names
