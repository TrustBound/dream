import siteConfig from "@generated/docusaurus.config";

export default function prismIncludeLanguages(PrismObject) {
  const prismConfig = siteConfig?.themeConfig?.prism ?? {};

  const additionalLanguages = prismConfig.additionalLanguages ?? [];

  // Temporarily inject Prism global instance
  const PrismBefore = globalThis.Prism;
  globalThis.Prism = PrismObject;

  // Load standard languages
  additionalLanguages.forEach((lang) => {
    require(`prismjs/components/prism-${lang}`);
  });

  // ----------------------------------------
  // 🔥 CUSTOM GLEAM LANGUAGE
  // ----------------------------------------
  PrismObject.languages.gleam = {
    comment: {
      pattern: /\/\/\/?.*/,
      greedy: true,
    },
    tag: /@(deprecated|external|internal)/,
    target: {
      pattern: /\b(erlang|javascript)\b/,
      alias: "symbol",
    },
    function: /\b(?<!@)([a-z_][a-z0-9_]+)(?=\()/,
    keyword:
      /\b(as|assert|auto|case|const|delegate|derive|echo|else|fn|if|implement|import|let|macro|opaque|panic|pub|test|todo|type|use)\b/,
    number:
      /\b(?:\d[\d_]*(\.[\d_]*(e-?[\d_]+)?)?|0[bB][01_]+|0[oO][0-7_]+|0[xX][\da-fA-F_]+)\b/,
    type: {
      pattern: /(?:[A-Z][A-Za-z0-9_]+)/,
      greedy: true,
      alias: "symbol",
    },
    namespace: {
      pattern: /(?:[a-z][a-z0-9_]*)\.(?!{)/,
      inside: {
        punctuation: /\./,
      },
    },
    punctuation: /[:!,{}()\[\]]/,
    operator: {
      pattern:
        /(<<|>>|<-|->|\|>|<>|\.\.|<=\.?|>=\.?|==\.?|!=\.?|<\.?|>\.?|&&|\|\||\+\.?|-\.?|\/\.?|\*\.?|%|=|\|)/,
      greedy: true,
    },
    boolean: /\b(?:True|False|Ok|Error|Nil)\b/,
    string: {
      pattern: /"[\s\S]*?(?<!\\)"/,
      inside: {
        punctuation: /\\./,
      },
      greedy: true,
    },
  };

  // Restore previous Prism global
  delete globalThis.Prism;
  if (typeof PrismBefore !== "undefined") {
    globalThis.Prism = PrismBefore;
  }
}
