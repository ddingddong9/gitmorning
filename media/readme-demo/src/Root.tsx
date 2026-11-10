import { Composition, Still } from "remotion";
import { MyComposition } from "./Composition";
import { SiteHero } from "./SiteHero";
import { SocialPreview } from "./SocialPreview";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <MyComposition />
      <Composition
        id="SiteHeroEn"
        component={SiteHero}
        durationInFrames={450}
        fps={30}
        width={1920}
        height={1200}
        defaultProps={{ lang: "en" as const }}
      />
      <Composition
        id="SiteHeroKo"
        component={SiteHero}
        durationInFrames={450}
        fps={30}
        width={1920}
        height={1200}
        defaultProps={{ lang: "ko" as const }}
      />
      <Still id="SocialPreview" component={SocialPreview} width={1280} height={640} />
    </>
  );
};
