import {
  createRemoteJWKSet,
  type JWTVerifyGetKey,
  jwtVerify,
} from "https://esm.sh/jose@5.9.6";

// Claves públicas de App Check; createRemoteJWKSet las cachea.
const jwksApp = createRemoteJWKSet(
  new URL("https://firebaseappcheck.googleapis.com/v1/jwks"),
);

export interface OpcionesAppCheck {
  enforce?: boolean;
  projectNumber?: string;
  keys?: JWTVerifyGetKey;
}

const numeroProyectoPorDefecto = "655179331422";

/// Verifica el token de App Check (cabecera X-Firebase-AppCheck): firma,
/// emisor y audiencia del proyecto.
export async function tokenAppCheckValido(
  token: string | null,
  opciones: OpcionesAppCheck = {},
): Promise<boolean> {
  if (!token) return false;
  const numero = opciones.projectNumber ??
    (Deno.env.get("FIREBASE_PROJECT_NUMBER") || numeroProyectoPorDefecto);
  try {
    await jwtVerify(token, opciones.keys ?? jwksApp, {
      issuer: `https://firebaseappcheck.googleapis.com/${numero}`,
      audience: `projects/${numero}`,
      algorithms: ["RS256"],
    });
    return true;
  } catch (error) {
    console.warn("App Check: token no válido", (error as Error).message);
    return false;
  }
}

/// true si la petición puede seguir. Con APPCHECK_ENFORCE="true" exige un
/// token válido; si no, solo avisa en el log (modo monitor).
export async function appCheckPermite(
  request: Request,
  opciones: OpcionesAppCheck = {},
): Promise<boolean> {
  const enforce = opciones.enforce ??
    (Deno.env.get("APPCHECK_ENFORCE") === "true");
  const token = request.headers.get("X-Firebase-AppCheck");
  if (await tokenAppCheckValido(token, opciones)) return true;
  if (enforce) return false;
  console.warn(
    token ? "App Check (monitor): token inválido" : "App Check (monitor): sin token",
  );
  return true;
}
