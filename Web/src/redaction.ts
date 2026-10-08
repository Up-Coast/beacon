/** The secret sweep, ported from Sources/BeaconCore/Redaction.swift: credential shapes in what the reporter typed
 * are masked before anything leaves the browser. Each pattern is deliberately narrow. */

export const MASK = "[removed by Beacon]";

const RULES: { label: string; pattern: RegExp }[] = [
  { label: "an Anthropic API key", pattern: /sk-ant-[A-Za-z0-9\-_]{16,}/g },
  { label: "an OpenAI-style API key", pattern: /\bsk-[A-Za-z0-9]{32,}/g },
  { label: "a GitHub token", pattern: /\bgh[pousr]_[A-Za-z0-9]{20,}/g },
  { label: "a GitHub fine-grained token", pattern: /\bgithub_pat_[A-Za-z0-9_]{20,}/g },
  { label: "an AWS access key id", pattern: /\bAKIA[0-9A-Z]{16}\b/g },
  { label: "a Google API key", pattern: /\bAIza[0-9A-Za-z\-_]{35}\b/g },
  { label: "a Slack token", pattern: /\bxox[baprs]-[A-Za-z0-9\-]{10,}/g },
  { label: "a Stripe key", pattern: /\b[rs]k_(live|test)_[A-Za-z0-9]{16,}/g },
  { label: "a private key block", pattern: /-----BEGIN [A-Z ]*PRIVATE KEY-----/g },
  { label: "a bearer token", pattern: /\bbearer\s+[A-Za-z0-9\-._~+/]{20,}={0,2}/gi },
  { label: "a JSON web token", pattern: /\beyJ[A-Za-z0-9\-_]{10,}\.[A-Za-z0-9\-_]{10,}\.[A-Za-z0-9\-_]{10,}/g },
  {
    label: "a password in a setting",
    pattern: /\b(password|passwd|secret|api[_-]?key|access[_-]?token)\b\s*[:=]\s*\S{6,}/gi,
  },
  { label: "a URL with a password in it", pattern: /[a-zA-Z][a-zA-Z0-9+.\-]*:\/\/[^\s/:@]+:[^\s/@]+@/g },
];

export function sweep(text: string): { text: string; findings: string[] } {
  let out = text;
  const findings: string[] = [];
  for (const { label, pattern } of RULES) {
    pattern.lastIndex = 0;
    if (pattern.test(out)) {
      findings.push(label);
      pattern.lastIndex = 0;
      out = out.replace(pattern, MASK);
    }
  }
  return { text: out, findings };
}
