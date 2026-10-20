"use client";
// Next.js client component: the engine touches the DOM, so it mounts in useEffect (never during server rendering).
// Keep explorer-engine.js, explorer.css and explorer-data.js in this folder. Pages Router: see reference/ui-shells.md.
import { useEffect, useRef } from "react";
import { mountExplorer } from "./explorer-engine.js";
import "./explorer.css";
import data from "./explorer-data.js";

export default function Explorer({ repoRoot }) {
  const ref = useRef(null);
  useEffect(() => {
    const explorer = mountExplorer(ref.current, data, { repoRoot });
    return () => explorer.destroy();
  }, [repoRoot]);
  return <div ref={ref} />;
}
