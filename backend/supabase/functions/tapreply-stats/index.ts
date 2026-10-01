// TapReply — Edge Function `tapreply-stats` : tableau de bord PRIVÉ de Pierre.
// Accès : https://<projet>.supabase.co/functions/v1/tapreply-stats?k=<jeton>  (jeton stocké dans tapreply_admin).
// Lecture seule. Données : événements d'usage anonymes (tapreply_events) + compteur serveur (tapreply_usage).
// Aucun contenu de conversation n'existe dans ces tables.

const SB_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SB_SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

async function sb(path: string, init: RequestInit = {}): Promise<Response> {
  return await fetch(`${SB_URL}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: SB_SERVICE, Authorization: `Bearer ${SB_SERVICE}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
    signal: AbortSignal.timeout(8000),
  });
}

const STEPS: Array<[string, string]> = [
  ["lamp", "Lampe"], ["hello", "Coucou"], ["situation", "Ça t'arrive ?"], ["phone", "iPhone géant"],
  ["demo", "Démo"], ["tryIt", "À toi d'essayer"], ["draft", "Brouillon"], ["name", "Prénom"], ["color", "Couleur"],
  ["privacy", "Consentement IA"], ["setupIntro", "Réglage : intro"], ["setupShortcut", "Raccourci"],
  ["setupBackTap", "Back Tap"], ["permissions", "Toujours autoriser"], ["notifications", "Notifications"],
  ["reward", "Prêt"], ["paywall", "Paywall"],
];

const esc = (s: unknown) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));
const pct = (a: number, b: number) => (b > 0 ? Math.round((a / b) * 100) : 0);

// deno-lint-ignore no-explicit-any
function page(d: any, days: number, k: string): string {
  const funnel = d.onb_funnel ?? {};
  const base = Math.max(1, Number(funnel.lamp ?? 0), ...Object.values(funnel).map(Number));
  const rows = STEPS.map(([key, label], i) => {
    const n = Number(funnel[key] ?? 0);
    const prev = i === 0 ? n : Number(funnel[STEPS[i - 1][0]] ?? 0);
    const drop = i > 0 && prev > 0 ? 100 - pct(n, prev) : 0;
    const skips = Number((d.onb_skips ?? {})[key] ?? 0);
    return `<tr><td class="lbl">${i + 1}. ${esc(label)}</td>
      <td class="barcell"><div class="bar" style="width:${Math.max(2, pct(n, base))}%"></div></td>
      <td class="num">${n}</td>
      <td class="num ${drop >= 25 ? "bad" : "muted"}">${i > 0 ? `−${drop} %` : ""}</td>
      <td class="num muted">${skips ? `${skips} passé${skips > 1 ? "s" : ""}` : ""}</td></tr>`;
  }).join("");
  const done = Number(d.onb_done ?? 0);
  const started = Number(funnel.lamp ?? 0);
  const daily = (d.daily ?? []) as Array<{ day: string; active: number; gens: number }>;
  const maxG = Math.max(1, ...daily.map((x) => Number(x.gens)), ...daily.map((x) => Number(x.active)));
  const spark = daily.map((x) => `<div class="col" title="${esc(x.day)} : ${x.active} actifs, ${x.gens} réponses">
      <div class="g" style="height:${pct(Number(x.gens), maxG)}%"></div><div class="a" style="height:${pct(Number(x.active), maxG)}%"></div></div>`).join("");
  const kv = (o: Record<string, number>) => Object.entries(o ?? {}).sort((a, b) => Number(b[1]) - Number(a[1]))
    .map(([k2, v]) => `<span class="chip">${esc(k2)} <b>${v}</b></span>`).join("") || `<span class="muted">rien pour l'instant</span>`;
  const pw = d.paywall ?? {};
  const s = d.setup ?? {};
  const buys = Object.values(pw.purchase_ok ?? {}).reduce((a: number, b) => a + Number(b), 0);
  const tab = (n: number) => `<a class="${n === days ? "on" : ""}" href="?k=${encodeURIComponent(k)}&d=${n}">${n} j</a>`;
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>TapReply · Statistiques</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
:root{--ink:#16151f;--sub:#6b6a7b;--line:#ecebf2;--acc:#5b4bff;--soft:#f6f6fa;--bad:#e5484d;--ok:#18a058}
*{box-sizing:border-box}body{margin:0;font-family:Inter,system-ui,sans-serif;color:var(--ink);background:#fff;-webkit-font-smoothing:antialiased}
.wrap{max-width:1040px;margin:0 auto;padding:28px 24px 60px}
header{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}
h1{font-size:24px;margin:0;letter-spacing:-.02em}h1 span{color:var(--acc)}
.tabs a{margin-left:6px;padding:6px 12px;border-radius:999px;border:1px solid var(--line);color:var(--sub);text-decoration:none;font-weight:600;font-size:13px}
.tabs a.on{background:var(--ink);color:#fff;border-color:var(--ink)}
.note{color:var(--sub);font-size:13px;margin:6px 0 22px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-bottom:26px}
.card{border:1px solid var(--line);border-radius:14px;padding:16px}
.card .k{color:var(--sub);font-size:12.5px;font-weight:600}.card .v{font-size:28px;font-weight:700;letter-spacing:-.02em;margin-top:4px}
.card .s{color:var(--sub);font-size:12.5px;margin-top:2px}
h2{font-size:16px;margin:28px 0 10px}
table{width:100%;border-collapse:collapse;font-size:14px}td{padding:7px 6px;border-bottom:1px solid var(--line)}
.lbl{width:190px;white-space:nowrap}.barcell{width:50%}.bar{height:14px;border-radius:7px;background:var(--acc)}
.num{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}.muted{color:var(--sub)}.bad{color:var(--bad);font-weight:600}
.spark{display:flex;align-items:flex-end;gap:3px;height:120px;border-bottom:1px solid var(--line);padding-top:6px}
.col{flex:1;height:100%;display:flex;align-items:flex-end;gap:1px}.col .g{flex:1;background:var(--acc);border-radius:3px 3px 0 0}.col .a{flex:1;background:#c9c3ff;border-radius:3px 3px 0 0}
.legend{font-size:12.5px;color:var(--sub);margin-top:6px}.legend i{display:inline-block;width:10px;height:10px;border-radius:2px;margin:0 4px 0 12px;vertical-align:-1px}
.chip{display:inline-block;background:var(--soft);border:1px solid var(--line);border-radius:999px;padding:4px 10px;margin:0 6px 6px 0;font-size:13px}
.two{display:grid;grid-template-columns:1fr 1fr;gap:18px}@media(max-width:760px){.two{grid-template-columns:1fr}.lbl{width:auto}}
</style></head><body><div class="wrap">
<header><h1>Tap<span>Reply</span> · statistiques</h1><div class="tabs">${tab(1)}${tab(7)}${tab(28)}${tab(90)}</div></header>
<p class="note">Personnes = identifiants anonymes (un par installation). Aucune donnée de conversation. Les versions antérieures au build 30 n'envoient pas d'événements : seul le compteur serveur (réponses générées) les voit.</p>
<div class="grid">
 <div class="card"><div class="k">Personnes actives</div><div class="v">${d.users_active ?? 0}</div><div class="s">ont ouvert l'app</div></div>
 <div class="card"><div class="k">Nouveaux (onboarding commencé)</div><div class="v">${started}</div><div class="s">${done} l'ont terminé (${pct(done, started)} %)</div></div>
 <div class="card"><div class="k">Réponses générées (serveur)</div><div class="v">${d.server_generations ?? 0}</div><div class="s">${d.server_users ?? 0} personnes</div></div>
 <div class="card"><div class="k">Ont eu une 1re réponse</div><div class="v">${d.first_reply_users ?? 0}</div><div class="s">depuis le build 30</div></div>
 <div class="card"><div class="k">Achats</div><div class="v">${buys}</div><div class="s">${pw.viewers ?? 0} ont vu le paywall (${pw.views ?? 0} fois)</div></div>
 <div class="card"><div class="k">Consentement IA</div><div class="v">${d.consent_ok ?? 0} <span style="font-size:15px;color:var(--sub)">/ ${Number(d.consent_ok ?? 0) + Number(d.consent_no ?? 0)}</span></div><div class="s">${d.consent_no ?? 0} refus · ${d.consent_revoked ?? 0} retraits</div></div>
</div>
<h2>Onboarding : où ça décroche</h2>
<table>${rows}</table>
<p class="note">« −X % » = part des personnes perdues depuis l'écran précédent (en rouge au-delà de 25 %). ${d.onb_backs ?? 0} retours en arrière sur la période.</p>
<h2>Activité par jour</h2>
<div class="spark">${spark}</div>
<div class="legend"><i style="background:var(--acc)"></i>réponses générées <i style="background:#c9c3ff"></i>personnes actives</div>
<div class="two">
 <div><h2>Réglage du geste</h2>
  <table>
   <tr><td>Raccourci ajouté</td><td class="num">${s.shortcut_ok ?? 0}</td><td class="num muted">${s.shortcut_later ?? 0} « plus tard »</td></tr>
   <tr><td>Back Tap réglé</td><td class="num">${s.backtap_ok ?? 0}</td><td class="num muted">${s.backtap_later ?? 0} « plus tard »</td></tr>
   <tr><td>Notifications acceptées</td><td class="num">${s.notif_yes ?? 0}</td><td class="num muted">${s.notif_no ?? 0} refus</td></tr>
  </table></div>
 <div><h2>Paywall</h2>
  <table>
   <tr><td>Affichages</td><td class="num">${pw.views ?? 0}</td></tr>
   <tr><td>Fermé sans acheter</td><td class="num">${pw.closes ?? 0}</td></tr>
   <tr><td>Achat commencé</td><td class="num">${pw.purchase_start ?? 0}</td></tr>
   <tr><td>Achat réussi</td><td class="num">${buys}</td></tr>
   <tr><td>Achat échoué / annulé</td><td class="num">${pw.purchase_fail ?? 0}</td></tr>
   <tr><td>Restaurations</td><td class="num">${pw.restore ?? 0}</td></tr>
  </table></div>
</div>
<h2>Réponses : déclencheur, ton, échecs</h2>
<p><b>Déclencheur :</b> ${kv(d.replies_by_trigger)}</p>
<p><b>Ton :</b> ${kv(d.tones)}</p>
<p><b>Échecs :</b> ${kv(d.replies_fail)}</p>
<p><b>Achats par offre :</b> ${kv(pw.purchase_ok)}</p>
<p><b>Versions de l'app :</b> ${kv(d.versions)}</p>
</div></body></html>`;
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};
const RC_SECRET = Deno.env.get("RC_SECRET_API_KEY") ?? "";
const RC_PROJECT = Deno.env.get("RC_PROJECT_ID") ?? "";
const ID_RE = /^\$RCAnonymousID:[0-9a-f]{32}$/;

/** GESTE COMMERCIAL : Pierre offre N crédits à un utilisateur (identifiant copié depuis Réglages › Identifiant
 *  anonyme, ou reçu dans l'e-mail de support). Transaction RevenueCat +N, tracée dans tapreply_events. */
async function gift(body: { appUserId?: string; amount?: number; reason?: string }): Promise<Response> {
  const uid = String(body.appUserId ?? "").trim();
  const amount = Math.floor(Number(body.amount ?? 0));
  const json = (status: number, o: unknown) =>
    new Response(JSON.stringify(o), { status, headers: { ...CORS, "Content-Type": "application/json" } });
  if (!ID_RE.test(uid)) return json(400, { error: "Identifiant invalide (il commence par $RCAnonymousID:)" });
  if (!(amount >= 1 && amount <= 500)) return json(400, { error: "Nombre de crédits entre 1 et 500" });
  if (!RC_SECRET || !RC_PROJECT) return json(500, { error: "RevenueCat non configuré" });
  const r = await fetch(`https://api.revenuecat.com/v2/projects/${RC_PROJECT}/customers/${encodeURIComponent(uid)}/virtual_currencies/transactions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${RC_SECRET}`, "Content-Type": "application/json" },
    body: JSON.stringify({ adjustments: { RPLY: amount }, reference: `gift:${crypto.randomUUID()}` }),
    signal: AbortSignal.timeout(8000),
  });
  if (r.status === 404) return json(404, { error: "Utilisateur inconnu chez RevenueCat (identifiant mal copié ?)" });
  if (!r.ok) return json(502, { error: `RevenueCat a refusé (${r.status})` });
  const data = await r.json().catch(() => null);
  const balance = data?.items?.find?.((i: { currency_code?: string }) => i?.currency_code === "RPLY")?.balance ?? null;
  await sb("tapreply_events", { method: "POST", body: JSON.stringify([{ app_user_id: uid, name: "admin_gift",
    props: { amount: String(amount), reason: String(body.reason ?? "").slice(0, 40) } }]) }).catch(() => null);
  return json(200, { ok: true, amount, balance });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  const url = new URL(req.url);
  let postBody: Record<string, unknown> | null = null;
  if (req.method === "POST") postBody = await req.json().catch(() => ({}));
  const k = String(postBody?.k ?? url.searchParams.get("k") ?? "");
  const days = Math.min(365, Math.max(1, Number(url.searchParams.get("d") ?? "28") || 28));
  const adm = await sb("tapreply_admin?id=eq.1&select=stats_token");
  const row = adm.ok ? (await adm.json())?.[0] : null;
  if (!row?.stats_token || k.length < 20 || k !== row.stats_token) {
    return new Response(JSON.stringify({ error: "forbidden" }), { status: 403,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } });
  }
  if (postBody && postBody.action === "gift") return await gift(postBody as { appUserId?: string; amount?: number; reason?: string });
  // Recherche d'un utilisateur : solde et activité récente (pour répondre vite à un e-mail de support).
  if (postBody && postBody.action === "lookup") {
    const uid = String(postBody.appUserId ?? "").trim();
    if (!ID_RE.test(uid)) return new Response(JSON.stringify({ error: "Identifiant invalide" }), { status: 400, headers: { ...CORS, "Content-Type": "application/json" } });
    const vc = await fetch(`https://api.revenuecat.com/v2/projects/${RC_PROJECT}/customers/${encodeURIComponent(uid)}/virtual_currencies`, {
      headers: { Authorization: `Bearer ${RC_SECRET}` }, signal: AbortSignal.timeout(8000) });
    const vcj = vc.ok ? await vc.json().catch(() => null) : null;
    const balance = vcj?.items?.find?.((i: { currency_code?: string }) => i?.currency_code === "RPLY")?.balance ?? null;
    const ev = await sb(`rpc/tapreply_user_activity`, { method: "POST", body: JSON.stringify({ p_user: uid }) });
    const activity = ev.ok ? await ev.json().catch(() => null) : null;
    return new Response(JSON.stringify({ balance, known: vc.status !== 404, activity }), { headers: { ...CORS, "Content-Type": "application/json" } });
  }
  const r = await sb("rpc/tapreply_stats", { method: "POST", body: JSON.stringify({ p_days: days }) });
  if (!r.ok) return new Response(`Erreur ${r.status}`, { status: 500 });
  const data = await r.json();
  // JSON (pour la page du tableau de bord publiée ailleurs) : Supabase transforme le HTML servi depuis
  // *.supabase.co en texte brut, on ne sert donc QUE les chiffres ici.
  if (url.searchParams.get("format") !== "html") {
    return new Response(JSON.stringify(data), {
      headers: { ...CORS, "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }
  return new Response(page(data, days, k), {
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store", "X-Robots-Tag": "noindex" },
  });
});
