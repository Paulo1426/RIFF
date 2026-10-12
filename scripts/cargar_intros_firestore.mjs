// Carga las intros del minijuego "Adivina la intro" en Firestore (colección
// `intros`). Uso:
//   node scripts/cargar_intros_firestore.mjs intros.json          (vista previa)
//   node scripts/cargar_intros_firestore.mjs intros.json --apply  (guarda)
// Los audios y la portada van en el bucket `cancion_intro`, en la carpeta de
// cada intro: {id}/intro.mp3, {id}/original.mp3 y {id}/portada.jpg (o las
// rutas que indique el JSON).
import { resolve } from "node:path";
import {
  encodeFields,
  getAccessToken,
  normalizeAnswer,
  readJson,
} from "./cargar_niveles_firestore.mjs";

const projectId = "song-gues-game";
const defaults = {
  introAudioPath: { file: "intro.mp3", ext: /\.mp3$/i },
  fullAudioPath: { file: "original.mp3", ext: /\.mp3$/i },
  portadaPath: { file: "portada.jpg", ext: /\.(jpe?g|png|webp)$/i },
};

function prepararIntro(intro, index) {
  const id = intro.id;
  if (typeof id !== "string" || !/^cancion-\d{2}$/.test(id)) {
    throw new Error(`Entrada ${index + 1}: "id" debe ser como "cancion-01".`);
  }
  for (const field of ["titulo", "artista", "respuesta"]) {
    if (typeof intro[field] !== "string" || !intro[field].trim()) {
      throw new Error(`${id}: completa el campo "${field}".`);
    }
  }
  const paths = Object.fromEntries(
    Object.entries(defaults).map(([field, { file, ext }]) => {
      const path = (intro[field] ?? `${id}/${file}`).trim();
      if (
        !path.startsWith(`${id}/`) ||
        !ext.test(path) ||
        path.split("/").some((part) => !part || part === "." || part === "..")
      ) {
        throw new Error(`${id}: "${field}" debe empezar por "${id}/" y tener la extensión correcta.`);
      }
      return [field, path];
    }),
  );
  return {
    id,
    fields: {
      titulo: intro.titulo.trim(),
      artista: intro.artista.trim(),
      respuestaCancionNormalizada: normalizeAnswer(intro.respuesta),
      ...paths,
      published: true,
    },
  };
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  const file = args.find((arg) => !arg.startsWith("--")) ?? "intros.json";
  const data = await readJson(resolve(file));
  if (!Array.isArray(data.intros) || data.intros.length === 0) {
    throw new Error(`${file}: el JSON debe tener una lista "intros".`);
  }
  const intros = data.intros.map(prepararIntro);
  if (new Set(intros.map((intro) => intro.id)).size !== intros.length) {
    throw new Error(`${file}: hay ids repetidos.`);
  }

  console.log(
    `${apply ? "Se escribirán" : "Vista previa; no se modificará Firestore:"} ${intros.length} intros.`,
  );
  for (const { id, fields } of intros) {
    console.log(
      `  ${id} "${fields.titulo}" - ${fields.artista}; ${fields.introAudioPath}, ${fields.fullAudioPath}, ${fields.portadaPath}`,
    );
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
  if (account.project_id !== projectId) {
    throw new Error(`La cuenta de servicio debe pertenecer a ${projectId}.`);
  }
  const token = await getAccessToken(account);
  const writes = intros.map(({ id, fields }) => ({
    update: {
      name: `projects/${projectId}/databases/(default)/documents/intros/${id}`,
      fields: encodeFields(fields),
    },
    updateMask: { fieldPaths: Object.keys(fields) },
  }));
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
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
    throw new Error(`Firestore rechazó la carga (${response.status}): ${details}`);
  }
  console.log(`Carga terminada: ${writes.length} intros.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
