import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { createSign } from "node:crypto";
import { pathToFileURL } from "node:url";

const instruments = ["acordeon", "bajo", "bateria", "guitarra"];
const difficultyConfigs = [
  {
    prefix: "facil",
    firestoreDifficulty: "facil",
    label: "Fácil",
    firstSongNumber: 1,
  },
  {
    prefix: "media",
    firestoreDifficulty: "medio",
    label: "Media",
    firstSongNumber: 6,
  },
  {
    prefix: "dificil",
    firestoreDifficulty: "avanzado",
    label: "Avanzada",
    firstSongNumber: 11,
  },
];
const scope = "https://www.googleapis.com/auth/datastore";
const firestoreApi = "https://firestore.googleapis.com/v1";

function base64Url(value) {
  return Buffer.from(value).toString("base64url");
}

export async function readJson(path) {
  const contents = await readFile(path, "utf8");
  return JSON.parse(contents.replace(/^\uFEFF/, ""));
}

function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === "number") return { doubleValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  if (typeof value === "object") {
    return { mapValue: { fields: encodeFields(value) } };
  }
  throw new TypeError(`Tipo de valor Firestore no admitido: ${typeof value}`);
}

export function encodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, encodeValue(value)]),
  );
}

function validateLevel(level, expectedNumber, config) {
  const id = `${config.prefix}-${String(expectedNumber).padStart(2, "0")}`;
  const songNumber = config.firstSongNumber + expectedNumber - 1;
  const songId = `cancion-${String(songNumber).padStart(3, "0")}`;
  if (
    level.numero !== expectedNumber ||
    level.levelId !== id ||
    level.songId !== songId
  ) {
    throw new Error(
      `La entrada ${expectedNumber} debe usar ${id} y ${songId}.`,
    );
  }
  for (const field of [
    "titulo",
    "artista",
    "respuesta",
    "fullAudioPath",
    "instrumentalAudioPath",
  ]) {
    if (
      typeof level[field] !== "string" ||
      !level[field].trim() ||
      level[field].includes("REEMPLAZAR")
    ) {
      throw new Error(`${id}: completa el campo "${field}" en el JSON.`);
    }
  }
  for (const pathField of ["fullAudioPath", "instrumentalAudioPath"]) {
    const path = level[pathField];
    if (
      path.startsWith("/") ||
      !path.startsWith(`${songId}/`) ||
      !path.endsWith(".mp3") ||
      path.split("/").some((part) => !part || part === "." || part === "..")
    ) {
      throw new Error(
        `${id}: "${pathField}" debe ser una ruta .mp3 relativa que comience por "${songId}/".`,
      );
    }
  }
  // Opcional: por defecto la portada es {songId}/portada.jpg en el bucket
  // "portadas".
  if (level.portadaPath !== undefined) {
    const path = level.portadaPath;
    if (
      typeof path !== "string" ||
      !path.startsWith(`${songId}/`) ||
      !/\.(jpe?g|png|webp)$/i.test(path) ||
      path.split("/").some((part) => !part || part === "." || part === "..")
    ) {
      throw new Error(
        `${id}: "portadaPath" debe ser una imagen .jpg, .png o .webp que comience por "${songId}/".`,
      );
    }
  }
}

function portadaDe(level) {
  return (level.portadaPath ?? `${level.songId}/portada.jpg`).trim();
}

export function normalizeAnswer(answer) {
  return answer
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function createStemPaths(level) {
  const folder = level.songId;
  return Object.fromEntries(
    instruments.map((instrument) => [
      instrument,
      { storagePath: `${folder}/${instrument}.mp3` },
    ]),
  );
}

function updateWrite(projectId, collection, id, fields) {
  const name =
    `projects/${projectId}/databases/(default)/documents/${collection}/${id}`;
  return {
    update: { name, fields: encodeFields(fields) },
    updateMask: { fieldPaths: Object.keys(fields) },
  };
}

export async function getAccessToken(account) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;
  const signer = createSign("RSA-SHA256");
  signer.update(unsigned);
  signer.end();
  const assertion = `${unsigned}.${signer.sign(account.private_key, "base64url")}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const data = await response.json();
  if (!response.ok || typeof data.access_token !== "string") {
    throw new Error(
      `Google no autorizó la carga Firestore (${response.status}): ${
        data.error_description ?? data.error ?? "respuesta inválida"
      }`,
    );
  }
  return data.access_token;
}

// Valida un JSON de cinco niveles y devuelve sus escrituras de Firestore.
async function prepararArchivo(dataPath) {
  const data = await readJson(dataPath);
  if (!Array.isArray(data.levels) || data.levels.length !== 5) {
    throw new Error(`${dataPath}: el JSON debe contener exactamente cinco niveles.`);
  }
  const firstLevelId = data.levels[0]?.levelId;
  const config = difficultyConfigs.find((item) =>
    typeof firstLevelId === "string" &&
    firstLevelId.startsWith(`${item.prefix}-`)
  );
  if (!config) {
    throw new Error(
      `${dataPath}: los levelId deben comenzar por facil-, media- o dificil-.`,
    );
  }
  data.levels.forEach((level, index) =>
    validateLevel(level, index + 1, config)
  );
  if (
    new Set(data.levels.map((level) => level.levelId)).size !== 5 ||
    new Set(data.levels.map((level) => level.songId)).size !== 5
  ) {
    throw new Error(`${dataPath}: los levelId y songId deben ser únicos.`);
  }

  const writes = [];
  for (const level of data.levels) {
    writes.push(
      updateWrite("song-gues-game", "songs", level.songId, {
        titulo: level.titulo.trim(),
        artista: level.artista.trim(),
        instrumentalAudioPath: level.instrumentalAudioPath.trim(),
        fullAudioPath: level.fullAudioPath.trim(),
        portadaPath: portadaDe(level),
        published: true,
      }),
      updateWrite("song-gues-game", "levels", level.levelId, {
        numero: level.numero,
        dificultad: config.firestoreDifficulty,
        cancionId: level.songId,
        published: true,
        modoPrueba: false,
        duracionFragmentoSegundos: 30,
        puntosInicio: [0],
        instrumentos: createStemPaths(level),
      }),
      updateWrite("song-gues-game", "privateLevelAnswers", level.levelId, {
        respuestaCancionNormalizada: normalizeAnswer(level.respuesta),
      }),
    );
  }
  return { config, levels: data.levels, writes };
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  // Sin archivos carga las tres dificultades de una vez.
  const files = args.filter((arg) => !arg.startsWith("--"));
  const paths = (files.length
    ? files
    : ["niveles-facil.json", "niveles-media.json", "niveles-dificil.json"])
    .map((file) => resolve(file));
  const archivos = [];
  for (const path of paths) archivos.push(await prepararArchivo(path));
  const writes = archivos.flatMap((archivo) => archivo.writes);

  for (const { config, levels } of archivos) {
    console.log(
      `${apply ? "Se escribirán" : "Vista previa; no se modificará Firestore:"} ${levels.length * 3} documentos para dificultad ${config.label}.`,
    );
    for (const level of levels) {
      console.log(
        `  ${level.levelId} -> ${level.songId} "${level.titulo.trim()}" - ${level.artista.trim()}; portada: portadas/${portadaDe(level)}; stems: ${
          Object.values(createStemPaths(level))
            .map((item) => item.storagePath)
            .join(", ")
        }`,
      );
    }
  }
  if (!apply) {
    console.log("Revisa el JSON. Para guardar, ejecuta otra vez con --apply.");
    return;
  }

  const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credentialPath) {
    throw new Error(
      "Define GOOGLE_APPLICATION_CREDENTIALS con la ruta local al JSON de una cuenta de servicio Firebase.",
    );
  }
  const account = await readJson(credentialPath);
  if (
    account.project_id !== "song-gues-game" ||
    !account.client_email ||
    !account.private_key
  ) {
    throw new Error(
      "La cuenta de servicio debe pertenecer al proyecto song-gues-game.",
    );
  }

  const token = await getAccessToken(account);
  const response = await fetch(
    `${firestoreApi}/projects/song-gues-game/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ writes }),
    },
  );
  if (!response.ok) {
    const details = (await response.text()).slice(0, 2000);
    throw new Error(
      `Firestore rechazó la carga (${response.status}): ${details}`,
    );
  }
  console.log(
    `Carga terminada: ${writes.length} documentos (${
      archivos.map((archivo) => archivo.config.label).join(", ")
    }).`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
