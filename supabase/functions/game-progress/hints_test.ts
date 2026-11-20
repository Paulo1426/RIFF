import {
  hintCosts,
  hintTypes,
  introHintTotal,
  introHintView,
  maskInitials,
  maskTitle,
  pickIntroHint,
  pickRandomHint,
  titleLetter,
} from "./hints.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Se esperaba ${JSON.stringify(expected)} y llegó ${
        JSON.stringify(actual)
      }`,
    );
  }
}

Deno.test("las iniciales dejan ver solo la primera letra de cada palabra", () => {
  assertEquals(
    maskInitials("Los caminos de la vida"),
    "L__ c______ d_ l_ v___",
  );
  assertEquals(maskInitials("¡Ay, corazón!"), "¡A_, c______!");
});

Deno.test("las casillas se destapan según las pistas compradas", () => {
  assertEquals(maskTitle("Los caminos", []), "___ _______");
  assertEquals(maskTitle("Los caminos", ["artist"]), "___ _______");
  assertEquals(maskTitle("Los caminos", ["initials"]), "L__ C______");
  assertEquals(
    maskTitle("¡Ay, corazón!", ["first_letter", "last_letter"]),
    "¡A_, ______N!",
  );
});

Deno.test("primera y última letra ignoran puntuación y espacios", () => {
  assertEquals(titleLetter("¡Ay, corazón!"), "A");
  assertEquals(titleLetter("¡Ay, corazón!", true), "N");
  assertEquals(titleLetter("90 60 90", true), "0");
  assertEquals(titleLetter("..."), "");
});

Deno.test("cada tipo de pista tiene precio", () => {
  for (const tipo of hintTypes) {
    assertEquals(typeof hintCosts[tipo as keyof typeof hintCosts], "number");
  }
  assertEquals(hintCosts, { random: 3, initials: 4, fourth_instrument: 5 });
});

Deno.test("la sorpresa solo da pistas que el jugador aún no tiene", () => {
  assertEquals(pickRandomHint([], () => 0), "first_letter");
  assertEquals(pickRandomHint(["first_letter"], () => 0), "last_letter");
  assertEquals(
    pickRandomHint(["first_letter", "artist"], (max) => max - 1),
    "last_letter",
  );
  assertEquals(
    pickRandomHint(["first_letter", "last_letter", "artist"], () => 0),
    null,
  );
});

Deno.test("pistas de intros: 3 o más palabras, palabra entera o inicial", () => {
  const t = "Mayor que yo";
  assertEquals(introHintTotal(t), 3);
  assertEquals(pickIntroHint(t, [], () => 0), "0:p");
  assertEquals(pickIntroHint(t, [], (max) => max - 1), "2:i");
  assertEquals(pickIntroHint(t, ["0:p", "2:i"], () => 0), "1:p");
  assertEquals(pickIntroHint(t, ["0:p", "1:i", "2:i"], () => 0), null);
  assertEquals(introHintView(t, ["2:p", "0:i"]), ["M", "", "yo"]);
});

Deno.test("pistas de intros: una palabra, inicial y luego letras", () => {
  assertEquals(introHintTotal("Lluvia"), 6);
  assertEquals(pickIntroHint("Lluvia", [], (max) => max - 1), "0:l:0");
  assertEquals(pickIntroHint("Lluvia", ["0:l:0"], () => 0), "0:l:1");
  assertEquals(
    introHintView("Lluvia", ["0:l:0", "0:l:3"]),
    ["L", "", "", "V", "", ""],
  );
  assertEquals(pickIntroHint("Hi", ["0:l:0", "0:l:1"], () => 0), null);
});

Deno.test("pistas de intros: dos palabras, siempre una inicial primero", () => {
  const t = "La Murga";
  assertEquals(introHintTotal(t), 7);
  assertEquals(pickIntroHint(t, [], (max) => max - 1), "1:l:0");
  // Segunda pista: la inicial de la otra palabra o una letra al azar.
  assertEquals(pickIntroHint(t, ["1:l:0"], () => 0), "0:l:0");
  assertEquals(pickIntroHint(t, ["1:l:0"], (max) => max - 1), "1:l:4");
  assertEquals(
    introHintView(t, ["1:l:0", "0:l:0"]),
    ["L", "", "/", "M", "", "", "", ""],
  );
});
