# My AI Map — personal TestFlight checklist

This is the shortest path from the native iOS project to a private build
on your own iPhone.

## Local machine

- Install full Xcode from the App Store or Apple Developer downloads.
- Select it:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

- Generate the project:

  ```bash
  cd ios-app
  xcodegen generate
  open MyAIMap.xcodeproj
  ```

## Apple account

- Enroll in Apple Developer Program.
- In Xcode, sign in with the Apple ID.
- Set the team on the `MyAIMap` target.
- Keep bundle id as `com.iliaturilia.myaimap` unless App Store Connect
  says it is unavailable.

## First device run

- Select a real iPhone or iOS Simulator.
- Run `My AI Map`.
- Verify:
  - app launches in dark mode
  - 3D universe appears
  - category chips switch pocket worlds
  - bottom sheet updates selected tool
  - haptics fire on category/tool taps on device

## TestFlight upload

- Product -> Archive in Xcode.
- Distribute App -> App Store Connect -> Upload.
- In App Store Connect, create app:
  - Name: `My AI Map`
  - Bundle ID: `com.iliaturilia.myaimap`
  - SKU: `myaimap-ios`
- Add yourself as an internal tester.

## Before public App Store

- Replace placeholder app icon with final brand art if desired.
- Add privacy nutrition labels.
- Add screenshots for iPhone 6.7, iPhone 6.5, iPad if submitting as
  universal.
- Add support URL and marketing URL.
- Run release-review skill pass.
