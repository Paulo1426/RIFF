import {
  coinBalance,
  coinsEarned,
  coinsEarnedByGenre,
  coinWalletBalance,
  introCoinRewards,
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
