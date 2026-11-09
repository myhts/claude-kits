// React (Vite, CRA, Remix…): the explorer as a component. Copy next to explorer-engine.js, explorer.css and
// explorer-data.js, and mount it on a dev-only route (see reference/ui-shells.md). TypeScript: rename to .tsx as is.
import { useEffect, useRef } from "react";
import { mountExplorer } from "./explorer-engine.js";
import "./explorer.css";
import data from "./explorer-data.js";

export default function Explorer({ repoRoot = import.meta.env?.VITE_REPO_ROOT, height }) {
  const ref = useRef(null);
  useEffect(() => {
    // repoRoot = absolute path of the repo on this machine (from .env.local, never committed): code links open the editor
    const explorer = mountExplorer(ref.current, data, { repoRoot, height });
    return () => explorer.destroy();   // StrictMode mounts twice in dev: destroy makes that harmless
  }, [repoRoot, height]);
  return <div ref={ref} />;
}
