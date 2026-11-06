# README demo video

A 13-second Remotion motion graphic for the public README, built only from real app screenshots.

```sh
npm install
npx remotion studio                    # preview and edit
npx remotion render ReadmeDemo out/gitmorning-demo.mp4 --crf=20
npx remotion render ReadmeDemo out/gitmorning-demo.gif --codec=gif --every-nth-frame=3 --scale=0.625
```

- `public/window.png`, `public/brief.png`: English dark screenshots from the DEBUG snapshot hook (`GITMORNING_SNAPSHOT_DIR`, see `Sources/GitMorning/DebugSnapshot.swift`).
- `public/icon.png`: extracted from `Resources/AppIcon.icns`.
- Scenes are in `src/Scenes.tsx`; order and timing in `src/Composition.tsx`.
- Remotion is free for individuals and companies of up to 3 people. See https://www.remotion.dev/docs/license.
