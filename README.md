# Automated Pet Feeding System with Mobile App and Telegram Bot Control

An IoT-based pet feeder built around an ESP32 microcontroller, controllable and monitorable through a Flutter Android app and a Telegram bot, with feeding and activity history logged to ThingSpeak.

## Screenshots

| Home Screen | Feeding Schedule | Telegram Bot |
| :---: | :---: | :---: |
| <img width="300" alt="image" src="https://github.com/user-attachments/assets/514b1888-3c76-4658-9e0e-42c0dfb88ce1" /> | <img width="300" alt="image" src="https://github.com/user-attachments/assets/fd595505-a9f9-48ca-ae88-d4457b5ced08" /> | <img width="300" alt="image" src="https://github.com/user-attachments/assets/8903d4b5-45e7-461d-846d-4533594e7acf" /> |

## Demo product
https://youtu.be/RJR3Aelb8gY?si=klo0W_3x2R3Sv7mN

## Overview

Manual pet feeding is easy to get wrong when an owner is busy, travelling, or away from home. This project automates it: the feeder dispenses food on a schedule or on manual command, detects when the pet actually shows up, and keeps the owner informed remotely — whether they're on the same Wi-Fi or on the other side of the world with just Telegram.

## Features

- **Automatic & manual feeding** — scheduled dispensing via a servo motor, plus on-demand feeding from the app or Telegram; multiple feeding times can be set
- **Pet detection** — an ultrasonic sensor detects the pet at the feeder and triggers a buzzer + Telegram alert
- **Remote control, two ways** — a Flutter Android app (same Wi-Fi as the feeder) and a Telegram bot (works from anywhere)
- **History & monitoring** — feeding history, a pet profile, and in-app cloud analytics (feeds/visits over time, proximity trend)
- **Wi-Fi management** — manage networks and troubleshoot the feeder's connection from within the app

## Hardware

ESP32 DevKit V1 · MG90S servo motor · HC-SR04 ultrasonic sensor · passive buzzer · 5V power supply · ~500 g food container

## Software & cloud

Arduino IDE (C++) for the ESP32 firmware · Flutter (Android) for the mobile app · Telegram Bot API for remote commands and notifications · ThingSpeak for cloud data storage

## Circuit diagram
<img width="650" alt="image" src="https://github.com/user-attachments/assets/9b1d0688-b864-4319-8afc-f1e4ad60d2b1" /> <img width="300" alt="image" src="https://github.com/user-attachments/assets/b3324da3-dcfc-4482-b67c-51270ea34bb5" />

## Product 
<img width="650" alt="product" src="https://github.com/user-attachments/assets/74b9f5c2-bf8c-4cfb-8824-877f7f551a86" />




