# ProxyVN / ExternalFF iOS AuthGate Builder

This repository is set up with GitHub Actions to compile `AuthGate.dylib` for iOS ARM64.

## How to Build `AuthGate.dylib`
1. Go to the **Actions** tab in this GitHub repository.
2. Select **Build iOS AuthGate Dylib** from the left sidebar.
3. Click **Run workflow** -> **Run workflow**.
4. Once completed (~30s), download `AuthGate-iOS-Dylib` from the **Artifacts** section at the bottom of the page.
5. Extract `AuthGate.dylib` and place it inside `ProxyVN.app/Frameworks/AuthGate.dylib`.
