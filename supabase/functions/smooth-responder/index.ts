// DriveBond — push notifications through Firebase (D-119).
//
// POST { "kind": "flush" }: send whatever the database queued (questions,
// agreed calls, owner notes) — any phone asks right after its own action;
// each queued note goes out once, so asking twice does no harm.
// POST { "kind": "version" }: a new build is out (CI calls it after Google
// Play took it); the build number is read from the public version.json.
// POST { "kind": "trip" } with the user's sign-in token, or
// POST { "kind": "test" } (a test notification to my own phones), or
// POST { "kind": "trip", "device_token": "…" } from the phone's background
// service. The database decides who is told (trip_push_claim); this only
// delivers. Secrets (never in git): FCM_SERVICE_ACCOUNT (the Firebase
// service account JSON), plus Supabase's own SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY, which every Edge Function has.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function b64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = "";
  for (const b of raw) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** A Google access token for Firebase Cloud Messaging (signed JWT). */
export async function googleToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claims}`)),
  );
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${head}.${claims}.${b64url(sig)}`,
    }),
  });
  if (!r.ok) throw new Error(`google token ${r.status}`);
  return (await r.json()).access_token;
}

/** The public file the build publishes next to the APK ({"build": N}). */
const VERSION_URL =
  "https://github.com/fenetnet/Drivetalk/releases/download/prototype/version.json";

/** [ref]: the outbox row it came from (to retry it if delivery failed). */
type Note = { push_token: string; data: Record<string, string>; ref?: number };

/** Sends [notes] through Firebase; tokens Firebase says are gone are dropped.
 * [retry]: outbox rows that reached no phone because of a passing problem
 * (Google sign-in, Firebase busy, network) — to be sent again. */
async function deliver(
  admin: ReturnType<typeof createClient>,
  saText: string,
  notes: Note[],
): Promise<{ sent: number; lastError: string; retry: number[] }> {
  if (notes.length === 0) return { sent: 0, lastError: "", retry: [] };
  const refs = (ns: Note[]) => [...new Set(ns.flatMap((n) => (n.ref == null ? [] : [n.ref])))];
  // deno-lint-ignore no-explicit-any
  let sa: any;
  let access: string;
  try {
    sa = JSON.parse(saText);
    access = await googleToken(sa);
  } catch (e) {
    console.error("push: no Google access", String(e));
    return { sent: 0, lastError: "google_auth", retry: refs(notes) };
  }
  let sent = 0;
  let lastError = "";
  const reached = new Set<number>();
  const passing: Note[] = [];
  for (const n of notes) {
    let r: Response;
    try {
      r = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${access}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            message: {
              token: n.push_token,
              // Data only: the app builds the notification itself (its
              // texts, its buttons).
              data: n.data,
              android: { priority: "HIGH", ttl: "1800s" },
            },
          }),
        },
      );
    } catch (e) {
      console.error("push: network", String(e));
      lastError = "network";
      passing.push(n);
      continue;
    }
    if (r.ok) {
      sent++;
      if (n.ref != null) reached.add(n.ref);
      continue;
    }
    const why = await r.text();
    console.error("push: Firebase answered", r.status, why);
    lastError = `firebase_${r.status}`;
    if (r.status === 404 || why.includes("UNREGISTERED")) {
      // The phone uninstalled the app or the token changed.
      await admin.rpc("drop_push_token", { p_token: n.push_token });
    } else if (r.status === 429 || r.status >= 500) {
      passing.push(n);
    }
  }
  // Retry a row only if none of its phones got it (no doubles).
  return { sent, lastError, retry: refs(passing).filter((id) => !reached.has(id)) };
}

/** Firebase data values must be strings. */
function strings(o: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(o)) out[k] = v == null ? "" : String(v);
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const saText = Deno.env.get("FCM_SERVICE_ACCOUNT");
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!saText || !url || !serviceKey) return json({ error: "not_configured" }, 503);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

  let body: { kind?: string; device_token?: string } = {};
  try {
    body = await req.json();
  } catch {
    // empty body
  }

  // Anyone may ask: only what the database already queued goes out, once.
  if (body.kind === "flush") {
    const { data, error } = await admin.rpc("push_outbox_claim");
    if (error) {
      console.error("flush: claim failed", error.message);
      return json({ error: "claim" }, 500);
    }
    const rows = (data ?? []) as {
      id: number;
      kind: string;
      data: Record<string, unknown>;
      push_token: string;
    }[];
    const r = await deliver(admin, saText, rows.map((x) => ({
      push_token: x.push_token,
      data: strings({ ...(x.data ?? {}), type: x.kind }),
      ref: x.id,
    })));
    // A passing problem: back in the queue for the next flush (rows older
    // than 10 minutes are dropped by the claim itself).
    if (r.retry.length > 0) {
      const { error: back } = await admin.from("push_outbox").update({ sent_at: null }).in("id", r.retry);
      if (back) console.error("flush: re-queue failed", back.message);
    }
    return json({ sent: r.sent, retry: r.retry.length });
  }

  // A new build: checked against the public version file, once per build.
  if (body.kind === "version") {
    let build = 0;
    try {
      const v = await fetch(VERSION_URL);
      build = Number((await v.json()).build) || 0;
    } catch {
      // unknown: nothing to announce
    }
    if (build <= 0) return json({ sent: 0, error: "no_version" });
    const { data, error } = await admin.rpc("version_push_claim", { p_build: build });
    if (error) {
      console.error("version: claim failed", error.message);
      return json({ error: "claim" }, 500);
    }
    const rows = (data ?? []) as { push_token: string }[];
    const r = await deliver(admin, saText, rows.map((x) => ({
      push_token: x.push_token,
      data: { type: "version", build: String(build) },
    })));
    return json({ sent: r.sent, build });
  }

  if (body.kind !== "trip" && body.kind !== "test") return json({ error: "kind" }, 400);

  // Who is asking: the background service (device token) or the app.
  let user: string | null = null;
  if (typeof body.device_token === "string" && body.device_token.length > 0) {
    const { data } = await admin.rpc("push_user_for_device", { p_token: body.device_token });
    user = typeof data === "string" ? data : null;
  } else {
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (jwt) {
      const { data } = await admin.auth.getUser(jwt);
      user = data.user?.id ?? null;
    }
  }
  if (!user) return json({ error: "not_authenticated" }, 401);

  let notes: Note[];
  if (body.kind === "test") {
    // The test button: my own phones only.
    const { data, error } = await admin.from("push_tokens").select("token").eq("user_id", user);
    if (error) {
      console.error("push test: reading tokens failed", error.message);
      return json({ error: "no_server" }, 500);
    }
    notes = (data ?? []).map((r: { token: string }) => ({ push_token: r.token, data: { type: "test" } }));
    if (notes.length === 0) return json({ sent: 0, error: "no_token" });
  } else {
    const { data: targets, error } = await admin.rpc("trip_push_claim", { p_user: user });
    if (error) {
      console.error("trip push: claim failed", error.message);
      return json({ error: "claim" }, 500);
    }
    notes = ((targets ?? []) as { push_token: string; from_name: string }[]).map((t) => ({
      push_token: t.push_token,
      data: { type: "trip", from: user!, name: t.from_name ?? "" },
    }));
  }
  const r = await deliver(admin, saText, notes);
  // Nothing went through: say why (the test button shows it).
  if (r.sent === 0 && r.lastError) return json({ sent: 0, error: r.lastError });
  return json({ sent: r.sent });
});
