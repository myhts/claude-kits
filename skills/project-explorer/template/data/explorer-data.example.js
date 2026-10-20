// ---------------------------------------------------------------------------------------------------------------
// EXAMPLE DATA: an invented "bookshop orders" service, only here to show the format and to test the engine.
// Replace all of it with the target project's data. Format: reference/data-schema.md.
// Allowed module syntax (so tools/bundle-html.mjs can inline it): import { a, b } from "./x.js" · import x from "./x.js"
// · export default … · export const x = … · export function f() {}
// ---------------------------------------------------------------------------------------------------------------
import { G } from "./explorer-engine.js";

const S = "src/orders/";   // path prefixes keep the links short; all paths are relative to the repository root
const T = "test/orders/";

export default {
  meta: {
    title: "Bookshop orders: architecture explorer",
    pagePath: "docs/explorer/explorer.html",   // where the generated page lives: lets file:// links open the editor
    measuredOn: "2026-01-01, a laptop",
    labsDoc: "docs/explorer/LABS.md",
    startHere: "Flow **1** first: one request, one thread. Then flow **2**, the failure path.",
    guides: [["Debug tour", "docs/explorer/TOUR.md"], ["Labs", "docs/explorer/LABS.md"]],
  },

  modules: {
    web: { label: "Browser", color: "#f08c00" },
    api: { label: "orders API", color: "#1c7ed6" },
    worker: { label: "worker", color: "#7048e8" },
    infra: { label: "infrastructure", color: "#5c3d2e", dark: "#c49a6c" },
  },

  map: {
    lanes: [{ id: "browser", label: "Browser" }, { id: "api", label: "API" }, { id: "async", label: "Queue & worker" }, { id: "data", label: "Data" }],
    nodes: [
      { id: "ui", lane: "browser", col: 0, label: "CheckoutPage", sub: "places the order", mod: "web",
        what: "Sends `POST /orders` with an `Idempotency-Key`, then polls until the order is `PAID` or `FAILED`.",
        files: [["web/src/CheckoutPage.tsx", 12, "onSubmit"]], observe: "DevTools → **Network**." },
      { id: "ctl", lane: "api", col: 0, label: "OrderController", sub: "validates, enqueues", mod: "api",
        what: "Validates the body, writes the order as `PENDING` and enqueues a `ChargeCard` job. Answers **202**.",
        files: [[S + "OrderController.ts", 20, "create"]] },
      { id: "limiter", lane: "api", col: 1, label: "RateLimiter", sub: "token bucket per customer", mod: "api",
        what: "One bucket per customer in Redis. Over the limit → **429** with `Retry-After`.", files: [[S + "rateLimit.ts", 8]] },
      { id: "queue", lane: "async", col: 0, label: "jobs queue", sub: "charge-card jobs", mod: "infra",
        what: "Holds jobs until a worker takes them.", observe: "`redis-cli LLEN jobs`" },
      { id: "worker", lane: "async", col: 1, label: "ChargeWorker", sub: "calls the payment partner", mod: "worker",
        what: "Takes a job, calls the payment partner through a **circuit breaker**, marks the order `PAID` or `FAILED`.",
        files: [[S + "ChargeWorker.ts", 31, "handle"]] },
      { id: "psp", lane: "async", col: 2, label: "Payment partner", sub: "external, sometimes slow", mod: "infra",
        what: "Outside our control. The lab switch `DRILL_PSP_FAILURE_RATE` makes the local stub fail." },
      { id: "db", lane: "data", col: 0, label: "Postgres", sub: "orders table", mod: "infra", what: "The source of truth." },
      { id: "redis", lane: "data", col: 1, label: "Redis", sub: "buckets + queue", mod: "infra", what: "Rate-limit buckets and the job queue." },
    ],
    edges: [
      { from: "ui", to: "ctl" }, { from: "ctl", to: "limiter", label: "check" },
      { from: "limiter", to: "redis", dashed: true, around: "right" },   // around the worker, not through it
      { from: "ctl", to: "queue", label: "enqueue" }, { from: "queue", to: "worker" }, { from: "worker", to: "psp", label: "charge" },
      { from: "ctl", to: "db", around: "left" },   // down the left edge, around the queue
      { from: "worker", to: "db" },
    ],
  },

  flows: [
    {
      id: "place-order", title: "1. Place an order (happy path)",
      intro: "One click on **Pay**, followed through 4 steps.",
      steps: [
        { n: ["ui"], e: ["ui>ctl"], t: "The browser sends the order",
          x: "A fresh `Idempotency-Key` per attempt, reused on retry.",
          d: "POST /orders\nIdempotency-Key: demo-001\n\n{\"bookId\":\"b-1\",\"qty\":1}", bp: ["web/src/CheckoutPage.tsx", 12, "Inspect `body`."] },
        { n: ["ctl", "limiter", "redis"], e: ["ctl>limiter", "limiter>redis"], t: "Is there budget left?",
          x: "One atomic script takes a token.", why: ["partner-calls", "L0"],
          st: [["chg", "Redis", "`bucket:c-1` tokens 5 → 4"]], bp: [S + "rateLimit.ts", 8, "Inspect `decision`."] },
        { n: ["ctl", "db", "queue"], e: ["ctl>db", "ctl>queue"], t: "Save PENDING, enqueue, answer 202",
          x: "The order row and the job are written; the request is done.",
          st: [["add", "Postgres", "order `o-1` PENDING"], ["add", "Queue", "job `charge o-1`"]], bp: [S + "OrderController.ts", 20, ""] },
        { n: ["worker", "psp", "db"], e: ["queue>worker", "worker>psp", "worker>db"], t: "The worker charges the card",
          x: "The partner answers in ~180 ms; the order becomes `PAID`.", why: ["partner-calls", "L2"],
          st: [["chg", "Postgres", "order `o-1` PENDING → PAID"], ["del", "Queue", "job removed"]], bp: [S + "ChargeWorker.ts", 31, "Inspect `result`."] },
      ],
    },
  ],

  concepts: [{
    id: "partner-calls", title: "Calling a flaky partner",
    intro: "From no timeout at all to a breaker with a fallback. Each level is a problem that forced a change.",
    docs: [["Primer: timeouts and breakers", "docs/learn/breakers.md"]],
    boxes: {
      w: { at: [0, 1], label: "ChargeWorker", sub: "8 threads" },
      cb: { at: [1, 1], label: "Circuit breaker", sub: "opens at 50% failed" },
      psp: { at: [3, 1], label: "Payment partner", sub: "slow today" },
      q: { at: [0, 0], label: "jobs queue", sub: "" },
    },
    levels: [
      {
        id: "L0", name: "No timeout", q: "The partner hangs. What happens to our workers?",
        before: { b: ["q", ["w", { sub: "8 threads, all waiting" }], ["psp", { sub: "hangs for 30 s" }]],
          e: [["q", "w", "jobs pile up", "heavy"], ["w", "psp", "charge (no timeout)", "slow", { cls: "hurt" }]], hurt: ["w"] },
        after: { b: ["q", ["w", { sub: "gives up after 2 s" }], "psp"],
          e: [["q", "w", "jobs", "ok"], ["w", "psp", "charge, 2 s timeout", "slow"]], changed: ["w"] },
        cap: ["Every worker thread waits on the partner, so the queue grows while the workers do nothing.",
              "Give every call a **timeout**: a slow partner now costs at most 2 s per job.",
              "Threads come back after 2 s. But every job still pays those 2 s while the partner is down."],
        cause: "A call without a timeout lets someone else decide how long our threads are blocked.",
        g1: [G("Busy worker threads", 8, 8, { thr: 8, text: "8 of 8", st: "bad", tag: "model", note: "all waiting" })],
        diff: [["chg", "`timeout: 2000` on the partner client", [S + "pspClient.ts", 5]]],
        g3: [G("Worst time per job", 2000, 30000, { log: 10, text: "30 s → 2 s", st: "good", tag: "calculated" })],
        next: "While the partner is down, every job still waits the full 2 s before failing.",
        options: [["yes", "A timeout per call", "cheap and bounded"], ["no", "More threads", "they all wait too"]],
        lab: { cfg: "Lab · partner hangs", steps: ["Start **Lab · partner hangs**.", "`node docs/explorer/tools/lab-kit.mjs burst --url http://localhost:3000/orders --n 20`. **Check:** answers within ~2 s."] },
        bp: [S + "pspClient.ts", 5, "Watch the timeout fire."],
      },
      {
        id: "L1", name: "Circuit breaker", q: "The partner is down for minutes. Why keep calling it?",
        widget: { name: "circuit-breaker", args: { window: 10, minCalls: 5, openSeconds: 30, trials: 2, failMs: 2000 } },
        before: { b: ["q", ["w", { sub: "every job waits 2 s" }], "psp"],
          e: [["q", "w", "jobs", "heavy"], ["w", "psp", "charge → timeout", "slow", { cls: "hurt" }]], hurt: ["w"] },
        after: { b: ["q", "w", "cb", "psp"],
          e: [["q", "w", "jobs", "ok"], ["w", "cb", "charge", "ok"], ["cb", "psp", "only while closed", "ok"], ["cb", "w", "fail fast", "reject", { off: 9 }]] },
        cap: ["The partner has been down for 3 minutes; each job still spends 2 s finding out.",
              "Put a **circuit breaker** in front of the call: after enough failures it stops calling and fails at once.",
              "Failing jobs fail in milliseconds; a trial call every 30 s finds out when the partner is back."],
        g1: [G("Time per failing job", 2000, 2500, { text: "2,000 ms", st: "bad", tag: "calculated" })],
        diff: [["add", "Breaker around the partner call", [S + "ChargeWorker.ts", 31]]],
        g3: [G("Time per failing job", 5, 2500, { log: 1, text: "2,000 → ~5 ms", st: "good", tag: "model" })],
        next: "Fast failure is still failure: the customer's order is `FAILED`.",
        bp: [S + "ChargeWorker.ts", 31, "Watch `breaker.state` change after the fifth failure."],
        tests: [[T + "ChargeWorker.test.ts", 40, "opensAfterFiveFailures"]],
      },
      {
        id: "L2", name: "Retry later instead of failing", proposed: true, q: "Can the order wait instead of failing?",
        before: { b: ["q", "w", "cb", "psp"], e: [["q", "w", "jobs", "ok"], ["w", "cb", "charge", "ok"], ["cb", "w", "fail fast → FAILED", "reject", { off: 9, cls: "hurt" }]], hurt: ["w"] },
        after: { b: ["q", ["w", { sub: "re-enqueues with a delay" }], "cb", "psp"],
          e: [["q", "w", "jobs", "ok"], ["w", "cb", "charge", "ok"], ["w", "q", "retry in 1 min", "slow", { off: 9 }]], changed: ["w"] },
        cap: ["Every job that meets an open breaker fails the order.", "Re-enqueue the job with a delay while the breaker is open.", "Orders wait a few minutes instead of failing."],
        g3: [G("Orders failed by a 5-minute outage", 0, 100, { text: "all → none (expected)", st: "good", tag: "model" })],
        next: "A long outage now builds a backlog: the drain rate after recovery matters.",
      },
    ],
    recap: {
      pattern: "Bound the wait (timeout), stop paying for known failures (breaker), then decide what failure means for the user (retry later, fallback).",
      elsewhere: [["A search page", "a slow recommendations call gets a timeout and an empty fallback"]],
      say: "Timeouts bound each call, the breaker bounds the cost of an outage, and the fallback is a product decision.",
      undo: ["If the partner offers webhooks, polling with retries goes away"],
    },
  }],
};
