# Shadow Warrior: Egypt — Godot 4 Android prototype

## What is included
- Self-contained 3D Egyptian temple arena (generated with low-poly geometry)
- Third-person warrior, sword attacks, 3 guards with chase-and-attack AI
- Health, victory/defeat, restart, keyboard and mobile touch controls
- Godot 4.2+ GL Compatibility renderer for mid-range Android phones

## Run on a computer
1. Install Godot 4.2 or newer (standard editor).
2. Import `project.godot` using Godot Project Manager.
3. Press F6/F5 or the Run Project button.
4. Use WASD/arrows to move, SPACE to attack, or the on-screen controls.

## Export to Android
1. Install Android SDK / OpenJDK 17 and configure their paths in Godot Editor Settings > Export > Android.
2. In Godot: Project > Install Android Build Template (only if your export setup requires it).
3. Project > Export > Add > Android; install Godot Android export templates if prompted.
4. Set your unique package name, e.g. `org.example.shadowwarrioregypt`.
5. Export a debug APK, install it on your Android device and test.

This zip is a Godot source project, NOT a precompiled APK. Exporting requires Godot and the Android toolchain. Assets are intentionally primitive placeholders, not photorealistic artwork. No copyrighted third-party assets are included.
