import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */

const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    "index",
    "quickstart",
    "examples",
    {
      type: "category",
      label: "Learn",
      link: {
        type: "doc",
        id: "learn/index",
      },
      items: [
        "learn/hello-world",
        "learn/building-api",
        "learn/adding-auth",
        "learn/advanced-patterns",
      ],
    },
    {
      type: "category",
      label: "Guides",
      link: {
        type: "doc",
        id: "guides/index",
      },
      items: [
        "guides/authentication",
        "guides/controllers-and-models",
        "guides/deployment",
        "guides/file-uploads",
        "guides/multiple-formats",
        "guides/operations",
        "guides/rest-api",
        "guides/streaming",
        "guides/streaming-quick-reference",
        "guides/templates",
        "guides/testing",
        "guides/websockets",
      ],
    },
    {
      type: "category",
      label: "Concepts",
      link: {
        type: "doc",
        id: "concepts",
      },
      items: [
        "concepts/how-it-works",
        "concepts/patterns",
        "concepts/project-structure",
      ],
    },
    {
      type: "category",
      label: "Contributing",
      link: {
        type: "doc",
        id: "contributing/index",
      },
      items: [
        "contributing/contributing-guide",
        "contributing/publishing",
        "contributing/testing",
        "contributing/tone-guide",
      ],
    },
    {
      type: "category",
      label: "Reference",
      link: {
        type: "doc",
        id: "reference/index",
      },
      items: [
        "reference/architecture",
        "reference/design-principles",
        "reference/dream-vs-mist",
        "reference/naming-conventions",
        "reference/streaming-api",
        "reference/why-beam",
      ],
    },
  ],
};

export default sidebars;
