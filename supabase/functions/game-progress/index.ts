import { createRemoteJWKSet, jwtVerify } from "https://esm.sh/jose@5.9.6";
import {
  canPurchaseInstrument,
  maxPurchasedInstruments,
  selectMelodyInstrument,
  selectNextInstrumentPrice,
} from "./pricing.ts";
import {
  canonicalDifficulty,
  levelsPerDifficulty,
  type PublishedLevel,
  selectDifficultyLevels,
} from "./level_selection.ts";
import {
  codigoValido,
  duracionContrarrelojMs,
  eliminadoDeRonda,
  generarCodigo,
  maxJugadoresSala,
  type ModoSala,
  modosSala,
  nivelDeIndice,
  precioCrearSalaIntros,
  precioEntrarSalaIntros,
  estadisticasSala,
  premiosSala,
  puntosAcierto,
  todosListos,
  type TipoSala,
  tiposSala,
} from "./salas.ts";
import {
  coinBalance,
  coinsEarned,
  introCoinRewards,
  introPrice,
} from "./intros.ts";
import { objectVersion } from "../_shared/storage_version.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const firebaseJwks = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);
const difficulties = ["facil", "medio", "avanzado"] as const;
type Difficulty = (typeof difficulties)[number];
type JsonObject = Record<string, unknown>;
const instrumentTypes = new Set([
  "bateria",
  "acordeon",
  "bajo",
  "guitarra",
]);

interface FirestoreDocument {
  name?: string;
  updateTime?: string;
  fields?: Record<string, unknown>;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

let cachedServiceToken: { token: string; expiresAt: number } | undefined;

function response(status: number, data: JsonObject): Response {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new HttpError(500, `Falta configurar ${name}`);
  return value;
}

function fromValue(value: unknown): unknown {
  if (!value || typeof value !== "object") return undefined;
  const field = value as JsonObject;
  if ("stringValue" in field) return field.stringValue;
  if ("booleanValue" in field) return field.booleanValue;
  if ("integerValue" in field) return Number(field.integerValue);
  if ("doubleValue" in field) return Number(field.doubleValue);
  if ("timestampValue" in field) return field.timestampValue;
  if ("nullValue" in field) return null;
  if ("arrayValue" in field) {
    const values = (field.arrayValue as { values?: unknown[] }).values ?? [];
    return values.map(fromValue);
  }
  if ("mapValue" in field) {
    return fromFields(
      (field.mapValue as { fields?: Record<string, unknown> }).fields ?? {},
    );
  }
  return undefined;
}

function fromFields(fields: Record<string, unknown>): JsonObject {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, fromValue(value)]),
  );
}

function normalizeDifficulty(value: unknown): string | undefined {
  return typeof value === "string" ? canonicalDifficulty(value) : undefined;
}

function toValue(value: unknown): JsonObject {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toValue) } };
  }
  if (typeof value === "object") {
    return { mapValue: { fields: toFields(value as JsonObject) } };
  }
  throw new HttpError(500, "Tipo de dato Firestore no soportado");
}

function toFields(value: JsonObject): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(value).map(([key, field]) => [
      key,
      typeof field === "string" &&
        (key === "createdAt" || key === "updatedAt")
        ? { timestampValue: field }
        : toValue(field),
    ]),
  );
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function privateKeyBytes(pem: string): ArrayBuffer {
  const encoded = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const bytes = Uint8Array.from(atob(encoded), (char) => char.charCodeAt(0));
  const buffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(buffer).set(bytes);
  return buffer;
}

async function firestoreToken(): Promise<string> {
  if (
    cachedServiceToken && cachedServiceToken.expiresAt > Date.now() + 60_000
  ) {
    return cachedServiceToken.token;
  }
  let account: ServiceAccount;
  try {
    account = JSON.parse(
      requiredEnv("FIREBASE_SERVICE_ACCOUNT_JSON"),
    ) as ServiceAccount;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(500, "La cuenta de servicio no es JSON válido");
  }
  if (
    account.project_id !== projectId || !account.client_email ||
    !account.private_key
  ) {
    throw new HttpError(500, "La cuenta de servicio no coincide con Firebase");
  }

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(
    new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })),
  );
  const claims = base64Url(
    new TextEncoder().encode(
      JSON.stringify({
        iss: account.client_email,
        scope: "https://www.googleapis.com/auth/datastore",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }),
    ),
  );
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!tokenResponse.ok) {
    console.error(
      "Firebase service token exchange failed",
      tokenResponse.status,
    );
    throw new HttpError(502, "No se pudo autenticar con Firestore");
  }
  const tokenData = await tokenResponse.json() as {
    access_token?: string;
    expires_in?: number;
  };
  if (!tokenData.access_token) {
    throw new HttpError(502, "Firebase no devolvió un token de servicio");
  }
  cachedServiceToken = {
    token: tokenData.access_token,
    expiresAt: Date.now() + (tokenData.expires_in ?? 3600) * 1000,
  };
  return tokenData.access_token;
}

function documentName(path: string): string {
  const encoded = path.split("/").map(encodeURIComponent).join("/");
  return `projects/${
    encodeURIComponent(projectId)
  }/databases/(default)/documents/${encoded}`;
}

function documentUrl(path: string): string {
  return `https://firestore.googleapis.com/v1/${documentName(path)}`;
}

async function getDocument(
  token: string,
  path: string,
): Promise<{ fields: JsonObject; updateTime?: string } | null> {
  const result = await fetch(documentUrl(path), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (result.status === 404) return null;
  if (!result.ok) {
    const details = (await result.text()).slice(0, 2000);
    console.error(
      "Firestore document read failed",
      result.status,
      path,
      details,
    );
    throw new HttpError(502, "No se pudieron consultar los datos del juego");
  }
  const document = await result.json() as FirestoreDocument;
  return {
    fields: fromFields(document.fields ?? {}),
    updateTime: document.updateTime,
  };
}

async function listCollection(
  token: string,
  path: string,
  pageToken?: string,
): Promise<FirestoreDocument[]> {
  const url = new URL(documentUrl(path));
  url.searchParams.set("pageSize", "1000");
  if (pageToken) url.searchParams.set("pageToken", pageToken);
  const result = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!result.ok) {
    const details = (await result.text()).slice(0, 2000);
    console.error(
      "Firestore collection read failed",
      result.status,
      path,
      details,
    );
    throw new HttpError(502, "No se pudieron consultar los niveles");
  }
  const data = await result.json() as {
    documents?: FirestoreDocument[];
    nextPageToken?: string;
  };
  const documents = data.documents ?? [];
  if (data.nextPageToken) {
    documents.push(
      ...await listCollection(token, path, data.nextPageToken),
    );
  }
  return documents;
}

async function commitWrites(
  token: string,
  writes: JsonObject[],
): Promise<void> {
  const result = await fetch(
    `https://firestore.googleapis.com/v1/projects/${
      encodeURIComponent(projectId)
    }/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ writes }),
    },
  );
  if (result.status === 409 || result.status === 412) {
    throw new HttpError(
      409,
      "El progreso cambió en otra solicitud; inténtalo de nuevo",
    );
  }
  if (!result.ok) {
    const details = await result.text();
    if (
      result.status === 400 &&
      /FAILED_PRECONDITION|ALREADY_EXISTS/.test(details)
    ) {
      throw new HttpError(409, "El documento cambió en otra solicitud");
    }
    console.error("Firestore commit failed", result.status, details);
    throw new HttpError(502, "No se pudo guardar el progreso del juego");
  }
}

async function clearDocuments(
  token: string,
  paths: string[],
): Promise<void> {
  for (let index = 0; index < paths.length; index += 450) {
    await commitWrites(
      token,
      paths.slice(index, index + 450).map((name) => ({ delete: name })),
    );
  }
}

async function clearGuestSession(token: string, uid: string): Promise<void> {
  const collections = [
    "games",
    `guestSessions/${uid}/progress`,
    `guestSessions/${uid}/difficultyOrders`,
    `guestSessions/${uid}/introProgress`,
  ];
  for (const collection of collections) {
    const documents = await listCollection(token, collection);
    const paths = documents
      .filter((document) =>
        collection === "games" ? document.fields?.uid === uid : true
      )
      .map((document) => document.name)
      .filter((name): name is string => typeof name === "string");
    await clearDocuments(token, paths);
  }
}

/// Empezar desde cero: borra progreso, orden de niveles, intros, fichas y
/// estadísticas de salas de una cuenta registrada.
async function resetUserProgress(token: string, uid: string): Promise<void> {
  for (const coleccion of [
    "progress",
    "difficultyOrders",
    "introProgress",
    "fichas",
  ]) {
    const documentos = await listCollection(token, `users/${uid}/${coleccion}`);
    await clearDocuments(
      token,
      documentos
        .map((documento) => documento.name)
        .filter((name): name is string => typeof name === "string"),
    );
  }
}

function createWrite(path: string, fields: JsonObject): JsonObject {
  return {
    update: { name: documentName(path), fields: toFields(fields) },
    currentDocument: { exists: false },
  };
}

function updateWrite(
  path: string,
  fields: JsonObject,
  updateTime: string,
): JsonObject {
  const fieldPaths = Object.keys(fields);
  return {
    update: { name: documentName(path), fields: toFields(fields) },
    updateMask: { fieldPaths },
    currentDocument: { updateTime },
  };
}

function validId(value: unknown): value is string {
  return typeof value === "string" &&
    /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

function normalizeAnswer(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function shuffled<T>(items: T[]): T[] {
  const result = [...items];
  for (let index = result.length - 1; index > 0; index--) {
    const random = new Uint32Array(1);
    crypto.getRandomValues(random);
    const other = random[0] % (index + 1);
    [result[index], result[other]] = [result[other], result[index]];
  }
  return result;
}

function userPath(
  uid: string,
  collection: string,
  difficulty: Difficulty,
  guest = false,
) {
  const root = guest ? `guestSessions/${uid}` : `users/${uid}`;
  return `${root}/${collection}/${difficulty}`;
}

async function publishedLevels(token: string): Promise<PublishedLevel[]> {
  const documents = await listCollection(token, "levels");
  return documents.map((document) => {
    const fields = fromFields(document.fields ?? {});
    return {
      id: document.name?.split("/").at(-1) ?? "",
      numero: typeof fields.numero === "number" ? fields.numero : Number.NaN,
      dificultad: normalizeDifficulty(fields.dificultad) ?? "",
      published: fields.published === true,
    };
  });
}

async function ensureOrder(
  token: string,
  uid: string,
  difficulty: Difficulty,
  guest = false,
): Promise<string[]> {
  const path = userPath(uid, "difficultyOrders", difficulty, guest);
  const existing = await getDocument(token, path);
  const levels = selectDifficultyLevels(
    await publishedLevels(token),
    difficulty,
  ).map((level) => level.id);
  if (existing) {
    const rawOrder = existing.fields.levelIds;
    if (
      !Array.isArray(rawOrder) ||
      !rawOrder.every((id) => typeof id === "string")
    ) {
      throw new HttpError(500, "El orden guardado tiene un formato inválido");
    }
    const availableIds = new Set(levels);
    const currentOrder = [...new Set(rawOrder as string[])].filter((id) =>
      availableIds.has(id)
    );
    const additions = shuffled(
      levels.filter((id) => !currentOrder.includes(id)),
    );
    if (
      additions.length === 0 &&
      currentOrder.length === rawOrder.length
    ) return currentOrder;
    if (!existing.updateTime) {
      throw new HttpError(
        500,
        "No se pudo validar la versión del orden guardado",
      );
    }
    const extendedOrder = [...currentOrder, ...additions];
    try {
      await commitWrites(token, [
        updateWrite(
          path,
          { levelIds: extendedOrder, updatedAt: new Date().toISOString() },
          existing.updateTime,
        ),
      ]);
      return extendedOrder;
    } catch (error) {
      if (!(error instanceof HttpError) || error.status !== 409) throw error;
      const latest = await getDocument(token, path);
      const latestIds = latest?.fields.levelIds;
      if (
        !Array.isArray(latestIds) ||
        !latestIds.every((id) => typeof id === "string")
      ) {
        throw error;
      }
      return (latestIds as string[]).filter((id) => levels.includes(id));
    }
  }
  if (levels.length === 0) {
    return [];
  }

  const levelIds = shuffled(levels);
  try {
    await commitWrites(token, [
      createWrite(path, {
        levelIds,
        createdAt: new Date().toISOString(),
      }),
    ]);
    return levelIds;
  } catch (error) {
    if (!(error instanceof HttpError) || error.status !== 409) throw error;
    const concurrentOrder = await getDocument(token, path);
    const ids = concurrentOrder?.fields.levelIds;
    if (!Array.isArray(ids) || !ids.every((id) => typeof id === "string")) {
      throw error;
    }
    return (ids as string[]).filter((id) => levels.includes(id));
  }
}

/// [difficulty] null (salas): acepta el nivel sea cual sea su dificultad.
async function buildLevelEntry(
  token: string,
  id: string,
  difficulty: Difficulty | null,
  completed: Set<string>,
  canStart: boolean,
): Promise<JsonObject> {
  const document = await getDocument(token, `levels/${id}`);
  if (!document || document.fields.published !== true) {
    throw new HttpError(
      409,
      "Un nivel del orden guardado dejó de estar publicado",
    );
  }
  const fields = document.fields;
  const songId = fields.cancionId;
  const levelDifficulty = normalizeDifficulty(fields.dificultad);
  if (
    !validId(songId) ||
    !Number.isInteger(fields.numero) ||
    !difficulties.includes(levelDifficulty as Difficulty) ||
    (difficulty !== null && levelDifficulty !== difficulty)
  ) {
    throw new HttpError(500, `El nivel ${id} tiene metadatos inválidos`);
  }
  const rawInstruments = fields.instrumentos;
  if (!rawInstruments || typeof rawInstruments !== "object") {
    throw new HttpError(500, `El nivel ${id} no tiene instrumentos`);
  }
  const instrumentEntries = Object.entries(rawInstruments as JsonObject);
  const testMode = fields.modoPrueba === true;
  const expectedInstrumentCount = testMode ? 3 : instrumentTypes.size;
  if (instrumentEntries.length !== expectedInstrumentCount) {
    throw new HttpError(
      500,
      testMode
        ? `El nivel de prueba ${id} debe tener tres instrumentos`
        : `El nivel ${id} debe tener cuatro instrumentos`,
    );
  }
  if (
    !instrumentEntries.some(([type]) => type === "acordeon") ||
    !instrumentEntries.some(([type]) => type === "bateria")
  ) {
    throw new HttpError(
      500,
      `El nivel ${id} debe incluir acordeón y batería`,
    );
  }
  const instruments = instrumentEntries.map(([type, value]) => {
    if (!instrumentTypes.has(type)) {
      throw new HttpError(500, `El instrumento ${type} no es válido`);
    }
    if (!value || typeof value !== "object") {
      throw new HttpError(500, `El instrumento ${type} del nivel no es válido`);
    }
    const instrument = value as JsonObject;
    if (
      typeof instrument.storagePath !== "string" ||
      instrument.storagePath.length === 0
    ) {
      throw new HttpError(
        500,
        `El instrumento ${type} del nivel no tiene audio configurado`,
      );
    }
    return { tipo: type, precio: 0, audio_url: "", comprable: true };
  });
  const durationSeconds = fields.duracionFragmentoSegundos ??
    (testMode ? 20 : 30);
  if (durationSeconds !== (testMode ? 20 : 30)) {
    throw new HttpError(
      500,
      testMode
        ? `El nivel de prueba ${id} debe usar fragmentos de 20 segundos`
        : `El nivel ${id} debe usar fragmentos de 30 segundos`,
    );
  }
  return {
    nivel: {
      id,
      numero: fields.numero,
      dificultad: levelDifficulty,
      cancion_id: songId,
      cancion_titulo: "Canción misteriosa",
      instrumentos: instruments,
      puntos_inicio: fields.puntosInicio ?? [],
      modo_prueba: testMode,
      duracion_fragmento_segundos: durationSeconds,
    },
    completado: completed.has(id),
    puede_iniciar: canStart,
  };
}

async function getProgress(
  token: string,
  uid: string,
  guest = false,
): Promise<JsonObject> {
  const summaries: JsonObject[] = [];
  let activeDifficulty: Difficulty = "facil";
  let previousComplete = true;
  let activeOrder: string[] = [];
  let activeCompleted = new Set<string>();
  let stoppedAt: number | null = null;

  for (let index = 0; index < difficulties.length; index++) {
    const difficulty = difficulties[index];
    const unlocked = previousComplete;
    if (!unlocked) {
      summaries.push({
        dificultad: difficulty,
        desbloqueada: false,
        completados: 0,
        total: 0,
      });
      continue;
    }
    const order = await ensureOrder(token, uid, difficulty, guest);
    if (order.length === 0) {
      summaries.push({
        dificultad: difficulty,
        desbloqueada: true,
        completados: 0,
        total: 0,
      });
      activeDifficulty = difficulty;
      activeOrder = [];
      activeCompleted = new Set();
      stoppedAt = index;
      break;
    }
    const progressDoc = await getDocument(
      token,
      userPath(uid, "progress", difficulty, guest),
    );
    const ids = progressDoc?.fields.completedLevelIds;
    const completed = new Set(
      Array.isArray(ids)
        ? ids.filter((id): id is string => typeof id === "string")
        : [],
    );
    const done = order.length === levelsPerDifficulty &&
      order.every((levelId) => completed.has(levelId));
    const unInstrumento = new Set(
      stringList(progressDoc?.fields.unInstrumentoIds),
    );
    summaries.push({
      dificultad: difficulty,
      desbloqueada: true,
      completados: order.filter((id) => completed.has(id)).length,
      total: order.length,
      un_instrumento: order.filter((id) => unInstrumento.has(id)).length,
    });
    if (!done) {
      activeDifficulty = difficulty;
      activeOrder = order;
      activeCompleted = completed;
      previousComplete = false;
      stoppedAt = index;
      break;
    }
    previousComplete = true;
    activeDifficulty = difficulty;
    activeOrder = order;
    activeCompleted = completed;
  }
  if (stoppedAt !== null) {
    for (const difficulty of difficulties.slice(stoppedAt + 1)) {
      summaries.push({
        dificultad: difficulty,
        desbloqueada: false,
        completados: 0,
        total: 0,
      });
    }
  }

  const nextActiveId = activeOrder.find((id) => !activeCompleted.has(id));
  const levelEntries = await Promise.all(
    activeOrder.map((id) =>
      buildLevelEntry(
        token,
        id,
        activeDifficulty,
        activeCompleted,
        activeCompleted.has(id) || id === nextActiveId,
      )
    ),
  );
  const activeIndex = difficulties.indexOf(activeDifficulty);
  const replayEntries: JsonObject[] = [];
  for (const difficulty of difficulties.slice(0, activeIndex)) {
    const order = await ensureOrder(token, uid, difficulty, guest);
    const progress = await getDocument(
      token,
      userPath(uid, "progress", difficulty, guest),
    );
    const ids = progress?.fields.completedLevelIds;
    const completed = new Set(
      Array.isArray(ids)
        ? ids.filter((id): id is string => typeof id === "string")
        : [],
    );
    const completedIds = order.filter((id) => completed.has(id));
    replayEntries.push(
      ...await Promise.all(
        completedIds.map((id) =>
          buildLevelEntry(token, id, difficulty, completed, true)
        ),
      ),
    );
  }
  return {
    dificultades: summaries,
    dificultad_activa: activeDifficulty,
    niveles: levelEntries,
    niveles_repetibles: replayEntries,
  };
}

async function createOfflineAudioUrl(
  path: string,
  bucket = Deno.env.get("SUPABASE_STEMS_BUCKET") ?? "instrumentos",
): Promise<string> {
  const supabaseUrl = requiredEnv("SUPABASE_URL").replace(/\/+$/, "");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const objectPath = path.split("/").map(encodeURIComponent).join("/");
  const result = await fetch(
    `${supabaseUrl}/storage/v1/object/sign/${
      encodeURIComponent(bucket)
    }/${objectPath}`,
    {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ expiresIn: 604800 }),
    },
  );
  if (!result.ok) {
    const details = (await result.text()).slice(0, 1000);
    console.error("Offline audio URL signing failed", result.status, details);
    throw new HttpError(502, "No se pudo preparar la descarga offline de audio");
  }
  const data = await result.json() as {
    signedURL?: string;
    signedUrl?: string;
  };
  const signedUrl = data.signedURL ?? data.signedUrl;
  if (!signedUrl) {
    throw new HttpError(502, "Storage no devolvió la URL de descarga");
  }
  if (/^https?:\/\//i.test(signedUrl)) return signedUrl;
  const pathWithPrefix = signedUrl.startsWith("/storage/v1/")
    ? signedUrl
    : `/storage/v1${signedUrl.startsWith("/") ? signedUrl : `/${signedUrl}`}`;
  return `${supabaseUrl}${pathWithPrefix}`;
}

async function createOfflineBundle(
  token: string,
  uid: string,
  guest: boolean,
): Promise<JsonObject> {
  const state = await getProgress(token, uid, guest);
  const entries = [
    ...(state.niveles as JsonObject[]),
    ...(state.niveles_repetibles as JsonObject[]),
  ];
  const eligible = [...new Map(
    entries
      .filter((entry) => {
        const nivel = entry.nivel as JsonObject;
        return !guest || nivel.dificultad === "facil";
      })
      .map((entry) => {
        const nivel = entry.nivel as JsonObject;
        return [nivel.id as string, entry] as const;
      }),
  ).values()];

  const levels = await Promise.all(eligible.map(async (entry) => {
    const nivel = entry.nivel as JsonObject;
    const levelId = nivel.id as string;
    const [level, answer] = await Promise.all([
      getDocument(token, `levels/${levelId}`),
      getDocument(token, `privateLevelAnswers/${levelId}`),
    ]);
    if (!level || !answer || answer.fields.respuestaCancionNormalizada === undefined) {
      throw new HttpError(404, `Faltan datos offline para ${levelId}`);
    }
    const instruments = level.fields.instrumentos;
    if (!instruments || typeof instruments !== "object") {
      throw new HttpError(500, `El nivel ${levelId} no tiene instrumentos`);
    }
    const songId = nivel.cancion_id;
    if (typeof songId !== "string" || !validId(songId)) {
      throw new HttpError(500, `El nivel ${levelId} no tiene una canción válida`);
    }
    const song = await getDocument(token, `songs/${songId}`);
    const instrumentalPath = song?.fields.instrumentalAudioPath;
    if (
      !song ||
      song.fields.published !== true ||
      typeof instrumentalPath !== "string" ||
      !instrumentalPath
    ) {
      throw new HttpError(404, `Falta la pista instrumental de ${levelId}`);
    }
    const audioUrls: JsonObject = {};
    const audioVersions: JsonObject = {};
    const stemsBucket = Deno.env.get("SUPABASE_STEMS_BUCKET") ?? "instrumentos";
    const versionOf = (bucket: string, path: string) =>
      objectVersion(
        requiredEnv("SUPABASE_URL").replace(/\/+$/, ""),
        requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
        bucket,
        path,
      );
    for (const [instrument, value] of Object.entries(instruments as JsonObject)) {
      if (!instrumentTypes.has(instrument) || !value || typeof value !== "object") {
        throw new HttpError(500, `Instrumentos inválidos en ${levelId}`);
      }
      const storagePath = (value as JsonObject).storagePath;
      if (typeof storagePath !== "string" || !storagePath) {
        throw new HttpError(500, `Falta la ruta del instrumento ${instrument}`);
      }
      audioUrls[instrument] = await createOfflineAudioUrl(storagePath);
      audioVersions[instrument] = await versionOf(stemsBucket, storagePath);
    }
    const instrumentalBucket =
      Deno.env.get("SUPABASE_INSTRUMENTAL_SONGS_BUCKET") ??
        "canciones-instrumentales";
    audioVersions.instrumental = await versionOf(
      instrumentalBucket,
      instrumentalPath,
    );
    return {
      entry,
      respuesta: answer.fields.respuestaCancionNormalizada,
      audioUrls,
      audioVersions,
      instrumentalAudioUrl: await createOfflineAudioUrl(
        instrumentalPath,
        instrumentalBucket,
      ),
    };
  }));
  return { estado: state, levels };
}

async function purchaseInstrument(
  token: string,
  uid: string,
  gameId: string,
  instrumentId: string,
): Promise<JsonObject> {
  if (!instrumentTypes.has(instrumentId)) {
    throw new HttpError(400, "El instrumento no es válido");
  }
  const gamePath = `games/${gameId}`;
  const game = await getDocument(token, gamePath);
  if (!game) throw new HttpError(404, "No se encontró la partida");
  if (game.fields.uid !== uid) {
    throw new HttpError(403, "La partida no pertenece a este usuario");
  }
  if (game.fields.ganada === true) {
    throw new HttpError(409, "La partida ya fue completada");
  }
  const levelId = game.fields.levelId;
  if (typeof levelId !== "string" || !validId(levelId)) {
    throw new HttpError(500, "La partida no tiene un nivel válido");
  }
  const level = await getDocument(token, `levels/${levelId}`);
  if (!level || level.fields.published !== true) {
    throw new HttpError(404, "El nivel no está disponible");
  }
  const rawInstruments = level.fields.instrumentos;
  if (!rawInstruments || typeof rawInstruments !== "object") {
    throw new HttpError(500, "El nivel no tiene instrumentos configurados");
  }
  const instrument = (rawInstruments as JsonObject)[instrumentId];
  if (!instrument || typeof instrument !== "object") {
    throw new HttpError(404, "El instrumento no pertenece a este nivel");
  }
  const storagePath = (instrument as JsonObject).storagePath;
  const rawPrices = game.fields.preciosInstrumentos;
  if (typeof storagePath !== "string" || storagePath.length === 0) {
    throw new HttpError(
      500,
      "El instrumento no tiene un audio válido",
    );
  }
  const purchased = Array.isArray(game.fields.instrumentosComprados)
    ? (game.fields.instrumentosComprados as unknown[])
      .filter((item): item is string => typeof item === "string")
    : [];
  const prices = rawPrices && typeof rawPrices === "object" &&
      !Array.isArray(rawPrices)
    ? Object.fromEntries(
      purchased.map((type) => [type, (rawPrices as JsonObject)[type]]),
    )
    : {};
  const purchasePrice = prices[instrumentId];
  if (purchased.includes(instrumentId)) {
    if (
      typeof purchasePrice !== "number" ||
      ![300000, 400000].includes(purchasePrice)
    ) {
      throw new HttpError(500, "No se encontró el precio de la compra");
    }
    return {
      compraRealizada: false,
      presupuestoRestante: game.fields.presupuestoRestante,
      instrumentosComprados: purchased,
      melodiaDescubierta: game.fields.melodiaDescubierta === true,
      precioInstrumento: purchasePrice,
    };
  }
  if (!canPurchaseInstrument(purchased.length)) {
    throw new HttpError(
      409,
      "Ya compraste el máximo de tres instrumentos para esta partida",
    );
  }
  const balance = game.fields.presupuestoRestante;
  if (typeof balance !== "number" || !Number.isInteger(balance)) {
    throw new HttpError(500, "El presupuesto de la partida no es válido");
  }
  const purchasedPrices = purchased.map((type) => {
    const price = prices[type];
    if (typeof price !== "number" || ![300000, 400000].includes(price)) {
      throw new HttpError(500, "El historial de precios de la partida no es válido");
    }
    return price;
  });
  if (
    balance !== 1000000 -
      purchasedPrices.reduce((total, price) => total + price, 0)
  ) {
    throw new HttpError(409, "El saldo no coincide con las compras registradas");
  }
  let price: number;
  try {
    price = selectNextInstrumentPrice(purchasedPrices);
  } catch (error) {
    console.error("Invalid game purchase history", gameId, error);
    throw new HttpError(500, "No se pudo calcular el precio de la compra");
  }
  if (price > balance) {
    throw new HttpError(409, "No tienes presupuesto suficiente para comprarlo");
  }
  const instrumentsPurchased = [...purchased, instrumentId];
  const updatedPrices = { ...prices, [instrumentId]: price };
  let melodyInstrument = game.fields.instrumentoMelodia;
  if (
    instrumentsPurchased.length === maxPurchasedInstruments &&
    (typeof melodyInstrument !== "string" ||
      !instrumentTypes.has(melodyInstrument))
  ) {
    try {
      melodyInstrument = selectMelodyInstrument(
        Object.keys(rawInstruments as JsonObject),
        instrumentsPurchased,
      );
    } catch (error) {
      console.error("Could not assign game melody", gameId, error);
      throw new HttpError(500, "No se pudo asignar la melodía de la partida");
    }
  }
  const melodyFound = (typeof melodyInstrument === "string" &&
    instrumentsPurchased.includes(melodyInstrument)) ||
    game.fields.melodiaDescubierta === true;
  const now = new Date().toISOString();
  if (!game.updateTime) {
    throw new HttpError(500, "No se pudo validar la versión de la partida");
  }
  await commitWrites(token, [
    updateWrite(
      gamePath,
      {
        presupuestoRestante: balance - price,
        preciosInstrumentos: updatedPrices,
        instrumentosComprados: instrumentsPurchased,
        melodiaDescubierta: melodyFound,
        instrumentoMelodia: melodyInstrument,
        updatedAt: now,
      },
      game.updateTime,
    ),
  ]);
  return {
    compraRealizada: true,
    presupuestoRestante: balance - price,
    instrumentosComprados: instrumentsPurchased,
    melodiaDescubierta: melodyFound,
    precioInstrumento: price,
  };
}

async function startLevel(
  token: string,
  uid: string,
  levelId: string,
  guest = false,
): Promise<JsonObject> {
  const state = await getProgress(token, uid, guest);
  const available = (state.niveles as JsonObject[]).find((entry) => {
    const nivel = entry.nivel as JsonObject;
    return nivel.id === levelId;
  });
  const replay = (state.niveles_repetibles as JsonObject[]).find((entry) => {
    const nivel = entry.nivel as JsonObject;
    return nivel.id === levelId;
  });
  const selected = available ?? replay;
  if (
    !selected ||
    selected.puede_iniciar !== true ||
    (selected.completado !== true && available?.puede_iniciar !== true)
  ) {
    throw new HttpError(
      403,
      "Ese nivel está bloqueado. Completa los niveles anteriores o elige uno ya completado para repetirlo.",
    );
  }

  const nivel = selected.nivel as JsonObject;
  const instrumentList = nivel.instrumentos as JsonObject[];
  const gameLevel = {
    ...nivel,
    instrumentos: instrumentList.map((instrument) => ({
      tipo: instrument.tipo,
      precio: 0,
      audio_url: "",
      comprable: true,
    })),
  };
  const { gameId, write } = newGame(uid, levelId, nivel);
  await commitWrites(token, [write]);
  return { gameId, nivel: gameLevel };
}

/// Partida nueva de [levelId] con presupuesto completo; [extra] añade campos
/// (p. ej. la sala a la que pertenece).
function newGame(
  uid: string,
  levelId: string,
  nivel: JsonObject,
  extra: JsonObject = {},
): { gameId: string; write: JsonObject } {
  const random = new Uint32Array(1);
  crypto.getRandomValues(random);
  const gameId = Array.from(crypto.getRandomValues(new Uint8Array(16)))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  const points = nivel.puntos_inicio as number[];
  const startPoint = points.length > 0 ? points[random[0] % points.length] : 0;
  const now = new Date().toISOString();
  return {
    gameId,
    write: createWrite(`games/${gameId}`, {
      uid,
      levelId,
      dificultad: nivel.dificultad,
      puntoInicio: startPoint,
      presupuestoRestante: 1000000,
      preciosInstrumentos: {},
      instrumentosComprados: [],
      melodiaDescubierta: false,
      instrumentoMelodia: null,
      ganada: false,
      failedAnswerAttempts: 0,
      nextAnswerAt: null,
      ...extra,
      createdAt: now,
      updatedAt: now,
    }),
  };
}

/// Título y artista de la canción del nivel, para el reproductor al acertar.
async function revealedSong(
  token: string,
  level: { fields: JsonObject },
): Promise<JsonObject> {
  const songId = level.fields.cancionId;
  const song = typeof songId === "string" && validId(songId)
    ? await getDocument(token, `songs/${songId}`)
    : null;
  return {
    titulo: typeof song?.fields.titulo === "string" ? song.fields.titulo : null,
    artista: typeof song?.fields.artista === "string"
      ? song.fields.artista
      : null,
  };
}

async function submitAnswer(
  token: string,
  uid: string,
  gameId: string,
  answer: string,
  guest = false,
): Promise<JsonObject> {
  const gamePath = `games/${gameId}`;
  const game = await getDocument(token, gamePath);
  if (!game) throw new HttpError(404, "No se encontró la partida");
  if (game.fields.uid !== uid) {
    throw new HttpError(403, "La partida no pertenece a este usuario");
  }
  if (game.fields.ganada === true) return { correct: true };
  const nextAnswerAt = game.fields.nextAnswerAt;
  if (
    typeof nextAnswerAt === "string" &&
    Date.parse(nextAnswerAt) > Date.now()
  ) {
    throw new HttpError(429, "Espera 30 segundos antes de volver a intentarlo");
  }
  const levelId = game.fields.levelId;
  const difficulty = game.fields.dificultad;
  if (
    typeof levelId !== "string" || !validId(levelId) ||
    typeof difficulty !== "string" ||
    !difficulties.includes(difficulty as Difficulty)
  ) {
    throw new HttpError(500, "La partida no tiene datos de nivel válidos");
  }

  // Las partidas de una sala no tocan el orden ni el progreso del jugador.
  const salaId = game.fields.salaId;
  const enSala = typeof salaId === "string";
  const [level, answerDoc, order, progress] = await Promise.all([
    getDocument(token, `levels/${levelId}`),
    getDocument(token, `privateLevelAnswers/${levelId}`),
    enSala
      ? [] as string[]
      : ensureOrder(token, uid, difficulty as Difficulty, guest),
    enSala ? null : getDocument(
      token,
      userPath(uid, "progress", difficulty as Difficulty, guest),
    ),
  ]);
  if (!level || level.fields.published !== true || !answerDoc) {
    throw new HttpError(404, "El nivel no está disponible");
  }
  const correctAnswer = answerDoc.fields.respuestaCancionNormalizada ??
    answerDoc.fields.titulo;
  if (typeof correctAnswer !== "string") {
    throw new HttpError(500, "El nivel no tiene una respuesta configurada");
  }
  if (normalizeAnswer(answer) !== normalizeAnswer(correctAnswer)) {
    const failedAttempts = typeof game.fields.failedAnswerAttempts === "number"
      ? game.fields.failedAnswerAttempts
      : 0;
    const rateLimited = failedAttempts >= 2;
    const now = new Date().toISOString();
    await commitWrites(token, [
      updateWrite(
        gamePath,
        {
          failedAnswerAttempts: rateLimited ? 0 : failedAttempts + 1,
          nextAnswerAt: rateLimited
            ? new Date(Date.now() + 30_000).toISOString()
            : null,
          updatedAt: now,
        },
        game.updateTime!,
      ),
    ]);
    return { correct: false };
  }
  if (enSala) {
    return await answerRoomGame(token, uid, gameId, salaId as string, level);
  }

  const currentOrder = order;
  const completedIds = new Set(
    Array.isArray(progress?.fields?.completedLevelIds)
      ? (progress.fields.completedLevelIds as unknown[])
        .filter((id): id is string =>
          typeof id === "string" && order.includes(id)
        )
      : [],
  );
  const nextLevelId = currentOrder.find((id) => !completedIds.has(id));
  const replayingCompletedLevel = completedIds.has(levelId);
  if (!replayingCompletedLevel && nextLevelId !== levelId) {
    throw new HttpError(
      403,
      "La partida no corresponde al siguiente nivel activo",
    );
  }
  completedIds.add(levelId);
  // "Música para mis oídos": niveles ganados comprando un solo instrumento
  // (cuenta también al repetir un nivel ya ganado).
  const unInstrumento = new Set(stringList(progress?.fields?.unInstrumentoIds));
  const conUnInstrumento =
    stringList(game.fields.instrumentosComprados).length === 1;
  const nuevoUnInstrumento = conUnInstrumento && !unInstrumento.has(levelId);
  if (conUnInstrumento) unInstrumento.add(levelId);
  const completedNumbers = new Set(
    Array.isArray(progress?.fields?.nivelesCompletados)
      ? (progress.fields.nivelesCompletados as unknown[])
        .filter((number): number is number => typeof number === "number")
      : [],
  );
  if (typeof level.fields.numero === "number") {
    completedNumbers.add(level.fields.numero);
  }
  const now = new Date().toISOString();
  const progressFields = {
    nivelActual: typeof level.fields.numero === "number"
      ? level.fields.numero + 1
      : completedIds.size + 1,
    nivelesCompletados: [...completedNumbers].sort((a, b) => a - b),
    completedLevelIds: [...completedIds],
    unInstrumentoIds: [...unInstrumento],
    updatedAt: now,
  };
  const progressPath = userPath(
    uid,
    "progress",
    difficulty as Difficulty,
    guest,
  );
  const writes = [
    updateWrite(
      gamePath,
      {
        ganada: true,
        failedAnswerAttempts: 0,
        nextAnswerAt: null,
        updatedAt: now,
      },
      game.updateTime!,
    ),
    ...(replayingCompletedLevel && !nuevoUnInstrumento ? [] : [
      progress
        ? updateWrite(progressPath, progressFields, progress.updateTime!)
        : createWrite(progressPath, progressFields),
    ]),
  ];
  await commitWrites(token, writes);
  return {
    correct: true,
    // Monedas para "Adivina la intro": solo la primera vez que se gana.
    monedas: replayingCompletedLevel
      ? 0
      : introCoinRewards[difficulty as Difficulty],
    completedDifficulty: currentOrder.every((id) => completedIds.has(id)),
    // Al acertar ya se puede revelar la canción para el reproductor.
    ...await revealedSong(token, level),
  };
}

// --- "Desafía a tus amigos" ---
// Firestore: salas/{codigo}. La app la escucha en tiempo real (las reglas
// dejan leerla a sus jugadores y listar las públicas en espera) y solo esta
// función la modifica. Cada canción de un jugador es una partida normal en
// games/{gameId} con salaId y salaIndice, así compras y audios (audio-link)
// funcionan igual que en el juego principal. En las salas de intros no hay
// partidas: el avance y los fallos de cada jugador viven en la propia sala.
// Fichas: users/{uid}/fichas/saldo, solo las escribe esta función.

interface Jugador extends JsonObject {
  nombre: string;
  puntos: number;
  aciertos: number;
  // Contrarreloj: canción en la que va el jugador.
  indice: number;
  gameId: string | null;
  inicioCancion: string | null;
  eliminado: boolean;
  eliminadoEnRonda: number | null;
  abandono: boolean;
  // En la espera: marcó "Listo". Fichas que pagó al entrar (se devuelven si
  // sale antes de empezar).
  listo?: boolean;
  pagado?: number;
  // Solo salas de intros: intros adivinadas (dan acceso a la original), qué
  // canción tiene el reloj en marcha y los fallos para la espera de 30 s.
  acertadas?: string[];
  indiceIniciado?: number | null;
  failedAnswerAttempts?: number;
  nextAnswerAt?: string | null;
}

function newPlayer(nombre: string, pagado = 0): Jugador {
  return {
    nombre,
    listo: false,
    pagado,
    puntos: 0,
    aciertos: 0,
    indice: 0,
    gameId: null,
    inicioCancion: null,
    eliminado: false,
    eliminadoEnRonda: null,
    abandono: false,
  };
}

function roomPath(codigo: string): string {
  return `salas/${codigo}`;
}

function roomPlayers(sala: JsonObject): Record<string, Jugador> {
  const raw = sala.jugadores;
  return raw && typeof raw === "object" && !Array.isArray(raw)
    ? { ...raw as Record<string, Jugador> }
    : {};
}

function roomOrder(sala: JsonObject): string[] {
  return Array.isArray(sala.orden)
    ? (sala.orden as unknown[]).filter((uid): uid is string =>
      typeof uid === "string"
    )
    : [];
}

function roomMember(sala: JsonObject, uid: string): Jugador {
  const jugador = roomPlayers(sala)[uid];
  if (!jugador) throw new HttpError(403, "No estás en esta sala");
  return jugador;
}

/// Canción que le toca al jugador: en eliminación es la de la ronda.
function roomSongIndex(sala: JsonObject, jugador: Jugador): number {
  return sala.modo === "eliminacion"
    ? (sala.ronda as number) - 1
    : jugador.indice;
}

function roomExpired(sala: JsonObject): boolean {
  return sala.modo === "contrarreloj" && typeof sala.finEn === "string" &&
    Date.parse(sala.finEn) <= Date.now();
}

/// Posiciones: en contrarreloj por puntos y luego aciertos; en eliminación,
/// los que siguen vivos y después quien cayó más tarde. A igualdad, quien
/// entró primero.
function roomRanking(sala: JsonObject): (Jugador & { uid: string })[] {
  const jugadores = roomPlayers(sala);
  const caida = (j: Jugador) =>
    j.eliminado ? j.eliminadoEnRonda ?? 0 : Number.MAX_SAFE_INTEGER;
  return roomOrder(sala)
    .filter((uid) => jugadores[uid])
    .map((uid) => ({ ...jugadores[uid], uid }))
    .sort((a, b) =>
      sala.modo === "eliminacion"
        ? caida(b) - caida(a)
        : b.puntos - a.puntos || b.aciertos - a.aciertos
    );
}

/// Fin de contrarreloj: gana el primero de la tabla.
function finishTimedRoom(sala: JsonObject): JsonObject {
  return {
    estado: "terminada",
    ganadorUid: roomRanking(sala)[0]?.uid ?? null,
  };
}

function walletPath(uid: string): string {
  return `users/${uid}/fichas/saldo`;
}

/// Suma (o resta) en [campo] del saldo: fichas o salas ganadas
/// (ganadasCancion, ganadasIntros); crea el saldo si no existe. Con
/// [updateTime] solo se aplica si el saldo no cambió desde que se leyó.
function walletWrite(
  uid: string,
  cantidad: number,
  updateTime?: string,
  campo = "fichas",
): JsonObject {
  return {
    update: { name: documentName(walletPath(uid)), fields: {} },
    updateMask: { fieldPaths: [] },
    updateTransforms: [{
      fieldPath: campo,
      increment: { integerValue: String(cantidad) },
    }],
    ...(updateTime ? { currentDocument: { updateTime } } : {}),
  };
}

/// Varios incrementos en el saldo de un jugador en una sola escritura.
function walletStatsWrite(
  uid: string,
  incrementos: Record<string, number>,
): JsonObject {
  return {
    update: { name: documentName(walletPath(uid)), fields: {} },
    updateMask: { fieldPaths: [] },
    updateTransforms: Object.entries(incrementos).map(([campo, n]) => ({
      fieldPath: campo,
      increment: { integerValue: String(n) },
    })),
  };
}

/// Cobra [precio] fichas por una sala de intros o explica por qué no alcanza.
async function chargeIntroRoom(
  token: string,
  uid: string,
  precio: number,
): Promise<JsonObject> {
  const saldo = await getDocument(token, walletPath(uid));
  const fichas = typeof saldo?.fields.fichas === "number"
    ? saldo.fields.fichas
    : 0;
  if (!saldo?.updateTime || fichas < precio) {
    throw new HttpError(
      409,
      `Necesitas ${precio} fichas y tienes ${fichas}. Gánalas en salas de Adivina la canción.`,
    );
  }
  return walletWrite(uid, -precio, saldo.updateTime);
}

/// Eliminación: saca al último en adivinar y abre la siguiente ronda, o
/// cierra la sala cuando queda uno.
function advanceElimination(
  sala: JsonObject,
  jugadores: Record<string, Jugador>,
  acertaron: string[],
): JsonObject {
  const ronda = sala.ronda as number;
  const vivos = roomOrder(sala).filter((uid) =>
    jugadores[uid] && !jugadores[uid].eliminado
  );
  const fuera = eliminadoDeRonda(vivos, acertaron);
  if (fuera) {
    jugadores[fuera] = {
      ...jugadores[fuera],
      eliminado: true,
      eliminadoEnRonda: ronda,
    };
  }
  const restantes = vivos.filter((uid) => uid !== fuera);
  if (restantes.length <= 1) {
    return {
      jugadores,
      acertaronRonda: acertaron,
      estado: "terminada",
      ganadorUid: restantes[0] ?? null,
    };
  }
  if (!fuera) return { jugadores, acertaronRonda: acertaron };
  return {
    jugadores,
    ronda: ronda + 1,
    acertaronRonda: [],
    inicioRonda: new Date().toISOString(),
  };
}

interface RoomChange<T> {
  campos?: JsonObject;
  borrar?: boolean;
  extra?: JsonObject[];
  resultado: T;
}

/// Lee la sala, aplica [cambio] y la guarda solo si nadie la modificó
/// entretanto; si otro jugador escribió antes, reintenta con la versión nueva.
async function updateRoom<T>(
  token: string,
  codigo: string,
  cambio: (sala: JsonObject) => Promise<RoomChange<T>> | RoomChange<T>,
): Promise<T> {
  for (let intento = 0; intento < 5; intento++) {
    const sala = await getDocument(token, roomPath(codigo));
    if (!sala?.updateTime) {
      throw new HttpError(404, "No existe una sala con ese código");
    }
    const cambiado = await cambio(sala.fields);
    const { borrar, extra = [], resultado } = cambiado;
    let campos = cambiado.campos;
    const writes = [...extra];
    // Al terminar una sala se guardan las estadísticas de cada jugador y,
    // si es de instrumentos, se reparten las fichas; todo en el mismo
    // guardado que la cierra para que no se cuente ni se pague dos veces.
    if (campos?.estado === "terminada" && sala.fields.estado !== "terminada") {
      const final = { ...sala.fields, ...campos };
      const ranking = roomRanking(final);
      const premios = final.tipo === "intros" ? {} : premiosSala(ranking);
      const ganadorUid = ranking.find((jugador) =>
        jugador.uid === final.ganadorUid
      )?.uid;
      for (const [puesto, jugador] of ranking.entries()) {
        writes.push(
          walletStatsWrite(
            jugador.uid,
            estadisticasSala(
              jugador,
              puesto,
              ranking.length,
              jugador.uid === ganadorUid,
              final.tipo === "intros",
              premios[jugador.uid] ?? 0,
            ),
          ),
        );
      }
      if (final.tipo !== "intros") campos = { ...campos, premios };
    }
    if (borrar) {
      writes.push({
        delete: documentName(roomPath(codigo)),
        currentDocument: { updateTime: sala.updateTime },
      });
    } else if (campos) {
      writes.push(
        updateWrite(
          roomPath(codigo),
          { ...campos, updatedAt: new Date().toISOString() },
          sala.updateTime,
        ),
      );
    }
    if (writes.length === 0) return resultado;
    try {
      await commitWrites(token, writes);
      return resultado;
    } catch (error) {
      if (!(error instanceof HttpError) || error.status !== 409) throw error;
    }
  }
  throw new HttpError(409, "La sala está muy ocupada; inténtalo de nuevo");
}

async function createRoom(
  token: string,
  uid: string,
  nombre: string,
  body: JsonObject,
): Promise<JsonObject> {
  const tipo = body.tipo ?? "instrumentos";
  if (
    !modosSala.includes(body.modo as ModoSala) ||
    !tiposSala.includes(tipo as TipoSala) ||
    typeof body.publica !== "boolean"
  ) {
    throw new HttpError(400, "tipo, modo o publica no son válidos");
  }
  const pagado = tipo === "intros" ? precioCrearSalaIntros : 0;
  const now = new Date().toISOString();
  for (let intento = 0; intento < 5; intento++) {
    const codigo = generarCodigo((max) => {
      const random = new Uint32Array(1);
      crypto.getRandomValues(random);
      return random[0] % max;
    });
    try {
      await commitWrites(token, [
        ...(pagado ? [await chargeIntroRoom(token, uid, pagado)] : []),
        createWrite(roomPath(codigo), {
          codigo,
          creadorUid: uid,
          publica: body.publica,
          tipo,
          modo: body.modo,
          // Las canciones salen de todas las dificultades.
          dificultad: null,
          maxJugadores: maxJugadoresSala,
          estado: "esperando",
          jugadores: { [uid]: newPlayer(nombre, pagado) },
          orden: [uid],
          levelIds: [],
          ronda: 0,
          acertaronRonda: [],
          inicioRonda: null,
          finEn: null,
          ganadorUid: null,
          createdAt: now,
          updatedAt: now,
        }),
      ]);
      return { codigo };
    } catch (error) {
      // Código repetido: se prueba con otro.
      if (!(error instanceof HttpError) || error.status !== 409) throw error;
    }
  }
  throw new HttpError(503, "No se pudo generar un código de sala");
}

function joinRoom(
  token: string,
  uid: string,
  nombre: string,
  codigo: string,
): Promise<JsonObject> {
  return updateRoom(token, codigo, async (sala) => {
    const jugadores = roomPlayers(sala);
    if (jugadores[uid]) return { resultado: { codigo } };
    if (sala.estado !== "esperando") {
      throw new HttpError(409, "La sala ya empezó");
    }
    const max = typeof sala.maxJugadores === "number"
      ? sala.maxJugadores
      : maxJugadoresSala;
    if (Object.keys(jugadores).length >= max) {
      throw new HttpError(409, "La sala está llena");
    }
    const pagado = sala.tipo === "intros" ? precioEntrarSalaIntros : 0;
    return {
      campos: {
        jugadores: { ...jugadores, [uid]: newPlayer(nombre, pagado) },
        orden: [...roomOrder(sala), uid],
      },
      extra: pagado ? [await chargeIntroRoom(token, uid, pagado)] : [],
      resultado: { codigo },
    };
  });
}

function leaveRoom(
  token: string,
  uid: string,
  codigo: string,
): Promise<JsonObject> {
  return updateRoom(token, codigo, async (sala) => {
    const jugadores = roomPlayers(sala);
    const jugador = jugadores[uid];
    if (!jugador || sala.estado === "terminada") {
      return { resultado: { salio: true } };
    }
    if (sala.estado === "esperando") {
      delete jugadores[uid];
      const orden = roomOrder(sala).filter((id) => id !== uid);
      // Salir antes de empezar devuelve lo que pagó (salas de intros).
      const extra = jugador.pagado ? [walletWrite(uid, jugador.pagado)] : [];
      if (orden.length === 0) {
        return { borrar: true, extra, resultado: { salio: true } };
      }
      const restante = {
        ...sala,
        jugadores,
        orden,
        // Si sale quien la creó, la sala pasa al siguiente en llegar.
        creadorUid: sala.creadorUid === uid ? orden[0] : sala.creadorUid,
      };
      return {
        campos: {
          jugadores,
          orden,
          creadorUid: restante.creadorUid,
          // Si los que quedan ya estaban todos listos, empieza ya.
          ...(todosListos(orden.map((id) => jugadores[id].listo === true))
            ? await roomStart(token, restante)
            : {}),
        },
        extra,
        resultado: { salio: true },
      };
    }
    // En juego el jugador queda en la tabla, pero ya no compite.
    jugadores[uid] = sala.modo === "eliminacion" && !jugador.eliminado
      ? {
        ...jugador,
        abandono: true,
        eliminado: true,
        eliminadoEnRonda: sala.ronda as number,
      }
      : { ...jugador, abandono: true };
    const activos = roomOrder(sala).filter((id) =>
      jugadores[id] && !jugadores[id].abandono
    );
    let campos: JsonObject = { jugadores };
    if (sala.modo === "eliminacion") {
      const acertaron = (sala.acertaronRonda as string[] ?? []).filter((id) =>
        id !== uid
      );
      campos = advanceElimination(sala, jugadores, acertaron);
    } else if (activos.length === 0) {
      campos = { jugadores, ...finishTimedRoom({ ...sala, jugadores }) };
    }
    return { campos, resultado: { salio: true } };
  });
}

/// Campos para arrancar la partida: canciones de todas las dificultades (o
/// todas las intros) mezcladas y, en contrarreloj, el reloj desde ahora.
async function roomStart(token: string, sala: JsonObject): Promise<JsonObject> {
  const levelIds = sala.tipo === "intros"
    ? (await listCollection(token, "intros"))
      .filter((document) => fromFields(document.fields ?? {}).published === true)
      .map((document) => document.name?.split("/").at(-1) ?? "")
      .filter(validId)
    : (await publishedLevels(token))
      .filter((level) =>
        level.published && Number.isInteger(level.numero) &&
        difficulties.includes(level.dificultad as Difficulty) &&
        validId(level.id)
      )
      .map((level) => level.id);
  if (levelIds.length === 0) {
    throw new HttpError(
      409,
      sala.tipo === "intros"
        ? "No hay intros publicadas"
        : "No hay canciones publicadas",
    );
  }
  const now = Date.now();
  return {
    estado: "jugando",
    levelIds: shuffled(levelIds),
    ronda: 1,
    acertaronRonda: [],
    inicioRonda: new Date(now).toISOString(),
    finEn: sala.modo === "contrarreloj"
      ? new Date(now + duracionContrarrelojMs).toISOString()
      : null,
  };
}

/// Marca o desmarca "Listo"; cuando todos (2 o más) están listos, empieza.
function readyRoom(
  token: string,
  uid: string,
  codigo: string,
  listo: unknown,
): Promise<JsonObject> {
  if (typeof listo !== "boolean") {
    throw new HttpError(400, "listo debe ser true o false");
  }
  return updateRoom(token, codigo, async (sala) => {
    const jugador = roomMember(sala, uid);
    if (sala.estado !== "esperando") {
      throw new HttpError(409, "La sala ya empezó");
    }
    const jugadores = { ...roomPlayers(sala), [uid]: { ...jugador, listo } };
    const empieza = todosListos(
      roomOrder(sala).map((id) => jugadores[id]?.listo === true),
    );
    return {
      campos: {
        jugadores,
        ...(empieza ? await roomStart(token, sala) : {}),
      },
      resultado: { listo, iniciada: empieza },
    };
  });
}

/// Partida del jugador para la canción que le toca; la crea si aún no existe
/// y, si ya existe, devuelve también sus compras para retomarla.
function roomGame(
  token: string,
  uid: string,
  codigo: string,
): Promise<JsonObject> {
  return updateRoom<JsonObject>(token, codigo, async (sala) => {
    const jugador = roomMember(sala, uid);
    if (sala.estado !== "jugando") return { resultado: { estado: sala.estado } };
    if (roomExpired(sala)) {
      return {
        campos: finishTimedRoom(sala),
        resultado: { estado: "terminada" },
      };
    }
    if (jugador.eliminado || jugador.abandono) {
      return { resultado: { estado: "jugando", eliminado: true } };
    }
    if ((sala.acertaronRonda as string[] ?? []).includes(uid)) {
      return { resultado: { estado: "jugando", esperando: true } };
    }
    const indice = roomSongIndex(sala, jugador);
    const levelId = nivelDeIndice(sala.levelIds as string[], indice);
    if (sala.tipo === "intros") {
      // El reloj de la intro arranca la primera vez que el jugador la abre.
      const resultado = { estado: "jugando", introId: levelId, indice };
      if (jugador.indiceIniciado === indice) return { resultado };
      return {
        campos: {
          jugadores: {
            ...roomPlayers(sala),
            [uid]: {
              ...jugador,
              indiceIniciado: indice,
              inicioCancion: new Date().toISOString(),
            },
          },
        },
        resultado,
      };
    }
    const entry = await buildLevelEntry(token, levelId, null, new Set(), true);
    const nivel = entry.nivel as JsonObject;
    const actual = jugador.gameId
      ? await getDocument(token, `games/${jugador.gameId}`)
      : null;
    if (
      actual && actual.fields.salaId === codigo &&
      actual.fields.salaIndice === indice && actual.fields.ganada !== true
    ) {
      const comprados = Array.isArray(actual.fields.instrumentosComprados)
        ? actual.fields.instrumentosComprados as string[]
        : [];
      const precios = (actual.fields.preciosInstrumentos ?? {}) as JsonObject;
      return {
        resultado: {
          estado: "jugando",
          gameId: jugador.gameId,
          nivel,
          indice,
          compras: Object.fromEntries(comprados.map((t) => [t, precios[t]])),
          melodiaDescubierta: actual.fields.melodiaDescubierta === true,
        },
      };
    }
    const { gameId, write } = newGame(uid, levelId, nivel, {
      salaId: codigo,
      salaIndice: indice,
    });
    return {
      campos: {
        jugadores: {
          ...roomPlayers(sala),
          [uid]: {
            ...jugador,
            gameId,
            inicioCancion: new Date().toISOString(),
          },
        },
      },
      extra: [write],
      resultado: {
        estado: "jugando",
        gameId,
        nivel,
        indice,
        compras: {},
        melodiaDescubierta: false,
      },
    };
  });
}

/// Contrarreloj: pasa a la siguiente canción sin puntos.
function skipRoomSong(
  token: string,
  uid: string,
  codigo: string,
): Promise<JsonObject> {
  return updateRoom(token, codigo, (sala) => {
    const jugador = roomMember(sala, uid);
    if (sala.modo !== "contrarreloj" || sala.estado !== "jugando") {
      throw new HttpError(409, "Solo se puede saltar en contrarreloj");
    }
    if (roomExpired(sala)) {
      return { campos: finishTimedRoom(sala), resultado: { saltada: false } };
    }
    return {
      campos: {
        jugadores: {
          ...roomPlayers(sala),
          [uid]: {
            ...jugador,
            indice: jugador.indice + 1,
            gameId: null,
            inicioCancion: null,
          },
        },
      },
      resultado: { saltada: true },
    };
  });
}

/// La app lo llama al acabarse el reloj para cerrar la sala.
function checkRoom(
  token: string,
  uid: string,
  codigo: string,
): Promise<JsonObject> {
  return updateRoom(token, codigo, (sala) => {
    roomMember(sala, uid);
    return roomExpired(sala) && sala.estado === "jugando"
      ? { campos: finishTimedRoom(sala), resultado: { estado: "terminada" } }
      : { resultado: { estado: sala.estado } };
  });
}

/// Respuesta correcta en una partida de sala: suma puntos (contrarreloj) o
/// registra el acierto de la ronda (eliminación).
async function answerRoomGame(
  token: string,
  uid: string,
  gameId: string,
  codigo: string,
  level: { fields: JsonObject },
): Promise<JsonObject> {
  const gamePath = `games/${gameId}`;
  const puntos = await updateRoom<number | null>(token, codigo, async (sala) => {
    const jugador = roomMember(sala, uid);
    if (sala.estado !== "jugando") {
      throw new HttpError(409, "La sala ya terminó");
    }
    if (roomExpired(sala)) {
      return { campos: finishTimedRoom(sala), resultado: null };
    }
    const game = await getDocument(token, gamePath);
    if (
      !game?.updateTime || game.fields.ganada === true ||
      jugador.eliminado ||
      game.fields.salaIndice !== roomSongIndex(sala, jugador)
    ) {
      throw new HttpError(409, "Esta canción ya no es la actual de la sala");
    }
    const ganar = updateWrite(gamePath, {
      ganada: true,
      failedAnswerAttempts: 0,
      nextAnswerAt: null,
      updatedAt: new Date().toISOString(),
    }, game.updateTime);
    const jugadores = roomPlayers(sala);
    if (sala.modo === "eliminacion") {
      jugadores[uid] = { ...jugador, aciertos: jugador.aciertos + 1 };
      return {
        campos: advanceElimination(sala, jugadores, [
          ...(sala.acertaronRonda as string[] ?? []),
          uid,
        ]),
        extra: [ganar],
        resultado: 0,
      };
    }
    const segundos = (Date.now() - Date.parse(jugador.inicioCancion ?? "")) /
      1000;
    const ganados = puntosAcierto(
      Number.isFinite(segundos) ? segundos : 0,
      game.fields.presupuestoRestante as number,
    );
    jugadores[uid] = {
      ...jugador,
      puntos: jugador.puntos + ganados,
      aciertos: jugador.aciertos + 1,
      indice: jugador.indice + 1,
      gameId: null,
      inicioCancion: null,
    };
    return { campos: { jugadores }, extra: [ganar], resultado: ganados };
  });
  if (puntos === null) {
    throw new HttpError(409, "Se acabó el tiempo de la sala");
  }
  return {
    correct: true,
    monedas: 0,
    completedDifficulty: false,
    puntos,
    ...await revealedSong(token, level),
  };
}

/// Audio de una sala de intros: la intro que le toca al jugador o, si ya la
/// adivinó, la canción original y la portada.
async function roomIntroAudio(
  token: string,
  uid: string,
  codigo: string,
  introId: unknown,
  type: unknown,
): Promise<JsonObject> {
  if (
    !validId(introId) || typeof type !== "string" ||
    !Object.hasOwn(introAudioTypes, type)
  ) {
    throw new HttpError(400, "introId o type no son válidos");
  }
  const sala = await getDocument(token, roomPath(codigo));
  if (!sala) throw new HttpError(404, "No existe una sala con ese código");
  const jugador = roomMember(sala.fields, uid);
  const acertada = stringList(jugador.acertadas).includes(introId);
  const actual = sala.fields.estado === "jugando" && !jugador.eliminado &&
    nivelDeIndice(
        sala.fields.levelIds as string[],
        roomSongIndex(sala.fields, jugador),
      ) === introId;
  if (type === "intro" ? !actual && !acertada : !acertada) {
    throw new HttpError(403, "Esa canción no está disponible para ti");
  }
  const intro = await getDocument(token, `intros/${introId}`);
  if (!intro || intro.fields.published !== true) {
    throw new HttpError(404, "Esa intro no está disponible");
  }
  return {
    url: await signedIntroUrl(
      introId,
      intro.fields,
      type as keyof typeof introAudioTypes,
    ),
  };
}

/// Respuesta en una sala de intros: mismas reglas de puntos, eliminación y
/// espera de 30 s tras 3 fallos que en las salas de instrumentos.
async function answerRoomIntro(
  token: string,
  uid: string,
  codigo: string,
  answer: unknown,
): Promise<JsonObject> {
  if (
    typeof answer !== "string" || answer.trim().length === 0 ||
    answer.length > 200
  ) {
    throw new HttpError(400, "La respuesta no es válida");
  }
  const resultado = await updateRoom<JsonObject | null>(
    token,
    codigo,
    async (sala) => {
      const jugador = roomMember(sala, uid);
      if (sala.tipo !== "intros" || sala.estado !== "jugando") {
        throw new HttpError(409, "La sala ya terminó");
      }
      if (roomExpired(sala)) {
        return { campos: finishTimedRoom(sala), resultado: null };
      }
      if (
        jugador.eliminado ||
        (sala.acertaronRonda as string[] ?? []).includes(uid)
      ) {
        throw new HttpError(409, "Esta canción ya no es la actual de la sala");
      }
      if (
        typeof jugador.nextAnswerAt === "string" &&
        Date.parse(jugador.nextAnswerAt) > Date.now()
      ) {
        throw new HttpError(
          429,
          "Espera 30 segundos antes de volver a intentarlo",
        );
      }
      const introId = nivelDeIndice(
        sala.levelIds as string[],
        roomSongIndex(sala, jugador),
      );
      const intro = await getDocument(token, `intros/${introId}`);
      const expected = intro?.fields.respuestaCancionNormalizada ??
        intro?.fields.titulo;
      if (typeof expected !== "string") {
        throw new HttpError(500, "La intro no tiene una respuesta configurada");
      }
      const jugadores = roomPlayers(sala);
      if (normalizeAnswer(answer) !== normalizeAnswer(expected)) {
        const fallos = jugador.failedAnswerAttempts ?? 0;
        jugadores[uid] = {
          ...jugador,
          failedAnswerAttempts: fallos >= 2 ? 0 : fallos + 1,
          nextAnswerAt: fallos >= 2
            ? new Date(Date.now() + 30_000).toISOString()
            : null,
        };
        return { campos: { jugadores }, resultado: { correct: false } };
      }
      const acierto = {
        ...jugador,
        aciertos: jugador.aciertos + 1,
        acertadas: [...stringList(jugador.acertadas), introId],
        failedAnswerAttempts: 0,
        nextAnswerAt: null,
      };
      const reveal = {
        correct: true,
        titulo: typeof intro!.fields.titulo === "string"
          ? intro!.fields.titulo
          : null,
        artista: typeof intro!.fields.artista === "string"
          ? intro!.fields.artista
          : null,
      };
      if (sala.modo === "eliminacion") {
        jugadores[uid] = acierto;
        return {
          campos: advanceElimination(sala, jugadores, [
            ...(sala.acertaronRonda as string[] ?? []),
            uid,
          ]),
          resultado: { ...reveal, puntos: 0 },
        };
      }
      const segundos =
        (Date.now() - Date.parse(jugador.inicioCancion ?? "")) / 1000;
      // Sin compras: solo cuentan los 100 base y la rapidez.
      const ganados = puntosAcierto(Number.isFinite(segundos) ? segundos : 0, 0);
      jugadores[uid] = {
        ...acierto,
        puntos: jugador.puntos + ganados,
        indice: jugador.indice + 1,
        indiceIniciado: null,
        inicioCancion: null,
      };
      return { campos: { jugadores }, resultado: { ...reveal, puntos: ganados } };
    },
  );
  if (resultado === null) {
    throw new HttpError(409, "Se acabó el tiempo de la sala");
  }
  return resultado;
}

// --- Minijuego "Adivina la intro" ---
// Firestore: intros/{id} (solo servidor: título, artista, respuesta y rutas en
// el bucket de intros) y {users|guestSessions}/{uid}/introProgress/state con
// las intros obtenidas (en orden de salida) y las adivinadas.
// Las monedas no se guardan: salen de los niveles completados.

const introAudioTypes = {
  intro: { field: "introAudioPath", file: "intro.mp3" },
  fullSong: { field: "fullAudioPath", file: "original.mp3" },
  cover: { field: "portadaPath", file: "portada.jpg" },
} as const;

function introStatePath(uid: string, guest: boolean): string {
  return `${guest ? "guestSessions" : "users"}/${uid}/introProgress/state`;
}

function stringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

async function loadIntroState(token: string, uid: string, guest: boolean) {
  const path = introStatePath(uid, guest);
  const [documents, state, ...progress] = await Promise.all([
    listCollection(token, "intros"),
    getDocument(token, path),
    ...difficulties.map((difficulty) =>
      getDocument(token, userPath(uid, "progress", difficulty, guest))
    ),
  ]);
  const intros = new Map<string, JsonObject>();
  for (const document of documents) {
    const id = document.name?.split("/").at(-1) ?? "";
    const fields = fromFields(document.fields ?? {});
    if (validId(id) && fields.published === true) intros.set(id, fields);
  }
  const earned = coinsEarned(
    Object.fromEntries(
      difficulties.map((difficulty, index) => [
        difficulty,
        stringList(progress[index]?.fields.completedLevelIds),
      ]),
    ),
  );
  return {
    path,
    state,
    intros,
    earned,
    unlocked: [...new Set(stringList(state?.fields.unlockedIds))],
    completed: new Set(stringList(state?.fields.completedIds)),
  };
}

/// Solo se envían las intros ya obtenidas, numeradas en el orden en que
/// salieron; de las demás basta saber cuántas quedan.
function introSummary(
  state: Awaited<ReturnType<typeof loadIntroState>>,
): JsonObject {
  const unlocked = new Set(state.unlocked);
  return {
    monedas: coinBalance(state.earned, state.unlocked.length),
    monedas_ganadas: state.earned,
    restantes: [...state.intros.keys()].filter((id) => !unlocked.has(id))
      .length,
    intros: state.unlocked
      .filter((id) => state.intros.has(id))
      .map((id, index) => {
        const done = state.completed.has(id);
        const fields = state.intros.get(id)!;
        return {
          id,
          numero: index + 1,
          estado: done ? "completada" : "desbloqueada",
          // El título solo se revela al adivinarla.
          titulo: done && typeof fields.titulo === "string"
            ? fields.titulo
            : null,
          artista: done && typeof fields.artista === "string"
            ? fields.artista
            : null,
        };
      }),
  };
}

/// Gasta una moneda y saca al azar una intro que el jugador aún no tiene.
async function drawIntro(
  token: string,
  uid: string,
  guest: boolean,
): Promise<JsonObject> {
  const state = await loadIntroState(token, uid, guest);
  const locked = [...state.intros.keys()].filter((id) =>
    !state.unlocked.includes(id)
  );
  if (locked.length === 0) {
    throw new HttpError(409, "Ya descubriste todas las intros");
  }
  if (coinBalance(state.earned, state.unlocked.length) < introPrice) {
    throw new HttpError(
      409,
      "No tienes monedas suficientes. Adivina canciones del juego principal para ganar más.",
    );
  }
  const introId = shuffled(locked)[0];
  const unlocked = [...state.unlocked, introId];
  const now = new Date().toISOString();
  await commitWrites(token, [
    state.state
      ? updateWrite(
        state.path,
        { unlockedIds: unlocked, updatedAt: now },
        state.state.updateTime!,
      )
      : createWrite(state.path, {
        unlockedIds: unlocked,
        completedIds: [],
        failedAnswerAttempts: 0,
        nextAnswerAt: null,
        createdAt: now,
        updatedAt: now,
      }),
  ]);
  return { ...introSummary({ ...state, unlocked }), nueva: introId };
}

/// Paquete para jugar sin conexión las intros ya obtenidas: enlaces de
/// descarga (intro, original y portada) y la respuesta normalizada, igual que
/// el paquete offline de los niveles.
async function introOfflineBundle(
  token: string,
  uid: string,
  guest: boolean,
): Promise<JsonObject> {
  const state = await loadIntroState(token, uid, guest);
  const bucket = Deno.env.get("SUPABASE_INTRO_BUCKET") ?? "cancion_intro";
  const intros = await Promise.all(
    state.unlocked.filter((id) => state.intros.has(id)).map(async (id) => {
      const fields = state.intros.get(id)!;
      const pathOf = (type: keyof typeof introAudioTypes) => {
        const { field, file } = introAudioTypes[type];
        const custom = fields[field];
        return typeof custom === "string" && custom ? custom : `${id}/${file}`;
      };
      const expected = fields.respuestaCancionNormalizada ?? fields.titulo;
      if (typeof expected !== "string") {
        throw new HttpError(500, `La intro ${id} no tiene respuesta`);
      }
      const [intro, fullSong, cover] = await Promise.all([
        createOfflineAudioUrl(pathOf("intro"), bucket),
        createOfflineAudioUrl(pathOf("fullSong"), bucket),
        // Sin portada subida se juega igual: el reproductor muestra el disco.
        createOfflineAudioUrl(pathOf("cover"), bucket).catch(() => null),
      ]);
      return {
        id,
        titulo: typeof fields.titulo === "string" ? fields.titulo : null,
        artista: typeof fields.artista === "string" ? fields.artista : null,
        respuesta: normalizeAnswer(expected),
        urls: { intro, fullSong, cover },
      };
    }),
  );
  return { estado: introSummary(state), intros };
}

async function loadIntroAccess(
  token: string,
  uid: string,
  introId: string,
  guest: boolean,
) {
  const [state, intro] = await Promise.all([
    getDocument(token, introStatePath(uid, guest)),
    getDocument(token, `intros/${introId}`),
  ]);
  if (!intro || intro.fields.published !== true) {
    throw new HttpError(404, "Esa intro no está disponible");
  }
  if (!state || !stringList(state.fields.unlockedIds).includes(introId)) {
    throw new HttpError(403, "Desbloquea esta intro con una moneda primero");
  }
  return {
    state,
    intro: intro.fields,
    completed: stringList(state.fields.completedIds).includes(introId),
  };
}

async function introAudioUrl(
  token: string,
  uid: string,
  introId: string,
  type: keyof typeof introAudioTypes,
  guest: boolean,
): Promise<JsonObject> {
  const { intro, completed } = await loadIntroAccess(token, uid, introId, guest);
  // La original y la portada revelan la canción: solo después de adivinarla.
  if (type !== "intro" && !completed) {
    throw new HttpError(403, "Adivina la canción para escucharla completa");
  }
  return { url: await signedIntroUrl(introId, intro, type) };
}

/// URL firmada de un archivo de la intro en su bucket.
async function signedIntroUrl(
  introId: string,
  intro: JsonObject,
  type: keyof typeof introAudioTypes,
): Promise<string> {
  const { field, file } = introAudioTypes[type];
  const custom = intro[field];
  const path = typeof custom === "string" && custom ? custom : `${introId}/${file}`;
  if (
    !path.startsWith(`${introId}/`) ||
    path.split("/").some((part) => !part || part === "." || part === "..")
  ) {
    throw new HttpError(500, `La ruta ${field} de ${introId} no es válida`);
  }
  return await createOfflineAudioUrl(
    path,
    Deno.env.get("SUPABASE_INTRO_BUCKET") ?? "cancion_intro",
  );
}

async function submitIntroAnswer(
  token: string,
  uid: string,
  introId: string,
  answer: string,
  guest: boolean,
): Promise<JsonObject> {
  const { state, intro, completed } = await loadIntroAccess(
    token,
    uid,
    introId,
    guest,
  );
  const reveal = {
    titulo: typeof intro.titulo === "string" ? intro.titulo : null,
    artista: typeof intro.artista === "string" ? intro.artista : null,
  };
  if (completed) return { correct: true, ...reveal };
  const nextAnswerAt = state.fields.nextAnswerAt;
  if (
    typeof nextAnswerAt === "string" &&
    Date.parse(nextAnswerAt) > Date.now()
  ) {
    throw new HttpError(429, "Espera 30 segundos antes de volver a intentarlo");
  }
  const expected = intro.respuestaCancionNormalizada ?? intro.titulo;
  if (typeof expected !== "string") {
    throw new HttpError(500, "La intro no tiene una respuesta configurada");
  }
  const now = new Date().toISOString();
  if (normalizeAnswer(answer) !== normalizeAnswer(expected)) {
    // Igual que en los niveles: tras 3 fallos seguidos, 30 s de espera.
    const failed = typeof state.fields.failedAnswerAttempts === "number"
      ? state.fields.failedAnswerAttempts
      : 0;
    const rateLimited = failed >= 2;
    await commitWrites(token, [
      updateWrite(
        introStatePath(uid, guest),
        {
          failedAnswerAttempts: rateLimited ? 0 : failed + 1,
          nextAnswerAt: rateLimited
            ? new Date(Date.now() + 30_000).toISOString()
            : null,
          updatedAt: now,
        },
        state.updateTime!,
      ),
    ]);
    return { correct: false };
  }
  await commitWrites(token, [
    updateWrite(
      introStatePath(uid, guest),
      {
        completedIds: [...stringList(state.fields.completedIds), introId],
        failedAnswerAttempts: 0,
        nextAnswerAt: null,
        updatedAt: now,
      },
      state.updateTime!,
    ),
  ]);
  return { correct: true, ...reveal };
}

async function handle(request: Request): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return response(405, { error: "Método no permitido" });
  }
  try {
    if (!projectId) {
      throw new HttpError(500, "Falta configurar FIREBASE_PROJECT_ID");
    }
    const bearer = request.headers.get("Authorization")
      ?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!bearer) throw new HttpError(401, "Falta el token de Firebase");
    let verified: Awaited<ReturnType<typeof jwtVerify>>;
    try {
      verified = await jwtVerify(bearer, firebaseJwks, {
        audience: projectId,
        issuer: `https://securetoken.google.com/${projectId}`,
      });
    } catch (error) {
      const code = (error as { code?: unknown }).code;
      if (typeof code === "string" && /^ERR_(JWT|JWS)_/.test(code)) {
        throw new HttpError(401, "El token de Firebase no es válido o expiró");
      }
      console.error("Firebase token verification service failed", error);
      throw new HttpError(502, "No se pudo verificar el token de Firebase");
    }
    const uid = verified.payload.sub;
    if (!uid) throw new HttpError(401, "El token no identifica al usuario");
    const firebaseClaim = verified.payload.firebase;
    const guest = firebaseClaim !== null &&
      typeof firebaseClaim === "object" &&
      (firebaseClaim as JsonObject).sign_in_provider === "anonymous";
    // Nombre visible en las salas: el de Google o la parte local del correo.
    const { name, email } = verified.payload;
    const playerName = typeof name === "string" && name.trim()
      ? name.trim().slice(0, 30)
      : typeof email === "string"
      ? email.split("@")[0].slice(0, 30)
      : "Jugador";
    let rawBody: unknown;
    try {
      rawBody = await request.json();
    } catch {
      throw new HttpError(400, "El cuerpo debe ser JSON válido");
    }
    if (!rawBody || typeof rawBody !== "object" || Array.isArray(rawBody)) {
      throw new HttpError(400, "El cuerpo debe ser un objeto JSON");
    }
    const body = rawBody as JsonObject;
    const action = body.action;
    const token = await firestoreToken();
    if (action === "startGuestSession") {
      if (!guest) {
        throw new HttpError(
          403,
          "Solo una sesión de invitado puede iniciarse",
        );
      }
      await clearGuestSession(token, uid);
      return response(200, { started: true });
    }
    if (action === "progress") {
      return response(200, { estado: await getProgress(token, uid, guest) });
    }
    if (action === "offlineBundle") {
      return response(
        200,
        { bundle: await createOfflineBundle(token, uid, guest) },
      );
    }
    if (action === "completeOfflineLevel") {
      if (
        !validId(body.levelId) ||
        typeof body.answer !== "string" ||
        body.answer.trim().length === 0 ||
        body.answer.length > 200
      ) {
        throw new HttpError(400, "levelId o respuesta no son válidos");
      }
      const started = await startLevel(token, uid, body.levelId, guest);
      const gameId = started.gameId;
      if (typeof gameId !== "string") {
        throw new HttpError(500, "No se pudo crear la partida offline");
      }
      const result = await submitAnswer(
        token,
        uid,
        gameId,
        body.answer,
        guest,
      );
      if (result.correct !== true) {
        throw new HttpError(400, "La respuesta offline no coincide");
      }
      return response(200, result);
    }
    if (action === "startLevel") {
      if (!validId(body.levelId)) {
        throw new HttpError(400, "levelId no es válido");
      }
      return response(
        200,
        await startLevel(token, uid, body.levelId, guest),
      );
    }
    if (action === "purchaseInstrument") {
      if (
        !validId(body.gameId) ||
        typeof body.instrument !== "string" ||
        !instrumentTypes.has(body.instrument)
      ) {
        throw new HttpError(400, "gameId o instrumento no son válidos");
      }
      return response(
        200,
        await purchaseInstrument(
          token,
          uid,
          body.gameId,
          body.instrument,
        ),
      );
    }
    if (action === "submitAnswer") {
      if (
        !validId(body.gameId) ||
        typeof body.answer !== "string" ||
        body.answer.trim().length === 0 ||
        body.answer.length > 200
      ) {
        throw new HttpError(400, "gameId o respuesta no son válidos");
      }
      return response(
        200,
        await submitAnswer(token, uid, body.gameId, body.answer, guest),
      );
    }
    if (action === "introState") {
      return response(
        200,
        introSummary(await loadIntroState(token, uid, guest)),
      );
    }
    if (action === "drawIntro") {
      return response(200, await drawIntro(token, uid, guest));
    }
    if (action === "introOfflineBundle") {
      return response(200, await introOfflineBundle(token, uid, guest));
    }
    if (action === "completeOfflineIntro") {
      if (
        !validId(body.introId) ||
        typeof body.answer !== "string" ||
        body.answer.trim().length === 0 ||
        body.answer.length > 200
      ) {
        throw new HttpError(400, "introId o respuesta no son válidos");
      }
      const result = await submitIntroAnswer(
        token,
        uid,
        body.introId,
        body.answer,
        guest,
      );
      if (result.correct !== true) {
        throw new HttpError(400, "La respuesta offline no coincide");
      }
      return response(200, result);
    }
    if (action === "introAudio") {
      if (
        !validId(body.introId) ||
        typeof body.type !== "string" ||
        !Object.hasOwn(introAudioTypes, body.type)
      ) {
        throw new HttpError(400, "introId o type no son válidos");
      }
      return response(
        200,
        await introAudioUrl(
          token,
          uid,
          body.introId,
          body.type as keyof typeof introAudioTypes,
          guest,
        ),
      );
    }
    if (action === "submitIntroAnswer") {
      if (
        !validId(body.introId) ||
        typeof body.answer !== "string" ||
        body.answer.trim().length === 0 ||
        body.answer.length > 200
      ) {
        throw new HttpError(400, "introId o respuesta no son válidos");
      }
      return response(
        200,
        await submitIntroAnswer(token, uid, body.introId, body.answer, guest),
      );
    }
    const roomActions: Record<
      string,
      (codigo: string) => Promise<JsonObject>
    > = {
      unirseSala: (codigo) => joinRoom(token, uid, playerName, codigo),
      salirSala: (codigo) => leaveRoom(token, uid, codigo),
      listoSala: (codigo) => readyRoom(token, uid, codigo, body.listo),
      partidaSala: (codigo) => roomGame(token, uid, codigo),
      saltarCancionSala: (codigo) => skipRoomSong(token, uid, codigo),
      revisarSala: (codigo) => checkRoom(token, uid, codigo),
      audioIntroSala: (codigo) =>
        roomIntroAudio(token, uid, codigo, body.introId, body.type),
      responderIntroSala: (codigo) =>
        answerRoomIntro(token, uid, codigo, body.answer),
    };
    if (action === "crearSala" || Object.hasOwn(roomActions, String(action))) {
      if (guest) {
        throw new HttpError(403, "Crea una cuenta para jugar con amigos");
      }
      if (action === "crearSala") {
        return response(200, await createRoom(token, uid, playerName, body));
      }
      if (!codigoValido(body.codigo)) {
        throw new HttpError(400, "El código de sala no es válido");
      }
      return response(200, await roomActions[action as string](body.codigo));
    }
    if (action === "reiniciarProgreso") {
      if (guest) {
        throw new HttpError(403, "Solo una cuenta registrada puede reiniciarse");
      }
      // Hace falta haber confirmado la contraseña (o Google) hace poco.
      const authTime = verified.payload.auth_time;
      if (
        typeof authTime !== "number" || Date.now() / 1000 - authTime > 300
      ) {
        throw new HttpError(
          401,
          "Vuelve a confirmar tu cuenta para reiniciar el progreso",
        );
      }
      await resetUserProgress(token, uid);
      return response(200, { reiniciado: true });
    }
    if (action === "endGuestSession") {
      if (!guest) {
        throw new HttpError(
          403,
          "Solo una sesión de invitado puede finalizarse",
        );
      }
      await clearGuestSession(token, uid);
      return response(200, { cleared: true });
    }
    throw new HttpError(400, "Acción no válida");
  } catch (error) {
    if (error instanceof HttpError) {
      return response(error.status, { error: error.message });
    }
    console.error("Unexpected game-progress function failure", error);
    return response(500, { error: "Error interno al procesar el progreso" });
  }
}

Deno.serve(handle);
