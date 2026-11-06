import React from "react";
import { Img, staticFile } from "remotion";
import { Background } from "./Scenes";

const pill: React.CSSProperties = {
  padding: "10px 20px",
  borderRadius: 999,
  background: "rgba(255,179,71,0.14)",
  border: "1px solid rgba(255,179,71,0.45)",
  color: "#ffd9a8",
  fontSize: 24,
  fontWeight: 600,
};

/** GitHub social preview (1280×640): shown when the repository link is shared. */
export const SocialPreview: React.FC = () => (
  <Background>
    <div style={{ position: "absolute", left: 80, top: 0, bottom: 0, width: 640, display: "flex", flexDirection: "column", justifyContent: "center" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 24 }}>
        <Img src={staticFile("icon.png")} style={{ width: 96, height: 96, borderRadius: 22 }} />
        <div style={{ fontSize: 76, fontWeight: 700, letterSpacing: -2 }}>GitMorning</div>
      </div>
      <div style={{ marginTop: 28, fontSize: 40, fontWeight: 600, lineHeight: 1.2, letterSpacing: -0.5 }}>
        Your morning digest of GitHub Trending, in the Mac menu bar.
      </div>
      <div style={{ marginTop: 18, fontSize: 26, color: "rgba(245,245,247,0.68)", lineHeight: 1.35 }}>
        New and rising projects since yesterday, read in your language.
      </div>
      <div style={{ marginTop: 34, display: "flex", gap: 12 }}>
        <span style={pill}>Free</span>
        <span style={pill}>Open source · MIT</span>
        <span style={pill}>macOS 14+</span>
      </div>
    </div>
    <div style={{ position: "absolute", right: 70, top: 29, width: 400, height: 582, borderRadius: 14, overflow: "hidden",
                  boxShadow: "0 30px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.1)" }}>
      <Img src={staticFile("brief.png")} style={{ width: 400 }} />
    </div>
  </Background>
);
