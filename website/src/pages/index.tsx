import type { ReactNode } from "react";
import clsx from "clsx";
import Link from "@docusaurus/Link";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import Layout from "@theme/Layout";
import styles from "./index.module.css";
import Example from "../components/Example";
import Features from "../components/Features";
import { Notebook } from "lucide-react";

function HomepageHeader() {
  return (
    <header className={clsx("hero hero--primary", styles.heroBanner)}>
      <div className={styles.container}>
        <div className={styles.present}>
          <h1 className={clsx(styles.title)}>Dream</h1>
          <p className={clsx(styles.description)}>
            A composable web toolkit for Gleam on the BEAM
          </p>
          <span className={styles.sub}>
            Focused on explicit configuration, type safety, and predictable
            behavior.
          </span>

          <div className={styles.buttons}>
            <Link
              className={clsx(
                "button button--secondary button--lg",
                styles.link,
              )}
              to="/docs"
            >
              <Notebook
                size={22}
                style={{
                  marginRight: "0.5rem",
                  position: "relative",
                  top: "3px",
                }}
              />
              Get Started
            </Link>
          </div>
        </div>

        <Example />
      </div>
    </header>
  );
}

export default function Home(): ReactNode {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout
      title={`Hello from ${siteConfig.title}`}
      description="Description will go into a meta tag in <head />"
    >
      <HomepageHeader />

      <main>
        {/* <Description /> */}
        <Features />
        {/* <HomepageFeatures /> */}
      </main>
    </Layout>
  );
}
