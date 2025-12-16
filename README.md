# Medtime - Medication Reminder App

A Flutter app for medication reminders with customizable schedules and adherence tracking.

## Features

- **Multiple Medications**: Add and manage multiple medications
- **Custom Schedules**: Set multiple daily times for each medication
- **Flexible Scheduling**: 
  - Daily schedules
  - Specific days of week
  - Skip weekends option
- **Smart Notifications**:
  - Configurable notification behavior (dismiss or remind)
  - Reminder intervals (5-60 minutes)
  - Local notifications scheduled up to 30 days ahead
- **Adherence Tracking**:
  - Track taken, missed, and skipped doses
  - Weekly and monthly statistics
  - Per-medication adherence rates
- **Data Export**: Export medications and adherence data to CSV
- **Clean UI**: Dark theme with green accent color

## Setup

### 1. Dependencies

```bash
flutter pub get
```

### 2. Generate App Icon

```bash
# Install Pillow if not already installed
pip install Pillow

# Generate development icon
python3 generate_icon.py
```

### 3. Run the App

```bash
flutter run
```

## Project Structure

```
Medtimer/
├── lib/
│   ├── main.dart                    - App entry point
│   ├── models/
│   │   ├── medication.dart          - Medication model
│   │   └── medication_dose.dart      - Dose tracking model
│   ├── services/
│   │   ├── medication_service.dart  - Medication CRUD operations
│   │   ├── notification_service.dart - Local notification scheduling
│   │   └── adherence_service.dart    - Adherence tracking & statistics
│   └── screens/
│       ├── medication_list_screen.dart  - Main home screen
│       ├── medication_edit_screen.dart  - Add/edit medication
│       ├── adherence_screen.dart        - Statistics & calendar view
│       └── settings_screen.dart         - App settings
├── assets/
│   └── icon/
│       └── app_icon.png            - App icon (generated)
└── generate_icon.py              - Icon generator script
```

## Dependencies

- `provider` - State management
- `shared_preferences` - Local storage
- `flutter_local_notifications` - Local notifications
- `timezone` - Timezone support for notifications
- `path_provider` - File system access
- `share_plus` - Share/export functionality
- `url_launcher` - Open URLs

## Usage

1. **Add Medication**: Tap the + button to add a new medication
2. **Set Schedule**: Add one or more daily times
3. **Configure Notifications**: Choose dismiss or remind behavior
4. **Track Adherence**: View statistics in the Adherence screen
5. **Export Data**: Export your data from Settings

## Design Philosophy

Following the Exertime app model:
- **Simple & Focused**: One core function, done elegantly
- **Useful Daily**: Solves real problems people face regularly
- **Clean Design**: Minimal UI, maximum clarity
- **Health-Aware**: Complements wellness/health-conscious users

## Branding

- **Name**: Medtime
- **Color Scheme**: Green accent (health/medicine theme)
- **Theme**: Dark mode with Material 3

## Development Notes

- Uses Provider for state management (consistent with Exertime)
- Local storage only (no cloud sync - privacy-focused)
- Notifications scheduled 30 days in advance
- Adherence tracking with 30-day rolling statistics
