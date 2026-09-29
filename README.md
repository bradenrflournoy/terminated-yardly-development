# Yardly

Yardly is a full-stack iOS app for booking local, small-group lawn and yard services. It connects
neighbors who need yard work done with young, local service providers — with built-in tooling for
guardians to supervise and support the young people running these micro-businesses.

## Overview

Yardly makes it easy to discover nearby services, book and track jobs, chat in real time, and leave
reviews. Beyond the customer experience, it includes a full business-management layer so young users
can create and run their own lawn-care businesses, with guardian supervision for accountability and
safety.

## Features

- **Service discovery & booking** — browse popular and nearby services, view details, and book jobs.
- **Real-time chat** — in-app messaging between customers and providers via Firebase Firestore.
- **Job tracking** — live tracking of active jobs, plus job history.
- **Reviews & ratings** — leave and view reviews with summarized rating breakdowns.
- **Business management** — create, configure, and analyze a lawn-care business (services, pricing, profile).
- **Guardian supervision** — supervision requests and controls so guardians can oversee young users.
- **Notifications** — push/in-app notifications for bookings, messages, and account activity.
- **Accounts & onboarding** — role-based onboarding for customers, providers, and guardians.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Architecture:** MVVM (models, view models, and views)
- **Backend:** Firebase (Firestore, Authentication)
- **Maps & Location:** MapKit / CoreLocation
- **Dependencies:** Swift Package Manager

## Project Structure

```
.
├── config/            App entry point, Info.plist, launch screen
├── data/
│   ├── models/        Data models (User, Business, Service, Booking, Chat, Review, ...)
│   ├── services/      Firestore, chat, location, and notification managers
│   └── viewmodels/    View models (e.g. AuthViewModel)
├── views/
│   ├── screens/       Main app screens (Home, Business, Chat, Tracking, ...)
│   ├── windows/       Modal/sheet windows (reviews, bookings, policies, ...)
│   └── other/         Reusable view components
├── utils/             Constants, error handling, and view extensions
├── firebaseconfig/    Firebase configuration
├── support/           Package manifest
└── tests/             App and UI tests
```

## Getting Started

### Prerequisites

- Xcode 15 or later
- An iOS 17+ simulator or device
- A Firebase project

### Setup

1. Clone the repository.
2. Open `Yardly.xcodeproj` in Xcode.
3. Add your own `GoogleService-Info.plist` to `firebaseconfig/` (the included file is a placeholder —
   replace it with the config from your Firebase project).
4. Let Swift Package Manager resolve dependencies.
5. Build and run on a simulator or device.

## Status

Yardly is an actively developed MVP.

## License

This project is proprietary. All rights reserved.
