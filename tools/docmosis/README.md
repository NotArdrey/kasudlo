# Docmosis bridge

The Flutter web app calls a local bridge at `http://127.0.0.1:8787/render` for the
Docmosis Word export. The browser cannot run the Java JAR directly, so keep this
bridge running while using the `Docmosis Word` button.

Start it from the repository root:

```powershell
dart run tools/docmosis_bridge.dart
```

Then run Flutter web in another terminal:

```powershell
flutter run -d chrome
```

The bridge renders `YOUR_ACTUAL_CDX_TEMPLATE_DO_NOT_EDIT_LAYOUT.docx` with
Docmosis Java and returns the generated `.docx` file to the app.
