import { Still } from "remotion";
import { MyComposition } from "./Composition";
import { SocialPreview } from "./SocialPreview";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <MyComposition />
      <Still id="SocialPreview" component={SocialPreview} width={1280} height={640} />
    </>
  );
};
