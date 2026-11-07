import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  conCors,
  corsHeaders,
  origenPermitido,
  respuestaCorsPrevia,
} from "./cors.ts";

Deno.test("origenes permitidos y rechazados", () => {
  for (
    const ok of [
      "https://riff-adivina-la-cancion.web.app",
      "https://riff-adivina-la-cancion.firebaseapp.com",
      "http://localhost:5000",
      "http://127.0.0.1:8080",
      "http://localhost",
    ]
  ) assert(origenPermitido(ok), ok);
  for (
    const mal of [
      null,
      "https://evil.com",
      "https://localhost:5000",
      "http://localhost.evil.com",
      "http://localhost:80@evil.com",
      "https://riff-adivina-la-cancion.web.app.evil.com",
    ]
  ) assert(!origenPermitido(mal), String(mal));
});

Deno.test("cabeceras: refleja origen, Vary y appcheck", () => {
  const h = corsHeaders("http://localhost:3000");
  assertEquals(h["Access-Control-Allow-Origin"], "http://localhost:3000");
  assertEquals(h.Vary, "Origin");
  assert(h["Access-Control-Allow-Headers"].includes("x-firebase-appcheck"));
  assertEquals(corsHeaders(null)["Access-Control-Allow-Origin"], undefined);
  assertEquals(
    corsHeaders("https://evil.com")["Access-Control-Allow-Origin"],
    undefined,
  );
});

Deno.test("preflight, origen ajeno y peticion sin Origin", () => {
  const pre = respuestaCorsPrevia(
    new Request("http://x/", {
      method: "OPTIONS",
      headers: { Origin: "https://riff-adivina-la-cancion.web.app" },
    }),
  )!;
  assertEquals(pre.status, 204);
  assertEquals(
    pre.headers.get("Access-Control-Allow-Origin"),
    "https://riff-adivina-la-cancion.web.app",
  );
  const ajeno = respuestaCorsPrevia(
    new Request("http://x/", {
      method: "POST",
      headers: { Origin: "https://evil.com" },
    }),
  )!;
  assertEquals(ajeno.status, 403);
  assertEquals(
    respuestaCorsPrevia(new Request("http://x/", { method: "POST" })),
    null,
  );
  const res = conCors(
    new Request("http://x/", { method: "POST" }),
    new Response("{}"),
  );
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), null);
  assertEquals(res.headers.get("Vary"), "Origin");
});
