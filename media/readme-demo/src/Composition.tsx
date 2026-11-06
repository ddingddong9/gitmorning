import { Composition } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { Brief, Intro, Outro, Window } from "./Scenes";

export const ReadmeDemo: React.FC = () => (
  <TransitionSeries>
    <TransitionSeries.Sequence name="Intro" durationInFrames={75}>
      <Intro />
    </TransitionSeries.Sequence>
    <TransitionSeries.Transition
      presentation={fade()}
      timing={linearTiming({ durationInFrames: 12 })}
    />
    <TransitionSeries.Sequence name="Brief" durationInFrames={120}>
      <Brief />
    </TransitionSeries.Sequence>
    <TransitionSeries.Transition
      presentation={fade()}
      timing={linearTiming({ durationInFrames: 12 })}
    />
    <TransitionSeries.Sequence name="Window" durationInFrames={140}>
      <Window />
    </TransitionSeries.Sequence>
    <TransitionSeries.Transition
      presentation={fade()}
      timing={linearTiming({ durationInFrames: 12 })}
    />
    <TransitionSeries.Sequence name="Outro" durationInFrames={90}>
      <Outro />
    </TransitionSeries.Sequence>
  </TransitionSeries>
);

// 75 + 120 + 140 + 90 - 3 × 12 = 389 frames ≈ 13 s
export const MyComposition = () => (
  <Composition
    id="ReadmeDemo"
    component={ReadmeDemo}
    durationInFrames={389}
    fps={30}
    width={1280}
    height={720}
  />
);
