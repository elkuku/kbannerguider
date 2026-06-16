# Download

kBannerGuider is an Android app distributed as a direct APK (not on the Play Store).

## Latest Release

The latest APK is built automatically from the `main` branch on every push.

<a href="./kbannerguider-latest.apk" download class="download-btn">Download kBannerGuider APK</a>

## Install Instructions

1. On your Android device, go to **Settings → Apps → Special app access → Install unknown apps**.
2. Enable installation from your browser or file manager.
3. Download the APK above and open it to install.

## Build Status & Coverage

The CI pipeline runs `flutter analyze` and `flutter test --coverage` on every push.

[View coverage report →](./coverage/index.html)

## Build from Source

See the [Development Guide](./development) to build from source yourself.

```bash
git clone https://github.com/elkuku/kbannerguider.git
cd kbannerguider
./build.sh
```

<style>
.download-btn {
  display: inline-block;
  background: var(--vp-c-brand-1);
  color: #fff !important;
  text-decoration: none;
  padding: 0.75rem 1.5rem;
  border-radius: 6px;
  font-weight: 600;
  font-size: 1rem;
  margin: 1rem 0 1.5rem;
}
.download-btn:hover {
  background: var(--vp-c-brand-2);
}
</style>
