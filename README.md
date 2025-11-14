# ngmy1

Production build of the NGMy1 Flutter experience. The `main` branch contains the
Flutter source, while GitHub Pages serves the compiled web bundle so the app can
launch directly from a browser.

## Live Demo

- URL: https://kbpabloqr-lgtm.github.io/ngmy1/

> After the first push to `main`, open **Settings → Pages** and select **GitHub
> Actions** as the source. The workflow added in `.github/workflows` will build
> and deploy the latest web bundle to the `gh-pages` branch automatically.

## Local Development

```powershell
flutter pub get
flutter run -d chrome
```

## Manual Web Build

```powershell
flutter build web --no-tree-shake-icons --no-wasm-dry-run
```

The compiled assets land in `build/web`. Pushing to `main` runs the same build in
CI and publishes the bundle to GitHub Pages. When building for GitHub Pages manually,
include the base href so asset URLs resolve correctly:

```powershell
flutter build web --base-href /ngmy1/ --no-tree-shake-icons --no-wasm-dry-run
```
