# iOS TestFlight setup

The repository includes a Codemagic workflow in `codemagic.yaml` named `ios-testflight`.

Before starting the workflow in Codemagic:

1. In App Store Connect, create or confirm the app with bundle ID `com.nasa.sport`.
2. In Codemagic, connect the App Store Connect integration and add the `app_store_connect` environment-variable group.
3. Add iOS signing to Codemagic for `com.nasa.sport` using an App Store distribution certificate and provisioning profile.
4. Select the `ios-testflight` workflow and start a build.

The workflow builds a release IPA and submits it to TestFlight. The Flutter version and marketing/build version come from `pubspec.yaml` (`1.0.0+1` currently); increase the build number for every new upload.

If your Apple Developer account already uses a different bundle ID, update that ID in both `ios/Runner.xcodeproj/project.pbxproj` and `codemagic.yaml` before building.