import type { ReactNode } from "react";
import Heading from "@theme/Heading";
import styles from "./styles.module.css";

type FeatureItem = {
  title: string;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: "🧠 Explicit by Design",
    description: (
      <>
        No magic, no hidden state, no surprises. Every router, service, and
        middleware is wired explicitly in your <code>main()</code>. What you see
        is what runs.
      </>
    ),
  },
  {
    title: "⚙️ Composable, Not a Framework",
    description: (
      <>
        Controllers are just functions. Middleware is just data. Build your own
        architecture or use Dream’s patterns—nothing is imposed, everything is
        composable.
      </>
    ),
  },
  {
    title: "🔥 BEAM-Powered Reliability",
    description: (
      <>
        Runs on the BEAM for massive concurrency, fault isolation, and hot code
        reloading. Long-lived connections, streaming, and WebSockets are
        first-class citizens.
      </>
    ),
  },
];

function Feature({ title, description }: FeatureItem) {
  return (
    <div className={styles.featureBox}>
      <Heading as="h3">{title}</Heading>
      <p>{description}</p>
    </div>
  );
}

export default function Features(): ReactNode {
  return (
    <section className={styles.features}>
      <div className={styles.row}>
        {FeatureList.map((props, idx) => (
          <Feature key={idx} {...props} />
        ))}
      </div>
    </section>
  );
}
