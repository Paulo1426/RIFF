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

import { comprimir } from "./comprimir_audio.mjs";

const segundosIntro = 30;
const kbpsIntro = 128;
const kbpsOriginal = 112;
// SIN_COMPRIMIR=1: sube el audio tal cual (el recorte de la intro no recodifica);
// al original solo se le quita la etiqueta ID3 (la carátula ya va en portada.jpg).
const sinComprimir = process.env.SIN_COMPRIMIR === "1";
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

// Suma de big_values del frame (valores cuantizados no nulos): ~0 en
// silencio, decenas o cientos con sonido.
function sonidoDe(frame, version, mono) {
  let bit = (((frame.readUInt32BE(0) >>> 16) & 1) === 0 ? 6 : 4) * 8;
  const leer = (n) => {
    let x = 0;
    for (let i = 0; i < n; i++, bit++) {
      x = (x << 1) | ((frame[bit >> 3] >> (7 - (bit & 7))) & 1);
    }
    return x;
  };
  const canales = mono ? 1 : 2;
  let grandes = 0;
  if (version === 3) {
    leer(9 + (mono ? 5 : 3) + 4 * canales);
    for (let i = 0; i < 2 * canales; i++) {
      leer(12);
      grandes += leer(9);
      leer(38);
    }
  } else {
    leer(8 + (mono ? 1 : 2));
    for (let i = 0; i < canales; i++) {
      leer(12);
      grandes += leer(9);
      leer(42);
    }
  }
  return grandes;
}

// Por debajo de esto un frame es silencio (medido: 0–3 en silencio, 30+ con
// música desde el primer golpe).
const umbralSonido = 20;
// Frames de silencio que se dejan antes del sonido: el frame donde empieza
// puede usar datos de los anteriores (reservorio de bits del mp3).
const framesPrevios = 2;

// [segundos] de un mp3 (Layer III) desde que empieza a sonar: salta el
// silencio inicial, corta en límite de frame y quita la etiqueta ID3 y el
// frame Xing/Info para que el reproductor no lea la duración de la canción
// completa.
export function recortar(buf, segundos) {
  let o = finId3(buf);
  const frames = [];
  let inicio = -1;
  let tiempo = 0;
  while (o + 4 <= buf.length && (inicio < 0 || tiempo < segundos)) {
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
    o += len;
    const cabecera = frame.subarray(0, 64).toString("latin1");
    if (!frames.length && /Xing|Info/.test(cabecera)) continue;
    const duracion = muestras / rate;
    frames.push({ frame, duracion });
    if (inicio < 0) {
      if (sonidoDe(frame, version, ((h >>> 6) & 3) === 3) < umbralSonido) continue;
      inicio = Math.max(0, frames.length - 1 - framesPrevios);
      tiempo = frames.slice(inicio).reduce((t, f) => t + f.duracion, 0);
    } else {
      tiempo += duracion;
    }
  }
  if (inicio < 0 || tiempo < segundos) {
    throw new Error("El mp3 dura menos que la intro.");
  }
  return Buffer.concat(frames.slice(inicio).map((f) => f.frame));
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
        // La intro se recorta del original y se comprime; la portada sale del original.
        ["intro.mp3", sinComprimir ? recortar(original, segundosIntro) : await comprimir(recortar(original, segundosIntro), kbpsIntro), "audio/mpeg"],
        ["original.mp3", sinComprimir ? original.subarray(finId3(original)) : await comprimir(original, kbpsOriginal), "audio/mpeg"],
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
