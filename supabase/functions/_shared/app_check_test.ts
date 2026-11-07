import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createLocalJWKSet,
  exportJWK,
  generateKeyPair,
  SignJWT,
} from "https://esm.sh/jose@5.9.6";
import { appCheckPermite, tokenAppCheckValido } from "./app_check.ts";

const numero = "655179331422";
const { publicKey, privateKey } = await generateKeyPair("RS256");
const { privateKey: otraClave } = await generateKeyPair("RS256");
const keys = createLocalJWKSet({
  keys: [{ ...(await exportJWK(publicKey)), kid: "k1", alg: "RS256" }],
});

function firmar(
  { iss = `https://firebaseappcheck.googleapis.com/${numero}`, aud = [
    `projects/${numero}`,
    "projects/riff",
  ], clave = privateKey, exp = "1h" } = {},
) {
  return new SignJWT({})
    .setProtectedHeader({ alg: "RS256", kid: "k1" })
    .setIssuer(iss)
    .setAudience(aud)
    .setSubject("1:655179331422:android:abc")
    .setExpirationTime(exp)
    .sign(clave);
}

Deno.test("acepta un token bien firmado y rechaza el resto", async () => {
  const opciones = { keys, projectNumber: numero };
  assertEquals(await tokenAppCheckValido(await firmar(), opciones), true);
  assertEquals(await tokenAppCheckValido(null, opciones), false);
  assertEquals(await tokenAppCheckValido("basura", opciones), false);
  assertEquals(
    await tokenAppCheckValido(await firmar({ clave: otraClave }), opciones),
    false,
  );
  assertEquals(
    await tokenAppCheckValido(
      await firmar({ iss: "https://firebaseappcheck.googleapis.com/1" }),
      opciones,
    ),
    false,
  );
  assertEquals(
    await tokenAppCheckValido(
      await firmar({ aud: ["projects/otro"] }),
      opciones,
    ),
    false,
  );
});

Deno.test("enforce rechaza sin token; monitor deja pasar", async () => {
  const sin = new Request("http://x/", { method: "POST" });
  assertEquals(
    await appCheckPermite(sin, { keys, projectNumber: numero, enforce: true }),
    false,
  );
  assertEquals(
    await appCheckPermite(sin, { keys, projectNumber: numero, enforce: false }),
    true,
  );
  const con = new Request("http://x/", {
    method: "POST",
    headers: { "X-Firebase-AppCheck": await firmar() },
  });
  assertEquals(
    await appCheckPermite(con, { keys, projectNumber: numero, enforce: true }),
    true,
  );
});
