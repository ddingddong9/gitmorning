# README demo video

A 13-second Remotion motion graphic for the public README, built only from real app screenshots.

```sh
npm install
npx remotion studio                    # preview and edit
npx remotion render ReadmeDemo out/gitmorning-demo.mp4 --crf=20
npx remotion render ReadmeDemo out/gitmorning-demo.gif --codec=gif --every-nth-frame=3 --scale=0.625
npx remotion still SocialPreview ../../docs/social-preview.png   # GitHub social preview (1280×640)
```

Website hero (`src/SiteHero.tsx`, 15 s loop, English and Korean), written to `web/media/`:

```sh
for l in En Ko; do
  npx remotion render SiteHero$l ../../web/media/hero-$(echo $l | tr A-Z a-z).mp4 --codec=h264 --crf=19 --scale=0.75 --x264-preset=slow
  npx remotion still SiteHero$l ../../web/media/hero-$(echo $l | tr A-Z a-z).jpg --frame=230 --image-format=jpeg --jpeg-quality=85 --scale=0.5
done
```

- `public/site/en`, `public/site/ko`: dark 2× snapshots (`main.png`, `brief.png`, `readme.png`) from the DEBUG snapshot hook with `GITMORNING_SNAPSHOT_README=anthropics/skills`.

- `public/window.png`, `public/brief.png`: English dark screenshots from the DEBUG snapshot hook (`GITMORNING_SNAPSHOT_DIR`, see `Sources/GitMorning/DebugSnapshot.swift`).
- `public/icon.png`: extracted from `Resources/AppIcon.icns`.
- Scenes are in `src/Scenes.tsx`; order and timing in `src/Composition.tsx`.
- Remotion is free for individuals and companies of up to 3 people. See https://www.remotion.dev/docs/license.
