import React from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";

/**
 * Website hero: the menu bar brief opens, the main window opens from it, the README preview opens
 * from the window, then everything closes back to the empty desktop so the video loops without a cut.
 * Built only from real DEBUG snapshots of the app (public/site/<lang>/).
 * 1920×1200, 30 fps, 450 frames (15 s).
 */
export type SiteHeroProps = { readonly lang: "en" | "ko" };

const W = 1920;
const H = 1200;
const MENU = 46;
const font =
  '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Apple SD Gothic Neo", "Helvetica Neue", sans-serif';
const out = Easing.bezier(0.16, 1, 0.3, 1);
const inOut = Easing.bezier(0.65, 0, 0.35, 1);

/** Clamped interpolation over [start, end] frames. */
const tween = (frame: number, range: [number, number], values: [number, number], easing = out) =>
  interpolate(frame, range, values, { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing });

const copy = {
  en: {
    clock: "Tue Nov 10  8:00 AM",
    brief: "New or rising since yesterday",
    window: "Read every project in your language",
    readme: "README, right in the app",
  },
  ko: {
    clock: "11월 10일 (화) 오전 8:00",
    brief: "어제보다 새로 올라오거나 순위가 오른 프로젝트",
    window: "모든 프로젝트를 내 언어로",
    readme: "README도 앱 안에서",
  },
} as const;

// Screenshot geometry (2× pixels). The brief and README snapshots have a 57 px empty title strip.
const STRIP = 57;
const brief = { left: 1300, top: MENU + 8, width: 540, src: { w: 720, h: 1048 } };
const briefScale = brief.width / brief.src.w;
const briefHeight = (brief.src.h - STRIP) * briefScale;
const main = { width: 1440, src: { w: 2120, h: 1496 } };
const mainScale = main.width / main.src.w;
const mainHeight = main.src.h * mainScale;
const mainLeft = (W - main.width) / 2 - 40;
const mainTop = MENU + (H - MENU - mainHeight) / 2;
const readme = { width: 1180, src: { w: 1560, h: 1300 } };
const readmeScale = readme.width / readme.src.w;
const readmeHeight = (readme.src.h - STRIP) * readmeScale;
const readmeLeft = (W - readme.width) / 2 + 60;
const readmeTop = MENU + (H - MENU - readmeHeight) / 2 + 10;

// Where things the cursor clicks are, in video pixels.
const sunIcon = { x: 1588, y: MENU / 2 };
const openButton = { x: brief.left + 520 * briefScale, y: brief.top + (1011 - STRIP) * briefScale };
// The window pushes in toward its detail pane; the README button moves with it.
const push = { origin: { x: 0.72, y: 0.2 }, scale: 1.06 };
const readmeButtonInWindow = { x: 1597 * mainScale, y: 323 * mainScale };
const readmeButton = {
  x: mainLeft + push.origin.x * main.width + (readmeButtonInWindow.x - push.origin.x * main.width) * push.scale,
  y: mainTop + push.origin.y * mainHeight + (readmeButtonInWindow.y - push.origin.y * mainHeight) * push.scale,
};
const rest = { x: 1060, y: 820 };

// Timeline (frames).
const T = {
  toSun: [10, 46] as [number, number],
  clickSun: 50,
  briefOpen: [52, 80] as [number, number],
  toOpen: [118, 150] as [number, number],
  clickOpen: 154,
  briefClose: [156, 176] as [number, number],
  windowOpen: [160, 196] as [number, number],
  pushIn: [196, 300] as [number, number],
  toReadme: [262, 296] as [number, number],
  clickReadme: 300,
  readmeOpen: [302, 334] as [number, number],
  readmeScroll: [340, 404] as [number, number],
  close: [408, 432] as [number, number],
  toRest: [404, 446] as [number, number],
};

const Wallpaper: React.FC = () => {
  const frame = useCurrentFrame();
  // One slow, full cycle of drift per loop keeps the first and last frames identical.
  const phase = (frame / 450) * Math.PI * 2;
  const x = 78 + Math.sin(phase) * 3;
  const y = 104 + Math.cos(phase) * 2;
  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(70% 80% at ${x}% ${y}%, #ff9a3d 0%, #e8590c 18%, #8f2d3c 42%, #2b1b3a 68%, #120f1f 100%)`,
      }}
    />
  );
};

const Sun: React.FC<{ size: number; color: string }> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={1.7} strokeLinecap="round">
    <path d="M7 16a5 5 0 0 1 10 0" />
    <path d="M3 19h18M12 6.5V9M5.6 9.6l1.7 1.7M18.4 9.6l-1.7 1.7M2.5 16h1.8M19.7 16h1.8" />
  </svg>
);

const MenuBar: React.FC<{ lang: SiteHeroProps["lang"]; pressed: number }> = ({ lang, pressed }) => (
  <div
    style={{
      position: "absolute", top: 0, left: 0, right: 0, height: MENU,
      display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 28px",
      background: "rgba(24, 18, 28, 0.42)", backdropFilter: "blur(30px)",
      color: "rgba(255,255,255,0.92)", fontFamily: font, fontSize: 22, fontWeight: 500,
    }}
  >
    <span style={{ fontWeight: 700 }}>GitMorning</span>
    <div style={{ display: "flex", alignItems: "center", gap: 30 }}>
      <div
        style={{
          width: 52, height: 36, borderRadius: 8, display: "grid", placeItems: "center",
          background: `rgba(255,255,255,${0.22 * pressed})`,
        }}
      >
        <Sun size={30} color="#fff" />
      </div>
      <span style={{ fontVariantNumeric: "tabular-nums" }}>{copy[lang].clock}</span>
    </div>
  </div>
);

const Cursor: React.FC<{ x: number; y: number; press: number }> = ({ x, y, press }) => (
  <svg
    width={46} height={46} viewBox="0 0 24 24"
    style={{ position: "absolute", left: x - 7, top: y - 4, scale: String(1 - 0.12 * press), transformOrigin: "7px 4px", filter: "drop-shadow(0 4px 8px rgba(0,0,0,0.45))" }}
  >
    <path d="M5 3l14 9.2-6.3 1.1 3.9 7.2-2.6 1.4-3.9-7.3L5 19.2z" fill="#111" stroke="#fff" strokeWidth={1.3} strokeLinejoin="round" />
  </svg>
);

const Chip: React.FC<{ text: string; show: number; x: number; y: number }> = ({ text, show, x, y }) => (
  <div
    style={{
      position: "absolute", left: x, top: y, opacity: show,
      translate: `0px ${(1 - show) * 18}px`,
      padding: "18px 30px", borderRadius: 999, fontFamily: font, fontSize: 38, fontWeight: 650,
      color: "#fff", background: "rgba(20, 14, 24, 0.62)", backdropFilter: "blur(24px)",
      border: "1px solid rgba(255,255,255,0.16)", boxShadow: "0 18px 50px rgba(0,0,0,0.35)",
      whiteSpace: "nowrap",
    }}
  >
    {text}
  </div>
);

const shadow = "0 40px 120px rgba(10, 4, 16, 0.55), 0 0 0 1px rgba(255,255,255,0.12)";

/** Press feedback: 0 → 1 → 0 over a few frames around a click. */
const pressAt = (frame: number, at: number) => tween(frame, [at - 4, at], [0, 1], inOut) - tween(frame, [at + 2, at + 8], [0, 1], inOut);

export const SiteHero: React.FC<SiteHeroProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const text = copy[lang];
  const img = (name: string) => staticFile(`site/${lang}/${name}.png`);

  // Cursor path: rest → sun → Open GitMorning → Preview README → rest.
  const p1 = tween(frame, T.toSun, [0, 1], inOut);
  const p2 = tween(frame, T.toOpen, [0, 1], inOut);
  const p3 = tween(frame, T.toReadme, [0, 1], inOut);
  const p4 = tween(frame, T.toRest, [0, 1], inOut);
  const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
  let cx = lerp(rest.x, sunIcon.x + 6, p1);
  let cy = lerp(rest.y, sunIcon.y + 4, p1);
  cx = lerp(cx, openButton.x, p2); cy = lerp(cy, openButton.y, p2);
  cx = lerp(cx, readmeButton.x, p3); cy = lerp(cy, readmeButton.y, p3);
  cx = lerp(cx, rest.x, p4); cy = lerp(cy, rest.y, p4);
  const press = Math.max(pressAt(frame, T.clickSun), pressAt(frame, T.clickOpen), pressAt(frame, T.clickReadme));

  const briefIn = tween(frame, T.briefOpen, [0, 1]);
  const briefOut = tween(frame, T.briefClose, [0, 1], inOut);
  const briefShow = briefIn * (1 - briefOut);
  const windowIn = tween(frame, T.windowOpen, [0, 1]);
  const closeAll = tween(frame, T.close, [0, 1], inOut);
  const windowShow = windowIn * (1 - closeAll);
  const zoom = tween(frame, T.pushIn, [1, push.scale], inOut);
  const readmeIn = tween(frame, T.readmeOpen, [0, 1]);
  const readmeShow = readmeIn * (1 - closeAll);
  const scroll = tween(frame, T.readmeScroll, [0, 230], inOut);

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      <Wallpaper />

      {/* Main window */}
      <div
        style={{
          position: "absolute", left: mainLeft, top: mainTop, width: main.width, height: mainHeight,
          opacity: windowShow, scale: String((0.94 + 0.06 * windowIn) * zoom - 0.03 * closeAll),
          transformOrigin: `${push.origin.x * 100}% ${push.origin.y * 100}%`,
          translate: `0px ${(1 - windowIn) * 30}px`,
          borderRadius: 22, overflow: "hidden", boxShadow: shadow,
        }}
      >
        <Img src={img("main")} style={{ width: main.width, height: mainHeight }} />
      </div>

      {/* README preview */}
      <div
        style={{
          position: "absolute", left: readmeLeft, top: readmeTop, width: readme.width, height: readmeHeight,
          opacity: readmeShow, scale: String(0.95 + 0.05 * readmeIn - 0.03 * closeAll),
          translate: `0px ${(1 - readmeIn) * 50}px`,
          borderRadius: 20, overflow: "hidden", boxShadow: shadow, background: "#262626",
        }}
      >
        {/* Title row stays put while the README body scrolls under it. */}
        <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
          <Img
            src={img("readme")}
            style={{ position: "absolute", top: -STRIP * readmeScale, width: readme.width }}
          />
        </div>
        <div style={{ position: "absolute", left: 0, right: 0, top: 150 * readmeScale, bottom: 0, overflow: "hidden", background: "#262626" }}>
          <Img
            src={img("readme")}
            style={{ position: "absolute", top: -(150 + STRIP) * readmeScale - scroll, width: readme.width }}
          />
        </div>
      </div>

      {/* Morning brief panel, opening from the menu bar */}
      <div
        style={{
          position: "absolute", left: brief.left, top: brief.top, width: brief.width, height: briefHeight,
          opacity: briefShow, borderRadius: 20, overflow: "hidden", boxShadow: shadow,
          transformOrigin: "84% 0%", scale: String(0.9 + 0.1 * briefIn),
          clipPath: `inset(0 0 ${(1 - briefIn) * 100}% 0 round 20px)`,
        }}
      >
        <Img src={img("brief")} style={{ position: "absolute", top: -STRIP * briefScale, width: brief.width }} />
      </div>

      <MenuBar lang={lang} pressed={briefShow} />

      <Chip text={text.brief} show={tween(frame, [84, 100], [0, 1]) * (1 - briefOut)} x={170} y={300} />
      <Chip text={text.window} show={tween(frame, [206, 222], [0, 1]) * (1 - tween(frame, [296, 306], [0, 1]))} x={140} y={H - 170} />
      <Chip text={text.readme} show={tween(frame, [344, 360], [0, 1]) * (1 - closeAll)} x={140} y={H - 170} />

      <Cursor x={cx} y={cy} press={press} />
    </AbsoluteFill>
  );
};
