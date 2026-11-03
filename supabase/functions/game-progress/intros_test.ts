import {
  assignIntrosByPlayer,
  coinBalance,
  coinsEarned,
  coinsEarnedByGenre,
  coinWalletBalance,
  introCoinRewards,
  introsInMedley,
  introsPerGenre,
  introsPerGenreInMedley,
  savedWelcomeCoins,
  welcomeCoins,
} from "./intros.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Se esperaba ${JSON.stringify(expected)} y llegó ${
        JSON.stringify(actual)
      }`,
    );
  }
}

Deno.test("completar las tres dificultades paga exactamente 45 monedas", () => {
  const five = (prefix: string) =>
    [1, 2, 3, 4, 5].map((n) => `${prefix}-0${n}`);
  assertEquals(
    coinsEarned({
      facil: five("facil"),
      medio: five("media"),
      avanzado: five("dificil"),
    }),
    45,
  );
  assertEquals(Object.values(introCoinRewards), [2, 3, 4]);
});

Deno.test("repetir un nivel no vuelve a pagar", () => {
  assertEquals(coinsEarned({ facil: ["facil-01", "facil-01"] }), 2);
  assertEquals(coinsEarned({}), 0);
});

Deno.test("los niveles pagan monedas solo a su propio género", () => {
  const earned = coinsEarnedByGenre({
    vallenato: { facil: ["facil-01"] },
    aleatorio: { facil: ["vallenato--facil-01"] },
  });
  assertEquals(
    earned,
    { vallenato: 2, aleatorio: 2 },
  );
  assertEquals(coinWalletBalance(earned.vallenato, 0), 2);
  assertEquals(coinWalletBalance(0, 0, 0, welcomeCoins), 10);
  assertEquals(coinWalletBalance(earned.vallenato, 1, 1), 0);
});

Deno.test("el saldo descuenta una moneda por intro y nunca es negativo", () => {
  assertEquals(coinBalance(9, 4), 5);
  assertEquals(coinBalance(2, 5), 0);
});

Deno.test("el bono de bienvenida guardado sigue disponible al recargar", () => {
  const welcome = savedWelcomeCoins([
    { bonoBienvenida: true, monedasBienvenida: welcomeCoins },
  ]);
  assertEquals(welcome, 10);
  assertEquals(coinBalance(0, 0, 0, welcome), 10);
  assertEquals(coinBalance(0, 2, 3, welcome), 5);
  assertEquals(savedWelcomeCoins([{ bonoBienvenida: true }]), 0);
});

Deno.test("cada jugador recibe 30 intros propias y 15 distintas para Medley", () => {
  const ids = Array.from(
    { length: 45 },
    (_, index) => `cancion-${String(index + 1).padStart(2, "0")}`,
  );
  const genres = ["vallenato", "reggaeton", "rock_pop", "salsa", "popular"];
  const first = assignIntrosByPlayer(ids, "usuario-1", "vallenato");
  const second = assignIntrosByPlayer(ids, "usuario-2", "vallenato");
  const medley = genres.flatMap((genre) =>
    assignIntrosByPlayer(ids, "usuario-1", genre).medley.map((id) =>
      `${genre}--${id}`
    )
  );

  assertEquals(first.personal.length, introsPerGenre);
  assertEquals(first.medley.length, introsPerGenreInMedley);
  assertEquals(medley.length, introsInMedley);
  assertEquals(new Set(medley).size, introsInMedley);
  assertEquals(
    first.personal.some((id) => first.medley.includes(id)),
    false,
  );
  assertEquals(
    [...first.personal, ...first.medley].length,
    new Set([...first.personal, ...first.medley]).size,
  );
  assertEquals(
    JSON.stringify(first),
    JSON.stringify(assignIntrosByPlayer(ids, "usuario-1", "vallenato")),
  );
  assertEquals(
    first.personal.every((id) => second.personal.includes(id)),
    false,
  );
});

Deno.test("la reasignación conserva las intros ya desbloqueadas", () => {
  const ids = Array.from(
    { length: 45 },
    (_, index) => `cancion-${String(index + 1).padStart(2, "0")}`,
  );
  const original = assignIntrosByPlayer(ids, "usuario", "salsa");
  const medleyId = `salsa--${original.medley[0]}`;
  const updated = assignIntrosByPlayer(
    ids,
    "usuario",
    "salsa",
    [original.personal[0]],
    [medleyId],
  );

  assertEquals(updated.personal.includes(original.personal[0]), true);
  assertEquals(updated.medley.includes(original.medley[0]), true);

  const sharedId = original.personal[1];
  const repartitioned = assignIntrosByPlayer(
    ids,
    "usuario",
    "salsa",
    [sharedId],
    [`salsa--${sharedId}`],
  );
  assertEquals(repartitioned.personal.includes(sharedId), true);
  assertEquals(repartitioned.medley.includes(sharedId), false);

  const medleyOnlyId = original.personal[2];
  const moved = assignIntrosByPlayer(
    ids,
    "usuario",
    "salsa",
    [],
    [`salsa--${medleyOnlyId}`],
  );
  assertEquals(moved.personal.includes(medleyOnlyId), false);
  assertEquals(moved.medley.includes(medleyOnlyId), true);
});
