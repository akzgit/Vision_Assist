from django.urls import path
from . import views

urlpatterns = [
    path('detect_currency/', views.detect_currency, name='detect_currency'),
    path('object_detection/', views.object_detection, name='object_detection'),
    path('recognize_face/', views.recognize_face, name='recognize_face'),
    path('add_face/', views.add_face, name='add_face'),  # To add new faces for recognition
    path('read_text/', views.read_text, name='read_text'),
    path('activity_recognition/', views.activity_recognition, name='activity_recognition'),
    path('describe_image/', views.describe_image, name='describe_image'),  # Image description API
]
