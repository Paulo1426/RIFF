import {
  hintCosts,
  hintTypes,
  introInitials,
  maskInitials,
  pickIntroHintWord,
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

Deno.test("pistas de intros: una inicial por palabra, sin repetir", () => {
  assertEquals(introInitials("¡Ay, corazón! 90"), ["A", "C", "9"]);
  assertEquals(introInitials("Lluvia"), ["L"]);
  assertEquals(pickIntroHintWord(3, [], () => 0), 0);
  assertEquals(pickIntroHintWord(3, [0, 2], () => 0), 1);
  assertEquals(pickIntroHintWord(2, [0, 1], () => 0), null);
});
