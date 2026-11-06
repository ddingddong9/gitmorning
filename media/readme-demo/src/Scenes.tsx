import React from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const font =
  '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif';
const sunrise = "#ffb347";
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ease = Easing.bezier(0.16, 1, 0.3, 1);

export const Background: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => (
  <AbsoluteFill
    style={{
      background:
        "radial-gradient(120% 90% at 85% -10%, #4a2a12 0%, #1a1410 38%, #0d1117 70%)",
      fontFamily: font,
      color: "#f5f5f7",
    }}
  >
    {children}
  </AbsoluteFill>
);

/** A thin macOS-style menu bar with the GitMorning sun icon. */
const MenuBar: React.FC<{ glow: number }> = ({ glow }) => (
  <div
    style={{
      position: "absolute",
      top: 0,
      left: 0,
      right: 0,
      height: 34,
      background: "rgba(30,30,32,0.72)",
      borderBottom: "1px solid rgba(255,255,255,0.08)",
      display: "flex",
      alignItems: "center",
      justifyContent: "flex-end",
      gap: 22,
      paddingRight: 24,
      fontSize: 15,
      color: "rgba(255,255,255,0.85)",
    }}
  >
    <span
      style={{
        fontSize: 20,
        filter: `drop-shadow(0 0 ${glow * 10}px ${sunrise})`,
      }}
    >
      ☀️
    </span>
    <span>Wed 8:00 AM</span>
  </div>
);

const Title: React.FC<{
  text: string;
  sub?: string;
  delay?: number;
  align?: "left" | "center";
  size?: number;
}> = ({ text, sub, delay = 0, align = "left", size = 64 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <div style={{ textAlign: align }}>
      <div
        style={{
          fontSize: size,
          fontWeight: 700,
          letterSpacing: -1.5,
          lineHeight: 1.08,
          opacity: interpolate(frame, [delay, delay + 0.5 * fps], [0, 1], clamp),
          translate: interpolate(
            frame,
            [delay, delay + 0.7 * fps],
            ["0px 24px", "0px 0px"],
            { ...clamp, easing: ease },
          ),
        }}
      >
        {text}
      </div>
      {sub ? (
        <div
          style={{
            marginTop: 18,
            fontSize: 30,
            color: "rgba(245,245,247,0.68)",
            lineHeight: 1.3,
            opacity: interpolate(
              frame,
              [delay + 0.3 * fps, delay + 0.9 * fps],
              [0, 1],
              clamp,
            ),
          }}
        >
          {sub}
        </div>
      ) : null}
    </div>
  );
};

/** 1. App icon and promise. */
export const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Background>
      <MenuBar glow={interpolate(frame, [0, fps], [0, 1], clamp)} />
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          flexDirection: "column",
          gap: 34,
        }}
      >
        <Img
          src={staticFile("icon.png")}
          style={{
            width: 150,
            height: 150,
            borderRadius: 34,
            boxShadow: "0 20px 60px rgba(255,179,71,0.25)",
            scale: interpolate(frame, [0, 0.8 * fps], [0.6, 1], {
              ...clamp,
              easing: Easing.spring({ damping: 14 }),
              output: "perceptual-scale",
            }),
            opacity: interpolate(frame, [0, 0.4 * fps], [0, 1], clamp),
          }}
        />
        <Title
          text="GitMorning"
          sub="Your morning digest of GitHub Trending"
          delay={0.3 * fps}
          align="center"
          size={84}
        />
      </AbsoluteFill>
    </Background>
  );
};

/** 2. The morning brief drops down from the menu bar. */
export const Brief: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Background>
      <MenuBar glow={1} />
      <div style={{ position: "absolute", left: 90, top: 230, width: 600 }}>
        <Title
          text="Every morning, only what's new."
          sub="A brief in your menu bar with projects that are new or climbing since yesterday."
          delay={0.2 * fps}
        />
      </div>
      <div
        style={{
          position: "absolute",
          top: 42,
          right: 70,
          width: 430,
          height: 626,
          borderRadius: 14,
          overflow: "hidden",
          boxShadow: "0 30px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.1)",
          clipPath: `inset(0 0 ${interpolate(frame, [0.4 * fps, 1.3 * fps], [100, 0], { ...clamp, easing: ease })}% 0 round 14px)`,
        }}
      >
        <Img
          src={staticFile("brief.png")}
          style={{
            width: 430,
            translate: interpolate(
              frame,
              [1.8 * fps, 3.6 * fps],
              ["0px 0px", "0px -14px"],
              clamp,
            ),
          }}
        />
      </div>
    </Background>
  );
};

const Chip: React.FC<{ text: string; at: number }> = ({ text, at }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <div
      style={{
        padding: "12px 22px",
        borderRadius: 999,
        background: "rgba(255,179,71,0.14)",
        border: "1px solid rgba(255,179,71,0.45)",
        color: "#ffd9a8",
        fontSize: 26,
        fontWeight: 600,
        opacity: interpolate(frame, [at, at + 0.4 * fps], [0, 1], clamp),
        translate: interpolate(frame, [at, at + 0.6 * fps], ["0px 14px", "0px 0px"], {
          ...clamp,
          easing: ease,
        }),
      }}
    >
      {text}
    </div>
  );
};

/** 3. The full window: details, translation, saving. */
export const Window: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Background>
      <div style={{ position: "absolute", top: 44, left: 0, right: 0 }}>
        <Title
          text="Read it. Save what to try."
          align="center"
          size={56}
          delay={0.1 * fps}
        />
      </div>
      <div
        style={{
          position: "absolute",
          top: 210,
          left: 140,
          width: 1000,
          height: 470,
          borderRadius: 16,
          overflow: "hidden",
          boxShadow: "0 30px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.1)",
          opacity: interpolate(frame, [0, 0.5 * fps], [0, 1], clamp),
        }}
      >
        <Img
          src={staticFile("window.png")}
          style={{
            width: 1000,
            transformOrigin: "75% 15%",
            scale: interpolate(frame, [0.6 * fps, 4.2 * fps], [1, 1.16], {
              ...clamp,
              easing: Easing.bezier(0.45, 0, 0.55, 1),
            }),
          }}
        />
      </div>
      <div
        style={{
          position: "absolute",
          top: 138,
          left: 0,
          right: 0,
          display: "flex",
          justifyContent: "center",
          gap: 16,
        }}
      >
        <Chip text="Stars & daily growth" at={0.6 * fps} />
        <Chip text="README preview" at={1.2 * fps} />
        <Chip text="Notes & status" at={1.8 * fps} />
      </div>
    </Background>
  );
};

/** 4. End card. */
export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Background>
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          flexDirection: "column",
          gap: 30,
        }}
      >
        <Img src={staticFile("icon.png")} style={{ width: 110, height: 110, borderRadius: 25 }} />
        <Title
          text="Free. No account. On your Mac."
          align="center"
          size={64}
          delay={0.1 * fps}
        />
        <div
          style={{
            marginTop: 10,
            fontFamily: "SF Mono, Menlo, monospace",
            fontSize: 26,
            padding: "14px 26px",
            borderRadius: 12,
            background: "rgba(255,255,255,0.07)",
            border: "1px solid rgba(255,255,255,0.12)",
            color: "#ffd9a8",
            opacity: interpolate(frame, [0.6 * fps, 1.1 * fps], [0, 1], clamp),
          }}
        >
          github.com/ddingddong9/gitmorning
        </div>
      </AbsoluteFill>
    </Background>
  );
};
