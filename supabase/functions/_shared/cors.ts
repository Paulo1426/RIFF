/// CORS restringido: la web publicada y localhost (desarrollo). La app móvil
/// no manda cabecera Origin y no pasa por aquí.
const origenesFijos = new Set([
  "https://riff-adivina-la-cancion.web.app",
  "https://riff-adivina-la-cancion.firebaseapp.com",
]);
const origenLocal = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

export function origenPermitido(origen: string | null): boolean {
  return origen !== null &&
    (origenesFijos.has(origen) || origenLocal.test(origen));
}

export function corsHeaders(origen: string | null): Record<string, string> {
  return {
    ...(origenPermitido(origen)
      ? { "Access-Control-Allow-Origin": origen! }
      : {}),
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-firebase-appcheck",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "600",
    Vary: "Origin",
  };
}

/// Preflight (OPTIONS) o rechazo de un Origin no permitido; null si la
/// petición puede seguir.
export function respuestaCorsPrevia(request: Request): Response | null {
  const origen = request.headers.get("Origin");
  if (origen !== null && !origenPermitido(origen)) {
    return new Response(JSON.stringify({ error: "Origen no permitido" }), {
      status: 403,
      headers: { "Content-Type": "application/json", Vary: "Origin" },
    });
  }
  return request.method === "OPTIONS"
    ? new Response(null, { status: 204, headers: corsHeaders(origen) })
    : null;
}

/// Añade las cabeceras CORS a una respuesta ya construida.
export function conCors(request: Request, respuesta: Response): Response {
  for (
    const [clave, valor] of Object.entries(
      corsHeaders(request.headers.get("Origin")),
    )
  ) respuesta.headers.set(clave, valor);
  return respuesta;
}
