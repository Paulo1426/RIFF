import {
  coleccion,
  coleccionJugador,
  conGenero,
  enCatalogo,
  esGenero,
  generoActual,
  idMezclado,
  ubicacion,
  vecino,
} from "../_shared/genero.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Se esperaba ${JSON.stringify(expected)} y llegó ${
        JSON.stringify(actual)
      }`,
    );
  }
}

Deno.test("colecciones con prefijo y un bucket por género con carpetas", () => {
  assertEquals(generoActual(), "vallenato");
  assertEquals(coleccion("songs"), "vallenato_songs");
  assertEquals(
    coleccion("privateLevelAnswers"),
    "vallenato_privateLevelAnswers",
  );
  assertEquals(ubicacion("instrumentos", "cancion-001/bateria.mp3"), {
    bucket: "vallenato",
    ruta: "instrumentos/cancion-001/bateria.mp3",
  });
  assertEquals(ubicacion("intro", "cancion-01/intro.mp3"), {
    bucket: "vallenato",
    ruta: "intro_vallenato/cancion-01/intro.mp3",
  });
  assertEquals(coleccionJugador("progress"), "progress");
});

Deno.test("cada petición usa su propio género", async () => {
  const [reggaeton, rock] = await Promise.all([
    conGenero("reggaeton", async () => {
      await new Promise((resolve) => setTimeout(resolve, 10));
      return [coleccion("levels"), coleccionJugador("progress")];
    }),
    conGenero("rock_pop", async () => {
      await new Promise((resolve) => setTimeout(resolve, 1));
      return [
        ubicacion("intro", "cancion-01/intro.mp3"),
        coleccionJugador("introProgress"),
      ];
    }),
  ]);
  assertEquals(reggaeton, ["reggaeton_levels", "reggaeton_progress"]);
  assertEquals(rock, [
    { bucket: "rock-pop", ruta: "intro_rock-pop/cancion-01/intro.mp3" },
    "rock_pop_introProgress",
  ]);
  assertEquals(conGenero("hackeo", generoActual), "vallenato");
  assertEquals(esGenero("hackeo"), false);
  assertEquals(generoActual(), "vallenato");
});

Deno.test("el progreso de canciones de Medley no comparte desbloqueos", () => {
  const normal = conGenero("vallenato", () => coleccionJugador("progress"));
  const medley = conGenero("aleatorio", () => coleccionJugador("progress"));

  assertEquals(normal, "progress");
  assertEquals(medley, "aleatorio_progress");
});

Deno.test("Medley mezcla los cinco catálogos con el género en el id", () => {
  conGenero("aleatorio", () => {
    assertEquals(idMezclado("salsa", "facil-03"), "salsa--facil-03");
    assertEquals(
      enCatalogo("levels", "salsa--facil-03"),
      "salsa_levels/facil-03",
    );
    assertEquals(
      enCatalogo("intros", "rock_pop--cancion-07"),
      "rock_pop_intros/cancion-07",
    );
    // La canción de un nivel vive en el catálogo de ese nivel.
    assertEquals(
      vecino("popular--medio-02", "cancion-008"),
      "popular--cancion-008",
    );
    assertEquals(coleccionJugador("progress"), "aleatorio_progress");
    let fallo = false;
    try {
      enCatalogo("levels", "facil-03");
    } catch {
      fallo = true;
    }
    assertEquals(fallo, true);
  });
  // Fuera de Medley los ids no cambian.
  assertEquals(enCatalogo("levels", "facil-03"), "vallenato_levels/facil-03");
  assertEquals(vecino("facil-03", "cancion-001"), "cancion-001");
});
