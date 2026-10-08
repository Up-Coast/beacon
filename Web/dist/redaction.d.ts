/** The secret sweep, ported from Sources/BeaconCore/Redaction.swift: credential shapes in what the reporter typed
 * are masked before anything leaves the browser. Each pattern is deliberately narrow. */
export declare const MASK = "[removed by Beacon]";
export declare function sweep(text: string): {
    text: string;
    findings: string[];
};
