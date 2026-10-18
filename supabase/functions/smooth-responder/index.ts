// DriveBond — push notifications through Firebase (D-119).
//
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

  let list: { friend_id: string; push_token: string; from_name: string }[];
  if (body.kind === "test") {
    // The test button: my own phones only.
    const { data, error } = await admin.from("push_tokens").select("token").eq("user_id", user);
    if (error) return json({ error: "no_server" }, 500);
    list = (data ?? []).map((r: { token: string }) => ({ friend_id: user!, push_token: r.token, from_name: "" }));
    if (list.length === 0) return json({ sent: 0, error: "no_token" });
  } else {
    const { data: targets, error } = await admin.rpc("trip_push_claim", { p_user: user });
    if (error) return json({ error: "claim" }, 500);
    list = (targets ?? []) as typeof list;
  }
  if (list.length === 0) return json({ sent: 0 });

  const sa = JSON.parse(saText);
  const access = await googleToken(sa);
  let sent = 0;
  for (const t of list) {
    const r = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${access}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: t.push_token,
            // Data only: the app builds the notification itself (its
            // texts, its "Talk" button).
            data: body.kind === "test"
              ? { type: "test" }
              : { type: "trip", from: user, name: t.from_name ?? "" },
            android: { priority: "HIGH", ttl: "1800s" },
          },
        }),
      },
    );
    if (r.ok) {
      sent++;
    } else if (r.status === 404 || r.status === 400) {
      // The phone uninstalled the app or the token changed.
      await admin.rpc("drop_push_token", { p_token: t.push_token });
    }
  }
  return json({ sent });
});
