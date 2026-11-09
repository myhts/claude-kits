// Next.js App Router: app/dev/explorer/page.jsx (not app/_explorer: folders starting with _ are not routable).
// Server component: refuses to render in production builds, so the explorer never ships.
import { notFound } from "next/navigation";
import Explorer from "./Explorer";

export const metadata = { title: "Project explorer" };

export default function Page() {
  if (process.env.NODE_ENV === "production" && process.env.EXPLORER_IN_PROD !== "1") notFound();
  return <Explorer repoRoot={process.env.REPO_ROOT} />;
}
