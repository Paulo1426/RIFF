// Sube las intros de un género a Supabase Storage: bucket `{genero}`, carpeta
// `intro_{genero}/{id}/` con intro.mp3 (primeros segundos), original.mp3 y
// portada.jpg (la carátula que trae el mp3). Uso:
//   GENERO=reggaeton node scripts/subir_intros_supabase.mjs <carpeta>          (vista previa)
//   GENERO=reggaeton node scripts/subir_intros_supabase.mjs <carpeta> --apply  (sube)
// <carpeta> tiene intros.json (cada intro con "archivo") y los mp3 en intros/.
// Después carga Firestore: GENERO=reggaeton node scripts/cargar_intros_firestore.mjs <carpeta>/intros.json
import { readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { genero, readJson } from "./cargar_niveles_firestore.mjs";

const segundosIntro = 30;
const supabaseUrl = process.env.SUPABASE_URL ??
  "https://hwjvwabvuavkexgibzps.supabase.co";
const bucket = genero.replaceAll("_", "-");
const carpeta = `intro_${bucket}`;

// Tamaño de la etiqueta ID3v2 (0 si no hay).
function finId3(buf) {
  if (buf.toString("latin1", 0, 3) !== "ID3") return 0;
  return 10 + ((buf[6] << 21) | (buf[7] << 14) | (buf[8] << 7) | buf[9]);
}

// Carátula del frame APIC (ID3v2.3/2.4).
export function portada(buf) {
  const fin = finId3(buf);
  const v = buf[3];
  const syn = (o) =>
    (buf[o] << 21) | (buf[o + 1] << 14) | (buf[o + 2] << 7) | buf[o + 3];
  for (let o = 10; o + 10 < fin;) {
    const id = buf.toString("latin1", o, o + 4);
    if (!/^[A-Z0-9]{4}$/.test(id)) break;
    const len = v === 4 ? syn(o + 4) : buf.readUInt32BE(o + 4);
    if (id === "APIC") {
      const f = buf.subarray(o + 10, o + 10 + len);
      const ancho = f[0] === 1 || f[0] === 2 ? 2 : 1;
      let i = f.indexOf(0, 1) + 2; // fin del mime + tipo de imagen
      while (f.subarray(i, i + ancho).some((b) => b !== 0)) i += ancho;
      const data = f.subarray(i + ancho);
      if (data[0] !== 0xff || data[1] !== 0xd8) throw new Error("La carátula no es JPEG.");
      return data;
    }
    o += 10 + len;
  }
  throw new Error("El mp3 no trae carátula.");
}

const bitrates = {
  1: [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
  2: [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
};
const sampleRates = { 3: [44100, 48000, 32000], 2: [22050, 24000, 16000], 0: [11025, 12000, 8000] };

// Primeros [segundos] de un mp3 (Layer III), cortado en límite de frame. Quita
// la etiqueta ID3 y el frame Xing/Info para que el reproductor no lea la
// duración de la canción completa.
export function recortar(buf, segundos) {
  let o = finId3(buf);
  let tiempo = 0;
  const frames = [];
  while (o + 4 <= buf.length && tiempo < segundos) {
    const h = buf.readUInt32BE(o);
    const version = (h >>> 19) & 3;
    const rate = sampleRates[version]?.[(h >>> 10) & 3];
    const kbps = bitrates[version === 3 ? 1 : 2][(h >>> 12) & 15];
    if ((h >>> 21) !== 0x7ff || ((h >>> 17) & 3) !== 1 || !rate || !kbps) {
      o++; // basura entre frames
      continue;
    }
    const muestras = version === 3 ? 1152 : 576;
    const len = Math.floor((muestras / 8) * kbps * 1000 / rate) + ((h >>> 9) & 1);
    const frame = buf.subarray(o, o + len);
    const cabecera = frame.subarray(0, 64).toString("latin1");
    if (frames.length || !/Xing|Info/.test(cabecera)) {
      frames.push(frame);
      tiempo += muestras / rate;
    }
    o += len;
  }
  if (tiempo < segundos) throw new Error("El mp3 dura menos que la intro.");
  return Buffer.concat(frames);
}

async function subir(key, ruta, cuerpo, tipo) {
  const response = await fetch(
    `${supabaseUrl}/storage/v1/object/${bucket}/${ruta}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        apikey: key,
        "Content-Type": tipo,
        "x-upsert": "true",
      },
      body: cuerpo,
    },
  );
  if (!response.ok) {
    throw new Error(`Supabase rechazó ${ruta} (${response.status}): ${await response.text()}`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  const base = resolve(args.find((arg) => !arg.startsWith("--")) ?? ".");
  const { intros } = await readJson(join(base, "intros.json"));

  // Prepara todo antes de subir: un archivo malo no deja la carga a medias.
  const listas = [];
  for (const intro of intros) {
    if (!/^cancion-\d{2}$/.test(intro.id) || !intro.archivo) {
      throw new Error(`Entrada inválida en intros.json: ${JSON.stringify(intro)}`);
    }
    const original = await readFile(join(base, "intros", intro.archivo));
    listas.push({
      intro,
      archivos: [
        ["intro.mp3", recortar(original, segundosIntro), "audio/mpeg"],
        ["original.mp3", original, "audio/mpeg"],
        ["portada.jpg", portada(original), "image/jpeg"],
      ],
    });
  }
  for (const { intro, archivos } of listas) {
    console.log(`  ${bucket}/${carpeta}/${intro.id}: ${intro.titulo} - ${intro.artista} (${
      archivos.map(([n, b]) => `${n} ${Math.round(b.length / 1024)} KB`).join(", ")
    })`);
  }
  if (!apply) {
    console.log(`Vista previa: ${listas.length} intros. Para subir, ejecuta otra vez con --apply.`);
    return;
  }

  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!key) throw new Error("Define SUPABASE_SERVICE_ROLE_KEY (Supabase > Settings > API).");
  // Bucket privado, como el de vallenato: la app pide URLs firmadas a audio-link.
  const creado = await fetch(`${supabaseUrl}/storage/v1/bucket`, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, apikey: key, "Content-Type": "application/json" },
    body: JSON.stringify({ id: bucket, name: bucket, public: false }),
  });
  const texto = await creado.text();
  if (!creado.ok && !/already exists|Duplicate/i.test(texto)) {
    throw new Error(`No se pudo crear el bucket ${bucket} (${creado.status}): ${texto}`);
  }
  for (const { intro, archivos } of listas) {
    for (const [nombre, cuerpo, tipo] of archivos) {
      await subir(key, `${carpeta}/${intro.id}/${nombre}`, cuerpo, tipo);
    }
    console.log(`  subida ${intro.id}`);
  }
  console.log(`Carga terminada: ${listas.length} intros en ${bucket}/${carpeta}.`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
